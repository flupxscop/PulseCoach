import Foundation
import UserNotifications
import PulseCore

/// Local notifications only when a *new* flag appears, at most once per flag per day.
/// Copy is action-first and never alarming; Apple Watch already handles medical alerts.
@MainActor
final class GentleNotifier {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    func notifyIfNeeded(newFlags: Set<ReadinessFlag>) async {
        guard defaults.object(forKey: "notify.rest") as? Bool ?? true else { return }
        let dayKey = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        let fresh = newFlags.filter { defaults.double(forKey: "notified.\($0.rawValue)") != dayKey }
        guard let flag = fresh.sorted(by: { $0.rawValue < $1.rawValue }).first else { return }

        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "วันนี้ลองพักหน่อยไหม"
        content.body = flag.gentleAdvice
        content.sound = .default
        let request = UNNotificationRequest(identifier: "readiness.\(flag.rawValue)", content: content, trigger: nil)
        try? await center.add(request)
        for f in fresh { defaults.set(dayKey, forKey: "notified.\(f.rawValue)") }
    }

    /// Repeating local reminders that match the Profile toggles:
    /// a 07:00 morning summary and a reminder 30 minutes before the preferred workout time.
    func scheduleReminders(hour: Int) async {
        let morning = defaults.object(forKey: "notify.morning") as? Bool ?? true
        let before = defaults.object(forKey: "notify.beforeWorkout") as? Bool ?? false
        center.removePendingNotificationRequests(withIdentifiers: ["reminder.morning", "reminder.beforeWorkout"])
        guard morning || before,
              (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        if morning {
            await add("reminder.morning", title: "ความพร้อมวันนี้มาแล้ว",
                      body: "ดูว่าร่างกายพร้อมแค่ไหน และวันนี้ควรทำอะไร", hour: 7, minute: 0)
        }
        if before {
            await add("reminder.beforeWorkout", title: "อีก 30 นาทีถึงเวลาออกกำลังกาย",
                      body: "เปิด PulseCoach เพื่อดูแผนวันนี้", hour: max(hour - 1, 0), minute: 30)
        }
    }

    private func add(_ id: String, title: String, body: String, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
