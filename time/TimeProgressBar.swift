
import SwiftUI

struct TimeProgressBar: View {
    @ObservedObject var timeManager: TimeManager
    var totalMaxSeconds: TimeInterval // e.g., 10 hours * 3600 seconds/hour

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar for total max time
                    Rectangle()
                        .fill(Color.persianGreen.opacity(0.8))
                        .frame(width: geometry.size.width)

                    ForEach(Array(timeManager.currentSegments.enumerated()), id: \.offset) { index, segment in
                        let segmentWidth = CGFloat(segment.duration / totalMaxSeconds) * geometry.size.width
                        
                        // Calculate xOffset declaratively by summing durations of preceding segments
                        let xOffset = timeManager.currentSegments[0..<index].reduce(0.0) { (currentTotalOffset, prevSegment) -> CGFloat in
                            currentTotalOffset + CGFloat(prevSegment.duration / totalMaxSeconds) * geometry.size.width
                        }

                        // Segment bar
                        Rectangle()
                            .fill(segment.type == .work ? Color.green : Color.orange)
                            .frame(width: min(segmentWidth, geometry.size.width - xOffset))
                            .offset(x: xOffset)
                        
                        // Time label for segment start
                        Text(segment.startTime, style: .time)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(90), anchor: .bottomLeading) // Rotate vertically, anchor at bottom-leading for better alignment
                            .offset(x: xOffset - 5, y: -30) // Position at segment start, moved 5 points further left, and up above the bar
                            .frame(width: 40) // Slightly wider frame for the rotated text
                    }
                }
                .frame(height: 80) // Fixed height for the bar
                .cornerRadius(0) // Ensure corners are square
            }
            .frame(height: 80) // Ensure the GeometryReader takes up space

            HStack {
                Text("Arbeit: \(timeFormatted(timeManager.timerState == .idle && timeManager.lastSummaryWork > 0 ? timeManager.lastSummaryWork : timeManager.workSeconds))")
                    .foregroundColor(.green)
                Spacer()
                Text("Pause: \(timeFormatted(timeManager.timerState == .idle && timeManager.lastSummaryPause > 0 ? timeManager.lastSummaryPause : timeManager.pauseSeconds))")
                    .foregroundColor(.orange)
            }
            .font(.caption)
            .bold()
            .padding(.top, 5)
        }
    }

    private func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        let seconds: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        let minutes: Int = Int((totalSeconds / 60).truncatingRemainder(dividingBy: 60))
        let hours: Int = Int(totalSeconds / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
