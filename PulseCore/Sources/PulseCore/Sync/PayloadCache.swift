import Foundation

/// The latest `SyncPayload`, stored in the App Group shared by the watch app and its widget,
/// so the complication can show readiness without the app running.
public enum PayloadCache {
    public static let appGroup = "group.com.pulsecoach.app"
    static let key = "lastPayload"

    /// Falls back to standard defaults when the App Group isn't provisioned (unsigned simulator builds).
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    /// Stores the JSON `Data` exactly as it arrived over WatchConnectivity.
    public static func save(_ data: Data) {
        defaults.set(data, forKey: key)
    }

    public static func load() -> SyncPayload? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? SyncPayload.decode(from: [SyncPayload.key: data])
    }
}
