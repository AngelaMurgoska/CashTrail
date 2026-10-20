import SwiftUI
import UserNotifications

/// Lets the user turn daily expense reminders on/off and choose the times.
struct RemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private let manager = ReminderManager.shared

    private var permissionDenied: Bool {
        manager.authorizationStatus == .denied
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Daily reminders",
                        isOn: Binding(
                            get: { manager.isEnabled },
                            set: { newValue in
                                Task { await manager.setEnabled(newValue) }
                            }
                        )
                    )
                } footer: {
                    Text("Get a reminder at the times you choose to log your expenses.")
                }

                if permissionDenied {
                    Section {
                        Text("Notifications are turned off for CashTrail in Settings, so reminders can't be shown.")
                            .font(.callout)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }

                if manager.isEnabled {
                    Section("Reminder times") {
                        ForEach(manager.times) { time in
                            DatePicker(
                                "Reminder",
                                selection: Binding(
                                    get: { time.date },
                                    set: { manager.updateTime(id: time.id, to: $0) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                        .onDelete { manager.removeTimes(at: $0) }

                        if manager.times.count < ReminderManager.maxTimes {
                            Button {
                                manager.addTime()
                            } label: {
                                Label("Add Time", systemImage: "plus")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await manager.refreshAuthorizationStatus() }
            .onChange(of: scenePhase) { _, newPhase in
                // Refresh when returning from the Settings app.
                if newPhase == .active {
                    Task { await manager.refreshAuthorizationStatus() }
                }
            }
        }
    }
}
