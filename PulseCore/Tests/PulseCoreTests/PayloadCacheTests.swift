import Foundation
import Testing
@testable import PulseCore

@Test func payloadCacheRoundTripsSyncData() throws {
    let start = Date(timeIntervalSince1970: 1_791_500_000)
    let payload = SyncPayload(plan: SampleData.plan(start: start), readiness: Readiness(score: 85, flags: [.shortSleep]),
                              today: SampleData.today(start), sentAt: start)
    let data = try #require(payload.applicationContext()[SyncPayload.key] as? Data)

    let previous = PayloadCache.defaults.data(forKey: PayloadCache.key)
    defer {
        if let previous { PayloadCache.save(previous) } else { PayloadCache.defaults.removeObject(forKey: PayloadCache.key) }
    }

    PayloadCache.save(data)
    #expect(PayloadCache.load() == payload)
}
