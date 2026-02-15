//
//  ContentView.swift
//  time
//
//  Created by Alireza on 14.02.26.
//

import SwiftUI
import UIKit // Required for UIActivityViewController

struct ContentView: View {
    @StateObject private var timeManager = TimeManager()
    @State private var showingHistory: Bool = false
    @State private var showingNotifications: Bool = false // New state for notifications
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var initialDisplayTime: Date = Date() // Capture the initial display time
    
    // Formatter for displaying only time (HH:MM)
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Use "HH:mm" for 24-hour format
        return formatter
    }()


    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                Text("Time Tracker")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.blue)
                
                // Time Bar Display
                TimeProgressBar(timeManager: timeManager, totalMaxSeconds: 10 * 3600)
                    .frame(height: 80)
                    .padding(.vertical, 10)
                
                // Time Markers
                GeometryReader { geometry in
                    let baseTimeForMilestones = timeManager.currentSegments.first?.startTime ?? Date() // Use current time if no session active
                    let totalMaxDuration: TimeInterval = 10 * 3600 // 10 hours in seconds
                    
                    HStack(spacing: 0) {
                        // Current actual time for the first marker
                        Text(timeFormatter.string(from: initialDisplayTime))
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .frame(width: 40, alignment: .leading) // Align left
                            .offset(x: -20) // Align left edge of text with left edge of bar
                        
                        // Spacer to 6-hour mark
                        // The width of the spacer needs to consider the 40pt width of the Text element itself
                        Spacer(minLength: 0)
                            .frame(width: max(0, (CGFloat(6 * 3600) / CGFloat(totalMaxDuration) * geometry.size.width) - 40))

                        // 6-hour mark
                        Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(6 * 3600)))
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .frame(width: 40, alignment: .center) // Center the text

                        // Spacer to 8-hour mark
                        Spacer(minLength: 0)
                            .frame(width: max(0, (CGFloat(8 * 3600) / CGFloat(totalMaxDuration) * geometry.size.width) - (CGFloat(6 * 3600) / CGFloat(totalMaxDuration) * geometry.size.width) - 40))

                        // 8-hour mark
                        Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(8 * 3600)))
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .frame(width: 40, alignment: .center) // Center the text
                        
                        // Spacer to 10-hour mark
                        Spacer(minLength: 0)
                            .frame(width: max(0, (CGFloat(totalMaxDuration) / CGFloat(totalMaxDuration) * geometry.size.width) - (CGFloat(8 * 3600) / CGFloat(totalMaxDuration) * geometry.size.width) - 40)) // Remaining width to end, adjusted for end text

                        // 10-hour mark
                        Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(totalMaxDuration)))
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .frame(width: 40, alignment: .trailing) // Align right
                            .offset(x: 20) // Align right edge of text with right edge of bar
                    }
                    .frame(height: 20)
                }
                .padding(.horizontal)
                
                Spacer() // Add a spacer to push the text down
                
                // Text for current durations
                HStack {
                    Text("Arbeit: \(timeFormatted(timeManager.workSeconds))")
                    Spacer()
                    Text("Pause: \(timeFormatted(timeManager.pauseSeconds))")
                }
                .font(.title2)
                .padding(.horizontal)
                
                Text("Status: \(statusText(for: timeManager.timerState))")
                    .font(.headline)
                    .padding(.bottom, 10)
                
                if let quote = timeManager.currentQuote {
                    VStack { // Use VStack for the box effect
                        Text(quote)
                            .font(.title3) // Much larger font
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal) // Apply horizontal padding to the text inside the box
                            .padding(.vertical, 15) // Increased vertical padding for the text
                    }
                    .background(.ultraThinMaterial) // No specific color, using a system material for transparency
                    .cornerRadius(10) // Rounded corners for the box
                    .padding(.horizontal) // Padding for the box itself from the edges of the screen
                    .padding(.bottom, 10) // Retain original bottom padding
                }

                HStack(spacing: 20) {
                    // Button Logic based on timerState
                    switch timeManager.timerState {
                    case .idle:
                        Button("Start Arbeitszeit") {
                            timeManager.startWork()
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .green))
                    case .working:
                        Button("Pause starten") {
                            timeManager.startPause()
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .orange))
                    case .pausing:
                        Button("Arbeitszeit fortsetzen") {
                            timeManager.resumeWork()
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .green))
                    }
                }
                .padding(.horizontal)

                if timeManager.timerState != .idle {
                    Button("Tag beenden") {
                        timeManager.finishDay()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .red))
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .onAppear(perform: timeManager.requestNotificationPermission)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle(isOn: $isDarkMode) {
                            Label("Dark Mode", systemImage: isDarkMode ? "moon.fill" : "moon")
                        }
                        
                        Toggle(isOn: $timeManager.testModeActive) {
                            Label("Test-Modus (300x Speed)", systemImage: "speedometer")
                        }
                        
                        Button {
                            showingHistory = true
                        } label: {
                            Label("History bearbeiten", systemImage: "list.bullet.rectangle.portrait")
                        }
                        
                        Button {
                            showingNotifications = true
                            timeManager.fetchDeliveredNotifications() // Fetch notifications before showing
                        } label: {
                            Label("Benachrichtigungen", systemImage: "bell.badge")
                        }
                        
                        Button {
                            let csvString = timeManager.exportToCSV()
                            shareCSV(csvString: csvString)
                        } label: {
                            Label("Export in Excel", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("Menü", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(timeManager: timeManager)
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView(timeManager: timeManager)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    private func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        let seconds: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        let minutes: Int = Int((totalSeconds / 60).truncatingRemainder(dividingBy: 60))
        let hours: Int = Int(totalSeconds / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func statusText(for state: TimerState) -> String {
        switch state {
        case .idle:
            return "Bereit"
        case .working:
            return "Arbeitet"
        case .pausing:
            return "Pause"
        }
    }
    
    private func shareCSV(csvString: String) {
        let fileName = "time_data.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path!, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create file")
            print("\(error)")
        }
        
        let activityViewController = UIActivityViewController(activityItems: [path!], applicationActivities: nil)
        
        // Find the topmost ViewController to present from
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var topController = root
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(activityViewController, animated: true, completion: nil)
        }
    }
}

// A reusable ButtonStyle for consistency
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .foregroundStyle(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}


#Preview {
    ContentView()
}