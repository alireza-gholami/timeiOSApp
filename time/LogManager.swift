import Foundation

class LogManager {
    static let shared = LogManager()
    private var logFile: URL?

    private init() {
        // Move log file to App Group container so it's accessible and persistent
        let groupID = "group.com.alireza.Widget"
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            logFile = groupURL.appendingPathComponent("app_log.txt")
        } else {
            // Fallback to documents if App Group is not available
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            logFile = urls.first?.appendingPathComponent("app_log.txt")
        }
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        print(logMessage) // Debug output

        guard let logFile = logFile else { return }

        // Ensure file exists before writing
        if !FileManager.default.fileExists(atPath: logFile.path) {
            try? "".write(to: logFile, atomically: true, encoding: .utf8)
        }

        if let data = logMessage.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    func readLog() -> String {
        guard let logFile = logFile, 
              let logData = try? Data(contentsOf: logFile), 
              let logText = String(data: logData, encoding: .utf8) else {
            return "No logs found."
        }
        return logText
    }
    
    func clearLog() {
        guard let logFile = logFile else { return }
        try? FileManager.default.removeItem(at: logFile)
        log("Log cleared.")
    }
}
