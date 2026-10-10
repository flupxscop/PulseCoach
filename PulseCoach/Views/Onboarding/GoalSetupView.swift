import SwiftUI
import PulseCore

/// Step 2 of 2: goal, active days and preferred time drive the whole plan.
struct GoalSetupView: View {
    @Environment(AppModel.self) private var model
    @State private var profile = UserProfile()
    @State private var isCreating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StepDots(current: 1).frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    Text("อยากให้ PulseCoach\nช่วยเรื่องอะไร").font(.title.bold())
                    Text("เราจะวางแผนให้เหมาะกับคุณ เปลี่ยนได้ทุกเมื่อในการตั้งค่า")
                        .foregroundStyle(.secondary)
                }

                GoalPicker(goal: $profile.goal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ออกกำลังกายได้กี่วันต่อสัปดาห์").font(.headline)
                    Picker("วันต่อสัปดาห์", selection: $profile.daysPerWeek) {
                        ForEach(3...7, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ช่วงเวลาที่สะดวก").font(.headline)
                    Picker("ช่วงเวลา", selection: $profile.preferredTime) {
                        ForEach(PreferredTime.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isCreating = true
                Task { await model.completeOnboarding(with: profile) }
            } label: {
                Group {
                    if isCreating { ProgressView() } else { Text("สร้างแผนของฉัน") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isCreating)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { profile = model.profile }
    }
}

struct GoalPicker: View {
    @Binding var goal: FitnessGoal

    var body: some View {
        VStack(spacing: 8) {
            ForEach(FitnessGoal.allCases) { option in
                let selected = option == goal
                Button {
                    goal = option
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.systemImage)
                            .font(.title2)
                            .foregroundStyle(.tint)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title).font(.headline)
                            Text(option.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected ? Color.accentColor : .secondary)
                    }
                    .padding(14)
                    .background(selected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground),
                                in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.plain)
                // VoiceOver: short label, description as hint, selection as a trait.
                .accessibilityLabel(option.title)
                .accessibilityHint(option.subtitle)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}
