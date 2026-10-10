import Foundation
import HealthKit
import WorkoutKit
import PulseCore

/// Turns plan days into WorkoutKit custom workouts that appear in the watch's Workout app,
/// which already handles GPS, lap alerts, rings and battery better than a custom screen.
enum WorkoutScheduling {
    static func activityType(_ kind: ActivityKind) -> HKWorkoutActivityType {
        switch kind {
        case .walk: .walking
        case .run: .running
        case .cycle: .cycling
        case .strength: .traditionalStrengthTraining
        case .hiit: .highIntensityIntervalTraining
        case .yoga: .yoga
        case .rest: .other
        }
    }

    static func customWorkout(for day: DayDTO) -> CustomWorkout? {
        guard !day.isRest, day.minutes >= 15 else { return nil }
        let activity = activityType(day.activity)
        guard CustomWorkout.supportsActivity(activity) else { return nil }

        let mainMinutes = Double(day.minutes - 10)   // 5 min warm-up + 5 min cool-down
        let work = IntervalStep(.work,
                                goal: .time(mainMinutes, .minutes),
                                alert: .heartRate(zone: day.intensity.heartRateZone))
        return CustomWorkout(
            activity: activity,
            location: .outdoor,
            displayName: "PulseCoach · \(day.activity.displayName)",
            warmup: WorkoutStep(goal: .time(5, .minutes)),
            blocks: [IntervalBlock(steps: [work], iterations: 1)],
            cooldown: WorkoutStep(goal: .time(5, .minutes))
        )
    }

    static func workoutPlan(for day: DayDTO) -> WorkoutPlan? {
        customWorkout(for: day).map { WorkoutPlan(.custom($0)) }
    }

    /// Replaces previously scheduled PulseCoach workouts with the current plan.
    @MainActor
    static func schedule(_ plan: PlanDTO, hour: Int) async {
        let scheduler = WorkoutScheduler.shared
        guard await scheduler.requestAuthorization() == .authorized else { return }

        for scheduled in await scheduler.scheduledWorkouts {
            await scheduler.remove(scheduled.plan, at: scheduled.date)
        }

        let calendar = Calendar.current
        for day in plan.days {
            guard let workout = workoutPlan(for: day),
                  let date = calendar.date(byAdding: .day, value: day.dayIndex - 1, to: plan.createdAt)
            else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: date)
            comps.hour = hour
            await scheduler.schedule(workout, at: comps)
        }
    }
}
