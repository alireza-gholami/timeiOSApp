//
//  SharedConstants.swift
//  time
//
//  Created by Alireza on 14.02.26.
//

import Foundation

struct AppGroup {
    static let identifier = "group.com.alireza.time" // Replace with your actual App Group Identifier
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
