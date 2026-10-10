import SwiftUI
import WorkoutKit
import PulseCore

/// Answers the user's first question of the day: "what should I do today?"
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var previewPlan: WorkoutPlan?
    @State private var showPreview = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showGymGuide = ProcessInfo.processInfo.arguments.contains("-gymGuide")

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                recommendationCard
                bodyCard
                weekCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("วันนี้")
        .navigationSubtitle(syncStatus)
        .navigationDestination(isPresented: $showGymGuide) { GymGuideView() }
        .refreshable { await model.refresh() }
        .workoutPreview(previewPlan ?? placeholderPlan, isPresented: $showPreview)
    }

    private var syncStatus: String {
        guard let date = model.lastSyncedAt else {
            return Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
        return "ซิงก์กับ Apple Watch แล้ว · \(date.formatted(.relative(presentation: .named)))"
    }

    // MARK: Cards

    @ViewBuilder
    private var recommendationCard: some View {
        Card {
            Label("แนะนำสำหรับวันนี้", systemImage: "sparkle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.purple)

            if let day = model.todayPlan {
                AdaptiveStack(spacing: 14) {
                    Image(systemName: day.activity.systemImage)
                        .font(.title2)
                        .foregroundStyle(day.tint)
                        .frame(width: 52, height: 52)
                        .background(day.tint.opacity(0.15), in: .rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.isRest ? day.activity.displayName : "\(day.activity.displayName) \(day.minutes) นาที")
                            .font(.title3.bold())
                        Text(day.tip).foregroundStyle(.secondary)
                    }
                }
                AdaptiveStack(spacing: 8) {
                    if let plan = WorkoutScheduling.workoutPlan(for: day) {
                        Button {
                            previewPlan = plan
                            showPreview = true
                        } label: {
                            Label("เริ่มบนนาฬิกา", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if day.activity == .strength {
                        Button("ดูท่า") { showGymGuide = true }
                            .buttonStyle(.bordered)
                    }
                    Button { model.selectedTab = .plan } label: {
                        Text("เปลี่ยนแผน").frame(maxWidth: day.isRest || typeSize.isAccessibilitySize ? .infinity : nil)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            } else if model.isGeneratingPlan {
                ProgressView("กำลังสร้างแผน…")
            } else {
                Button("สร้างแผน") { Task { await model.generatePlan() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AdaptiveStack(spacing: 14) {
                ReadinessRing(score: model.displayReadiness?.score, lineWidth: 8)
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ร่างกายวันนี้").font(.footnote.weight(.semibold)).foregroundStyle(.green)
                    Text(model.today == nil ? "กำลังอ่านข้อมูล…" : model.displayReadiness?.headline ?? "ยังไม่มีข้อมูลสุขภาพ")
                        .font(.headline)
                }
            }
            .padding(16)

            if model.today != nil && !model.hasHealthData {
                NoHealthDataView { await model.requestHealthAccess() }
                    .padding([.horizontal, .bottom], 16)
            } else {
                metricRows
            }

            Divider().padding(.leading, 16)
            Button {
                model.selectedTab = .body
            } label: {
                HStack {
                    Text("ค่าเหล่านี้หมายถึงอะไร").multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    @ViewBuilder
    private var metricRows: some View {
            ForEach(model.checks.filter { $0.flag != .lowSpO2 }) { check in
                Divider().padding(.leading, 16)
                AdaptiveStack(spacing: 10) {
                    Label {
                        Text(check.flag.shortName)
                    } icon: {
                        Image(systemName: check.flag.systemImage).foregroundStyle(check.flag.tint)
                    }
                    if !typeSize.isAccessibilitySize { Spacer() }
                    HStack(spacing: 10) {
                        Text(check.formattedValue).fontWeight(.semibold).monospacedDigit()
                        StatusChip(check: check)
                    }
                }
                .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
            }
    }

    @ViewBuilder
    private var weekCard: some View {
        if let plan = model.plan {
            Card {
                AdaptiveStack(spacing: 4) {
                    Text("7 วันข้างหน้า").font(.headline)
                    if !typeSize.isAccessibilitySize { Spacer() }
                    Text("ออกกำลังกาย \(plan.days.filter { !$0.isRest }.count) วัน")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    ForEach(plan.days) { day in
                        let isToday = day.dayIndex == model.todayPlan?.dayIndex
                        VStack(spacing: 4) {
                            Circle()
                                .fill(day.isRest ? Color.clear : day.tint.opacity(isToday ? 1 : 0.35))
                                .overlay {
                                    Circle().strokeBorder(isToday ? Color.accentColor : .secondary.opacity(day.isRest ? 0.4 : 0),
                                                          style: StrokeStyle(lineWidth: isToday ? 2 : 1.5, dash: day.isRest ? [3] : []))
                                }
                                .frame(width: 30, height: 30)
                            Text(weekday(for: day)).font(.caption).foregroundStyle(isToday ? Color.accentColor : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(weekday(for: day)) \(day.activity.displayName)")
                    }
                }
            }
        }
    }

    private func weekday(for day: DayDTO) -> String {
        guard let plan = model.plan,
              let date = Calendar.current.date(byAdding: .day, value: day.dayIndex - 1, to: plan.createdAt)
        else { return "" }
        return date.formatted(.dateTime.weekday(.short))
    }

    /// `.workoutPreview` needs a non-optional plan even while hidden.
    private var placeholderPlan: WorkoutPlan {
        WorkoutPlan(.goal(SingleGoalWorkout(activity: .walking, goal: .time(20, .minutes))))
    }
}
