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
        
        let testModeActive = sharedDefaults?.bool(forKey: "testModeActive") ?? false
        let factor: Double = testModeActive ? 300.0 : 1.0
        
        switch action {
        case "toggleTestMode":
            let newState = !testModeActive
            sharedDefaults?.set(newState, forKey: "testModeActive")
            if let lastIndex = currentSegments.indices.last, currentSegments[lastIndex].endTime == nil {
                var updatedSegment = currentSegments[lastIndex]
                updatedSegment.accelerationFactor = newState ? 300.0 : 1.0
                currentSegments[lastIndex] = updatedSegment
            }
            
        case "work", "resume", "pause", "stop":
            // Aktuelles Segment beenden für Statusänderungen
            if let lastIndex = currentSegments.indices.last, currentSegments[lastIndex].endTime == nil {
                var updatedSegment = currentSegments[lastIndex]
                updatedSegment.endTime = Date()
                currentSegments[lastIndex] = updatedSegment
            }
            
            if action == "work" || action == "resume" {
                currentSegments.append(TimeSegment(type: .work, startTime: Date(), accelerationFactor: factor))
                sharedDefaults?.set(TimerState.working.rawValue, forKey: "timerState")
            } else if action == "pause" {
                currentSegments.append(TimeSegment(type: .pause, startTime: Date(), accelerationFactor: factor))
                sharedDefaults?.set(TimerState.pausing.rawValue, forKey: "timerState")
            } else if action == "stop" {
                if !currentSegments.isEmpty {
                    // Tag in die Historie speichern
                    let newDay = CompletedDay(id: UUID(), date: Date(), segments: currentSegments)
                    completedDays.append(newDay)
                    
                    if let encodedDays = try? JSONEncoder().encode(completedDays) {
                        sharedDefaults?.set(encodedDays, forKey: "completedDays")
                    }
                    
                    // Letzte Zusammenfassung für Widget sichern
                    let totalWork = currentSegments.filter { $0.type == .work }.reduce(0.0) { $0 + $1.duration }
                    let totalPause = currentSegments.filter { $0.type == .pause }.reduce(0.0) { $0 + $1.duration }
                    sharedDefaults?.set(totalWork, forKey: "lastSummaryWork")
                    sharedDefaults?.set(totalPause, forKey: "lastSummaryPause")
                }
                
                // Alles zurücksetzen
                currentSegments = []
                sharedDefaults?.set(TimerState.idle.rawValue, forKey: "timerState")
            }
            
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
