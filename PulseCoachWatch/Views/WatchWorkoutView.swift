import SwiftUI
import HealthKit
import PulseCore

/// "What is my heart doing right now?" Live BPM in a coral tick ring.
/// Ending goes through a confirm screen so a mis-tap never loses a workout.
struct WatchWorkoutView: View {
    let activity: ActivityKind
    @Environment(WorkoutManager.self) private var workout
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false

    /// Zone 2 band (rough default until HealthKit workout zones are wired in).
    private let zone = 132.0...148.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 4) {
                TickRing(progress: min(workout.heartRate / 200, 1), tint: .heartCoral, tickLength: 12) {
                    VStack(spacing: 0) {
                        Text(zone.contains(workout.heartRate) ? "โซน 2" : "ชีพจร")
                            .font(.caption2).foregroundStyle(Color.heartCoral)
                        Text(workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "–")
                            .font(.system(size: 46, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("ครั้ง/นาที").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 124, height: 124)
                .accessibilityLabel("ชีพจร \(Int(workout.heartRate)) ครั้งต่อนาที")

                if let start = workout.startDate {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.restAmber)
                        .accessibilityLabel("เวลาที่ออกกำลังกาย")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(workout.state == .paused ? "หยุดชั่วคราว" : "กำลังบันทึก")
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(Color.black, for: .navigation)
            .toolbar {
                // Replaces the system close button: leaving always goes through the confirm screen.
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        confirmEnd = true
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("สิ้นสุด")
                }
                // watchOS places these in the bottom corners, clear of the rounded screen edge.
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        workout.togglePause()
                    } label: {
                        Image(systemName: workout.state == .paused ? "play.fill" : "pause.fill")
                    }
                    .tint(Color.restAmber)
                    .accessibilityLabel(workout.state == .paused ? "ทำต่อ" : "หยุดชั่วคราว")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        confirmEnd = true
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(Color.heartCoral)
                    .accessibilityLabel("สิ้นสุด")
                }
            }
        }
        // Ending only through the confirm screen, never a stray swipe or close button.
        .interactiveDismissDisabled()
        .task {
            if !workout.isActive {
                await workout.start(Self.activityType(activity))
            }
        }
        .sheet(isPresented: $confirmEnd) {
            NavigationStack {
                EndConfirmView { saved in
                    confirmEnd = false
                    if saved != nil { dismiss() }
                }
                .containerBackground(Color.black, for: .navigation)
            }
        }
    }

    static func activityType(_ kind: ActivityKind) -> HKWorkoutActivityType {
        switch kind {
        case .walk: .walking
        case .run: .running
        case .cycle: .cycling
        case .strength: .traditionalStrengthTraining
        case .hiit: .highIntensityIntervalTraining
        case .yoga: .yoga
        case .rest: .other
        }
    }
}

/// Error prevention: summary first, save as the primary action, discard last and in red.
struct EndConfirmView: View {
    /// nil = keep going, true = saved, false = discarded.
    let onDone: (Bool?) -> Void
    @Environment(WorkoutManager.self) private var workout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("สิ้นสุดการออกกำลังกาย?").font(.headline)
                HStack {
                    summary("เวลา", workout.startDate.map { Duration.seconds(Date.now.timeIntervalSince($0)).formatted(.time(pattern: .minuteSecond)) } ?? "–",
                            .restAmber)
                    summary("ชีพจรเฉลี่ย", workout.averageHeartRate > 0 ? "\(Int(workout.averageHeartRate))" : "–", .heartCoral)
                }
                Button("บันทึกและสิ้นสุด") {
                    Task {
                        await workout.finish()
                        onDone(true)
                    }
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)

                Button("ออกกำลังกายต่อ") { onDone(nil) }
                    .frame(maxWidth: .infinity)

                Button("ทิ้งโดยไม่บันทึก", role: .destructive) {
                    workout.discard()
                    onDone(false)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func summary(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.semibold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
