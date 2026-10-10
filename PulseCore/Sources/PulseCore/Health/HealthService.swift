#if os(iOS) || os(watchOS)
import Foundation
import HealthKit
import Observation

public enum HealthError: Error { case unavailable }

/// Reads HealthKit and flattens it into `DailyMetrics`.
/// HealthKit never reports denied *read* access (privacy), it just returns empty results,
/// so every value stays optional and the UI shows "–" rather than 0.
@MainActor
@Observable
public final class HealthService {
    public let store = HKHealthStore()

    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKCategoryType(.sleepAnalysis),
        HKObjectType.workoutType()
    ]

    static let shareTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned)
    ]

    public init() {}

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
    }

    // MARK: - Queries

    /// Average of a discrete quantity type in a window.
    public func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                        from start: Date, to end: Date) async throws -> Double? {
        let type = HKQuantityType(id)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .discreteAverage
        )
        let stats = try await descriptor.result(for: store)
        return stats?.averageQuantity()?.doubleValue(for: unit)
    }

    /// Step count is cumulative, so it uses `.cumulativeSum`, not an average.
    public func steps(from start: Date, to end: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate),
            options: .cumulativeSum
        )
        return try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: .count()) ?? 0
    }

    /// Hours actually asleep (excludes in-bed and awake stages).
    public func sleepHours(from start: Date, to end: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let asleep = samples.filter { asleepValues.contains($0.value) }
        guard !asleep.isEmpty else { return nil }
        return asleep.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600
    }

    // MARK: - Daily metrics

    /// Metrics for the calendar day containing `date`. Sleep is counted from 18:00 the evening before.
    public func dailyMetrics(for date: Date, calendar: Calendar = .current) async -> DailyMetrics {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let sleepStart = calendar.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
        let sleepEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayEnd
        let bpm = HKUnit.count().unitDivided(by: .minute())

        async let rhr = try? average(.restingHeartRate, unit: bpm, from: dayStart, to: dayEnd)
        async let hrv = try? average(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: dayStart, to: dayEnd)
        async let spo2 = try? average(.oxygenSaturation, unit: .percent(), from: dayStart, to: dayEnd)
        async let sleep = try? sleepHours(from: sleepStart, to: sleepEnd)
        async let stepCount = try? steps(from: dayStart, to: dayEnd)

        return await DailyMetrics(date: dayStart, restingHR: rhr ?? nil, hrv: hrv ?? nil,
                                  spo2: spo2 ?? nil, sleepHours: sleep ?? nil, steps: stepCount ?? 0)
    }

    /// The previous `days` days, oldest first, for the baseline window.
    public func history(days: Int = 28, endingBefore date: Date = .now) async -> [DailyMetrics] {
        var out: [DailyMetrics] = []
        for offset in stride(from: days, through: 1, by: -1) {
            guard let d = Calendar.current.date(byAdding: .day, value: -offset, to: date) else { continue }
            out.append(await dailyMetrics(for: d))
        }
        return out
    }

    // MARK: - Workouts

    /// One-line summaries of recent workouts, used by the planner's tool call.
    public func recentWorkoutSummaries(days: Int) async -> [String] {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 20
        )
        guard let workouts = try? await descriptor.result(for: store) else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return workouts.map { w in
            let minutes = Int(w.duration / 60)
            return "\(formatter.string(from: w.startDate)): activity \(w.workoutActivityType.rawValue), \(minutes) min"
        }
    }

    // MARK: - Background delivery

    /// Re-evaluates readiness when a new resting heart rate arrives. `.hourly` is enough:
    /// these values change a few times a day and the system throttles delivery anyway.
    public func observeRestingHR(onChange: @escaping @Sendable () async -> Void) async throws {
        let type = HKQuantityType(.restingHeartRate)
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            // HealthKit's completion isn't annotated Sendable; it is safe to call once from any thread.
            nonisolated(unsafe) let done = completion
            Task {
                await onChange()
                done()   // must always be called or the system wakes the app less often
            }
        }
        store.execute(query)
        try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
    }
}
#endif
