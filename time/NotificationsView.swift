import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var timeManager: TimeManager
    
    var body: some View {
        NavigationView {
            List {
                if timeManager.notificationHistory.isEmpty {
                    Text("Keine Benachrichtigungen")
                        .foregroundColor(.secondary)
                        .font(.body)
                } else {
                    ForEach(timeManager.notificationHistory.reversed()) { record in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(record.body)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(record.date, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                    .onDelete { indexSet in
                        // Handle manual deletion of specific notifications
                        let reversedIndexSet = IndexSet(indexSet.map { timeManager.notificationHistory.count - 1 - $0 })
                        timeManager.notificationHistory.remove(atOffsets: reversedIndexSet)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Benachrichtigungen")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !timeManager.notificationHistory.isEmpty {
                        Button("Löschen") {
                            timeManager.notificationHistory = []
                        }
                    }
                }
            }
            .onAppear {
                // Clear the actual system delivered notifications and badge when viewing the in-app list
                timeManager.markNotificationsAsRead()
            }
        }
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        let tm = TimeManager()
        // For preview, we cannot directly instantiate UNNotification.
        // The view will simply show "Keine Benachrichtigungen" or a state from TimeManager's actual delivered notifications.
        // To properly preview with content, a mocking framework or refactoring of deliveredNotifications to a simpler type would be needed.
        
        return NotificationsView(timeManager: tm)
    }
}
