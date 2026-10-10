import SwiftUI
import PulseCore

/// iPhone exercise guide for a gym day: a big animated demo of the selected move,
/// how-to steps, a horizontal move picker, and a button that opens Gym Mode on the watch.
struct GymGuideView: View {
    @Environment(AppModel.self) private var model
    var exercises: [Exercise] = ExerciseLibrary.backDay
    @State private var selected = 0
    @State private var watchAlert = false

    private var exercise: Exercise { exercises[selected] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                demoCard
                header
                stepsCard
                picker
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .toolbarVisibility(.hidden, for: .tabBar)
        .navigationTitle("วันเล่นหลัง")
        .navigationSubtitle("เวทเทรนนิ่ง · \(exercises.count) ท่า · 30 นาที")
        .safeAreaInset(edge: .bottom) {
            Button {
                if !model.startGymOnWatch() { watchAlert = true }
            } label: {
                Label("เริ่มบน Apple Watch", systemImage: "applewatch").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .alert("เปิดแอป PulseCoach บนนาฬิกา", isPresented: $watchAlert) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text("นาฬิกาต้องอยู่ใกล้และเปิดแอปไว้ แล้วกดโหมดยิมจากหน้าวันนี้บนนาฬิกาได้เลย")
        }
    }

    private var demoCard: some View {
        ExerciseImageView(exercise: exercise)
            .frame(height: 228)
            .clipShape(.rect(cornerRadius: 20))
            .overlay(alignment: .topLeading) {
                Text("\(selected + 1) / \(exercises.count)")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 9, height: 9)
                    Text("กล้ามเนื้อเป้าหมาย")
                }
                .font(.caption)
                .foregroundStyle(.black.opacity(0.7))
                .padding(12)
                .accessibilityHidden(true)
            }
            .id(exercise.id)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.title2.bold())
                Text(exercise.dose + (exercise.weightText.map { " · \($0)" } ?? ""))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(exercise.muscle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.red.opacity(0.12), in: .rect(cornerRadius: 8))
        }
        .padding(.horizontal, 4)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.blue, in: .circle)
                    Text(step)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private var picker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { i, ex in
                    let isSelected = i == selected
                    Button {
                        selected = i
                    } label: {
                        VStack(spacing: 4) {
                            ExerciseImageView(exercise: ex, animated: false)
                                .frame(width: 64, height: 62)
                                .clipShape(.rect(cornerRadius: 10))
                            Text(ex.shortName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        }
                        .padding(4)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ex.name)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 4, for: .scrollContent)
    }
}
