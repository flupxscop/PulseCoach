import Foundation

/// One day of health data, flattened from HealthKit into plain values.
/// Every value except steps is optional: the user may not wear the watch to bed
/// or may not grant a permission, and "no data" must never read as "bad data".
public struct DailyMetrics: Sendable, Codable, Equatable {
    public var date: Date
    public var restingHR: Double?     // bpm
    public var hrv: Double?           // ms (SDNN)
    public var spo2: Double?          // 0...1
    public var sleepHours: Double?
    public var steps: Double

    public init(date: Date, restingHR: Double?, hrv: Double?,
                spo2: Double?, sleepHours: Double?, steps: Double) {
        self.date = date
        self.restingHR = restingHR
        self.hrv = hrv
        self.spo2 = spo2
        self.sleepHours = sleepHours
        self.steps = steps
    }

    /// False when none of the values readiness depends on are present (no watch at night,
    /// no Health permission). The UI must then say "no data" instead of showing a perfect score.
    public var hasReadinessData: Bool {
        restingHR != nil || hrv != nil || sleepHours != nil || spo2 != nil
    }
}
