import Foundation
import Testing
@testable import PulseCore

private let start = Date(timeIntervalSince1970: 1_791_500_000)
private let good = Readiness(score: 100, flags: [])
private let low = Readiness(score: 40, flags: [.elevatedRestingHR, .lowHRV])

private func plan(_ days: [DayDTO]) -> PlanDTO {
    PlanDTO(createdAt: start, rationale: "", days: days, source: .onDeviceModel)
}

private func day(_ i: Int, _ a: ActivityKind, _ intensity: IntensityLevel, _ min: Int = 30) -> DayDTO {
    DayDTO(dayIndex: i, activity: a, minutes: min, intensity: intensity, tip: "")
}

// MARK: - SafetyValidator

@Test func lowReadinessMakesDayOneEasy() {
    let p = SafetyValidator.enforce(plan((1...7).map { day($0, .hiit, .hard, 45) }), readiness: low)
    #expect(p.days[0].intensity == .easy)
    #expect(p.days[0].minutes <= 30)
    #expect(p.days[0].activity == .walk)
}

@Test func noBackToBackHardDays() {
    let p = SafetyValidator.enforce(plan((1...7).map { day($0, .run, .hard) }), readiness: good)
    for i in p.days.indices.dropFirst() {
        #expect(!(p.days[i].intensity == .hard && p.days[i - 1].intensity == .hard))
    }
}

@Test func atLeastOneRestDay() {
    let p = SafetyValidator.enforce(plan((1...7).map { day($0, .walk, .easy) }), readiness: good)
    #expect(p.days.contains { $0.isRest })
}

@Test func normalisesToSevenOrderedDays() {
    let p = SafetyValidator.enforce(plan([day(5, .run, .easy), day(2, .yoga, .easy)]), readiness: good)
    #expect(p.days.count == 7)
    #expect(p.days.map(\.dayIndex) == Array(1...7))
    #expect(p.days[0].activity == .yoga)
}

@Test func restDaysCarryNoLoad() {
    let p = SafetyValidator.enforce(plan([day(1, .rest, .hard, 40)] + (2...7).map { day($0, .walk, .easy) }),
                                    readiness: good)
    #expect(p.days[0].minutes == 0 && p.days[0].intensity == .easy)
}

// MARK: - RuleBasedPlanner

@Test(arguments: FitnessGoal.allCases, [3, 5, 7])
func ruleBasedPlanIsAlwaysSafe(goal: FitnessGoal, daysPerWeek: Int) {
    let profile = UserProfile(goal: goal, daysPerWeek: daysPerWeek, maxMinutes: 40)
    let p = SafetyValidator.enforce(RuleBasedPlanner().makePlan(profile: profile, readiness: good, startingOn: start),
                                    readiness: good)
    #expect(p.days.count == 7)
    #expect(p.days.contains { $0.isRest })
    #expect(p.days.allSatisfy { $0.minutes <= 40 })
    #expect(!p.days[0].isRest)
    #expect(p.source == .ruleBased)
}

@Test func ruleBasedRespectsActiveDays() {
    let p = RuleBasedPlanner().makePlan(profile: UserProfile(daysPerWeek: 4), readiness: good, startingOn: start)
    #expect(p.days.filter { !$0.isRest }.count == 4)
}

@Test func ruleBasedLowReadinessStartsWithWalk() {
    let p = RuleBasedPlanner().makePlan(profile: UserProfile(), readiness: low, startingOn: start)
    #expect(p.days[0].activity == .walk && p.days[0].intensity == .easy)
}

// MARK: - FallbackPlanner

private struct FailingPlanner: WorkoutPlanner {
    func makePlan(profile: UserProfile, readiness: Readiness,
                  recent: [DailyMetrics], startingOn start: Date) async throws -> PlanDTO {
        throw PlannerError.modelUnavailable
    }
}

private struct RecklessPlanner: WorkoutPlanner {
    func makePlan(profile: UserProfile, readiness: Readiness,
                  recent: [DailyMetrics], startingOn start: Date) async throws -> PlanDTO {
        plan((1...7).map { day($0, .hiit, .hard, 60) })
    }
}

@Test func fallbackUsesRulesWhenModelFails() async throws {
    let p = try await FallbackPlanner([FailingPlanner()])
        .makePlan(profile: UserProfile(), readiness: good, recent: [], startingOn: start)
    #expect(p.source == .ruleBased)
}

