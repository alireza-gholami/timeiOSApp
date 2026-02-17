
import Foundation

class LogManager {
    static let shared = LogManager()
    private var logFile: URL?

    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentDirectory = urls.first {
            logFile = documentDirectory.appendingPathComponent("app_log.txt")
        }
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .long)
        let logMessage = "\(timestamp): \(message)\n"
        print(logMessage) // Also print to console for debugging

        guard let logFile = logFile else { return }

        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? logMessage.data(using: .utf8)?.write(to: logFile)
        }
    }

    func readLog() -> String {
        guard let logFile = logFile, let logData = try? Data(contentsOf: logFile), let logText = String(data: logData, encoding: .utf8) else {
            return "No logs found."
        }
        return logText
    }
    
    func clearLog() {
        guard let logFile = logFile else { return }
        try? FileManager.default.removeItem(at: logFile)
    }
}
