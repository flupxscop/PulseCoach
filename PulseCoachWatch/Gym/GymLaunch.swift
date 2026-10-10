import Foundation
import Observation
import WatchConnectivity

/// Opens Gym Mode on the watch when the iPhone guide taps "เริ่มบน Apple Watch",
/// or when launched with `-gymDemo` / `-gymRestDemo` (simulator screenshots).
@MainActor
@Observable
final class GymLauncher {
    static let shared = GymLauncher()

    var isPresented = false
    var demo: GymSessionView.Demo = .none

    private init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-gymRestDemo") {
            demo = .rest
            isPresented = true
        } else if args.contains("-gymDemo") {
            demo = .exercise
            isPresented = true
        }
    }
}

extension PlanStore {
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["startGym"] as? Bool == true else { return }
        Task { @MainActor in GymLauncher.shared.isPresented = true }
    }
}
