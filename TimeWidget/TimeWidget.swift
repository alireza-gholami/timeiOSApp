//
//  TimeWidget.swift
//  TimeWidget
//
//  Created by Alireza on 22.02.26.
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), timerState: .idle, workSeconds: 0, pauseSeconds: 0, activeSegmentStartTime: nil, testModeActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = loadEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadEntry(for: Date())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func loadEntry(for date: Date) -> SimpleEntry {
        // Swift 6 fix: hardcode or use safe access
        let groupID = "group.com.alireza.Widget"
        let sharedDefaults = UserDefaults(suiteName: groupID)
        
        let testModeActive = sharedDefaults?.bool(forKey: "testModeActive") ?? false
        
        var currentSegments: [TimeSegment] = []
        if let data = sharedDefaults?.data(forKey: "currentSegments") {
            currentSegments = (try? JSONDecoder().decode([TimeSegment].self, from: data)) ?? []
        }
        
        let stateString = sharedDefaults?.string(forKey: "timerState") ?? "idle"
        let timerState = TimerState(rawValue: stateString) ?? .idle
        
        let lastSummaryWork = sharedDefaults?.double(forKey: "lastSummaryWork") ?? 0
        let lastSummaryPause = sharedDefaults?.double(forKey: "lastSummaryPause") ?? 0
        
        var totalWork = currentSegments.filter { $0.type == .work }
            .reduce(0.0) { $0 + $1.duration }
        var totalPause = currentSegments.filter { $0.type == .pause }
            .reduce(0.0) { $0 + $1.duration }
        
        // Wenn Idle und Zusammenfassung vorhanden, diese nutzen
        if timerState == .idle && lastSummaryWork > 0 {
            totalWork = lastSummaryWork
            totalPause = lastSummaryPause
        }
        
        var activeStartTime: Date? = nil
        
        if let last = currentSegments.last, last.endTime == nil {
            if last.type == .work && timerState == .working {
                activeStartTime = last.startTime.addingTimeInterval(-totalWork + last.duration)
            } else if last.type == .pause && timerState == .pausing {
                activeStartTime = last.startTime.addingTimeInterval(-totalPause + last.duration)
            }
        }
        
        return SimpleEntry(date: date, 
                          timerState: timerState, 
                          workSeconds: totalWork, 
                          pauseSeconds: totalPause,
                          activeSegmentStartTime: activeStartTime,
                          testModeActive: testModeActive)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let timerState: TimerState
    let workSeconds: TimeInterval
    let pauseSeconds: TimeInterval
    let activeSegmentStartTime: Date?
    let testModeActive: Bool
}

struct TimeWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Status Anzeige
            HStack(spacing: 4) {
                Image(systemName: iconName)
                Text(statusText)
                
                Spacer()
                
                if #available(iOS 17.0, *) {
                    Link(destination: URL(string: "timeapp://edit")!) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 4)

                    Button(intent: ToggleTimerIntent(action: "toggleTestMode")) {
                        Image(systemName: entry.testModeActive ? "bolt.fill" : "bolt")
                            .foregroundColor(entry.testModeActive ? .yellow : .gray)
                    }
                    .buttonStyle(.plain)
                } else if entry.testModeActive {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                }
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.top, 4)
            
            // Live Timer HH:MM:SS
            VStack(spacing: 0) {
                if let startTime = entry.activeSegmentStartTime, entry.timerState != .idle {
                    Text(startTime, style: .timer)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                } else {
                    Text(timeFormatted(entry.timerState == .pausing ? entry.pauseSeconds : entry.workSeconds))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                }
            }
            
            // Zusammenfassung im Widget
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Arbeit").font(.system(size: 8, weight: .bold))
                    Text(timeFormattedShort(entry.workSeconds)).font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Pause").font(.system(size: 8, weight: .bold))
                    Text(timeFormattedShort(entry.pauseSeconds)).font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.orange)
            }
            .padding(.horizontal, 12)
            
            Spacer(minLength: 0)
            
            // Drei Buttons: Arbeit, Pause, Ende
            if #available(iOS 17.0, *) {
                HStack(spacing: 4) {
                    Button(intent: ToggleTimerIntent(action: entry.timerState == .idle ? "work" : "resume")) {
                        VStack(spacing: 1) {
                            Image(systemName: "play.fill")
                            Text("Arbeit").font(.system(size: 7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(entry.timerState == .working)

                    Button(intent: ToggleTimerIntent(action: "pause")) {
                        VStack(spacing: 1) {
                            Image(systemName: "pause.fill")
                            Text("Pause").font(.system(size: 7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(entry.timerState == .pausing || entry.timerState == .idle)

                    Button(intent: ToggleTimerIntent(action: "stop")) {
                        VStack(spacing: 1) {
                            Image(systemName: "stop.fill")
                            Text("Ende").font(.system(size: 7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(entry.timerState == .idle)
                }
                .frame(height: 32)
                .padding(.bottom, 4)
            }
        }
    }
    
    private var statusText: String {
        switch entry.timerState {
        case .working: return "ARBEIT"
        case .pausing: return "PAUSE"
        case .idle: return "FREI"
        }
    }
    
    private var iconName: String {
        switch entry.timerState {
        case .working: return "briefcase.fill"
        case .pausing: return "pause.circle.fill"
        case .idle: return "sun.max.fill"
        }
    }
    
    private var statusColor: Color {
        switch entry.timerState {
        case .working: return .blue
        case .pausing: return .orange
        case .idle: return .green
        }
    }
    
    private func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        let hours: Int = Int(totalSeconds / 3600)
        let minutes: Int = Int((totalSeconds / 60).truncatingRemainder(dividingBy: 60))
        let seconds: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func timeFormattedShort(_ totalSeconds: TimeInterval) -> String {
        let hours: Int = Int(totalSeconds / 3600)
        let minutes: Int = Int((totalSeconds / 60).truncatingRemainder(dividingBy: 60))
        return String(format: "%02dh %02dm", hours, minutes)
    }
}

struct TimeWidget: Widget {
    let kind: String = "TimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                TimeWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TimeWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Arbeitszeit")
        .description("Steuere Arbeit und Pause direkt vom Homescreen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
