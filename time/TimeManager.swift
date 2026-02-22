import Foundation
import Combine
import SwiftUI // Import SwiftUI for @AppStorage and ScenePhase
import UIKit // For background task
import UserNotifications
import WidgetKit // Import WidgetKit to reload the timeline

class TimeManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var currentSegments: [TimeSegment] = [] {
        didSet { saveData() } // Save data when currentSegments changes
    }
    @Published var timerState: TimerState = .idle
    @Published var completedDays: [CompletedDay] = [] {
        didSet { saveData() } // Save data when completedDays changes
    }
    @Published var testModeActive: Bool = false {
        didSet {
            // Recalculate duration for active segment if test mode changes while running
            if let lastIndex = currentSegments.indices.last, currentSegments[lastIndex].endTime == nil {
                currentSegments[lastIndex].accelerationFactor = testModeFactor // Update factor for active segment
            }
            saveData() // Save when testModeActive changes to persist setting
        }
    }
    @Published var currentQuote: String?
    @Published var deliveredNotifications: [UNNotification] = []

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
    
    // Flags to prevent spamming notifications
    private var sent6HourWarning = false
    private var sent9HourWarning = false
    private var sent10HourWarning = false

    override init() {
        super.init()
        LogManager.shared.log("TimeManager initialized.")
        UNUserNotificationCenter.current().delegate = self
        loadData() // Load data when TimeManager is initialized
        
        // Observe scenePhase changes to save data when app goes to background
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIScene.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func appMovedToBackground() {
        LogManager.shared.log("App moved to background, starting background task.")
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // End the task if time runs out.
            self?.endBackgroundTask()
        }
        
        saveData()
        
        // End the background task shortly after saving.
        // Give it a couple of seconds to make sure the save is complete.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    @objc private func appMovedToForeground() {
        LogManager.shared.log("App moved to foreground.")
        loadData() // Reload data to sync with Widget changes
        endBackgroundTask()
    }
    
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            LogManager.shared.log("Ended background task.")
        }
    }

    // Delegate method to handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    var testModeFactor: TimeInterval {
        testModeActive ? 300 : 1
    }

    // Computed property for total work duration for the current day
    var workSeconds: TimeInterval {
        currentSegments.filter { $0.type == .work }.reduce(0) { total, segment in
            total + segment.duration
        }
    }
    
    // Computed property for total pause duration for the current day
    var pauseSeconds: TimeInterval {
        currentSegments.filter { $0.type == .pause }.reduce(0) { total, segment in
            total + segment.duration
        }
    }

    var remainingWorkUntilBreak: TimeInterval {
        let maxWorkBeforeBreak: TimeInterval = 6 * 3600 // 6 hours
        return max(0, maxWorkBeforeBreak - workSeconds)
    }

    var requiredBreakAfter6Hours: TimeInterval {
        if workSeconds >= 9 * 3600 {
            return 45 * 60
        } else if workSeconds >= 6 * 3600 {
            return 30 * 60
        }
        return 0
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
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Increment badge for each new notification
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let currentBadge = notifications.filter { $0.request.content.badge != nil }.count
            content.badge = (currentBadge + 1) as NSNumber
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Immediate trigger
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func fetchDeliveredNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] notifications in
            DispatchQueue.main.async {
                self?.deliveredNotifications = notifications.sorted(by: { $0.date > $1.date }) // Sort by newest first
            }
        }
    }
    
    func markNotificationsAsRead() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0) // Use new API for iOS 17+
        deliveredNotifications = [] // Clear the list in the manager
    }
    
    func sendTestPush() {
        sendNotification(title: "Test Push", body: "Notifications are working correctly!")
    }
    
    private func checkBreakRules() {
        // Rule for 30-min break warning (at 5h 45m of work)
        if !sent6HourWarning && workSeconds >= (345 * 60) && pauseSeconds < (30 * 60) {
            sendNotification(title: "Pause fällig (30 Min)!", body: "Nach 6 Stunden Arbeit sind 30 Minuten Pause gesetzlich vorgeschrieben.")
            sent6HourWarning = true
        }

        // Rule for 45-min break warning (at 8h 45m of work)
        if !sent9HourWarning && workSeconds >= (525 * 60) && pauseSeconds < (45 * 60) {
            sendNotification(title: "Pause fällig (45 Min)!", body: "Nach 9 Stunden Arbeit sind 45 Minuten Pause gesetzlich vorgeschrieben.")
            sent9HourWarning = true
        }

        // Rule for 10-hour max work time
        if !sent10HourWarning && workSeconds >= (600 * 60) {
            sendNotification(title: "Maximale Arbeitszeit erreicht!", body: "Die gesetzliche Höchstarbeitszeit von 10 Stunden ist erreicht.")
            sent10HourWarning = true
        }
    }

    private func startTimer() {
        if currentTimer == nil {
            LogManager.shared.log("Timer started.")
            var lastSaveTime = Date()
            currentTimer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] currentTime in
                    guard let self = self else { return }
                    
                    self.objectWillChange.send() // Force UI update to recalculate computed properties
                    self.checkBreakRules() // Check rules every second work ticks

                    if currentTime.timeIntervalSince(lastSaveTime) >= 10 {
                        self.saveData()
                        lastSaveTime = currentTime
                    }
                }
        }
    }

    private func stopTimer() {
        LogManager.shared.log("Timer stopped.")
        currentTimer?.cancel()
        currentTimer = nil
    }

    private func endLastActiveSegment() {
        if let lastIndex = currentSegments.indices.last, currentSegments[lastIndex].endTime == nil {
            currentSegments[lastIndex].endTime = Date() // Set real end time
            LogManager.shared.log("Ended last active segment.")
        }
    }

    func startWork() {
        LogManager.shared.log("Starting work.")
        if timerState == .idle {
            currentQuote = funnyWorkQuotes.randomElement()
        }
        
        endLastActiveSegment() // End any previously active segment
        currentSegments.append(TimeSegment(type: .work, startTime: Date(), accelerationFactor: testModeFactor)) // Pass current testModeFactor
        timerState = .working
        startTimer()
    }

    func startPause() {
        LogManager.shared.log("Starting pause.")
        endLastActiveSegment() // End active work segment
        currentSegments.append(TimeSegment(type: .pause, startTime: Date(), accelerationFactor: testModeFactor)) // Pass current testModeFactor
        timerState = .pausing
        startTimer() // Ensure timer is running for pause
    }

    func resumeWork() {
        LogManager.shared.log("Resuming work.")
        endLastActiveSegment() // End active pause segment
        currentSegments.append(TimeSegment(type: .work, startTime: Date(), accelerationFactor: testModeFactor)) // Pass current testModeFactor
        timerState = .working
        startTimer() // Ensure timer is running for work
    }

    func finishDay() {
        LogManager.shared.log("Finishing day.")
        endLastActiveSegment() // End any active segment

        let dayRecord = CompletedDay(id: UUID(), date: Date(), segments: currentSegments)
        completedDays.append(dayRecord)
        
        reset()
    }

    func reset() {
        LogManager.shared.log("Resetting TimeManager.")
        stopTimer()
        currentSegments = []
        timerState = .idle
        currentQuote = nil
        // Reset warning flags for the new day
        sent6HourWarning = false
        sent9HourWarning = false
        sent10HourWarning = false
    }
    
    // Key for UserDefaults
    private let completedDaysKey = "completedDays"
    private let currentSegmentsKey = "currentSegments"
    private let testModeActiveKey = "testModeActive"

    func saveData() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            LogManager.shared.log("Saving data to AppGroup.")
            do {
                guard let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) else { return }
                
                let encodedCompletedDays = try JSONEncoder().encode(self.completedDays)
                sharedDefaults.set(encodedCompletedDays, forKey: "completedDays")

                let encodedCurrentSegments = try JSONEncoder().encode(self.currentSegments)
                sharedDefaults.set(encodedCurrentSegments, forKey: "currentSegments")
                
                sharedDefaults.set(self.testModeActive, forKey: "testModeActive")
                sharedDefaults.set(self.timerState.rawValue, forKey: "timerState")
                
                LogManager.shared.log("Data saved successfully to AppGroup. Total completed days: \(self.completedDays.count)")
                
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                LogManager.shared.log("Failed to save data to AppGroup: \(error)")
            }
        }
    }

    func loadData() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            LogManager.shared.log("Loading data from AppGroup.")
            
            guard let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
                LogManager.shared.log("Failed to access AppGroup defaults.")
                return
            }

            if let savedCompletedDays = sharedDefaults.data(forKey: "completedDays") {
                do {
                    let decodedCompletedDays = try JSONDecoder().decode([CompletedDay].self, from: savedCompletedDays)
                    DispatchQueue.main.async {
                        self.completedDays = decodedCompletedDays
                        LogManager.shared.log("Completed days loaded from AppGroup: \(decodedCompletedDays.count)")
                    }
                } catch {
                    LogManager.shared.log("Failed to load completed days from AppGroup: \(error)")
                }
            }
            
            if let savedCurrentSegments = sharedDefaults.data(forKey: "currentSegments") {
                do {
                    let decodedCurrentSegments = try JSONDecoder().decode([TimeSegment].self, from: savedCurrentSegments)
                    DispatchQueue.main.async {
                        self.currentSegments = decodedCurrentSegments
                        LogManager.shared.log("Current segments loaded from AppGroup.")
                        
                        // Check state from AppGroup instead of recalculating (more reliable with Widget)
                        let stateString = sharedDefaults.string(forKey: "timerState") ?? "idle"
                        self.timerState = TimerState(rawValue: stateString) ?? .idle
                        
                        if !self.currentSegments.isEmpty && self.currentSegments.last?.endTime == nil {
                            self.startTimer()
                        }
                    }
                } catch {
                    LogManager.shared.log("Failed to load current segments from AppGroup: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.testModeActive = sharedDefaults.bool(forKey: "testModeActive")
            }
        }
    }

    func updateDay(id: UUID, workMinutes: Double, pauseMinutes: Double) {
        if let index = completedDays.firstIndex(where: { $0.id == id }) {
            // This is a simplified update: we're reconstructing segments based on new total durations.
            // Original segment start/end times are lost.
            var updatedSegments: [TimeSegment] = []
            let now = Date()
            let editingAccelerationFactor = completedDays[index].segments.first?.accelerationFactor ?? 1.0 // Use factor from an existing segment if any

            if workMinutes > 0 {
                // Approximate start/end for work segment with accelerated duration
                let workRealDuration = (workMinutes * 60) / editingAccelerationFactor
                let workSegment = TimeSegment(type: .work, startTime: now.addingTimeInterval(-workRealDuration), endTime: now, accelerationFactor: editingAccelerationFactor)
                updatedSegments.append(workSegment)
            }
            // If both are present, pause is assumed to be before work for simplicity
            if pauseMinutes > 0 {
                let pauseRealDuration = (pauseMinutes * 60) / editingAccelerationFactor
                let pauseEndTime = updatedSegments.first?.startTime ?? now // End of pause is start of work, or now if no work
                let pauseStartTime = pauseEndTime.addingTimeInterval(-pauseRealDuration)
                let pauseSegment = TimeSegment(type: .pause, startTime: pauseStartTime, endTime: pauseEndTime, accelerationFactor: editingAccelerationFactor)
                updatedSegments.append(pauseSegment)
            }
            
            // Sort by start time for consistency
            completedDays[index].segments = updatedSegments.sorted { $0.startTime < $1.startTime }
        }
    }
    
    func updateSegment(forDayId dayId: UUID, segmentId: UUID, newStartTime: Date, newEndTime: Date?) {
        if let dayIndex = completedDays.firstIndex(where: { $0.id == dayId }) {
            if let segmentIndex = completedDays[dayIndex].segments.firstIndex(where: { $0.id == segmentId }) {
                // Update the segment's start and end times
                completedDays[dayIndex].segments[segmentIndex].startTime = newStartTime
                completedDays[dayIndex].segments[segmentIndex].endTime = newEndTime
                // Note: This simple update does not re-evaluate or shift subsequent segments.
                // It also assumes the accelerationFactor remains the same.
                // The duration property of the TimeSegment will automatically recalculate.
            }
        }
    }
    
    // MARK: - Export Logic
    func exportToCSV() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var lines = ["Date,Type,Start Time (Real),End Time (Real),Real Duration (seconds),Accelerated Duration (seconds),Accelerated Duration (HH:MM:SS)"]
        
        for day in completedDays {
            let dayDateString = dateFormatter.string(from: day.date).split(separator: " ").first!
            
            for segment in day.segments {
                let segmentType = segment.type.rawValue.capitalized
                let startTimeString = dateFormatter.string(from: segment.startTime)
                let endTimeString = segment.endTime.map { dateFormatter.string(from: $0) } ?? ""
                
                let realDurationSeconds = String(format: "%.0f", segment.realDuration)
                let acceleratedDurationSeconds = String(format: "%.0f", segment.duration)
                
                let durationFormatted = timeFormatted(segment.duration)
                
                let line = "\(dayDateString),\(segmentType),\(startTimeString),\(endTimeString),\(realDurationSeconds),\(acceleratedDurationSeconds),\(durationFormatted)"
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
    
    // Helper function for time formatting, similar to ContentView's
    private func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        let seconds: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        let minutes: Int = Int((totalSeconds / 60).truncatingRemainder(dividingBy: 60))
        let hours: Int = Int(totalSeconds / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
