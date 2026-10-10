import SwiftUI
import WidgetKit

@main
struct PulseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ReadinessWidget()
    }
}

/// Watch-face complication. The kind string must match `PlanStore`'s reload call.
struct ReadinessWidget: Widget {
    static let kind = "Readiness"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ReadinessProvider()) { entry in
            ReadinessWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ความพร้อม")
        .description("คะแนนความพร้อมและแผนออกกำลังกายวันนี้")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

#Preview("Circular", as: .accessoryCircular) {
    ReadinessWidget()
} timeline: {
    ReadinessEntry.sample
    ReadinessEntry.empty
}

#Preview("Rectangular", as: .accessoryRectangular) {
    ReadinessWidget()
} timeline: {
    ReadinessEntry.sample
    ReadinessEntry.empty
}
