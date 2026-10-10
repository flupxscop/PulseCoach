import SwiftUI
import WatchKit
import PulseCore

/// Guided gym session: exercise → rest → next set, driven by `GymSession`.
struct GymSessionView: View {
    @State private var session: GymSession
    @Environment(\.dismiss) private var dismiss

    init(exercises: [Exercise] = ExerciseLibrary.backDay, demo: Demo = .none) {
        var s = GymSession(exercises: exercises)
        switch demo {
        case .none: break
        case .exercise:
            // Mirrors the design: set 2 of 3, 8 reps counted.
            s.finishSet(at: .now)
            s.startNextSet()
            s.setReps(8)
        case .rest:
            s.setReps(12)
            s.finishSet(at: .now)
            s.adjustRest(by: -15, now: .now)
        }
        _session = State(initialValue: s)
    }

    enum Demo { case none, exercise, rest }

    var body: some View {
        NavigationStack {
            Group {
                switch session.phase {
                case .exercise: GymExerciseScreen(session: $session)
                case .rest: GymRestScreen(session: $session)
                case .finished: GymDoneScreen(session: session) { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(Color.black, for: .navigation)
            .animation(.snappy, value: session.phase)
        }
    }
}

// MARK: - Exercise

struct GymExerciseScreen: View {
    @Binding var session: GymSession
    @State private var crown = 0.0
    @State private var showSteps = false

    var body: some View {
        if let ex = session.current {
            ScrollView {
                VStack(spacing: 4) {
                    SetDots(current: session.setNumber, total: ex.sets)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ExerciseImageView(exercise: ex)
                        .frame(height: 68)
                        .clipShape(.rect(cornerRadius: 18))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                showSteps = true
                            } label: {
                                Image(systemName: "info").font(.caption.bold())
                            }
                            .buttonStyle(.plain)
                            .frame(width: 32, height: 32)
                            .background(.gray.opacity(0.25), in: .circle)
                            .foregroundStyle(.blue)
                            .padding(4)
                            .accessibilityLabel("ดูวิธีทำท่านี้")
                        }

                    HStack(alignment: .center, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ex.name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                            Text([ex.weightText, ex.cue].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("\(session.currentReps)")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                                Text("/\(ex.reps)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            Label("Crown", systemImage: "digitalcrown.arrow.clockwise")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .focusable()
                        .digitalCrownRotation($crown, from: 0, through: 99, by: 1, sensitivity: .medium,
                                              isContinuous: false, isHapticFeedbackEnabled: true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("ทำไปแล้ว \(session.currentReps) จาก \(ex.reps) ครั้ง")
                        .accessibilityAdjustableAction { direction in
                            session.setReps(session.currentReps + (direction == .increment ? 1 : -1))
                        }
                    }
                }
            }
            .navigationTitle("ท่า \(session.exerciseIndex + 1)/\(session.exercises.count)")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button { session.skipExercise() } label: { Image(systemName: "forward.end.fill") }
                        .accessibilityLabel("ข้ามท่า")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        WKInterfaceDevice.current().play(.success)
                        session.finishSet(at: .now)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .tint(.green)
                    .accessibilityLabel("เสร็จเซ็ต")
                }
            }
            .onAppear { crown = Double(session.currentReps) }
            .onChange(of: crown) { _, value in session.setReps(Int(value.rounded())) }
            .sheet(isPresented: $showSteps) { StepsSheet(exercise: ex) }
        }
    }
}

struct SetDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...max(total, 1), id: \.self) { i in
                Circle()
                    .strokeBorder(Color.green, lineWidth: i == current ? 1.5 : 0)
                    .background(Circle().fill(i < current ? Color.green : i == current ? .clear : .gray.opacity(0.4)))
                    .frame(width: 6, height: 6)
            }
            Text("เซ็ต \(current)/\(total)").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("เซ็ตที่ \(current) จาก \(total)")
    }
}

struct StepsSheet: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name).font(.headline)
                Text(exercise.muscle).font(.caption2).foregroundStyle(.red)
                ForEach(Array(exercise.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(i + 1)").font(.caption2.bold()).frame(width: 18, height: 18)
                            .background(.blue, in: .circle)
                        Text(step).font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Rest

struct GymRestScreen: View {
    @Binding var session: GymSession
    @State private var editing = false
    @State private var buzzed = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = session.restRemaining(at: context.date)
            ScrollView {
                VStack(spacing: 4) {
                    if let log = session.lastLog {
                        Button {
                            editing = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark").foregroundStyle(.green)
                                Text("เซ็ต \(log.setNumber) · \(log.reps) ครั้ง").lineLimit(1)
                                Spacer(minLength: 0)
                                Text("แก้ไข").foregroundStyle(.blue)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(.gray.opacity(0.2), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }

                    if let next = session.current {
                        Text("ถัดไป: \(next.name) · เซ็ต \(session.setNumber)/\(next.sets)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    TickRing(progress: session.restProgress(at: context.date), tint: .restAmber, tickLength: 8) {
                        VStack(spacing: 0) {
                            Text(Duration.seconds(remaining.rounded(.up)).formatted(.time(pattern: .minuteSecond)))
                                .font(.system(size: 30, weight: .thin, design: .rounded))
                                .monospacedDigit()
                            Text("จาก \(Duration.seconds(session.restDuration).formatted(.time(pattern: .minuteSecond)))")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .accessibilityLabel("เหลือเวลาพัก \(Int(remaining.rounded(.up))) วินาที")

                }
            }
            .navigationTitle("พัก")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button { session.adjustRest(by: -15, now: .now) } label: { Image(systemName: "gobackward.15") }
                        .accessibilityLabel("ลดเวลาพัก 15 วินาที")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { session.startNextSet() } label: { Image(systemName: "play.fill") }
                        .tint(.restAmber)
                        .accessibilityLabel("เริ่มเซ็ตต่อไป")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { session.adjustRest(by: 15, now: .now) } label: { Image(systemName: "goforward.15") }
                        .accessibilityLabel("เพิ่มเวลาพัก 15 วินาที")
                }
            }
            .onChange(of: remaining <= 0) { _, done in
                if done && !buzzed {
                    buzzed = true
                    WKInterfaceDevice.current().play(.notification)
                }
            }
        }
        .sheet(isPresented: $editing) {
            EditSetSheet(reps: session.lastLog?.reps ?? 0) { session.editLastSet(reps: $0) }
        }
    }
}

struct EditSetSheet: View {
    @State var reps: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            Text("แก้จำนวนครั้ง").font(.headline)
            Stepper(value: $reps, in: 0...99) {
                Text("\(reps)").font(.system(size: 34, weight: .bold, design: .rounded))
            }
            Button("บันทึก") {
                onSave(reps)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Done

struct GymDoneScreen: View {
    let session: GymSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
            Text("เสร็จแล้ว!").font(.headline)
            Text("\(session.logs.count) เซ็ต · \(Set(session.logs.map(\.exerciseID)).count) ท่า")
                .font(.footnote).foregroundStyle(.secondary)
            Button("ปิด", action: onClose).buttonStyle(.borderedProminent)
        }
    }
}
