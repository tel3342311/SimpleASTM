import Foundation

// MARK: - ASTM Control Characters
enum ASTMControlCharacter: UInt8, CaseIterable {
    case ENQ = 0x05  // Enquiry
    case ACK = 0x06  // Acknowledge
    case NAK = 0x15  // Negative Acknowledge
    case EOT = 0x04  // End of Transmission
    case STX = 0x02  // Start of Text
    case ETB = 0x17  // End of Transmission Block
    case ETX = 0x03  // End of Text
    case CR = 0x0D   // Carriage Return
    case LF = 0x0A   // Line Feed
    
    var character: Character {
        return Character(UnicodeScalar(self.rawValue)!)
    }
    
    var data: Data {
        return Data([self.rawValue])
    }
}

// MARK: - ASTM Delimiters
enum ASTMDelimiter: String {
    case field = "|"          // Field delimiter
    case component = "^"      // Component delimiter
    case repeat = "\\"        // Repeat delimiter
    case escape = "&"         // Escape delimiter
}

// MARK: - ASTM Message Types
enum ASTMMessageType: String {
    case analyticResult = "Analytic Result"
    case connectionStatus = "Connection Status"
    case workList = "Work List"
}

// MARK: - Connection Status
enum ConnectionStatus: String, CaseIterable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
    
    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "orange"
        case .connected: return "green"
        case .error: return "red"
        }
    }
}

// MARK: - Test Result Flags
enum ResultFlag: String, CaseIterable {
    case normal = "N"         // Normal
    case low = "L"            // Low
    case high = "H"           // High
    case critical = "<"       // Critical Low
    case criticalHigh = ">"   // Critical High
    case abnormal = "A"       // Abnormal
    
    var description: String {
        switch self {
        case .normal: return "Normal"
        case .low: return "Low"
        case .high: return "High"
        case .critical: return "Critical Low"
        case .criticalHigh: return "Critical High"
        case .abnormal: return "Abnormal"
        }
    }
}

// MARK: - ASTM Record Models
struct ASTMHeaderRecord {
    let recordType: String = "H"
    let delimiters: String = "\\^&"
    let senderInfo: String
    let softwareVersion: String
    let processId: String = "P"
    let astmVersion: String = "1"
    let timestamp: String
    
    func toASTMString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let currentTimestamp = dateFormatter.string(from: Date())
        
        return "H|\\^&|||Skyla Solution^\(softwareVersion)|||||P|1|\(timestamp.isEmpty ? currentTimestamp : timestamp)"
    }
}

struct ASTMPatientRecord {
    let recordType: String = "P"
    let sequenceNumber: Int
    let patientId: String
    let patientName: String
    let age: String
    let gender: String
    let species: String
    let weight: String
    let ownerName: String
    
    func toASTMString() -> String {
        return "P|\(sequenceNumber)||\(patientId)||\(patientName)||^\(age)^Year|\(gender)||||||||\(ownerName)|\(species)||\(weight)^Kg||||||||||||||||"
    }
}

struct ASTMOrderRecord {
    let recordType: String = "O"
    let sequenceNumber: Int
    let specimenId: String
    let testPanelId: String
    let actionCode: String // N = New, Q = Query, C = Cancel
    let timestamp: String
    let reportType: String = "N"
    
    func toASTMString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let currentTimestamp = dateFormatter.string(from: Date())
        
        return "O|\(sequenceNumber)|\(specimenId)||^^^\(testPanelId)|\(actionCode)|\(timestamp.isEmpty ? currentTimestamp : timestamp)|||||\(reportType)||||||||||||||"
    }
}

struct ASTMResultRecord {
    let recordType: String = "R"
    let sequenceNumber: Int
    let testId: String
    let value: String
    let unit: String
    let referenceRange: String
    let flag: ResultFlag
    let timestamp: String
    
    func toASTMString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let currentTimestamp = dateFormatter.string(from: Date())
        
