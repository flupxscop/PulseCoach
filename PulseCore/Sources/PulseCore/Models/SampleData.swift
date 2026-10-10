import Foundation

/// Deterministic demo data for SwiftUI previews, the simulator (no sensors)
/// and the App Review "demo mode" the guide's checklist asks for.
public enum SampleData {
    public static func history(days: Int = 28, endingBefore end: Date = .now,
                               calendar: Calendar = .current) -> [DailyMetrics] {
        (1...days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: end)) else {
                return nil
            }
            // Small repeatable wobble around a resting HR of 57 and HRV of 51.
            let wobble = Double((offset * 7) % 5) - 2
            return DailyMetrics(date: date, restingHR: 57 + wobble, hrv: 51 - wobble,
                                spo2: 0.97, sleepHours: 6.9 + wobble / 10, steps: 7000 + wobble * 500)
        }
    }

    public static func today(_ date: Date = .now, calendar: Calendar = .current) -> DailyMetrics {
        DailyMetrics(date: calendar.startOfDay(for: date), restingHR: 58, hrv: 54,
                     spo2: 0.97, sleepHours: 7.4, steps: 3200)
    }

    public static let readiness = Readiness(score: 100, flags: [])

    public static func plan(start: Date = .now) -> PlanDTO {
        SafetyValidator.enforce(
            RuleBasedPlanner().makePlan(profile: UserProfile(), readiness: readiness, startingOn: start),
            readiness: readiness)
    }
}
