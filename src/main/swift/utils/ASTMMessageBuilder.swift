import Foundation

class ASTMMessageBuilder: ObservableObject {
    
    // MARK: - Sample Data Generation
    
    static func createSampleAnalyticResultMessage() -> ASTMMessage {
        let header = ASTMHeaderRecord(
            senderInfo: "Skyla Solution",
            softwareVersion: "4.2.0.0",
            timestamp: ""
        )
        
        let patient = ASTMPatientRecord(
            sequenceNumber: 1,
            patientId: "BBB",
            patientName: "金城武",
            age: "5",
            gender: "M",
            species: "Canine",
            weight: "16",
            ownerName: "OwnerName"
        )
        
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: "000030",
            testPanelId: "LiverPanel",
            actionCode: "A",
            timestamp: ""
        )
        
        let results = [
            ASTMResultRecord(
                sequenceNumber: 1,
                testId: "ALB",
                value: "3.0",
                unit: "g/dL",
                referenceRange: "2.3-4.0",
                flag: .normal,
                timestamp: ""
            ),
            ASTMResultRecord(
                sequenceNumber: 2,
                testId: "ALT",
                value: "35",
                unit: "U/L",
                referenceRange: "10-100",
                flag: .normal,
                timestamp: ""
            )
        ]
        
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        return ASTMMessage(
            messageType: .analyticResult,
            header: header,
            patient: patient,
            orders: [order],
            results: results,
            comments: [],
            terminator: terminator
        )
    }
    
    static func createAbnormalResultMessage() -> ASTMMessage {
        let header = ASTMHeaderRecord(
            senderInfo: "Skyla Solution",
            softwareVersion: "4.2.0.0",
            timestamp: ""
        )
        
        let patient = ASTMPatientRecord(
            sequenceNumber: 1,
            patientId: "CCC",
            patientName: "Test Patient",
            age: "3",
            gender: "F",
            species: "Canine",
            weight: "12",
            ownerName: "Owner"
        )
        
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: "000031",
            testPanelId: "LiverPanel",
            actionCode: "A",
            timestamp: ""
        )
        
        let results = [
            ASTMResultRecord(
                sequenceNumber: 1,
                testId: "ALB",
                value: "1.8",
                unit: "g/dL",
                referenceRange: "2.3-4.0",
                flag: .low,
                timestamp: ""
            ),
            ASTMResultRecord(
                sequenceNumber: 2,
                testId: "ALT",
                value: "150",
                unit: "U/L",
                referenceRange: "10-100",
                flag: .high,
                timestamp: ""
            )
        ]
        
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        return ASTMMessage(
            messageType: .analyticResult,
            header: header,
            patient: patient,
            orders: [order],
            results: results,
            comments: [],
            terminator: terminator
        )
    }
    
    static func createSingleTestMessage() -> ASTMMessage {
        let header = ASTMHeaderRecord(
            senderInfo: "Skyla Solution",
            softwareVersion: "4.2.0.0",
            timestamp: ""
        )
        
        let patient = ASTMPatientRecord(
            sequenceNumber: 1,
            patientId: "DDD",
            patientName: "Single Test",
            age: "7",
            gender: "M",
            species: "Canine",
            weight: "20",
            ownerName: "SingleOwner"
        )
        
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: "000032",
            testPanelId: "GLU",
            actionCode: "A",
            timestamp: ""
        )
        
        let result = ASTMResultRecord(
            sequenceNumber: 1,
            testId: "GLU",
            value: "145",
            unit: "mg/dL",
            referenceRange: "74-143",
            flag: .high,
            timestamp: ""
        )
        
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        return ASTMMessage(
            messageType: .analyticResult,
            header: header,
            patient: patient,
            orders: [order],
            results: [result],
            comments: [],
            terminator: terminator
        )
    }
    
    static func createWorkListMessage(action: String, specimenId: String, testPanel: String) -> ASTMMessage {
        let header = ASTMHeaderRecord(
            senderInfo: "Skyla Solution",
            softwareVersion: "4.2.0.0",
            timestamp: ""
        )
        
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: specimenId,
            testPanelId: testPanel,
            actionCode: action, // N = New, C = Cancel
            timestamp: ""
        )
        
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        return ASTMMessage(
            messageType: .workList,
            header: header,
            patient: nil,
            orders: [order],
            results: [],
            comments: [],
            terminator: terminator
        )
    }
    
    static func createCommentMessage(comment: String) -> ASTMMessage {
        let header = ASTMHeaderRecord(
            senderInfo: "Skyla Solution",
            softwareVersion: "4.2.0.0",
            timestamp: ""
        )
        
        let commentRecord = ASTMCommentRecord(
            sequenceNumber: 1,
            comment: comment
        )
        
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        return ASTMMessage(
            messageType: .analyticResult,
            header: header,
            patient: nil,
            orders: [],
            results: [],
            comments: [commentRecord],
            terminator: terminator
        )
    }
    
    // MARK: - Random Test Data Generation
    
    static func generateRandomTestResult(for testDef: TestDefinition) -> ASTMResultRecord {
        let variation = Double.random(in: 0.7...1.3) // ±30% variation
        let baseValue = (testDef.normalMin + testDef.normalMax) / 2
        let randomValue = baseValue * variation
        
        let flag: ResultFlag
        if randomValue < testDef.normalMin {
            flag = randomValue < testDef.normalMin * 0.5 ? .critical : .low
        } else if randomValue > testDef.normalMax {
            flag = randomValue > testDef.normalMax * 1.5 ? .criticalHigh : .high
        } else {
            flag = .normal
        }
        
        return ASTMResultRecord(
            sequenceNumber: 1,
            testId: testDef.id,
            value: String(format: "%.1f", randomValue),
            unit: testDef.unit,
            referenceRange: testDef.referenceRange,
            flag: flag,
            timestamp: ""
        )
    }
    
    static func generateRandomPatient() -> ASTMPatientRecord {
        let names = ["Max", "Bella", "Charlie", "Luna", "Cooper", "Lucy", "Bear", "Daisy"]
        let owners = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
        let genders = ["M", "F"]
        
        return ASTMPatientRecord(
            sequenceNumber: 1,
            patientId: String(format: "PET%03d", Int.random(in: 1...999)),
            patientName: names.randomElement() ?? "Unknown",
            age: String(Int.random(in: 1...15)),
            gender: genders.randomElement() ?? "M",
            species: "Canine",
            weight: String(Int.random(in: 5...50)),
            ownerName: owners.randomElement() ?? "Unknown"
        )
    }
    
    static func generateRandomMessage(testPanel: TestPanel) -> ASTMMessage {
        let header = ASTMHeaderRecord(
            senderInfo: "Skyla Solution",
            softwareVersion: "4.2.0.0",
            timestamp: ""
        )
        
        let patient = generateRandomPatient()
        
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: String(format: "%06d", Int.random(in: 1...999999)),
            testPanelId: testPanel.id,
            actionCode: "A",
            timestamp: ""
        )
        
        let results = testPanel.tests.enumerated().map { index, testDef in
            var result = generateRandomTestResult(for: testDef)
            result = ASTMResultRecord(
                sequenceNumber: index + 1,
                testId: result.testId,
                value: result.value,
                unit: result.unit,
                referenceRange: result.referenceRange,
                flag: result.flag,
                timestamp: result.timestamp
            )
            return result
        }
        
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        return ASTMMessage(
            messageType: .analyticResult,
            header: header,
            patient: patient,
            orders: [order],
            results: results,
            comments: [],
            terminator: terminator
        )
    }
    
    // MARK: - Predefined Message Templates
    
    static let sampleMessages: [String: () -> ASTMMessage] = [
        "Normal Liver Panel": { createSampleAnalyticResultMessage() },
        "Abnormal Results": { createAbnormalResultMessage() },
        "Single Glucose Test": { createSingleTestMessage() },
        "Random Liver Panel": { generateRandomMessage(testPanel: TestPanel.liverPanel) },
        "Random Kidney Panel": { generateRandomMessage(testPanel: TestPanel.kidneyPanel) },
        "Add to Work List": { createWorkListMessage(action: "N", specimenId: "WL001", testPanel: "LiverPanel") },
        "Cancel from Work List": { createWorkListMessage(action: "C", specimenId: "WL001", testPanel: "LiverPanel") },
        "Status Comment": { createCommentMessage(comment: "SN^Queued") }
    ]
}