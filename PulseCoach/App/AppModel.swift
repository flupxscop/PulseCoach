import Foundation
import Observation
import PulseCore

enum AppTab: Hashable { case today, plan, body }

/// iPhone is the "brain": it reads HealthKit, scores readiness, builds the plan
/// (on-device LLM with rule-based fallback) and pushes everything to the watch.
@MainActor
@Observable
final class AppModel {
    // Persisted
    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) } }
    var profile: UserProfile { didSet { save(profile, Keys.profile) } }
    var plan: PlanDTO? { didSet { save(plan, Keys.plan) } }
    var demoMode: Bool { didSet { defaults.set(demoMode, forKey: Keys.demo) } }

    // Derived from health data
    var today: DailyMetrics?
    var baseline = Baseline()
    var readiness: Readiness?
    var checks: [ReadinessCheck] = []

    /// False when HealthKit returned nothing readiness can use (not worn at night, permission off).
    var hasHealthData: Bool { today?.hasReadinessData ?? false }

    /// What the UI shows. Never a confident score without data behind it.
    var displayReadiness: Readiness? { hasHealthData ? readiness : nil }

    // UI state
    var selectedTab: AppTab = .today
    var isGeneratingPlan = false
    var lastSyncedAt: Date?

    let health = HealthService()
    private let engine = ReadinessEngine()
    private let defaults = UserDefaults.standard
    private let sync = PhoneSync()
    private let notifier = GentleNotifier()

    init() {
        Self.applyUITestArguments()
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        profile = Self.load(UserProfile.self, Keys.profile) ?? UserProfile()
        plan = Self.load(PlanDTO.self, Keys.plan)
        #if targetEnvironment(simulator)
        demoMode = defaults.object(forKey: Keys.demo) as? Bool ?? true
        #else
        demoMode = defaults.bool(forKey: Keys.demo)
        #endif
    }

    var todayPlan: DayDTO? { plan?.day(for: .now) }

    /// Launch arguments used only by PulseCoachUITests to start from a known state.
    /// `-uiTestReset` clears saved state, `-uiTestOnboarded` skips onboarding with demo data,
    /// `-uiTestNoData` turns demo data off to exercise the empty states.
    private static func applyUITestArguments() {
        let args = ProcessInfo.processInfo.arguments
        let defaults = UserDefaults.standard
        if args.contains("-uiTestReset") {
            // removePersistentDomain can be served stale from the prefs cache; remove keys one by one.
            for key in [Keys.onboarded, Keys.profile, Keys.plan, Keys.demo] {
                defaults.removeObject(forKey: key)
            }
        }
        if args.contains("-uiTestOnboarded") {
            defaults.set(true, forKey: Keys.onboarded)
            defaults.set(true, forKey: Keys.demo)
        }
        if args.contains("-uiTestNoData") {
            defaults.set(false, forKey: Keys.demo)
        }
    }

    // MARK: - Lifecycle

    func start() async {
        sync.activate()
        guard hasOnboarded else { return }
        await refresh()
        try? await health.observeRestingHR { [weak self] in
            await self?.refresh()
        }
    }

    func completeOnboarding(with profile: UserProfile) async {
        self.profile = profile
        hasOnboarded = true
        try? await health.requestAuthorization()
        await refresh(forceNewPlan: true)
    }

    /// Re-reads health data, scores readiness, and makes a new plan when the old one is out of date.
    func refresh(forceNewPlan: Bool = false) async {
        let history: [DailyMetrics]
        let todayMetrics: DailyMetrics
        if demoMode {
            history = SampleData.history()
            todayMetrics = SampleData.today()
        } else {
            history = await health.history(days: 28)
            todayMetrics = await health.dailyMetrics(for: .now)
        }
        today = todayMetrics
        baseline = Baseline.from(history: history)
        // Without data, plan from a neutral readiness instead of a misleading 100.
        let newReadiness = todayMetrics.hasReadinessData
            ? engine.evaluate(today: todayMetrics, baseline: baseline)
            : .unknown
        checks = engine.explain(today: todayMetrics, baseline: baseline)
        let previousFlags = Set(readiness?.flags ?? [])
        readiness = newReadiness
        await notifier.notifyIfNeeded(newFlags: Set(newReadiness.flags).subtracting(previousFlags))

        if forceNewPlan || plan == nil || todayPlan == nil {
            await generatePlan(recent: history)
        } else {
            pushToWatch()
        }
    }

    func requestHealthAccess() async {
        try? await health.requestAuthorization()
        await refresh()
    }

    // MARK: - Plan

    func generatePlan(recent: [DailyMetrics]? = nil) async {
        guard let readiness else { return }
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }
        let planner = FallbackPlanner([OnDevicePlanner(health: health)])
        plan = try? await planner.makePlan(profile: profile, readiness: readiness,
                                           recent: recent ?? [], startingOn: .now)
        await applyPlan()
    }

    /// Returns the plan before the change so the UI can offer "เลิกทำ".
    @discardableResult
    func moveToNextDay(_ day: DayDTO) async -> PlanDTO? {
        guard let plan, let readiness else { return nil }
        self.plan = PlanAdjuster.moveToNextDay(plan, dayIndex: day.dayIndex, readiness: readiness)
        await applyPlan()
        return plan
    }

    @discardableResult
    func makeEasier(_ day: DayDTO) async -> PlanDTO? {
        guard let plan, let readiness else { return nil }
        self.plan = PlanAdjuster.makeEasier(plan, dayIndex: day.dayIndex, readiness: readiness)
        await applyPlan()
        return plan
    }

    func restore(_ previous: PlanDTO) async {
        plan = previous
        await applyPlan()
    }

    /// Sync to the watch app and the system Workout app. Both happen automatically,
    /// so the user never has to remember to "send" a plan.
    private func applyPlan() async {
        await notifier.scheduleReminders(hour: profile.preferredTime.scheduleHour)
        pushToWatch()
        if let plan, !demoMode {
            await WorkoutScheduling.schedule(plan, hour: profile.preferredTime.scheduleHour)
        }
    }

    private func pushToWatch() {
        guard let plan, let readiness else { return }
        if sync.send(SyncPayload(plan: plan, readiness: readiness, today: today)) {
            lastSyncedAt = .now
        }
    }

    var isWatchReachable: Bool { sync.isWatchAppInstalled }

    func updateReminders() async {
        await notifier.scheduleReminders(hour: profile.preferredTime.scheduleHour)
    }

    /// "เริ่มบน Apple Watch" from the gym guide. False when the watch app isn't reachable.
    func startGymOnWatch() -> Bool { sync.startGym() }

    // MARK: - Persistence

    private enum Keys {
        static let onboarded = "onboarded"
        static let profile = "profile"
        static let plan = "plan"
        static let demo = "demoMode"
    }

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