@Test func fallbackStillValidatesModelOutput() async throws {
    let p = try await FallbackPlanner([RecklessPlanner()])
        .makePlan(profile: UserProfile(), readiness: low, recent: [], startingOn: start)
    #expect(p.days[0].intensity == .easy)
    #expect(p.days.contains { $0.isRest })
}

private struct SlowPlanner: WorkoutPlanner {
    func makePlan(profile: UserProfile, readiness: Readiness,
                  recent: [DailyMetrics], startingOn start: Date) async throws -> PlanDTO {
        try await Task.sleep(for: .seconds(30))
        return plan((1...7).map { day($0, .run, .hard) })
    }
}

/// DEF-02: a stuck on-device model must fall back instead of spinning forever.
@Test func fallbackTimesOutSlowPlanner() async throws {
    let clock = ContinuousClock()
    let started = clock.now
    let p = try await FallbackPlanner([SlowPlanner()], timeout: .milliseconds(100))
        .makePlan(profile: UserProfile(), readiness: good, recent: [], startingOn: start)
    #expect(p.source == .ruleBased)
    #expect(clock.now - started < .seconds(5))
}

// MARK: - PlanAdjuster

@Test func moveToNextDaySwapsAndRenumbers() {
    let p0 = plan([day(1, .run, .moderate), day(2, .yoga, .easy)] + (3...7).map { day($0, .walk, .easy) } )
    let p = PlanAdjuster.moveToNextDay(p0, dayIndex: 1, readiness: good)
    #expect(p.days[0].activity == .yoga && p.days[0].dayIndex == 1)
    #expect(p.days[1].activity == .run && p.days[1].dayIndex == 2)
}

@Test func moveCannotCreateBackToBackHardDays() {
    let p0 = plan([day(1, .hiit, .hard), day(2, .walk, .easy), day(3, .hiit, .hard),
                   day(4, .walk, .easy), day(5, .walk, .easy), day(6, .walk, .easy), day(7, .rest, .easy, 0)])
    let p = PlanAdjuster.moveToNextDay(p0, dayIndex: 1, readiness: good)
    #expect(p.days[1].intensity == .hard)
    #expect(p.days[2].intensity == .moderate)
}

@Test func makeEasierLowersIntensityAndTime() {
    let p0 = plan([day(1, .hiit, .hard, 30)] + (2...7).map { day($0, .walk, .easy) })
    let p = PlanAdjuster.makeEasier(p0, dayIndex: 1, readiness: good)
    #expect(p.days[0].intensity == .moderate)
    #expect(p.days[0].minutes == 20)
    #expect(p.days[0].activity == .cycle)
}

/// DEF-08: no odd durations like "23 นาที".
@Test func makeEasierRoundsToFiveMinutes() {
    let p0 = plan([day(1, .run, .moderate, 35)] + (2...7).map { day($0, .walk, .easy) })
    let p = PlanAdjuster.makeEasier(p0, dayIndex: 1, readiness: good)
    #expect(p.days[0].minutes % 5 == 0)
    #expect(p.days[0].minutes == 25)
}

@Test func lastDayCannotMoveForward() {
    let p0 = SafetyValidator.enforce(plan((1...7).map { day($0, .walk, .easy) }), readiness: good)
    #expect(PlanAdjuster.moveToNextDay(p0, dayIndex: 7, readiness: good) == p0)
}

// MARK: - Plan lookup & sync

@Test func dayForDateCountsFromCreation() throws {
    let p = SafetyValidator.enforce(plan((1...7).map { day($0, .walk, .easy) }), readiness: good)
    let cal = Calendar(identifier: .gregorian)
    let third = try #require(cal.date(byAdding: .day, value: 2, to: start))
    #expect(p.day(for: third, calendar: cal)?.dayIndex == 3)
    let later = try #require(cal.date(byAdding: .day, value: 9, to: start))
    #expect(p.day(for: later, calendar: cal) == nil)
}

@Test func syncPayloadRoundTrips() throws {
    let p = RuleBasedPlanner().makePlan(profile: UserProfile(), readiness: good, startingOn: start)
    let payload = SyncPayload(plan: p, readiness: good,
                              today: DailyMetrics(date: start, restingHR: 58, hrv: 54, spo2: nil, sleepHours: 7.4, steps: 1200),
                              sentAt: start)
    let decoded = try SyncPayload.decode(from: payload.applicationContext())
    #expect(decoded == payload)
}
