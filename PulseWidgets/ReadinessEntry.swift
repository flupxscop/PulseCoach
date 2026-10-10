import Foundation
import WidgetKit
import PulseCore

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let score: Int?
    let shortHeadline: String?
    let day: DayDTO?

    /// Entry for `date` built from the cached payload; `nil` payload shows "–" rather than a fake 0.
    init(date: Date, payload: SyncPayload?) {
        self.date = date
        // No health data behind the score -> show "–", never a confident 100.
        let hasData = payload?.today?.hasReadinessData ?? false
        score = hasData ? payload?.readiness.score : nil
        shortHeadline = hasData ? payload?.readiness.shortHeadline : nil
        day = payload?.plan.day(for: date)
    }

    static let sample = ReadinessEntry(
        date: .now,
        payload: SyncPayload(plan: SampleData.plan(), readiness: Readiness(score: 82, flags: []), today: SampleData.today())
    )

    static let empty = ReadinessEntry(date: .now, payload: nil)
}

struct ReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(context.isPreview ? .sample : ReadinessEntry(date: .now, payload: PayloadCache.load()))
    }

    /// Readiness changes a few times a day and the app reloads us when it does,
    /// so the timeline only needs one entry per day boundary (today's activity changes at midnight).
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let payload = PayloadCache.load()
        let calendar = Calendar.current
        let now = Date.now
        var entries = [ReadinessEntry(date: now, payload: payload)]
        for offset in 1...2 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) {
                entries.append(ReadinessEntry(date: midnight, payload: payload))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
