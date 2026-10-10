import SwiftUI
import HealthKit
import PulseCore

/// "How ready am I today?" One big number inside a tick ring, then today's session.
struct WatchTodayView: View {
    @Environment(PlanStore.self) private var store
    @Environment(WorkoutManager.self) private var workout
    @State private var showWorkout = false
    @Bindable private var gym = GymLauncher.shared

    /// Same rule as the iPhone: no confident score without data behind it.
    private var score: Int? {
        guard store.metrics?.hasReadinessData ?? false else { return nil }
        return store.readiness?.score
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                TickRing(progress: Double(score ?? 0) / 100, tint: .readinessMint) {
                    VStack(spacing: 0) {
                        Text(score == nil ? "ไม่มีข้อมูล" : store.readiness?.shortHeadline ?? "")
                            .font(.footnote)
                            .frame(maxWidth: 90)
                            .foregroundStyle(Color.readinessMint)
                        Text(score.map(String.init) ?? "–")
                            .font(.system(size: 56, weight: .thin, design: .rounded))
                            .monospacedDigit()
                        Text("จาก 100").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
                .accessibilityLabel(score.map { "ความพร้อม \($0) จาก 100" } ?? "ยังไม่มีข้อมูลความพร้อม")

                if let m = store.metrics {
                    HStack(spacing: 10) {
                        metric("ชีพจรพัก", m.restingHR.map { "\(Int($0))" })
                        metric("HRV", m.hrv.map { "\(Int($0))" })
                        metric("นอน", m.sleepHours.map { String(format: "%.1f", $0) })
                    }
                    .font(.caption2)
                }

                if let day = store.today, !day.isRest {
                    Button {
                        if day.activity == .strength { gym.isPresented = true } else { showWorkout = true }
                    } label: {
                        Label("\(day.activity.displayName) · \(day.minutes) นาที",
                              systemImage: day.activity == .strength ? "dumbbell.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.readinessMint)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                } else if let day = store.today {
                    Label(day.activity.displayName, systemImage: day.activity.systemImage)
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if store.today?.activity != .strength {
                    Button {
                        gym.isPresented = true
                    } label: {
                        Label("โหมดยิม", systemImage: "dumbbell.fill").frame(maxWidth: .infinity)
                    }
                }

                if let sent = store.payload?.sentAt {
                    Text("อัปเดต \(sent.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("วันนี้")
        .onAppear {
            // Simulator screenshots: open the live workout directly.
            if ProcessInfo.processInfo.arguments.contains("-workoutDemo") { showWorkout = true }
        }
        .fullScreenCover(isPresented: $showWorkout) {
            WatchWorkoutView(activity: store.today?.activity ?? .walk)
        }
        .fullScreenCover(isPresented: $gym.isPresented) {
            GymSessionView(demo: gym.demo)
        }
    }

    private func metric(_ label: String, _ value: String?) -> some View {
        VStack(spacing: 0) {
            Text(label).foregroundStyle(.secondary)
            Text(value ?? "–").font(.footnote.weight(.semibold)).monospacedDigit()
        }
    }
}
