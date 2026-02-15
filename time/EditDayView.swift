import SwiftUI

struct EditDayView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var timeManager: TimeManager
    
    let day: CompletedDay // This is the original day passed
    
    @State private var editableSegments: [TimeSegment] // Editable copy of segments
    
    init(day: CompletedDay) {
        self.day = day
        _editableSegments = State(initialValue: day.segments) // Initialize with original segments
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Segmente bearbeiten")) {
                    ForEach($editableSegments) { $segment in // Use $ to get Binding to individual segment
                        VStack(alignment: .leading) {
                            Text(segment.type == .work ? "Arbeit" : "Pause")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            DatePicker("Startzeit", selection: $segment.startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden() // Hide default label
                                .datePickerStyle(.compact)
                            
                            // Only show Endzeit for segments that are not active (endTime is not nil)
                            if segment.endTime != nil {
                                DatePicker("Endzeit", selection: Binding( // Use Binding to handle optional Date
                                    get: { segment.endTime ?? Date() },
                                    set: { segment.endTime = $0 }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                Section {
                    Button("Speichern") {
                        // Call timeManager.updateSegment for each edited segment
                        for segment in editableSegments {
                            timeManager.updateSegment(forDayId: day.id, segmentId: segment.id, newStartTime: segment.startTime, newEndTime: segment.endTime)
                        }
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
