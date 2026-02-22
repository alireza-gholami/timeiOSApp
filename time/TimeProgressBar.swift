import SwiftUI

struct TimeProgressBar: View {
    @ObservedObject var timeManager: TimeManager
    var totalMaxSeconds: TimeInterval = 10 * 3600 // 10 Stunden Standard

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Hintergrund (Heller Grau)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    ForEach(Array(timeManager.currentSegments.enumerated()), id: \.offset) { index, segment in
                        let segmentWidth = CGFloat(segment.duration / totalMaxSeconds) * geometry.size.width
                        
                        let xOffset = timeManager.currentSegments[0..<index].reduce(0.0) { (currentTotalOffset, prevSegment) -> CGFloat in
                            currentTotalOffset + CGFloat(prevSegment.duration / totalMaxSeconds) * geometry.size.width
                        }

                        // Segment Balken
                        RoundedRectangle(cornerRadius: 6)
                            .fill(segment.type == .work ? Color.blue : Color.orange)
                            .frame(width: max(0, min(segmentWidth, geometry.size.width - xOffset)), height: 12)
                            .offset(x: xOffset)
                            .shadow(color: segment.type == .work ? .blue.opacity(0.3) : .orange.opacity(0.3), radius: 2)
                    }
                    
                    // Markierung für 8 Stunden (Ziel)
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 2, height: 18)
                        .offset(x: CGFloat(8 * 3600 / totalMaxSeconds) * geometry.size.width)
                }
            }
            .frame(height: 18)
        }
    }
}
