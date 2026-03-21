import Foundation
import Combine
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

class TimeManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var currentSegments: [TimeSegment] = [] {
        didSet { 
            LogManager.shared.log("Segments updated, total: \(currentSegments.count)")
            saveData() 
        }
    }
    @Published var timerState: TimerState = .idle {
        didSet { 
            LogManager.shared.log("Timer state changed to: \(timerState.rawValue)")
            saveData() 
        }
    }
    @Published var completedDays: [CompletedDay] = [] {
        didSet { 
            LogManager.shared.log("Completed days updated, total: \(completedDays.count)")
            saveData() 
        }
    }
    @Published var testModeActive: Bool = false {
        didSet {
            LogManager.shared.log("Test mode: \(testModeActive)")
            if let lastIndex = currentSegments.indices.last, currentSegments[lastIndex].endTime == nil {
                currentSegments[lastIndex].accelerationFactor = testModeFactor
            }
            saveData()
        }
    }
    @Published var currentQuote: String?
    @Published var deliveredNotifications: [UNNotification] = []
    @Published var notificationHistory: [NotificationRecord] = [] {
        didSet { saveData() }
    }

    private let funnyWorkQuotes: [String] = [
        "Ich liebe Deadlines. Ich mag das Geräusch, das sie machen, wenn sie vorbeirasen.",
        "Teamwork ist wichtig; es gibt anderen immer jemanden, den man verantwortlich machen kann.",
        "Mein Job ist es, Probleme zu lösen, die ich ohne meinen Job nicht hätte.",
        "Der beste Weg, um Ihre Arbeit zu schätzen, ist, sich einen Job ohne Arbeit vorzustellen.",
        "Ich bin nicht faul. Ich bin im Energiesparmodus.",
        "Montage wären einfacher, wenn sie dienstags beginnen würden.",
        "Kaffee, weil das Leben zu kurz ist für schlechte Stimmung.",
        "Ich verbringe 8 Stunden am Tag mit der Arbeit und kann nicht sagen, was ich getan habe.",
        "Das Licht am Ende des Tunnels ist nur ein entgegenkommender Zug.",
        "Meine Lieblingsbeschäftigung bei der Arbeit ist, nach Hause zu gehen.",
        "Ich stehe nur zu drei Dingen auf: Kaffee, Mittagessen und Feierabend.",
        "Der einzige Grund, warum ich meinen Wecker stelle, ist, dass ich die Arbeit hasse.",
        "Ich bin Produktivität, aber mein Chef weiß es noch nicht.",
        "Ich bin eine wertvolle Ressource für die Nicht-Produktivität.",
        "Ich arbeite hart, damit mein Hund ein besseres Leben hat.",
        "Ein Job ist ein Job, ein Chef ist ein Chef, aber das Wochenende ist das Wochenende.",
        "Ich habe einen Job, ich arbeite, ich verdiene Geld. Was mache ich damit? Ich schlafe!",
        "Das Leben ist zu kurz, um ein langweiliges Büro zu haben.",
        "Die meisten meiner besten Ideen kommen mir, wenn ich eigentlich arbeiten sollte.",
        "Jeder Tag ist ein Kampf zwischen dem Wunsch, produktiv zu sein, und dem Wunsch, ein Nickerchen zu machen."
    ]

    private var currentTimer: AnyCancellable?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @Published var lastSummaryWork: TimeInterval = 0
    @Published var lastSummaryPause: TimeInterval = 0
    private var sent5h45mWarning = false
    private var sent6HourWarning = false
    private var sent9HourWarning = false
    private var sent10HourWarning = false

    override init() {
        super.init()
        LogManager.shared.log("TimeManager initializing...")
        UNUserNotificationCenter.current().delegate = self
        loadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIScene.willEnterForegroundNotification, object: nil)
        LogManager.shared.log("TimeManager initialized.")
    }
    
    @objc private func appMovedToBackground() {
        LogManager.shared.log("App moved to background.")
        saveData()
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    @objc private func appMovedToForeground() {
        LogManager.shared.log("App moved to foreground.")
        loadData()
        endBackgroundTask()
    }
    
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            LogManager.shared.log("Background task ended.")
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    var testModeFactor: TimeInterval { testModeActive ? 300 : 1 }

    var workSeconds: TimeInterval {
        currentSegments.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
    }
    
    var pauseSeconds: TimeInterval {
        currentSegments.filter { $0.type == .pause }.reduce(0) { $0 + $1.duration }
    }

    func startWork() {
        LogManager.shared.log("Attempting to start work.")
        if timerState == .idle { 
            currentQuote = funnyWorkQuotes.randomElement() 
            lastSummaryWork = 0
            lastSummaryPause = 0
        }
        endLastActiveSegment()
        currentSegments.append(TimeSegment(type: .work, startTime: Date(), accelerationFactor: testModeFactor))
        timerState = .working
        startTimer()
    }

    func startPause() {
        LogManager.shared.log("Attempting to start pause.")
        endLastActiveSegment()
        currentSegments.append(TimeSegment(type: .pause, startTime: Date(), accelerationFactor: testModeFactor))
        timerState = .pausing
        startTimer()
    }

    func resumeWork() {
        LogManager.shared.log("Attempting to resume work.")
        endLastActiveSegment()
        currentSegments.append(TimeSegment(type: .work, startTime: Date(), accelerationFactor: testModeFactor))
        timerState = .working
        startTimer()
    }

    func finishDay() {
        LogManager.shared.log("Attempting to finish day.")
        endLastActiveSegment()
        
        // Aktuelle Summen sichern für die Zusammenfassung-Anzeige
        self.lastSummaryWork = self.workSeconds
        self.lastSummaryPause = self.pauseSeconds

        let dayRecord = CompletedDay(id: UUID(), date: Date(), segments: currentSegments)
        LogManager.shared.log("Created day record with \(currentSegments.count) segments.")
        
        self.completedDays.append(dayRecord)
        
        // Wait a bit to ensure the save from completedDays.didSet is initiated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            LogManager.shared.log("Resetting state after finishDay.")
            self.reset()
        }
    }

    func reset() {
        LogManager.shared.log("Resetting TimeManager state.")
        stopTimer()
        currentSegments = []
        timerState = .idle
        currentQuote = nil
        sent5h45mWarning = false
        sent6HourWarning = false
        sent9HourWarning = false
        sent10HourWarning = false
    }

    private func endLastActiveSegment() {
        if let lastIndex = currentSegments.indices.last, currentSegments[lastIndex].endTime == nil {
            currentSegments[lastIndex].endTime = Date()
            LogManager.shared.log("Ended active segment: \(currentSegments[lastIndex].type.rawValue)")
        }
    }

    private func startTimer() {
        if currentTimer == nil {
            LogManager.shared.log("Timer starting.")
            currentTimer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                    self?.checkBreakRules()
                }
        }
    }

    private func stopTimer() {
        LogManager.shared.log("Timer stopping.")
        currentTimer?.cancel()
        currentTimer = nil
    }

    func saveData() {
        // Capture data safely on main thread
        let segments = self.currentSegments
        let days = self.completedDays
        let notifications = self.notificationHistory
        let state = self.timerState
        let testMode = self.testModeActive
        let summaryW = self.lastSummaryWork
        let summaryP = self.lastSummaryPause
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) else { 
                LogManager.shared.log("CRITICAL: Could not access AppGroup for saving!")
                return 
            }
            
            do {
                let encodedDays = try JSONEncoder().encode(days)
                let encodedSegments = try JSONEncoder().encode(segments)
                let encodedNotifications = try JSONEncoder().encode(notifications)
                
                sharedDefaults.set(encodedDays, forKey: "completedDays")
                sharedDefaults.set(encodedSegments, forKey: "currentSegments")
                sharedDefaults.set(encodedNotifications, forKey: "notificationHistory")
                sharedDefaults.set(testMode, forKey: "testModeActive")
                sharedDefaults.set(state.rawValue, forKey: "timerState")
                sharedDefaults.set(summaryW, forKey: "lastSummaryWork")
                sharedDefaults.set(summaryP, forKey: "lastSummaryPause")
                
                // Important for AppGroup sync
                sharedDefaults.synchronize()
                
                WidgetCenter.shared.reloadAllTimelines()
                // Do not log from here to avoid endless loops or excessive noise in background
            } catch {
                LogManager.shared.log("ERROR during saving: \(error.localizedDescription)")
            }
        }
    }

    func loadData() {
        LogManager.shared.log("Loading data from AppGroup...")
        guard let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) else { 
            LogManager.shared.log("CRITICAL: Could not access AppGroup for loading!")
            return 
        }
        
        if let savedDays = sharedDefaults.data(forKey: "completedDays"),
           let decodedDays = try? JSONDecoder().decode([CompletedDay].self, from: savedDays) {
            DispatchQueue.main.async { 
                self.completedDays = decodedDays 
                LogManager.shared.log("Loaded \(decodedDays.count) completed days.")
            }
        }

        if let savedHistory = sharedDefaults.data(forKey: "notificationHistory"),
           let decodedHistory = try? JSONDecoder().decode([NotificationRecord].self, from: savedHistory) {
            DispatchQueue.main.async {
                self.notificationHistory = decodedHistory
                LogManager.shared.log("Loaded \(decodedHistory.count) notifications.")
            }
        }

        let summaryW = sharedDefaults.double(forKey: "lastSummaryWork")
        let summaryP = sharedDefaults.double(forKey: "lastSummaryPause")
        DispatchQueue.main.async {
            self.lastSummaryWork = summaryW
            self.lastSummaryPause = summaryP
        }
        
        if let savedSegments = sharedDefaults.data(forKey: "currentSegments"),
           let decodedSegments = try? JSONDecoder().decode([TimeSegment].self, from: savedSegments) {
            DispatchQueue.main.async {
                self.currentSegments = decodedSegments
                let stateString = sharedDefaults.string(forKey: "timerState") ?? "idle"
                self.timerState = TimerState(rawValue: stateString) ?? .idle
                LogManager.shared.log("Loaded \(decodedSegments.count) segments. State: \(self.timerState.rawValue)")
                if !self.currentSegments.isEmpty && self.currentSegments.last?.endTime == nil {
                    self.startTimer()
                }
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                LogManager.shared.log("Notification permission granted.")
            } else if let error = error {
                LogManager.shared.log("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchDeliveredNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] notifications in
            DispatchQueue.main.async {
                self?.deliveredNotifications = notifications.sorted(by: { $0.date > $1.date })
            }
        }
    }
    
    func markNotificationsAsRead() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0)
        deliveredNotifications = []
    }
    
    func sendTestPush() {
        sendNotification(title: "Test Push", body: "Notifications are working correctly!")
    }

    private func checkBreakRules() {
        if !sent5h45mWarning && workSeconds >= (345 * 60) && pauseSeconds < (30 * 60) {
            sendNotification(title: "Pause fällig (in 15 Min)!", body: "Nach 6 Stunden Arbeit sind 30 Minuten Pause gesetzlich vorgeschrieben. Noch 15 Minuten bis dahin.")
            sent5h45mWarning = true
        }
        if !sent6HourWarning && workSeconds >= (360 * 60) && pauseSeconds < (30 * 60) {
            sendNotification(title: "Pause fällig (30 Min)!", body: "Nach 6 Stunden Arbeit sind 30 Minuten Pause gesetzlich vorgeschrieben.")
            sent6HourWarning = true
        }
        if !sent9HourWarning && workSeconds >= (525 * 60) && pauseSeconds < (45 * 60) {
            sendNotification(title: "Pause fällig (45 Min)!", body: "Nach 9 Stunden Arbeit sind 45 Minuten Pause gesetzlich vorgeschrieben.")
            sent9HourWarning = true
        }
        if !sent10HourWarning && workSeconds >= (600 * 60) {
            sendNotification(title: "Maximale Arbeitszeit erreicht!", body: "Die gesetzliche Höchstarbeitszeit von 10 Stunden ist erreicht.")
            sent10HourWarning = true
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        // Add to persistent history
        let record = NotificationRecord(title: title, body: body, date: Date())
        DispatchQueue.main.async {
            self.notificationHistory.append(record)
        }
    }

    func updateDay(id: UUID, workMinutes: Double, pauseMinutes: Double) {
        if let index = completedDays.firstIndex(where: { $0.id == id }) {
            var updatedSegments: [TimeSegment] = []
            let now = Date()
            let factor = completedDays[index].segments.first?.accelerationFactor ?? 1.0
            if workMinutes > 0 {
                let dur = (workMinutes * 60) / factor
                updatedSegments.append(TimeSegment(type: .work, startTime: now.addingTimeInterval(-dur), endTime: now, accelerationFactor: factor))
            }
            if pauseMinutes > 0 {
                let dur = (pauseMinutes * 60) / factor
                let end = updatedSegments.first?.startTime ?? now
                updatedSegments.append(TimeSegment(type: .pause, startTime: end.addingTimeInterval(-dur), endTime: end, accelerationFactor: factor))
            }
            completedDays[index].segments = updatedSegments.sorted { $0.startTime < $1.startTime }
        }
    }
    
    func updateSegment(forDayId dayId: UUID, segmentId: UUID, newStartTime: Date, newEndTime: Date?) {
        if let dayIndex = completedDays.firstIndex(where: { $0.id == dayId }) {
            if let segmentIndex = completedDays[dayIndex].segments.firstIndex(where: { $0.id == segmentId }) {
                completedDays[dayIndex].segments[segmentIndex].startTime = newStartTime
                completedDays[dayIndex].segments[segmentIndex].endTime = newEndTime
            }
        }
    }
    
    func exportToCSV() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var lines = ["Date,Type,Start Time,End Time,Duration (s)"]
        for day in completedDays {
            for seg in day.segments {
                let line = "\(dateFormatter.string(from: day.date)),\(seg.type.rawValue),\(dateFormatter.string(from: seg.startTime)),\(seg.endTime.map { dateFormatter.string(from: $0) } ?? ""),\(seg.duration)"
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}
