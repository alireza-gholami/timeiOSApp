import SwiftUI

struct HistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var timeManager: TimeManager // Use ObservedObject since it's passed from ContentView
    @State private var dayToEdit: CompletedDay?
    
    // Formatter for displaying date and time
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Formatter for displaying only time
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Abgeschlossene Tage")) {
                    ForEach(timeManager.completedDays) { day in
                        VStack(alignment: .leading, spacing: 10) { // Added spacing
                            HStack {
                                Text(day.date, formatter: dateFormatter)
                                    .font(.subheadline) // Subtler font
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button("Edit") {
                                    self.dayToEdit = day
                                }
                                .font(.caption) // Smaller font for edit button
                                .foregroundColor(.accentColor) // Use accent color
                                // Removed background and cornerRadius for minimalist look
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            // Display total durations
                            HStack {
                                Text("Gesamtarbeit: \(timeFormatted(day.workDuration))")
                                Spacer()
                                Text("Gesamtpause: \(timeFormatted(day.pauseDuration))")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                            
                            // Display individual segments
                            ForEach(day.segments) { segment in
                                HStack {
                                    Image(systemName: segment.type == .work ? "briefcase.fill" : "pause.fill")
                                        .foregroundColor(segment.type == .work ? .accentColor : .orange.opacity(0.8)) // Use accent color
                                        .font(.caption) // Smaller icon
                                    Text(segment.type == .work ? "Arbeit" : "Pause")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(timeFormatter.string(from: segment.startTime)) - \(segment.endTime.map { timeFormatter.string(from: $0) } ?? "Aktiv")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .onDelete(perform: deleteDay) // Add swipe to delete functionality
                }
            }
            .listStyle(PlainListStyle()) // Minimalist list style
            .navigationTitle("Verlauf")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fertig") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.accentColor) // Accent color for toolbar button
                }
            }
        }
        .sheet(item: $dayToEdit) { day in
            EditDayView(day: day)
                .environmentObject(timeManager) // Pass timeManager as EnvironmentObject
        }
    }
    
    private func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        let seconds: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        let minutes: Int = Int((totalSeconds / 60).truncatingRemainder(dividingBy: 60))
        let hours: Int = Int(totalSeconds / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func deleteDay(at offsets: IndexSet) {
        timeManager.completedDays.remove(atOffsets: offsets)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let timeManager = TimeManager()
        timeManager.completedDays.append(CompletedDay(id: UUID(), date: Date(), segments: [
            TimeSegment(id: UUID(), type: .work, startTime: Date().addingTimeInterval(-3*3600), endTime: Date().addingTimeInterval(-1*3600)),
            TimeSegment(id: UUID(), type: .pause, startTime: Date().addingTimeInterval(-1*3600), endTime: Date().addingTimeInterval(-0.5*3600)),
            TimeSegment(id: UUID(), type: .work, startTime: Date().addingTimeInterval(-0.5*3600), endTime: Date())
        ]))
        timeManager.completedDays.append(CompletedDay(id: UUID(), date: Date().addingTimeInterval(-86400), segments: [
            TimeSegment(id: UUID(), type: .work, startTime: Date().addingTimeInterval(-8*3600), endTime: Date().addingTimeInterval(-5*3600)),
            TimeSegment(id: UUID(), type: .pause, startTime: Date().addingTimeInterval(-5*3600), endTime: Date().addingTimeInterval(-4.5*3600)),
            TimeSegment(id: UUID(), type: .work, startTime: Date().addingTimeInterval(-4.5*3600), endTime: Date().addingTimeInterval(-2*3600))
        ]))
        
        return HistoryView(timeManager: timeManager)
    }
}
