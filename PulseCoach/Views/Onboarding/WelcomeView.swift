import SwiftUI

/// Step 1 of 2: what the app does and why it needs Health access.
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            StepDots(current: 0)

            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .frame(width: 104, height: 104)
                    .background(LinearGradient(colors: [.pink.opacity(0.85), .pink], startPoint: .top, endPoint: .bottom),
                                in: .rect(cornerRadius: 24))
                    .accessibilityHidden(true)
                Text("ยินดีต้อนรับสู่\nPulseCoach")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 24) {
                Feature(icon: "waveform.path.ecg", tint: .pink, title: "ความพร้อมรายวัน",
                        text: "เทียบชีพจรขณะพัก HRV และการนอน กับค่าปกติของคุณเอง")
                Feature(icon: "calendar", tint: .green, title: "แผน 7 วันด้วย AI",
                        text: "สร้างบน iPhone และส่งเข้าแอป Workout บน Apple Watch")
                Feature(icon: "lock.shield", tint: .blue, title: "ส่วนตัวโดยออกแบบ",
                        text: "ข้อมูลสุขภาพประมวลผลในเครื่อง ไม่ขึ้นคลาวด์")
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text("PulseCoach จะขออนุญาตอ่านข้อมูลจากแอปสุขภาพ")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    GoalSetupView()
                } label: {
                    Text("ดำเนินการต่อ").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
}

private struct Feature: View {
    let icon: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(tint)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}

struct StepDots: View {
    let current: Int
    var count = 2

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == current ? 20 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ขั้นตอน \(current + 1) จาก \(count)")
    }
}
