import XCTest
@testable import SimpleASTM

class ASTMModelTests: XCTestCase {
    
    func testASTMHeaderRecord() {
        let header = ASTMHeaderRecord(
            senderInfo: "Test Sender",
            softwareVersion: "1.0.0",
            timestamp: "20220308092241"
        )
        
        let astmString = header.toASTMString()
        XCTAssertTrue(astmString.contains("Test Sender"))
        XCTAssertTrue(astmString.contains("1.0.0"))
        XCTAssertTrue(astmString.contains("20220308092241"))
        XCTAssertTrue(astmString.hasPrefix("H|"))
    }
    
    func testASTMPatientRecord() {
        let patient = ASTMPatientRecord(
            sequenceNumber: 1,
            patientId: "TEST001",
            patientName: "Test Patient",
            age: "5",
            gender: "M",
            species: "Canine",
            weight: "20",
            ownerName: "Test Owner"
        )
        
        let astmString = patient.toASTMString()
        XCTAssertTrue(astmString.contains("TEST001"))
        XCTAssertTrue(astmString.contains("Test Patient"))
        XCTAssertTrue(astmString.contains("Canine"))
        XCTAssertTrue(astmString.hasPrefix("P|1|"))
    }
    
    func testASTMOrderRecord() {
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: "SPEC001",
            testPanelId: "LiverPanel",
            actionCode: "A",
            timestamp: "20220308092241"
        )
        
        let astmString = order.toASTMString()
        XCTAssertTrue(astmString.contains("SPEC001"))
        XCTAssertTrue(astmString.contains("LiverPanel"))
        XCTAssertTrue(astmString.contains("|A|"))
        XCTAssertTrue(astmString.hasPrefix("O|1|"))
    }
    
    func testASTMResultRecord() {
        let result = ASTMResultRecord(
            sequenceNumber: 1,
            testId: "ALB",
            value: "3.0",
            unit: "g/dL",
            referenceRange: "2.3-4.0",
            flag: .normal,
            timestamp: "20220308092241"
        )
        
        let astmString = result.toASTMString()
        XCTAssertTrue(astmString.contains("ALB"))
        XCTAssertTrue(astmString.contains("3.0"))
        XCTAssertTrue(astmString.contains("g/dL"))
        XCTAssertTrue(astmString.contains("2.3-4.0"))
        XCTAssertTrue(astmString.contains("|N|"))
        XCTAssertTrue(astmString.hasPrefix("R|1|"))
    }
    
    func testASTMCommentRecord() {
        let comment = ASTMCommentRecord(
            sequenceNumber: 1,
            comment: "SN^Connect"
        )
        
        let astmString = comment.toASTMString()
        XCTAssertTrue(astmString.contains("SN^Connect"))
        XCTAssertTrue(astmString.hasPrefix("C|1|I|"))
    }
    
    func testASTMTerminatorRecord() {
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        let astmString = terminator.toASTMString()
        XCTAssertEqual(astmString, "L|1|N")
    }
    
    func testResultFlags() {
        XCTAssertEqual(ResultFlag.normal.rawValue, "N")
        XCTAssertEqual(ResultFlag.low.rawValue, "L")
        XCTAssertEqual(ResultFlag.high.rawValue, "H")
        XCTAssertEqual(ResultFlag.critical.rawValue, "<")
        XCTAssertEqual(ResultFlag.criticalHigh.rawValue, ">")
        
        XCTAssertEqual(ResultFlag.normal.description, "Normal")
        XCTAssertEqual(ResultFlag.low.description, "Low")
        XCTAssertEqual(ResultFlag.high.description, "High")
    }
    
    func testConnectionStatus() {
        XCTAssertEqual(ConnectionStatus.connected.color, "green")
        XCTAssertEqual(ConnectionStatus.disconnected.color, "gray")
        XCTAssertEqual(ConnectionStatus.connecting.color, "orange")
        XCTAssertEqual(ConnectionStatus.error.color, "red")
    }
    
    func testASTMControlCharacters() {
        XCTAssertEqual(ASTMControlCharacter.ENQ.rawValue, 0x05)
        XCTAssertEqual(ASTMControlCharacter.ACK.rawValue, 0x06)
        XCTAssertEqual(ASTMControlCharacter.NAK.rawValue, 0x15)
        XCTAssertEqual(ASTMControlCharacter.EOT.rawValue, 0x04)
        XCTAssertEqual(ASTMControlCharacter.STX.rawValue, 0x02)
        XCTAssertEqual(ASTMControlCharacter.ETB.rawValue, 0x17)
        XCTAssertEqual(ASTMControlCharacter.ETX.rawValue, 0x03)
    }
    
    func testCompleteASTMMessage() {
        let header = ASTMHeaderRecord(
            senderInfo: "Test System",
            softwareVersion: "1.0.0",
            timestamp: "20220308092241"
        )
        
        let patient = ASTMPatientRecord(
            sequenceNumber: 1,
            patientId: "TEST001",
            patientName: "Test Patient",
            age: "5",
            gender: "M",
            species: "Canine",
            weight: "20",
            ownerName: "Test Owner"
        )
        
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: "SPEC001",
            testPanelId: "LiverPanel",
            actionCode: "A",
            timestamp: "20220308092241"
        )
        
        let result = ASTMResultRecord(
            sequenceNumber: 1,
            testId: "ALB",
            value: "3.0",
            unit: "g/dL",
            referenceRange: "2.3-4.0",
            flag: .normal,
            timestamp: "20220308092241"
        )
        
        let terminator = ASTMTerminatorRecord(sequenceNumber: 1)
        
        let message = ASTMMessage(
            messageType: .analyticResult,
            header: header,
            patient: patient,
            orders: [order],
            results: [result],
            comments: [],
            terminator: terminator
        )
        
        let records = message.buildCompleteMessage()
        
        // Should have 5 records: H, P, O, R, L
        XCTAssertEqual(records.count, 5)
        
        // Check record types
        XCTAssertTrue(records[0].hasPrefix("H|"))
        XCTAssertTrue(records[1].hasPrefix("P|"))
        XCTAssertTrue(records[2].hasPrefix("O|"))
        XCTAssertTrue(records[3].hasPrefix("R|"))
        XCTAssertTrue(records[4].hasPrefix("L|"))
        
        // Check that all records contain expected content
        XCTAssertTrue(records[0].contains("Test System"))
        XCTAssertTrue(records[1].contains("TEST001"))
        XCTAssertTrue(records[2].contains("LiverPanel"))
        XCTAssertTrue(records[3].contains("ALB"))
        XCTAssertTrue(records[4].contains("N"))
    }
    
    func testTestPanelDefinitions() {
        let liverPanel = TestPanel.liverPanel
        XCTAssertEqual(liverPanel.id, "LiverPanel")
        XCTAssertEqual(liverPanel.name, "Liver Panel")
        XCTAssertTrue(liverPanel.tests.count > 0)
        
        let albTest = liverPanel.tests.first { $0.id == "ALB" }
        XCTAssertNotNil(albTest)
        XCTAssertEqual(albTest?.name, "Albumin")
        XCTAssertEqual(albTest?.unit, "g/dL")
        XCTAssertEqual(albTest?.referenceRange, "2.3-4.0")
        
        let kidneyPanel = TestPanel.kidneyPanel
        XCTAssertEqual(kidneyPanel.id, "KidneyPanel")
        XCTAssertEqual(kidneyPanel.name, "Kidney Panel")
        XCTAssertTrue(kidneyPanel.tests.count > 0)
    }
}