        return "R|\(sequenceNumber)|^^^\(testId)|\(value)|\(unit)|\(referenceRange)|\(flag.rawValue)||||F||\(timestamp.isEmpty ? currentTimestamp : timestamp)"
    }
}

struct ASTMCommentRecord {
    let recordType: String = "C"
    let sequenceNumber: Int
    let commentType: String = "I" // I = Information
    let comment: String
    let commentSource: String = "G"
    
    func toASTMString() -> String {
        return "C|\(sequenceNumber)|\(commentType)|\(comment)|\(commentSource)"
    }
}

struct ASTMTerminatorRecord {
    let recordType: String = "L"
    let sequenceNumber: Int
    let terminationCode: String = "N" // N = Normal Termination
    
    func toASTMString() -> String {
        return "L|\(sequenceNumber)|\(terminationCode)"
    }
}

// MARK: - Complete ASTM Message
struct ASTMMessage {
    let messageType: ASTMMessageType
    let header: ASTMHeaderRecord
    let patient: ASTMPatientRecord?
    let orders: [ASTMOrderRecord]
    let results: [ASTMResultRecord]
    let comments: [ASTMCommentRecord]
    let terminator: ASTMTerminatorRecord
    
    func buildCompleteMessage() -> [String] {
        var records: [String] = []
        
        // Always start with header
        records.append(header.toASTMString())
        
        // Add patient if available
        if let patient = patient {
            records.append(patient.toASTMString())
        }
        
        // Add orders
        for order in orders {
            records.append(order.toASTMString())
        }
        
        // Add results
        for result in results {
            records.append(result.toASTMString())
        }
        
        // Add comments
        for comment in comments {
            records.append(comment.toASTMString())
        }
        
        // Always end with terminator
        records.append(terminator.toASTMString())
        
        return records
    }
}

// MARK: - Predefined Test Panels
struct TestPanel {
    let id: String
    let name: String
    let tests: [TestDefinition]
}

struct TestDefinition {
    let id: String
    let name: String
    let unit: String
    let referenceRange: String
    let normalMin: Double
    let normalMax: Double
}

// Common test panels from the ASTM document
extension TestPanel {
    static let liverPanel = TestPanel(
        id: "LiverPanel",
        name: "Liver Panel",
        tests: [
            TestDefinition(id: "ALB", name: "Albumin", unit: "g/dL", referenceRange: "2.3-4.0", normalMin: 2.3, normalMax: 4.0),
            TestDefinition(id: "ALT", name: "Alanine Aminotransferase", unit: "U/L", referenceRange: "10-100", normalMin: 10, normalMax: 100),
            TestDefinition(id: "AST", name: "Aspartate Aminotransferase", unit: "U/L", referenceRange: "15-66", normalMin: 15, normalMax: 66),
            TestDefinition(id: "ALP", name: "Alkaline Phosphatase", unit: "U/L", referenceRange: "23-212", normalMin: 23, normalMax: 212),
            TestDefinition(id: "TBIL", name: "Total Bilirubin", unit: "mg/dL", referenceRange: "0.1-0.3", normalMin: 0.1, normalMax: 0.3)
        ]
    )
    
    static let kidneyPanel = TestPanel(
        id: "KidneyPanel",
        name: "Kidney Panel",
        tests: [
            TestDefinition(id: "BUN", name: "Blood Urea Nitrogen", unit: "mg/dL", referenceRange: "7-27", normalMin: 7, normalMax: 27),
            TestDefinition(id: "CREA", name: "Creatinine", unit: "mg/dL", referenceRange: "0.5-1.8", normalMin: 0.5, normalMax: 1.8),
            TestDefinition(id: "UA", name: "Uric Acid", unit: "mg/dL", referenceRange: "0-1", normalMin: 0, normalMax: 1),
            TestDefinition(id: "PHOS", name: "Phosphorus", unit: "mg/dL", referenceRange: "2.5-6.8", normalMin: 2.5, normalMax: 6.8)
        ]
    )
    
    static let allPanels = [liverPanel, kidneyPanel]
}