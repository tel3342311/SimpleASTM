import Foundation
import OSLog

class MessageLogger: ObservableObject {
    static let shared = MessageLogger()
    
    private let logger = Logger(subsystem: "com.simpleastm.simulator", category: "MessageLogger")
    private let dateFormatter = DateFormatter()
    
    @Published var logEntries: [LogEntry] = []
    @Published var exportableLog: String = ""
    
    private let maxLogEntries = 1000 // Prevent memory issues with very long sessions
    
    private init() {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    // MARK: - Log Entry Model
    
    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
        let details: String?
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
        
        var fullTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        
        var color: String {
            switch self {
            case .debug: return "gray"
            case .info: return "blue"
            case .warning: return "orange"
            case .error: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .debug: return "ladybug"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }
    
    enum LogCategory: String, CaseIterable {
        case connection = "CONNECTION"
        case transmission = "TRANSMISSION"
        case protocol = "PROTOCOL"
        case message = "MESSAGE"
        case error = "ERROR"
        case system = "SYSTEM"
        
        var icon: String {
            switch self {
            case .connection: return "network"
            case .transmission: return "arrow.up.arrow.down"
            case .protocol: return "doc.text"
            case .message: return "envelope"
            case .error: return "exclamationmark.triangle"
            case .system: return "gear"
            }
        }
    }
    
    // MARK: - Logging Methods
    
    func log(level: LogLevel, category: LogCategory, message: String, details: String? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            details: details
        )
        
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            
            // Maintain maximum log entries
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
            
            self.updateExportableLog()
        }
        
        // Also log to system logger
        let logMessage = "[\(category.rawValue)] \(message)"
        switch level {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        }
    }
    
    // MARK: - Convenience Methods
    
    func logConnection(status: String, details: String? = nil) {
        log(level: .info, category: .connection, message: status, details: details)
    }
    
    func logTransmission(message: String, details: String? = nil) {
        log(level: .info, category: .transmission, message: message, details: details)
    }
    
    func logProtocol(message: String, details: String? = nil) {
        log(level: .debug, category: .protocol, message: message, details: details)
    }
    
    func logMessage(type: String, content: String) {
        log(level: .info, category: .message, message: "Sent \(type)", details: content)
    }
    
    func logError(error: String, details: String? = nil) {
        log(level: .error, category: .error, message: error, details: details)
    }
    
    func logSystem(message: String, details: String? = nil) {
        log(level: .info, category: .system, message: message, details: details)
    }
    
    // MARK: - Log Management
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
            self.exportableLog = ""
        }
    }
    
    func getFilteredLogs(level: LogLevel? = nil, category: LogCategory? = nil) -> [LogEntry] {
        return logEntries.filter { entry in
            let levelMatch = level == nil || entry.level == level
            let categoryMatch = category == nil || entry.category == category
            return levelMatch && categoryMatch
        }
    }
    
    // MARK: - Export Functionality
    
    private func updateExportableLog() {
        let logText = logEntries.map { entry in
            var text = "[\(entry.fullTimestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)"
            if let details = entry.details {
                text += "\n    Details: \(details)"
            }
            return text
        }.joined(separator: "\n")
        
        exportableLog = """
        SimpleASTM Simulator Log
        Generated: \(dateFormatter.string(from: Date()))
        Total Entries: \(logEntries.count)
        
        \(logText)
        """
    }
    
    func exportLogToFile() -> URL? {
        let fileName = "SimpleASTM_Log_\(dateFormatter.string(from: Date()).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ":", with: "-")).txt"
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try exportableLog.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            logError(error: "Failed to export log", details: error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Statistics
    
    func getLogStatistics() -> LogStatistics {
        let totalEntries = logEntries.count
        let errorCount = logEntries.filter { $0.level == .error }.count
        let warningCount = logEntries.filter { $0.level == .warning }.count
        let infoCount = logEntries.filter { $0.level == .info }.count
        let debugCount = logEntries.filter { $0.level == .debug }.count
        
        let categoryStats = LogCategory.allCases.map { category in
            CategoryStat(
                category: category,
                count: logEntries.filter { $0.category == category }.count
            )
        }.sorted { $0.count > $1.count }
        
        return LogStatistics(
            totalEntries: totalEntries,
            errorCount: errorCount,
            warningCount: warningCount,
            infoCount: infoCount,
            debugCount: debugCount,
            categoryStats: categoryStats,
            sessionStartTime: logEntries.first?.timestamp ?? Date(),
            lastLogTime: logEntries.last?.timestamp ?? Date()
        )
    }
    
    struct LogStatistics {
        let totalEntries: Int
        let errorCount: Int
        let warningCount: Int
        let infoCount: Int
        let debugCount: Int
        let categoryStats: [CategoryStat]
        let sessionStartTime: Date
        let lastLogTime: Date
        
        var sessionDuration: TimeInterval {
            return lastLogTime.timeIntervalSince(sessionStartTime)
        }
        
        var formattedSessionDuration: String {
            let hours = Int(sessionDuration) / 3600
            let minutes = Int(sessionDuration) % 3600 / 60
            let seconds = Int(sessionDuration) % 60
            
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }
    
    struct CategoryStat {
        let category: LogCategory
        let count: Int
    }
}

// MARK: - Logger Extensions for TCPClientService Integration

extension MessageLogger {
    func logASTMMessage(_ message: ASTMMessage, direction: String) {
        let messageType = message.messageType.rawValue
        let records = message.buildCompleteMessage()
        
        log(
            level: .info,
            category: .message,
            message: "\(direction) \(messageType) message",
            details: "Records: \(records.count)\nFirst record: \(records.first ?? "N/A")"
        )
        
        // Log individual records for detailed tracking
        for (index, record) in records.enumerated() {
            log(
                level: .debug,
                category: .protocol,
                message: "Record \(index + 1): \(String(record.prefix(20)))...",
                details: record
            )
        }
    }
    
    func logConnectionEvent(_ event: String, status: ConnectionStatus, details: String? = nil) {
        let level: LogLevel = status == .error ? .error : .info
        log(
            level: level,
            category: .connection,
            message: "\(event) - Status: \(status.rawValue)",
            details: details
        )
    }
    
    func logTransmissionEvent(_ event: String, success: Bool, details: String? = nil) {
        let level: LogLevel = success ? .info : .error
        log(
            level: level,
            category: .transmission,
            message: event,
            details: details
        )
    }
}