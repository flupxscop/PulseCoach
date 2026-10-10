import Foundation
import WatchConnectivity
import PulseCore

/// Sends the latest plan + readiness to the watch with `updateApplicationContext`:
/// only the newest value is kept, it arrives even if the watch app isn't running,
/// and health data never goes through a server.
@MainActor
final class PhoneSync: NSObject {
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    var isWatchAppInstalled: Bool {
        guard let session, session.activationState == .activated else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    /// Asks the watch app to open Gym Mode. Needs the watch app to be reachable (open, nearby).
    func startGym() -> Bool {
        guard let session, session.activationState == .activated, session.isReachable else { return false }
        session.sendMessage(["startGym": true], replyHandler: nil)
        return true
    }

    /// Returns true when the context was handed to WatchConnectivity.
    @discardableResult
    func send(_ payload: SyncPayload) -> Bool {
        guard let session, session.activationState == .activated, session.isPaired else { return false }
        do {
            try session.updateApplicationContext(payload.applicationContext())
            return true
        } catch {
            return false
        }
    }
}

extension PhoneSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after switching to a different paired watch.
        session.activate()
    }
}
