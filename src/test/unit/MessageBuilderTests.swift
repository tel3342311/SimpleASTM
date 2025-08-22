import XCTest
@testable import SimpleASTM

class MessageBuilderTests: XCTestCase {
    
    func testCreateSampleAnalyticResultMessage() {
        let message = ASTMMessageBuilder.createSampleAnalyticResultMessage()
        
        XCTAssertEqual(message.messageType, .analyticResult)
        XCTAssertNotNil(message.patient)
        XCTAssertEqual(message.orders.count, 1)
        XCTAssertEqual(message.results.count, 2)
        XCTAssertEqual(message.comments.count, 0)
        
        // Check patient details
        let patient = message.patient!
        XCTAssertEqual(patient.patientId, "BBB")
        XCTAssertEqual(patient.patientName, "金城武")
        XCTAssertEqual(patient.species, "Canine")
        
        // Check order details
        let order = message.orders.first!
        XCTAssertEqual(order.specimenId, "000030")
        XCTAssertEqual(order.testPanelId, "LiverPanel")
        XCTAssertEqual(order.actionCode, "A")
        
        // Check results
        let results = message.results
        XCTAssertEqual(results[0].testId, "ALB")
        XCTAssertEqual(results[0].value, "3.0")
        XCTAssertEqual(results[0].flag, .normal)
        
        XCTAssertEqual(results[1].testId, "ALT")
        XCTAssertEqual(results[1].value, "35")
        XCTAssertEqual(results[1].flag, .normal)
    }
    
    func testCreateAbnormalResultMessage() {
        let message = ASTMMessageBuilder.createAbnormalResultMessage()
        
        XCTAssertEqual(message.messageType, .analyticResult)
        XCTAssertNotNil(message.patient)
        XCTAssertEqual(message.results.count, 2)
        
        let results = message.results
        
        // Check abnormal results
        XCTAssertEqual(results[0].testId, "ALB")
        XCTAssertEqual(results[0].value, "1.8")
        XCTAssertEqual(results[0].flag, .low)
        
        XCTAssertEqual(results[1].testId, "ALT")
        XCTAssertEqual(results[1].value, "150")
        XCTAssertEqual(results[1].flag, .high)
    }
    
    func testCreateSingleTestMessage() {
        let message = ASTMMessageBuilder.createSingleTestMessage()
        
        XCTAssertEqual(message.messageType, .analyticResult)
        XCTAssertNotNil(message.patient)
        XCTAssertEqual(message.orders.count, 1)
        XCTAssertEqual(message.results.count, 1)
        
        let order = message.orders.first!
        XCTAssertEqual(order.testPanelId, "GLU")
        
        let result = message.results.first!
        XCTAssertEqual(result.testId, "GLU")
        XCTAssertEqual(result.value, "145")
        XCTAssertEqual(result.flag, .high)
        XCTAssertEqual(result.unit, "mg/dL")
    }
    
    func testCreateWorkListMessage() {
        let addMessage = ASTMMessageBuilder.createWorkListMessage(
            action: "N",
            specimenId: "WL001",
            testPanel: "LiverPanel"
        )
        
        XCTAssertEqual(addMessage.messageType, .workList)
        XCTAssertNil(addMessage.patient)
        XCTAssertEqual(addMessage.orders.count, 1)
        XCTAssertEqual(addMessage.results.count, 0)
        
        let order = addMessage.orders.first!
        XCTAssertEqual(order.specimenId, "WL001")
        XCTAssertEqual(order.testPanelId, "LiverPanel")
        XCTAssertEqual(order.actionCode, "N")
        
        let cancelMessage = ASTMMessageBuilder.createWorkListMessage(
            action: "C",
            specimenId: "WL001",
            testPanel: "LiverPanel"
        )
        
        let cancelOrder = cancelMessage.orders.first!
        XCTAssertEqual(cancelOrder.actionCode, "C")
    }
    
    func testCreateCommentMessage() {
        let message = ASTMMessageBuilder.createCommentMessage(comment: "SN^Connect")
        
        XCTAssertEqual(message.messageType, .analyticResult)
        XCTAssertNil(message.patient)
        XCTAssertEqual(message.orders.count, 0)
        XCTAssertEqual(message.results.count, 0)
        XCTAssertEqual(message.comments.count, 1)
        
        let comment = message.comments.first!
        XCTAssertEqual(comment.comment, "SN^Connect")
        XCTAssertEqual(comment.commentType, "I")
    }
    
