import SwiftUI
import Foundation
import Observation
import UserNotifications

/// A time of day (no date) at which a daily reminder fires.
struct ReminderTime: Codable, Identifiable, Hashable {
    var id = UUID()
    var hour: Int
    var minute: Int

    /// Today at this time. Used only to feed/read a DatePicker.
    var date: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.hour = parts.hour ?? 0
        self.minute = parts.minute ?? 0
    }
}

/// Schedules daily "log your expenses" reminders as *local* notifications.
/// These are scheduled on the device itself, so no server, push certificate,
/// or paid developer account is involved. iOS keeps repeating them even when
/// the app isn't running.
@MainActor
@Observable
final class ReminderManager {
    static let shared = ReminderManager()
    static let maxTimes = 8

    private(set) var isEnabled: Bool
    private(set) var times: [ReminderTime]
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let enabledKey = "reminders.enabled"
    private let timesKey = "reminders.times"
    private let idPrefix = "expense-reminder-"
    private var scheduleTask: Task<Void, Never>?

    private init() {
        isEnabled = defaults.bool(forKey: enabledKey)
        if let data = defaults.data(forKey: timesKey),
           let saved = try? JSONDecoder().decode([ReminderTime].self, from: data) {
            times = saved
        } else {
            times = [ReminderTime(hour: 13, minute: 0), ReminderTime(hour: 20, minute: 0)]
        }
    }

    // MARK: - Permission

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Turns reminders on or off. Turning on asks for notification permission
    /// the first time; if it's denied, reminders stay off.
    func setEnabled(_ enabled: Bool) async {
        if enabled {
            await refreshAuthorizationStatus()
            if authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                await refreshAuthorizationStatus()
            }
            guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
                isEnabled = false
                persist()
                return
            }
        }
        isEnabled = enabled
        persist()
        scheduleUpdate()
    }

    // MARK: - Editing times

    func addTime() {
        guard times.count < Self.maxTimes else { return }
        times.append(ReminderTime(hour: 12, minute: 0))
        persist()
        scheduleUpdate()
    }

    func updateTime(id: UUID, to date: Date) {
        guard let index = times.firstIndex(where: { $0.id == id }) else { return }
        let updated = ReminderTime(date: date)
        times[index].hour = updated.hour
        times[index].minute = updated.minute
        persist()
        scheduleUpdate()
    }

    func removeTimes(at offsets: IndexSet) {
        times.remove(atOffsets: offsets)
        persist()
        scheduleUpdate()
    }

    // MARK: - Scheduling

    private func persist() {
        defaults.set(isEnabled, forKey: enabledKey)
        if let data = try? JSONEncoder().encode(times) {
            defaults.set(data, forKey: timesKey)
        }
    }

    /// Queues a reschedule, running them one at a time so rapid changes
    /// (e.g. spinning a time picker) can't interleave.
    private func scheduleUpdate() {
        let previous = scheduleTask
        scheduleTask = Task {
            await previous?.value
            await reschedule()
        }
    }

    private func reschedule() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard isEnabled else { return }

        for time in times {
            let content = UNMutableNotificationContent()
            content.title = "Time to log your expenses"
            content.body = "Add any receipts or costs you've had so far to CashTrail."
            content.sound = .default

            var components = DateComponents()
            components.hour = time.hour
            components.minute = time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: idPrefix + time.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}

/// By default iOS hides notifications while the app is open. This shows them
/// as a banner anyway.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
