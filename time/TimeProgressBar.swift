
import SwiftUI

struct TimeProgressBar: View {
    var workSeconds: TimeInterval
    var pauseSeconds: TimeInterval
    var totalMaxSeconds: TimeInterval // e.g., 10 hours * 3600 seconds/hour

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar for total max time
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width)

                // Work time bar (green)
                Rectangle()
                    .fill(Color.green)
                    .frame(width: min(CGFloat(workSeconds / totalMaxSeconds) * geometry.size.width, geometry.size.width))

                // Pause time bar (orange) - starts after work time
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: min(CGFloat(pauseSeconds / totalMaxSeconds) * geometry.size.width, geometry.size.width))
                    .offset(x: min(CGFloat(workSeconds / totalMaxSeconds) * geometry.size.width, geometry.size.width))
            }
            .frame(height: 80) // Fixed height for the bar
            .cornerRadius(0) // Ensure corners are square
        }
        .frame(height: 20) // Ensure the GeometryReader takes up space
    }
}

struct TimeProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Working Example")
            TimeProgressBar(workSeconds: 3 * 3600, pauseSeconds: 1 * 3600, totalMaxSeconds: 10 * 3600)
                .padding(.horizontal)
            
            Text("Pausing Example")
            TimeProgressBar(workSeconds: 5 * 3600, pauseSeconds: 0.5 * 3600, totalMaxSeconds: 10 * 3600)
                .padding(.horizontal)
            
            Text("Full Example")
            TimeProgressBar(workSeconds: 8 * 3600, pauseSeconds: 2 * 3600, totalMaxSeconds: 10 * 3600)
                .padding(.horizontal)
            
            Text("Empty Example")
            TimeProgressBar(workSeconds: 0, pauseSeconds: 0, totalMaxSeconds: 10 * 3600)
                .padding(.horizontal)
        }
    }
}
