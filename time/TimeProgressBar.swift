
import SwiftUI

struct TimeProgressBar: View {
    @ObservedObject var timeManager: TimeManager
    var totalMaxSeconds: TimeInterval // e.g., 10 hours * 3600 seconds/hour

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar for total max time
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width)

                ForEach(Array(timeManager.currentSegments.enumerated()), id: \.offset) { index, segment in
                    let segmentWidth = CGFloat(segment.duration / totalMaxSeconds) * geometry.size.width
                    
                    // Calculate xOffset declaratively by summing durations of preceding segments
                    let xOffset = timeManager.currentSegments[0..<index].reduce(0.0) { (currentTotalOffset, prevSegment) -> CGFloat in
                        currentTotalOffset + CGFloat(prevSegment.duration / totalMaxSeconds) * geometry.size.width
                    }

                    Rectangle()
                        .fill(segment.type == .work ? Color.green : Color.orange)
                        .frame(width: min(segmentWidth, geometry.size.width - xOffset))
                        .offset(x: xOffset)
                }
            }
            .frame(height: 80) // Fixed height for the bar
            .cornerRadius(0) // Ensure corners are square
        }
        .frame(height: 20) // Ensure the GeometryReader takes up space
    }
}

struct TimeProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock TimeManager for preview
        let mockTimeManager = TimeManager()
        mockTimeManager.currentSegments = [
            TimeSegment(type: .work, startTime: Date().addingTimeInterval(-3*3600), endTime: Date().addingTimeInterval(-2*3600), accelerationFactor: 1),
            TimeSegment(type: .pause, startTime: Date().addingTimeInterval(-2*3600), endTime: Date().addingTimeInterval(-1*3600), accelerationFactor: 1),
            TimeSegment(type: .work, startTime: Date().addingTimeInterval(-1*3600), endTime: nil, accelerationFactor: 1) // Active segment
        ]
        
        return VStack(spacing: 20) {
            Text("Segmented Example")
            TimeProgressBar(timeManager: mockTimeManager, totalMaxSeconds: 10 * 3600)
                .padding(.horizontal)
            
            Text("Empty Example")
            TimeProgressBar(timeManager: TimeManager(), totalMaxSeconds: 10 * 3600)
                .padding(.horizontal)
        }
    }
}
