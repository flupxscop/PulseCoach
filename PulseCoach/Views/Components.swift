import SwiftUI
import PulseCore

/// Activity-style readiness ring: green to mint gradient with round caps.
struct ReadinessRing: View {
    let score: Int?
    var lineWidth: CGFloat = 12
    var showsLabel = true

    private var progress: Double { Double(score ?? 0) / 100 }

    var body: some View {
        ZStack {
            Circle().stroke(Color.green.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [.green, .mint], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * progress)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                GeometryReader { geo in
                    Text(score.map(String.init) ?? "–")
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.3, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ความพร้อม \(score.map(String.init) ?? "ไม่มีข้อมูล") จาก 100")
    }
}

/// "ปกติ" / "↑ ดีขึ้น" / "ต่ำกว่าปกติ" chip next to a metric.
struct StatusChip: View {
    let check: ReadinessCheck

    var body: some View {
        Text(check.statusText)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: 8))
    }

    private var isBetter: Bool { check.statusText.hasPrefix("↑") || check.statusText.hasPrefix("↓") }

    private var foreground: Color {
        switch check.status {
        case .flagged: .orange
        case .ok where isBetter: .green
        default: .secondary
        }
    }

    private var background: Color {
        switch check.status {
        case .flagged: .orange.opacity(0.15)
        case .ok where isBetter: .green.opacity(0.15)
        default: .secondary.opacity(0.12)
        }
    }
}

extension ReadinessFlag {
    var tint: Color {
        switch self {
        case .elevatedRestingHR: .pink
        case .lowHRV: .blue
        case .shortSleep: .indigo
        case .lowSpO2: .teal
        }
    }
}

extension IntensityLevel {
    var tint: Color {
        switch self {
        case .easy: .cyan
        case .moderate: .green
        case .hard: .pink
        }
    }
}

extension DayDTO {
    var tint: Color {
        switch activity {
        case .rest: .gray
        case .strength: .orange
        default: intensity.tint
        }
    }

    var summary: String {
        isRest ? "ไม่มีกิจกรรม" : "\(minutes) นาที · \(intensity.displayName)"
    }
}

/// Empty state when HealthKit has nothing to score: explain why and offer the fix.
struct NoHealthDataView: View {
    let requestAccess: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ใส่ Apple Watch ตอนนอน และอนุญาตให้ PulseCoach อ่านข้อมูลสุขภาพ แล้วคะแนนจะขึ้นในวันถัดไป",
                  systemImage: "applewatch.radiowaves.left.and.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("ตรวจสอบการอนุญาต") { Task { await requestAccess() } }
                .buttonStyle(.bordered)
        }
    }
}

/// Side by side normally, stacked at accessibility text sizes (HIG: avoid truncation).
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout { content }
    }
}

/// Card container used on the Today tab.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }
}
