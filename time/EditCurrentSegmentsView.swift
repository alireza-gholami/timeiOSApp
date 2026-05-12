import SwiftUI

struct EditCurrentSegmentsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var timeManager: TimeManager
    
    @State private var editableSegments: [TimeSegment]
    
    init(timeManager: TimeManager) {
        self.timeManager = timeManager
        _editableSegments = State(initialValue: timeManager.currentSegments)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Aktuelle Segmente bearbeiten")) {
                    if editableSegments.isEmpty {
                        Text("Keine aktiven Segmente vorhanden.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach($editableSegments) { $segment in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(segment.type == .work ? "Arbeit" : "Pause")
                                        .font(.headline)
                                    Spacer()
                                    if segment.endTime == nil {
                                        Text("Aktiv")
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.bottom, 5)
                                
                                DatePicker("Startzeit", selection: $segment.startTime, displayedComponents: [.hourAndMinute, .date])
                                    .datePickerStyle(.compact)
                                
                                if segment.endTime != nil {
                                    DatePicker("Endzeit", selection: Binding(
                                        get: { segment.endTime ?? Date() },
                                        set: { segment.endTime = $0 }
                                    ), displayedComponents: [.hourAndMinute, .date])
                                    .datePickerStyle(.compact)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                
                Section {
                    Button("Speichern") {
                        for segment in editableSegments {
                            timeManager.updateCurrentSegment(id: segment.id, newStartTime: segment.startTime, newEndTime: segment.endTime)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.accentColor)
                    .disabled(editableSegments.isEmpty)
                }
                
                Section {
                    Button("Abbrechen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Zeit anpassen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
