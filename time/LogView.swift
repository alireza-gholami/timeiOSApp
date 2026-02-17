
import SwiftUI

struct LogView: View {
    @State private var logText: String = ""

    var body: some View {
        VStack {
            Text("App Logs")
                .font(.largeTitle)
                .padding()

            ScrollView {
                Text(logText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Refresh") {
                    logText = LogManager.shared.readLog()
                }
                .padding()

                Button("Clear") {
                    LogManager.shared.clearLog()
                    logText = ""
                }
                .padding()
            }
        }
        .onAppear {
            logText = LogManager.shared.readLog()
        }
    }
}

#Preview {
    LogView()
}
