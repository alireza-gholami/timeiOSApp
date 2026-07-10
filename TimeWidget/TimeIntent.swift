import AppIntents
import WidgetKit
import Foundation
import UserNotifications

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
                    
                    // Sicherstellen dass die Daten sofort geschrieben werden
                    sharedDefaults?.synchronize()
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
        
        // Finales Synchronisieren für AppGroup
        sharedDefaults?.synchronize()
        
        // Widget aktualisieren
        WidgetCenter.shared.reloadAllTimelines()
        
        // Benachrichtigungen planen, wenn Arbeit gestartet wurde
        if action == "work" || action == "resume" {
            scheduleWidgetNotifications(currentSegments: currentSegments, testModeActive: testModeActive)
        } else if action == "pause" || action == "stop" {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
        
        return .result()
    }
    
    private func scheduleWidgetNotifications(currentSegments: [TimeSegment], testModeActive: Bool) {
        let factor: Double = testModeActive ? 300.0 : 1.0
        let workSec = currentSegments.filter { $0.type == .work }.reduce(0.0) { $0 + $1.duration }
        let pauseSec = currentSegments.filter { $0.type == .pause }.reduce(0.0) { $0 + $1.duration }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        func schedule(milestoneMinutes: Double, identifier: String, title: String, body: String, condition: Bool) {
            guard condition else { return }
            let milestoneSeconds = milestoneMinutes * 60
            let secondsUntilMilestone = (milestoneSeconds - workSec) / factor
            
            if secondsUntilMilestone > 0 {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilMilestone, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }

        // Gleiche Regeln wie in der App
        schedule(milestoneMinutes: 345, identifier: "break_warn_545", title: "Pause fällig (in 15 Min)!", body: "Nach 6 Stunden Arbeit sind 30 Minuten Pause gesetzlich vorgeschrieben. Noch 15 Minuten bis dahin.", condition: pauseSec < 1800)
        schedule(milestoneMinutes: 360, identifier: "break_warn_600", title: "Pause fällig (30 Min)!", body: "6 Stunden Arbeit erreicht! Du musst jetzt mindestens 30 Minuten Pause gemacht haben.", condition: pauseSec < 1800)
        schedule(milestoneMinutes: 525, identifier: "break_warn_845", title: "Pause fällig (in 15 Min)!", body: "Nach 9 Stunden Arbeit sind 45 Minuten Pause gesetzlich vorgeschrieben. Noch 15 Minuten bis dahin.", condition: pauseSec < 2700)
        schedule(milestoneMinutes: 540, identifier: "break_warn_900", title: "Pause fällig (45 Min)!", body: "9 Stunden Arbeit erreicht! Du musst jetzt mindestens 45 Minuten Pause gemacht haben.", condition: pauseSec < 2700)
        schedule(milestoneMinutes: 600, identifier: "limit_warn_1000", title: "Maximale Arbeitszeit erreicht!", body: "Die gesetzliche Höchstarbeitszeit von 10 Stunden ist erreicht.", condition: true)
    }
}
