import SwiftUI
import SwiftData
import UserNotifications

@main
struct CashTrailApp: App {
    init() {
        // Lets reminders show as a banner even while the app is open.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            TripListView()
                .tint(.brandAccent)
        }
        .modelContainer(for: [Trip.self, Receipt.self])
    }
}
