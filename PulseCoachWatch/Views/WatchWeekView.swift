import SwiftUI
import PulseCore

/// "What's coming this week?" Compact list of the 7-day plan.
struct WatchWeekView: View {
    @Environment(PlanStore.self) private var store

    var body: some View {
        List {
            if let plan = store.plan {
                ForEach(plan.days) { day in
                    let isToday = day.dayIndex == store.today?.dayIndex
                    HStack(spacing: 10) {
                        Circle().fill(color(for: day)).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(day.activity.displayName).font(.headline)
                            Text(day.isRest ? "พัก" : "\(day.minutes) นาที · \(day.intensity.displayName)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(isToday ? "วันนี้" : weekday(day, plan))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isToday ? Color.readinessMint : .secondary)
                    }
                }
            } else {
                Text("เปิดแอป PulseCoach บน iPhone เพื่อสร้างแผน").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("แผน 7 วัน")
    }

    private func color(for day: DayDTO) -> Color {
        switch (day.activity, day.intensity) {
        case (.rest, _): .gray
        case (.strength, _): .orange
        case (_, .hard): .heartCoral
        case (_, .moderate): .green
        case (_, .easy): .cyan
        }
    }

    private func weekday(_ day: DayDTO, _ plan: PlanDTO) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: day.dayIndex - 1, to: plan.createdAt) else { return "" }
        return date.formatted(.dateTime.weekday(.short))
    }
}
