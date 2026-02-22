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
        SimpleEntry(date: Date(), timerState: .idle, workSeconds: 0, pauseSeconds: 0, activeSegmentStartTime: nil)
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
        let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier)
        
        var currentSegments: [TimeSegment] = []
        if let data = sharedDefaults?.data(forKey: "currentSegments") {
            currentSegments = (try? JSONDecoder().decode([TimeSegment].self, from: data)) ?? []
        }
        
        let stateString = sharedDefaults?.string(forKey: "timerState") ?? "idle"
        let timerState = TimerState(rawValue: stateString) ?? .idle
        
        // Berechne die abgeschlossene Arbeit und Pause (ohne das aktuell laufende Segment)
        let completedWork = currentSegments.filter { $0.type == .work && $0.endTime != nil }
            .reduce(0) { $0 + $1.duration }
        let completedPause = currentSegments.filter { $0.type == .pause && $0.endTime != nil }
            .reduce(0) { $0 + $1.duration }
        
        var activeStartTime: Date? = nil
        
        if let last = currentSegments.last, last.endTime == nil {
            if last.type == .work && timerState == .working {
                // Wenn gearbeitet wird: Startzeitpunkt für Arbeits-Timer berechnen
                activeStartTime = last.startTime.addingTimeInterval(-completedWork)
            } else if last.type == .pause && timerState == .pausing {
                // Wenn Pause gemacht wird: Startzeitpunkt für Pausen-Timer berechnen
                activeStartTime = last.startTime.addingTimeInterval(-completedPause)
            }
        }
        
        return SimpleEntry(date: date, 
                          timerState: timerState, 
                          workSeconds: completedWork, 
                          pauseSeconds: completedPause,
                          activeSegmentStartTime: activeStartTime)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let timerState: TimerState
    let workSeconds: TimeInterval
    let pauseSeconds: TimeInterval
    let activeSegmentStartTime: Date?
}

struct TimeWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            // Status Anzeige
            HStack(spacing: 4) {
                Image(systemName: iconName)
                Text(statusText)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.top, 4)
            
            // Live Timer HH:MM:SS
            VStack(spacing: 0) {
                if let startTime = entry.activeSegmentStartTime, entry.timerState != .idle {
                    Text(startTime, style: .timer)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                } else {
                    Text(timeFormatted(entry.timerState == .pausing ? entry.pauseSeconds : entry.workSeconds))
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                }
                
                // Kleine Info, was gerade angezeigt wird
                Text(entry.timerState == .pausing ? "Pausezeit" : "Arbeitszeit")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 0)
            
            // Drei Buttons: Arbeit, Pause, Ende
            if #available(iOS 17.0, *) {
                HStack(spacing: 4) {
                    // Arbeit Button (Start/Weiter)
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

                    // Pause Button
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

                    // Ende Button
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
                .frame(height: 34)
                .padding(.bottom, 4)
            }
        }
    }
    
    private var statusText: String {
        switch entry.timerState {
        case .working: return "ARBEIT LÄUFT"
        case .pausing: return "IN PAUSE"
        case .idle: return "FEIERABEND"
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
        .configurationDisplayName("Arbeitszeit & Pause")
        .description("Steuere Arbeit und Pause direkt vom Homescreen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
