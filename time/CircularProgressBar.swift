
import SwiftUI

struct CircularProgressBar: View {
    @ObservedObject var timeManager: TimeManager
    var totalMaxSeconds: TimeInterval
    var initialDisplayTime: Date // For the 0-hour mark
    var baseTimeForMilestones: Date // For 6, 8, 10-hour marks

    // Formatter for displaying only time (HH:MM)
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Use "HH:mm" for 24-hour format
        return formatter
    }()

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            let radius = diameter / 2
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let lineWidth: CGFloat = 20
            let textRadius = radius + (lineWidth / 2) + 20 // Position text further outside the bar to prevent overlap
            
            // Calculate the angle corresponding to initialDisplayTime (0=12 o'clock, clockwise)
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: initialDisplayTime)
            let minute = calendar.component(.minute, from: initialDisplayTime)
            let normalizedTime = Double(hour % 12) + (Double(minute) / 60.0)
            let initialTimeOffsetAngleFrom12Clock = Angle.degrees(normalizedTime * 30.0) // 30 degrees per hour (360/12)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.persianGreen.opacity(0.8), lineWidth: lineWidth)
                
                // Progress arcs
                ForEach(Array(timeManager.currentSegments.enumerated()), id: \.offset) { index, segment in
                    // Calculate startAngle declaratively by summing angles of preceding segments
                    let currentAccumulatedAngle = timeManager.currentSegments[0..<index].reduce(Angle.zero) { (currentTotalAngle, prevSegment) -> Angle in
                        currentTotalAngle + Angle.degrees(prevSegment.duration / totalMaxSeconds * 360)
                    }
                    
                    let segmentDuration = segment.duration
                    let segmentAngle = Angle.degrees(segmentDuration / totalMaxSeconds * 360)
                    
                    Path { path in
                        // Convert angles from 0=12 o'clock CW to 0=3 o'clock CCW for addArc
                        let arcStartAngle = Angle.degrees(90) - (initialTimeOffsetAngleFrom12Clock + currentAccumulatedAngle)
                        let arcEndAngle = Angle.degrees(90) - (initialTimeOffsetAngleFrom12Clock + currentAccumulatedAngle + segmentAngle)
                        
                        path.addArc(center: center,
                                    radius: radius - (lineWidth / 2), // Adjust radius for line width
                                    startAngle: arcStartAngle,
                                    endAngle: arcEndAngle,
                                    clockwise: false) // Always draw counter-clockwise
                    }
                    .stroke(segment.type == .work ? Color.green : Color.orange, lineWidth: lineWidth)
                }

                // Time Markers
                Group {
                    // 0-hour mark (Initial Display Time)
                    Text(timeFormatter.string(from: initialDisplayTime))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: positionAngleFrom12Clock(initialTimeOffsetAngleFrom12Clock + Angle.zero), center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(0)) // No rotation needed for text if ZStack is not rotated

                    // 6-hour mark
                    let sixHourAngle = Angle.degrees((6 * 3600) / totalMaxSeconds * 360)
                    Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(6 * 3600)))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: positionAngleFrom12Clock(initialTimeOffsetAngleFrom12Clock + sixHourAngle), center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(0))

                    // 8-hour mark
                    let eightHourAngle = Angle.degrees((8 * 3600) / totalMaxSeconds * 360)
                    Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(8 * 3600)))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: positionAngleFrom12Clock(initialTimeOffsetAngleFrom12Clock + eightHourAngle), center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(0))

                    // 10-hour mark
                    let tenHourAngle = Angle.degrees((10 * 3600) / totalMaxSeconds * 360)
                    Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(10 * 3600)))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: positionAngleFrom12Clock(initialTimeOffsetAngleFrom12Clock + tenHourAngle), center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(0))
                }
            }
            // No rotation on ZStack, as arcs and text positions are now correctly calculated relative to 0=12 o'clock, CW
            .frame(width: geometry.size.width, height: geometry.size.height) // Ensure ZStack respects GeometryReader's frame
        }
    }
    
    // Helper to position text for a given angle
    private func positionForAngle(angle: Angle, center: CGPoint, textRadius: CGFloat) -> CGPoint {
        let x = center.x + textRadius * cos(angle.radians)
        let y = center.y + textRadius * sin(angle.radians)
        return CGPoint(x: x, y: y)
    }

    // Helper to convert 0=12 o'clock CW to 0=3 o'clock CCW for positionForAngle
    private func positionAngleFrom12Clock(_ angleFrom12Clock: Angle) -> Angle {
        return Angle.degrees(90) - angleFrom12Clock
    }
}

struct CircularProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        let mockTimeManager = TimeManager()
        mockTimeManager.currentSegments = [
            TimeSegment(type: .work, startTime: Date().addingTimeInterval(-3*3600), endTime: Date().addingTimeInterval(-2*3600), accelerationFactor: 1),
            TimeSegment(type: .pause, startTime: Date().addingTimeInterval(-2*3600), endTime: Date().addingTimeInterval(-1*3600), accelerationFactor: 1),
            TimeSegment(type: .work, startTime: Date().addingTimeInterval(-1*3600), endTime: nil, accelerationFactor: 1) // Active segment
        ]
        
        return VStack {
            Text("Circular Progress Bar")
            CircularProgressBar(timeManager: mockTimeManager, totalMaxSeconds: 12 * 3600, // Updated to 12 hours
                                initialDisplayTime: Date(),
                                baseTimeForMilestones: Date().addingTimeInterval(-5 * 3600)) // Mock base time
                .frame(width: 200, height: 200)
        }
    }
}
