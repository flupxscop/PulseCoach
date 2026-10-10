import SwiftUI
import PulseCore

/// Account & settings sheet opened from the avatar on every tab.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = UserProfile()
    @AppStorage("notify.morning") private var morningSummary = true
    @AppStorage("notify.rest") private var restAdvice = true
    @AppStorage("notify.beforeWorkout") private var beforeWorkout = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("แผนของฉัน") {
                    Picker("เป้าหมาย", selection: $draft.goal) {
                        ForEach(FitnessGoal.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("วันออกกำลังกาย \(draft.daysPerWeek) วัน/สัปดาห์", value: $draft.daysPerWeek, in: 3...7)
                    Picker("ช่วงเวลาที่สะดวก", selection: $draft.preferredTime) {
                        ForEach(PreferredTime.allCases) { Text($0.title).tag($0) }
                    }
                    if draft != model.profile {
                        Button("บันทึกและสร้างแผนใหม่") {
                            model.profile = draft
                            Task { await model.generatePlan() }
                        }
                    }
                }

                Section("การแจ้งเตือน") {
                    Toggle(isOn: $morningSummary) {
                        Text("สรุปตอนเช้า")
                        Text("ความพร้อมและแผนวันนี้")
                    }
                    Toggle(isOn: $restAdvice) {
                        Text("แนะนำให้พัก")
                        Text("เมื่อค่าร่างกายต่างจากปกติ")
                    }
                    Toggle(isOn: $beforeWorkout) {
                        Text("เตือนก่อนออกกำลังกาย")
                        Text("30 นาทีก่อนเวลาที่สะดวก")
                    }
                }
                .onChange(of: morningSummary) { Task { await model.updateReminders() } }
                .onChange(of: beforeWorkout) { Task { await model.updateReminders() } }

                Section {
                    LabeledContent("Apple Watch", value: model.isWatchReachable ? "เชื่อมต่อแล้ว" : "ยังไม่พบแอปบนนาฬิกา")
                    Toggle("โหมดสาธิต (ข้อมูลตัวอย่าง)", isOn: $model.demoMode)
                        .onChange(of: model.demoMode) { Task { await model.refresh() } }
                } header: {
                    Text("อุปกรณ์และข้อมูล")
                } footer: {
                    Text(model.isWatchReachable
                         ? "ข้อมูลสุขภาพประมวลผลบน iPhone และ Apple Watch ของคุณเท่านั้น ไม่ส่งขึ้นคลาวด์"
                         : "ติดตั้ง PulseCoach บน Apple Watch ได้จากแอป Watch บน iPhone ข้อมูลสุขภาพประมวลผลในเครื่องของคุณเท่านั้น")
                }
            }
            .navigationTitle("บัญชีและการตั้งค่า")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จสิ้น") { dismiss() }
                }
            }
            .onAppear { draft = model.profile }
        }
    }
}
