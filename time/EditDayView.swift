import SwiftUI

struct EditDayView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var timeManager: TimeManager
    
    let day: CompletedDay // This is the original day passed
    
    @State private var workMinutes: Double
    @State private var pauseMinutes: Double
    
    init(day: CompletedDay) {
        self.day = day
        // Initialize with accelerated durations
        _workMinutes = State(initialValue: day.workDuration / 60)
        _pauseMinutes = State(initialValue: day.pauseDuration / 60)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Zeiten anpassen (in Minuten)")) {
                    Stepper(value: $workMinutes, in: 0...1440, step: 1) {
                        Text("Arbeitszeit: \(workMinutes, specifier: "%.0f") min")
                            .foregroundColor(.primary)
                    }
                    Stepper(value: $pauseMinutes, in: 0...1440, step: 1) {
                        Text("Pausenzeit: \(pauseMinutes, specifier: "%.0f") min")
                            .foregroundColor(.primary)
                    }
                }
                
                Section {
                    Button("Speichern") {
                        timeManager.updateDay(id: day.id, workMinutes: workMinutes, pauseMinutes: pauseMinutes)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.accentColor)
                }
                
                Section {
                    Button("Abbrechen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle(Text(day.date, style: .date))
            .navigationBarTitleDisplayMode(.inline) // Minimalist title display
        }
    }
}
