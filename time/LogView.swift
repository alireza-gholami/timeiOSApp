
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

                Button("Teilen") {
                    shareLog()
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
    
    private func shareLog() {
        let logContent = LogManager.shared.readLog()
        let fileName = "app_log.txt"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try logContent.write(to: path!, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create log file for sharing")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [path!], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var topController = root
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(activityViewController, animated: true, completion: nil)
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
