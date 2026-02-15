
import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var timeManager: TimeManager
    
    var body: some View {
        NavigationView {
            List {
                if timeManager.deliveredNotifications.isEmpty {
                    Text("Keine Benachrichtigungen")
                        .foregroundColor(.gray)
                } else {
                    ForEach(timeManager.deliveredNotifications, id: \.request.identifier) { notification in
                        VStack(alignment: .leading) {
                            Text(notification.request.content.title)
                                .font(.headline)
                            Text(notification.request.content.body)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(notification.date, style: .relative) // Displays "2 minutes ago", etc.
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Benachrichtigungen")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // When this view appears, mark all delivered notifications as read
                timeManager.markNotificationsAsRead()
                // Fetch again to ensure the list is empty (after removal)
                timeManager.fetchDeliveredNotifications()
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
