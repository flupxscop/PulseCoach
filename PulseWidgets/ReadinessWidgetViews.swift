import SwiftUI
import WidgetKit
import PulseCore

private let mint = Color(red: 0.31, green: 0.89, blue: 0.76)

/// `.accessoryCircular`: readiness score in a gauge.
struct ReadinessCircularView: View {
    let entry: ReadinessEntry

    var body: some View {
        Gauge(value: Double(entry.score ?? 0), in: 0...100) {
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text(entry.score.map(String.init) ?? "–")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.green, mint]))
        .widgetAccentable()
        .accessibilityLabel("ความพร้อม \(entry.score.map(String.init) ?? "ไม่มีข้อมูล") จาก 100")
    }
}

/// `.accessoryRectangular`: score plus today's activity.
struct ReadinessRectangularView: View {
    let entry: ReadinessEntry

    var body: some View {
        HStack(spacing: 8) {
            ReadinessCircularView(entry: entry)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.shortHeadline.map { "ความพร้อม · \($0)" } ?? "ความพร้อม")
                    .font(.headline)
                    .foregroundStyle(mint)
                    .widgetAccentable()
                    .lineLimit(1)
                if let day = entry.day {
                    Label(day.activity.displayName, systemImage: day.activity.systemImage)
                        .lineLimit(1)
                    Text(day.isRest ? "พักให้เต็มที่" : "\(day.minutes) นาที · \(day.intensity.displayName)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("เปิด PulseCoach บน iPhone")
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .font(.caption)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
}

struct ReadinessWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReadinessEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: ReadinessRectangularView(entry: entry)
        default: ReadinessCircularView(entry: entry)
        }
    }
}
