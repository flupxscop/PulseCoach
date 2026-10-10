import Foundation
import Observation
import WatchConnectivity
import WidgetKit
import PulseCore

/// Receives the latest plan and readiness from the iPhone and keeps a copy on disk,
/// so the watch still has today's plan when the phone is out of range.
@MainActor
@Observable
final class PlanStore: NSObject {
    private(set) var payload: SyncPayload?

    override init() {
        super.init()
        if let cached = PayloadCache.load() {
            payload = cached
        } else {
            #if targetEnvironment(simulator)
            payload = SyncPayload(plan: SampleData.plan(), readiness: SampleData.readiness, today: SampleData.today())
            #endif
        }
    }

    var readiness: Readiness? { payload?.readiness }
    var plan: PlanDTO? { payload?.plan }
    var today: DayDTO? { payload?.plan.day(for: .now) }
    var metrics: DailyMetrics? { payload?.today }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    fileprivate func apply(_ context: [String: Any]) {
        guard let decoded = try? SyncPayload.decode(from: context) else { return }
        payload = decoded
        if let data = context["payload"] as? Data {
            // Shared App Group cache: the complication reads the same copy.
            PayloadCache.save(data)
            WidgetCenter.shared.reloadTimelines(ofKind: "Readiness")
        }
    }
}

extension PlanStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        // Pick up anything the phone sent while the watch app wasn't running.
        guard let data = session.receivedApplicationContext["payload"] as? Data else { return }
        Task { @MainActor in self.apply(["payload": data]) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Pull out Data (Sendable) before hopping to the main actor.
        guard let data = applicationContext["payload"] as? Data else { return }
        Task { @MainActor in self.apply(["payload": data]) }
    }
}
