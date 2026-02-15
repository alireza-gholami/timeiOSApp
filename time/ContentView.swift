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


    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                Text("Time Tracker")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.blue)
                
                // Time Bar Display
                TimeProgressBar(workSeconds: timeManager.workSeconds, pauseSeconds: timeManager.pauseSeconds, totalMaxSeconds: 10 * 3600)
                    .frame(height: 80)
                    .padding(.vertical, 10)
                
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
                    Text(quote)
                        .font(.caption)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
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