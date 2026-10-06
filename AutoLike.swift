import Foundation
import BackgroundTasks
import UserNotifications

@MainActor
final class AutoLike: ObservableObject {
    static let shared = AutoLike()
    nonisolated static let taskID = "com.nmh.fftool.autolike"

    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "auto.enabled")
            enabled ? schedule() : cancel()
        }
    }
    @Published var lastRun: Date?
    @Published var lastResult: String
    @Published var running = false

    private init() {
        let d = UserDefaults.standard
        enabled = d.bool(forKey: "auto.enabled")
        let t = d.double(forKey: "auto.lastRun")
        lastRun = t > 0 ? Date(timeIntervalSince1970: t) : nil
        lastResult = d.string(forKey: "auto.lastResult") ?? "Chưa chạy lần nào"
    }

    nonisolated static func registerBackground() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            Task { @MainActor in
                AutoLike.shared.scheduleBackground()
                await AutoLike.shared.runIfDue()
                task.setTaskCompleted(success: true)
            }
        }
    }

    static func next5AM() -> Date {
        Calendar.current.nextDate(after: Date(),
                                  matching: DateComponents(hour: 5, minute: 0),
                                  matchingPolicy: .nextTime) ?? Date().addingTimeInterval(86400)
    }

    func scheduleBackground() {
        let req = BGAppRefreshTaskRequest(identifier: Self.taskID)
        req.earliestBeginDate = Self.next5AM()
        try? BGTaskScheduler.shared.submit(req)
    }

    func schedule() {
        scheduleBackground()
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        c.removePendingNotificationRequests(withIdentifiers: ["auto5am"])
        let content = UNMutableNotificationContent()
        content.title = "Buff Like"
        content.body = "5h sáng rồi! Mở app để auto like hôm nay."
        content.sound = .default
        var dc = DateComponents()
        dc.hour = 5; dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        c.add(UNNotificationRequest(identifier: "auto5am", content: content, trigger: trigger))
    }

    func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["auto5am"])
    }

    func runIfDue() async {
        guard enabled, !running else { return }
        let uid = UserDefaults.standard.string(forKey: "uid") ?? ""
        guard !uid.isEmpty else { return }
        let today5 = Calendar.current.date(bySettingHour: 5, minute: 0, second: 0, of: Date())!
        guard Date() >= today5 else { return }
        if let l = lastRun, l >= today5 { return }
        await run(uid: uid, auto: true)
    }

    func run(uid: String, auto: Bool) async {
        guard !running else { return }
        running = true
        var text: String
        do {
            let rows = try await API.call(.like, uid: uid)
            text = rows.prefix(5).map { "\($0.0): \($0.1)" }.joined(separator: "\n")
        } catch {
            text = "Lỗi: \(error.localizedDescription)"
        }
        let d = UserDefaults.standard
        if auto {
            lastRun = Date()
            d.set(Date().timeIntervalSince1970, forKey: "auto.lastRun")
        }
        lastResult = text
        d.set(text, forKey: "auto.lastResult")
        running = false
        if auto { notify(text) }
    }

    private func notify(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Auto Like đã chạy"
        content.body = text
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
