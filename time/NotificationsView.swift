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
                        .foregroundColor(.secondary) // Muted color for empty state
                        .font(.body)
                } else {
                    ForEach(timeManager.deliveredNotifications, id: \.request.identifier) { notification in
                        VStack(alignment: .leading, spacing: 5) { // Added spacing
                            Text(notification.request.content.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(notification.request.content.body)
                                .font(.subheadline)
                                .foregroundColor(.secondary) // Muted body text
                            Text(notification.date, style: .relative) // Displays "2 minutes ago", etc.
                                .font(.caption)
                                .foregroundColor(.secondary) // Use secondary for consistency
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .listStyle(PlainListStyle()) // Minimalist list style
            .navigationTitle("Benachrichtigungen")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.accentColor) // Accent color for toolbar button
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
