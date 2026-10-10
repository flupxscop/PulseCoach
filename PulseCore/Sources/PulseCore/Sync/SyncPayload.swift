import Foundation

/// What the iPhone sends to the watch via WatchConnectivity `updateApplicationContext`.
/// Only the latest value matters, and health data never leaves the user's devices.
public struct SyncPayload: Codable, Sendable, Equatable {
    public var plan: PlanDTO
    public var readiness: Readiness
    public var today: DailyMetrics?
    public var sentAt: Date

    public init(plan: PlanDTO, readiness: Readiness, today: DailyMetrics?, sentAt: Date = .now) {
        self.plan = plan
        self.readiness = readiness
        self.today = today
        self.sentAt = sentAt
    }

    static let key = "payload"

    /// Application-context dictionaries must hold property-list values, so the payload travels as JSON `Data`.
    public func applicationContext() throws -> [String: Any] {
        [Self.key: try Self.encoder.encode(self)]
    }

    public static func decode(from context: [String: Any]) throws -> SyncPayload? {
        guard let data = context[key] as? Data else { return nil }
        return try decoder.decode(SyncPayload.self, from: data)
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
