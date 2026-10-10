import SwiftUI
import PulseCore

/// 7-day plan as a scannable list. Tap a day for its tip and quick fixes for real life:
/// "เลื่อนไปพรุ่งนี้" and "ขอเบาลง", each with an undo toast.
struct PlanView: View {
    @Environment(AppModel.self) private var model
    @State private var expanded: Int? = nil
    @State private var toast: Toast?
    @State private var confirmRegenerate = false
    @Environment(\.dynamicTypeSize) private var typeSize

    struct Toast: Equatable {
        var message: String
        var previous: PlanDTO
    }

    var body: some View {
        List {
            if let plan = model.plan {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.rationale)
                            Text("อิงเป้าหมาย “\(model.profile.goal.title)” · \(model.profile.daysPerWeek) วัน/สัปดาห์")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkle").foregroundStyle(.purple)
                    }
                } footer: {
                    Text(plan.source == .onDeviceModel ? "สร้างด้วย AI ในเครื่อง · ทำงานออฟไลน์ได้" : "แผนพื้นฐาน (AI ในเครื่องไม่พร้อมใช้งาน)")
                }

                Section("แตะวันเพื่อดูรายละเอียดหรือปรับแผน") {
                    ForEach(plan.days) { day in
                        dayRow(day, in: plan)
                    }
                }
            } else if model.isGeneratingPlan {
                ProgressView("กำลังสร้างแผน…")
            }
        }
        .navigationTitle("แผน 7 วัน")
        .navigationSubtitle("ส่งเข้าแอป Workout บนนาฬิกาอัตโนมัติ")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("สร้างแผนใหม่", systemImage: "arrow.clockwise") {
                    confirmRegenerate = true
                }
                .disabled(model.isGeneratingPlan)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let toast {
                toastView(toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: toast)
        // Error prevention: regenerating discards the user's own edits.
        .confirmationDialog("สร้างแผนใหม่?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("สร้างแผนใหม่", role: .destructive) {
                Task { await model.generatePlan() }
            }
        } message: {
            Text("แผนที่คุณปรับไว้จะถูกแทนที่ด้วยแผนใหม่จากความพร้อมวันนี้")
        }
        .animation(.snappy, value: expanded)
    }

    @ViewBuilder
    private func dayRow(_ day: DayDTO, in plan: PlanDTO) -> some View {
        let isToday = day.dayIndex == model.todayPlan?.dayIndex
        let isOpen = expanded == day.dayIndex
        VStack(alignment: .leading, spacing: 10) {
            Button {
                expanded = isOpen ? nil : day.dayIndex
            } label: {
                HStack(spacing: 12) {
                    if typeSize.isAccessibilitySize {
                        // Large text: one column, date on its own line, no fixed widths.
                        VStack(alignment: .leading, spacing: 4) {
                            Text(date(for: day, in: plan).formatted(.dateTime.weekday(.wide).day()))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isToday ? Color.accentColor : .secondary)
                            Text(day.activity.displayName).font(.headline)
                            Text(day.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 0) {
                            Text(date(for: day, in: plan).formatted(.dateTime.weekday(.short))).font(.caption.weight(.semibold))
                            Text(date(for: day, in: plan).formatted(.dateTime.day())).font(.headline)
                        }
                        .foregroundStyle(isToday ? Color.accentColor : .primary)
                        .frame(width: 38)
                        RoundedRectangle(cornerRadius: 2).fill(day.tint).frame(width: 4, height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.activity.displayName).font(.headline)
                            Text(day.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if isToday && !typeSize.isAccessibilitySize {
                        Text("วันนี้").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor, in: .capsule)
                    }
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isOpen ? "ซ่อนรายละเอียด" : "แสดงรายละเอียดและตัวเลือกปรับแผน")

            if isOpen {
                Text(day.tip).font(.subheadline).foregroundStyle(.secondary)
                if day.activity == .strength {
                    NavigationLink {
                        GymGuideView()
                    } label: {
                        Label("ดูท่าออกกำลังกาย", systemImage: "dumbbell.fill")
                    }
                }
                if !day.isRest {
                    HStack(spacing: 8) {
                        Button("เลื่อนไปพรุ่งนี้") { adjust(day, message: "เลื่อน “\(day.activity.displayName)” ไปวันถัดไปแล้ว", move: true) }
                            .disabled(day.dayIndex == 7)
                        Button("ขอเบาลง") { adjust(day, message: "ปรับ “\(day.activity.displayName)” ให้เบาลงแล้ว", move: false) }
                            .disabled(day.intensity == .easy && day.minutes <= 15)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func adjust(_ day: DayDTO, message: String, move: Bool) {
        Task {
            let previous = move ? await model.moveToNextDay(day) : await model.makeEasier(day)
            if let previous { toast = Toast(message: message, previous: previous) }
            try? await Task.sleep(for: .seconds(5))
            if toast?.message == message { toast = nil }
        }
    }

    private func toastView(_ toast: Toast) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(toast.message).font(.subheadline)
            Spacer()
            Button("เลิกทำ") {
                Task { await model.restore(toast.previous) }
                self.toast = nil
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }

    private func date(for day: DayDTO, in plan: PlanDTO) -> Date {
        Calendar.current.date(byAdding: .day, value: day.dayIndex - 1, to: plan.createdAt) ?? plan.createdAt
    }
}
