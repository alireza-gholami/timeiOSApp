//
//  SharedConstants.swift
//  time
//
//  Created by Alireza on 14.02.26.
//

import Foundation
import SwiftUI

extension Color {
    static let persianGreen = Color(red: 0/255, green: 166/255, blue: 147/255)
}

struct AppGroup {
    static let identifier = "group.com.alireza.Widget" // Match the entitlements
}

// MARK: - Shared Data Structures

public enum TimerState: String, Codable {
    case idle
    case working
    case pausing
}

public enum SegmentType: String, Codable {
    case work
    case pause
}

public struct TimeSegment: Identifiable, Codable {
    public var id = UUID()
    public var type: SegmentType
    public var startTime: Date
    public var endTime: Date?
    public var accelerationFactor: TimeInterval = 1

    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime) * accelerationFactor
    }
    
    public var realDuration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
}

public struct CompletedDay: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var segments: [TimeSegment]
    
    public var workDuration: TimeInterval {
        segments.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
    }
    
    public var pauseDuration: TimeInterval {
        segments.filter { $0.type == .pause }.reduce(0) { $0 + $1.duration }
    }
}

public struct NotificationRecord: Identifiable, Codable {
    public var id = UUID()
    public var title: String
    public var body: String
    public var date: Date
}
