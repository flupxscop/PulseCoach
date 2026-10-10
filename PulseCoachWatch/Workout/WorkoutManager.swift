import Foundation
import HealthKit
import Observation

/// Live workout session: high-frequency heart rate while the user trains,
/// saved to Health when they finish. Requires the "Workout processing" background mode.
@MainActor
@Observable
final class WorkoutManager: NSObject {
    private let store: HKHealthStore
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var heartRate: Double = 0
    var averageHeartRate: Double = 0
    var activeEnergy: Double = 0
    var state: HKWorkoutSessionState = .notStarted
    var startDate: Date?
    var lastError: String?

    init(store: HKHealthStore) { self.store = store }

    var isActive: Bool { state == .running || state == .paused }

    func start(_ activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType = .outdoor) async {
        let config = HKWorkoutConfiguration()
        config.activityType = activity
        config.locationType = location
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            startDate = start
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func togglePause() {
        state == .paused ? session?.resume() : session?.pause()
    }

    /// Ends and saves to Health.
    func finish() async {
        session?.end()
        do {
            try await builder?.endCollection(at: .now)
            _ = try await builder?.finishWorkout()
        } catch {
            lastError = error.localizedDescription
        }
        reset()
    }

    /// Ends without saving (the destructive option on the confirm screen).
    func discard() {
        session?.end()
        builder?.discardWorkout()
        reset()
    }

    private func reset() {
        session = nil
        builder = nil
        heartRate = 0
        averageHeartRate = 0
        activeEnergy = 0
        startDate = nil
        state = .notStarted
    }
}

// HealthKit calls these on its own queue: stay nonisolated, convert to Sendable values,
// then hop back to the main actor.
extension WorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ s: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in self.state = toState }
    }

    nonisolated func workoutSession(_ s: HKWorkoutSession, didFailWithError error: Error) {
        // e.g. another workout started: only one session can run at a time.
        let message = error.localizedDescription
        Task { @MainActor in
            self.lastError = message
            self.state = .ended
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ b: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ b: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let hrStats = b.statistics(for: HKQuantityType(.heartRate))
        let bpm = hrStats?.mostRecentQuantity()?.doubleValue(for: bpmUnit)
        let avg = hrStats?.averageQuantity()?.doubleValue(for: bpmUnit)
        let kcal = b.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        Task { @MainActor in
            if let bpm { self.heartRate = bpm }
            if let avg { self.averageHeartRate = avg }
            if let kcal { self.activeEnergy = kcal }
        }
    }
}
