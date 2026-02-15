
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
            
            // Calculate initial rotation based on initialDisplayTime
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: initialDisplayTime)
            let minute = calendar.component(.minute, from: initialDisplayTime)
            // Total minutes from 00:00, then normalized to 12-hour cycle (0-11.99)
            let normalizedTimeForRotation = Double(hour % 12) + (Double(minute) / 60.0)
            let startRotationDegrees = normalizedTimeForRotation * 30.0 // 30 degrees per hour (360/12)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.persianGreen.opacity(0.8), lineWidth: lineWidth)
                
                // Progress arcs
                ForEach(Array(timeManager.currentSegments.enumerated()), id: \.offset) { index, segment in
                    // Calculate startAngle declaratively by summing angles of preceding segments
                    let currentStartAngle = timeManager.currentSegments[0..<index].reduce(Angle.zero) { (currentTotalAngle, prevSegment) -> Angle in
                        currentTotalAngle + Angle.degrees(prevSegment.duration / totalMaxSeconds * 360)
                    }
                    
                    let segmentDuration = segment.duration
                    let segmentAngle = Angle.degrees(segmentDuration / totalMaxSeconds * 360)
                    
                    Path { path in
                        path.addArc(center: center,
                                    radius: radius - (lineWidth / 2), // Adjust radius for line width
                                    startAngle: currentStartAngle,
                                    endAngle: currentStartAngle + segmentAngle,
                                    clockwise: false) // Clockwise for standard progression
                    }
                    .stroke(segment.type == .work ? Color.green : Color.orange, lineWidth: lineWidth)
                }

                // Time Markers
                Group {
                    // 0-hour mark (Initial Display Time)
                    Text(timeFormatter.string(from: initialDisplayTime))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: Angle.zero, center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(90 - startRotationDegrees)) // Counter-rotate relative to ZStack rotation

                    // 6-hour mark
                    let sixHourAngle = Angle.degrees((6 * 3600) / totalMaxSeconds * 360)
                    Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(6 * 3600)))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: sixHourAngle, center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(90 - startRotationDegrees))

                    // 8-hour mark
                    let eightHourAngle = Angle.degrees((8 * 3600) / totalMaxSeconds * 360)
                    Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(8 * 3600)))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: eightHourAngle, center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(90 - startRotationDegrees))

                    // 10-hour mark
                    let tenHourAngle = Angle.degrees((10 * 3600) / totalMaxSeconds * 360)
                    Text(timeFormatter.string(from: baseTimeForMilestones.addingTimeInterval(10 * 3600)))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .position(positionForAngle(angle: tenHourAngle, center: center, textRadius: textRadius))
                        .rotationEffect(.degrees(90 - startRotationDegrees))
                }
            }
            .rotationEffect(.degrees(-90 + startRotationDegrees)) // -90 for 12 o'clock start, then offset by actual time
            .frame(width: geometry.size.width, height: geometry.size.height) // Ensure ZStack respects GeometryReader's frame
        }
    }    
    // Helper to position text for a given angle
    private func positionForAngle(angle: Angle, center: CGPoint, textRadius: CGFloat) -> CGPoint {
        let x = center.x + textRadius * cos(angle.radians)
        let y = center.y + textRadius * sin(angle.radians)
        return CGPoint(x: x, y: y)
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
