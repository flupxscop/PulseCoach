import SwiftUI

/// Ring of fine ticks: bright ticks show progress, dim ticks the rest.
/// One accent colour per screen (readiness mint, heart rate coral, rest amber).
struct TickRing<Content: View>: View {
    var progress: Double
    var tint: Color
    var tickCount = 90
    var tickLength: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let radius = min(size.width, size.height) / 2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let lit = Int((Double(tickCount) * min(max(progress, 0), 1)).rounded())
                for i in 0..<tickCount {
                    let angle = Angle.degrees(Double(i) / Double(tickCount) * 360 - 90).radians
                    let outer = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    let inner = CGPoint(x: center.x + cos(angle) * (radius - tickLength),
                                        y: center.y + sin(angle) * (radius - tickLength))
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    ctx.stroke(path, with: .color(i < lit ? tint : tint.opacity(0.2)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
            .shadow(color: tint.opacity(0.5), radius: 4)
            content
                .padding(tickLength + 6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
    }
}

extension Color {
    static let readinessMint = Color(red: 0.31, green: 0.89, blue: 0.76)
    static let heartCoral = Color(red: 1.0, green: 0.31, blue: 0.43)
    static let restAmber = Color(red: 1.0, green: 0.79, blue: 0.24)
}