    func testGenerateRandomTestResult() {
        let testDef = TestDefinition(
            id: "ALB",
            name: "Albumin",
            unit: "g/dL",
            referenceRange: "2.3-4.0",
            normalMin: 2.3,
            normalMax: 4.0
        )
        
        let result = ASTMMessageBuilder.generateRandomTestResult(for: testDef)
        
        XCTAssertEqual(result.testId, "ALB")
        XCTAssertEqual(result.unit, "g/dL")
        XCTAssertEqual(result.referenceRange, "2.3-4.0")
        
        // Value should be a valid number
        XCTAssertNotNil(Double(result.value))
        
        // Flag should be appropriate for the value
        let value = Double(result.value)!
        if value < 2.3 {
            XCTAssertTrue(result.flag == .low || result.flag == .critical)
        } else if value > 4.0 {
            XCTAssertTrue(result.flag == .high || result.flag == .criticalHigh)
        } else {
            XCTAssertEqual(result.flag, .normal)
        }
    }
    
    func testGenerateRandomPatient() {
        let patient = ASTMMessageBuilder.generateRandomPatient()
        
        XCTAssertTrue(patient.patientId.hasPrefix("PET"))
        XCTAssertFalse(patient.patientName.isEmpty)
        XCTAssertTrue(patient.gender == "M" || patient.gender == "F")
        XCTAssertEqual(patient.species, "Canine")
        XCTAssertFalse(patient.ownerName.isEmpty)
        
        // Age should be a valid number between 1-15
        if let age = Int(patient.age) {
            XCTAssertTrue(age >= 1 && age <= 15)
        }
        
        // Weight should be a valid number between 5-50
        if let weight = Int(patient.weight) {
            XCTAssertTrue(weight >= 5 && weight <= 50)
        }
    }
    
    func testGenerateRandomMessage() {
        let message = ASTMMessageBuilder.generateRandomMessage(testPanel: TestPanel.liverPanel)
        
        XCTAssertEqual(message.messageType, .analyticResult)
        XCTAssertNotNil(message.patient)
        XCTAssertEqual(message.orders.count, 1)
        XCTAssertEqual(message.results.count, TestPanel.liverPanel.tests.count)
        
        // Check that all liver panel tests are included
        let testIds = message.results.map { $0.testId }
        for test in TestPanel.liverPanel.tests {
            XCTAssertTrue(testIds.contains(test.id))
        }
        
        // Check sequence numbers
        for (index, result) in message.results.enumerated() {
            XCTAssertEqual(result.sequenceNumber, index + 1)
        }
    }
    
    func testSampleMessagesAvailable() {
        XCTAssertTrue(ASTMMessageBuilder.sampleMessages.count > 0)
        
        // Check that all expected message types are available
        let expectedTypes = [
            "Normal Liver Panel",
            "Abnormal Results",
            "Single Glucose Test",
            "Random Liver Panel",
            "Random Kidney Panel",
            "Add to Work List",
            "Cancel from Work List",
            "Status Comment"
        ]
        
        for expectedType in expectedTypes {
            XCTAssertNotNil(ASTMMessageBuilder.sampleMessages[expectedType])
        }
    }
    
    func testSampleMessageGeneration() {
        // Test that all sample message builders work
        for (name, builder) in ASTMMessageBuilder.sampleMessages {
            let message = builder()
            
            // Basic validation
            XCTAssertNotNil(message.header)
            XCTAssertNotNil(message.terminator)
            
            // Check that message can be built
            let records = message.buildCompleteMessage()
            XCTAssertTrue(records.count >= 2) // At least header and terminator
            
            print("✓ \(name) message generated successfully with \(records.count) records")
        }
    }
    
    func testMessageTypeConsistency() {
        let analyticMessage = ASTMMessageBuilder.createSampleAnalyticResultMessage()
        XCTAssertEqual(analyticMessage.messageType, .analyticResult)
        
        let workListMessage = ASTMMessageBuilder.createWorkListMessage(
            action: "N",
            specimenId: "TEST",
            testPanel: "LiverPanel"
        )
        XCTAssertEqual(workListMessage.messageType, .workList)
    }
}