import AppIntents
import WidgetKit
import Foundation

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer Status ändern"
    static var description = IntentDescription("Steuert die Zeiterfassung.")

    @Parameter(title: "Aktion")
    var action: String

    init() {}
    
    init(action: String) {
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        // Fix for Swift 6 Actor isolation: Accessing identifier from AppGroup
        let groupID = "group.com.alireza.Widget" 
        let sharedDefaults = UserDefaults(suiteName: groupID)
        
        var currentSegments: [TimeSegment] = []
        if let data = sharedDefaults?.data(forKey: "currentSegments") {
            currentSegments = (try? JSONDecoder().decode([TimeSegment].self, from: data)) ?? []
        }
        
        var completedDays: [CompletedDay] = []
        if let data = sharedDefaults?.data(forKey: "completedDays") {
            completedDays = (try? JSONDecoder().decode([CompletedDay].self, from: data)) ?? []
        }
        
        // Aktuelles Segment beenden, falls vorhanden
        if let lastIndex = currentSegments.indices.last, currentSegments[lastIndex].endTime == nil {
            currentSegments[lastIndex].endTime = Date()
        }
        
        // Neue Aktion ausführen
        switch action {
        case "work", "resume":
            currentSegments.append(TimeSegment(type: .work, startTime: Date()))
            sharedDefaults?.set(TimerState.working.rawValue, forKey: "timerState")
        case "pause":
            currentSegments.append(TimeSegment(type: .pause, startTime: Date()))
            sharedDefaults?.set(TimerState.pausing.rawValue, forKey: "timerState")
        case "stop":
            if !currentSegments.isEmpty {
                // Tag in die Historie speichern
                let newDay = CompletedDay(id: UUID(), date: Date(), segments: currentSegments)
                completedDays.append(newDay)
                
                // Historie speichern
                if let encodedDays = try? JSONEncoder().encode(completedDays) {
                    sharedDefaults?.set(encodedDays, forKey: "completedDays")
                }
            }
            
            // Alles zurücksetzen
            currentSegments = []
            sharedDefaults?.set(TimerState.idle.rawValue, forKey: "timerState")
        default:
            break
        }
        
        // Aktuelle Segmente speichern
        if let encodedSegments = try? JSONEncoder().encode(currentSegments) {
            sharedDefaults?.set(encodedSegments, forKey: "currentSegments")
        }
        
        // Widget aktualisieren
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}
