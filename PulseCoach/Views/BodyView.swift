import SwiftUI
import PulseCore

/// "Why is my score what it is?" Each rule next to the user's own value today.
struct BodyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ReadinessRing(score: model.displayReadiness?.score, lineWidth: 10)
                        .frame(width: 84, height: 84)
                    Text("คะแนนเริ่มที่ 100 แล้วหักเมื่อค่าวันนี้ต่างจากค่าปกติ 28 วันของคุณเอง")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if model.today != nil && !model.hasHealthData {
                Section {
                    NoHealthDataView { await model.requestHealthAccess() }
                        .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(model.checks) { check in
                    HStack(spacing: 12) {
                        Image(systemName: check.flag.systemImage)
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(check.flag.tint, in: .rect(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.flag.metricName)
                            Text(check.flag.ruleDescription).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(check.formattedValue).fontWeight(.semibold).monospacedDigit()
                            StatusChip(check: check)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("ค่าของคุณวันนี้เทียบกับเกณฑ์")
            } footer: {
                Text("การคำนวณใช้กฎที่ตรวจสอบได้ ไม่ใช้ AI ตัดสินค่าผิดปกติ")
            }

            Section("เกี่ยวกับ") {
                Label("PulseCoach เป็นแอปดูแลสุขภาพทั่วไป ไม่ใช่อุปกรณ์การแพทย์ หากมีอาการผิดปกติ โปรดปรึกษาแพทย์",
                      systemImage: "info.circle")
            }
        }
        .navigationTitle("ร่างกาย")
        .navigationSubtitle(model.displayReadiness.map { "ความพร้อมวันนี้ \($0.score) จาก 100" } ?? "ยังไม่มีข้อมูลสุขภาพ")
        .refreshable { await model.refresh() }
    }
}
