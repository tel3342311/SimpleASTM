import Foundation
import Network
import Combine

class TCPClientService: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    @Published var sentMessages: [String] = []
    @Published var receivedMessages: [String] = []
    @Published var isTransmitting: Bool = false
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "TCPClient", qos: .utility)
    private var hostEndpoint: NWEndpoint.Host = "localhost"
    private var port: NWEndpoint.Port = 3000
    
    // ASTM Protocol State
    private var frameNumber: Int = 1
    private var isEstablished: Bool = false
    private var pendingACKCallback: ((Bool) -> Void)?
    private var isReceivingFrames: Bool = false
    private var receivedFrameBuffer: [String] = []
    
    // MARK: - Connection Management
    
    func connect(to host: String, port: Int) {
        guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
            updateError("Invalid port number: \(port)")
            return
        }
        
        self.hostEndpoint = NWEndpoint.Host(host)
        self.port = portNumber
        
        DispatchQueue.main.async {
            self.connectionStatus = .connecting
            self.lastError = nil
        }
        
        let connection = NWConnection(host: hostEndpoint, port: self.port, using: .tcp)
        self.connection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionStateUpdate(state)
            }
        }
        
        connection.start(queue: queue)
        startReceiving()
    }
    
    func disconnect() {
        // Don't send disconnect message if we're not actually connected
        if connectionStatus == .connected {
            sendDisconnectMessage()
        }
        
        connection?.cancel()
        connection = nil
        
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.isEstablished = false
            self.frameNumber = 1
            self.isTransmitting = false
            self.lastError = nil
            self.isReceivingFrames = false
            self.receivedFrameBuffer.removeAll()
        }
    }
    
    private func handleConnectionStateUpdate(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionStatus = .connected
            sendConnectionMessage()
            
        case .failed(let error):
            connectionStatus = .error
            updateError("Connection failed: \(error.localizedDescription)")
            
        case .cancelled:
            connectionStatus = .disconnected
            
        case .waiting(let error):
            updateError("Connection waiting: \(error.localizedDescription)")
            
        default:
            break
        }
    }
    
    // MARK: - ASTM Protocol Implementation
    
    func sendASTMMessage(_ message: ASTMMessage) {
        guard connectionStatus == .connected else {
            updateError("Not connected to server")
            return
        }
        
        DispatchQueue.main.async {
            self.isTransmitting = true
        }
        
        // Step 1: Send ENQ to establish transmission
        sendControlCharacter(.ENQ) { [weak self] success in
            if success {
                // Wait for ACK before sending message frames
                self?.waitForACK { ackReceived in
                    if ackReceived {
                        // ACK received, start sending frames
                        self?.sendMessageFrames(message)
                    } else {
                        DispatchQueue.main.async {
                            self?.isTransmitting = false
                            self?.updateError("Did not receive ACK for ENQ")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isTransmitting = false
                    self?.updateError("Failed to send ENQ")
                }
            }
        }
    }
    
    func sendRawMessage(_ rawMessage: String) {
        guard connectionStatus == .connected else {
            updateError("Not connected to server")
            return
        }
        
        guard !rawMessage.isEmpty else {
            updateError("Message cannot be empty")
            return
        }
        
        DispatchQueue.main.async {
            self.isTransmitting = true
        }
        
        // Send raw message directly (add newline for proper transmission)
        let messageWithNewline = rawMessage + "\n"
        sendFrame(messageWithNewline) { [weak self] success in
            DispatchQueue.main.async {
                self?.isTransmitting = false
                if success {
                    self?.sentMessages.append(rawMessage)
                } else {
                    self?.updateError("Failed to send custom message")
                }
            }
        }
    }
    
    private func sendMessageFrames(_ message: ASTMMessage) {
        let records = message.buildCompleteMessage()
        sendNextFrame(records: records, currentIndex: 0)
    }
    
    private func sendNextFrame(records: [String], currentIndex: Int) {
        guard currentIndex < records.count else {
            // All frames sent and ACKed, now send EOT
            sendControlCharacter(.EOT) { [weak self] success in
                DispatchQueue.main.async {
                    self?.isTransmitting = false
                    self?.frameNumber = 1
                    if !success {
                        self?.updateError("Failed to send EOT")
                    }
                }
            }
            return
        }
        
        let record = records[currentIndex]
        let isLastFrame = (currentIndex == records.count - 1)
        let frame = buildASTMFrame(record: record, frameNumber: frameNumber, isLast: isLastFrame)
        
        sendFrame(frame) { [weak self] success in
            if success {
                self?.frameNumber += 1
                // Wait for ACK before sending next frame
                self?.waitForACK { ackReceived in
                    if ackReceived {
                        // ACK received, send next frame
                        self?.sendNextFrame(records: records, currentIndex: currentIndex + 1)
                    } else {
                        DispatchQueue.main.async {
                            self?.isTransmitting = false
                            self?.updateError("Did not receive ACK for frame \(currentIndex + 1)")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isTransmitting = false
                    self?.updateError("Failed to send frame \(currentIndex + 1)")
                }
            }
        }
    }
    
    private func buildASTMFrame(record: String, frameNumber: Int, isLast: Bool) -> String {
        let frameNumberStr = String(frameNumber % 8) // Frame numbers cycle 0-7
        let endChar = isLast ? ASTMControlCharacter.ETX.character : ASTMControlCharacter.ETB.character
        
        let frameContent = "\(ASTMControlCharacter.STX.character)\(frameNumberStr)\(record)\(endChar)"
        let checksum = calculateChecksum(frameContent)
        
        return "\(frameContent)\(checksum)\(ASTMControlCharacter.CR.character)\(ASTMControlCharacter.LF.character)"
    }
    
    private func calculateChecksum(_ content: String) -> String {
        var sum: UInt8 = 0
        for char in content {
            if let asciiValue = char.asciiValue {
                sum = sum &+ asciiValue
            }
        }
        
        // ASTM checksum is just 2 hex characters representing the low 8 bits
        return String(format: "%02X", sum)
    }
    
    // MARK: - Low-Level Communication
    
    private func sendControlCharacter(_ char: ASTMControlCharacter, completion: @escaping (Bool) -> Void) {
        guard let connection = connection else {
            completion(false)
            return
        }
        
        connection.send(content: char.data, completion: .contentProcessed { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.updateError("Send error: \(error.localizedDescription)")
                }
                completion(false)
            } else {
                print("📤 SENT CONTROL CHARACTER: \(char)")
                DispatchQueue.main.async {
                    self.sentMessages.append("Control: \(char)")
                }
                completion(true)
            }
        })
    }
    
    private func sendFrame(_ frame: String, completion: @escaping (Bool) -> Void) {
        guard let connection = connection,
              let data = frame.data(using: .ascii) else {
            completion(false)
            return
        }
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.updateError("Send frame error: \(error.localizedDescription)")
                }
                completion(false)
            } else {
                print("📤 SENT FRAME: \(frame)")
                print("📏 Frame Length: \(frame.count) bytes")
                DispatchQueue.main.async {
                    self.sentMessages.append("Frame: \(frame)")
                }
                completion(true)
            }
        })
    }
    
    private func startReceiving() {
        guard let connection = connection else { return }
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                if let message = String(data: data, encoding: .ascii) {
                    // Print raw server response to console immediately
                    print("🔥 REAL SERVER RESPONSE:")
                    print("📡 Raw Data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    print("📝 ASCII Message: '\(message)'")
                    print("📏 Length: \(message.count) bytes")
                    print("⏰ Timestamp: \(Date())")
                    print("─────────────────────────────────────")
                    
                    DispatchQueue.main.async {
                        // Add timestamp and formatting to UI display
                        let timestamp = DateFormatter().string(from: Date())
                        let formattedMessage = "[\(timestamp)] Server: \(message)"
                        self?.receivedMessages.append(formattedMessage)
                        self?.handleReceivedMessage(message)
                    }
                }
            }
            
            if let error = error {
                print("❌ RECEIVE ERROR: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.updateError("Receive error: \(error.localizedDescription)")
                }
            }
            
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    private func waitForACK(timeout: TimeInterval = 5.0, completion: @escaping (Bool) -> Void) {
        pendingACKCallback = completion
        
        // Set timeout for ACK
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            if self?.pendingACKCallback != nil {
                self?.pendingACKCallback?(false) // Timeout
                self?.pendingACKCallback = nil
            }
        }
    }
    
    private func handleReceivedMessage(_ message: String) {
        // Print detailed analysis of server response
        print("🔍 ANALYZING SERVER RESPONSE:")
        
        // Handle ACK, NAK, EOT responses
        if message.contains(String(ASTMControlCharacter.ACK.character)) {
            print("✅ ACK Response - Server acknowledged message")
            // Received ACK - continue transmission
            if let callback = pendingACKCallback {
                pendingACKCallback = nil
                callback(true)
            }
        } else if message.contains(String(ASTMControlCharacter.NAK.character)) {
            print("❌ NAK Response - Server rejected message")
            // Received NAK - retransmit (for now, treat as failed)
            if let callback = pendingACKCallback {
                pendingACKCallback = nil
                callback(false)
            }
        } else if message.contains(String(ASTMControlCharacter.EOT.character)) {
            print("🔚 EOT Response - End of transmission from server")
            // Received EOT - transmission complete
        } else if message.contains(String(ASTMControlCharacter.ENQ.character)) {
            print("🔔 ENQ Response - Server requesting transmission")
            handleServerENQ()
        } else if message.contains(String(ASTMControlCharacter.STX.character)) {
            print("📦 ASTM Frame - Server sending data frame")
            handleIncomingFrame(message)
        } else if message.contains("H|") {
            print("📋 ASTM Header Record - Server sending header information")
            print("   Header Content: \(message)")
        } else if message.contains("P|") {
            print("👤 ASTM Patient Record - Server sending patient data")
            print("   Patient Content: \(message)")
        } else if message.contains("R|") {
            print("🧪 ASTM Result Record - Server sending test results")
            print("   Result Content: \(message)")
        } else if message.contains("L|") {
            print("🔚 ASTM Terminator Record - Server ending message")
            print("   Terminator Content: \(message)")
        } else {
            print("📄 Unknown/Custom Server Response:")
            print("   Content: \(message)")
            print("   Hex: \(message.data(using: .ascii)?.map { String(format: "%02X", $0) }.joined(separator: " ") ?? "N/A")")
        }
        print("═════════════════════════════════════")
    }
    
    // MARK: - Connection Status Messages
    
    private func sendConnectionMessage() {
        let comment = ASTMCommentRecord(
            sequenceNumber: 1,
            comment: "SN^Connect"
        )
        
        let connectionMessage = ASTMMessage(
            messageType: .connectionStatus,
            header: ASTMHeaderRecord(
                senderInfo: "Skyla Solution",
                softwareVersion: "1.0.0",
                timestamp: ""
            ),
            patient: nil,
            orders: [],
            results: [],
            comments: [comment],
            terminator: ASTMTerminatorRecord(sequenceNumber: 1)
        )
        
        sendASTMMessage(connectionMessage)
    }
    
    private func sendDisconnectMessage() {
        guard connectionStatus == .connected else { return }
        
        let comment = ASTMCommentRecord(
            sequenceNumber: 1,
            comment: "SN^Disconnect"
        )
        
        let disconnectMessage = ASTMMessage(
            messageType: .connectionStatus,
            header: ASTMHeaderRecord(
                senderInfo: "Skyla Solution",
                softwareVersion: "1.0.0",
                timestamp: ""
            ),
            patient: nil,
            orders: [],
            results: [],
            comments: [comment],
            terminator: ASTMTerminatorRecord(sequenceNumber: 1)
        )
        
        sendASTMMessage(disconnectMessage)
    }
    
    // MARK: - Utility Methods
    
    private func updateError(_ message: String) {
        DispatchQueue.main.async {
            self.lastError = message
        }
    }
    
    func clearMessages() {
        DispatchQueue.main.async {
            self.sentMessages.removeAll()
            self.receivedMessages.removeAll()
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.lastError = nil
        }
    }
    
    // MARK: - Testing/Simulation Methods
    
    func simulateReceivedMessage(_ message: String) {
        DispatchQueue.main.async {
            self.receivedMessages.append(message)
        }
    }
    
    func simulateACKResponse() {
        simulateReceivedMessage("ACK - Message acknowledged")
    }
    
    func simulateResultsResponse() {
        let mockResponse = "H|\\^&|||Mock Server^1.0.0|||||||||\r\nR|1|^^^GLU|95|mg/dL|70-110|N|||||\r\nL|1|N\r\n"
        simulateReceivedMessage(mockResponse)
    }
    
    func simulateServerInitiatedTransmission() {
        // Simulate server initiating communication with ENQ
        print("🎭 SIMULATING: Server initiating transmission with ENQ")
        simulateReceivedMessage(String(ASTMControlCharacter.ENQ.character))
        
        // After a brief delay, simulate server sending frames
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let mockFrame1 = "\(ASTMControlCharacter.STX.character)1H|\\^&|||Server^1.0.0|||||||||\(ASTMControlCharacter.ETB.character)5A\(ASTMControlCharacter.CR.character)\(ASTMControlCharacter.LF.character)"
            let mockFrame2 = "\(ASTMControlCharacter.STX.character)2R|1|^^^GLU|120|mg/dL|70-110|H|||||\(ASTMControlCharacter.ETX.character)4B\(ASTMControlCharacter.CR.character)\(ASTMControlCharacter.LF.character)"
            
            self.simulateReceivedMessage(mockFrame1)
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                self.simulateReceivedMessage(mockFrame2)
                
                // Finally send EOT to complete transmission
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    self.simulateReceivedMessage(String(ASTMControlCharacter.EOT.character))
                }
            }
        }
    }
    
    // MARK: - Server-Initiated Communication Handling
    
    private func handleServerENQ() {
        print("💫 Server ENQ detected - Sending ACK to accept transmission")
        
        // Reset frame receiving state
        isReceivingFrames = true
        receivedFrameBuffer.removeAll()
        
        // Send ACK to accept server's transmission request
        sendControlCharacter(.ACK) { [weak self] success in
            if success {
                print("✅ ACK sent successfully - Ready to receive frames")
                DispatchQueue.main.async {
                    self?.receivedMessages.append("📤 Sent ACK in response to server ENQ")
                }
            } else {
                print("❌ Failed to send ACK response")
                DispatchQueue.main.async {
                    self?.updateError("Failed to send ACK response to server ENQ")
                    self?.isReceivingFrames = false
                }
            }
        }
    }
    
    private func handleIncomingFrame(_ frame: String) {
        print("📦 Processing incoming frame from server")
        
        guard isReceivingFrames else {
            print("⚠️ Received frame but not in receiving state - ignoring")
            return
        }
        
        // Extract frame number and content
        if let stxIndex = frame.firstIndex(of: ASTMControlCharacter.STX.character) {
            let afterSTX = frame.index(after: stxIndex)
            
            if afterSTX < frame.endIndex {
                let frameNumberChar = frame[afterSTX]
                print("📋 Frame Number: \(frameNumberChar)")
                
                // Extract content between frame number and ETX/ETB
                let contentStart = frame.index(after: afterSTX)
                var contentEnd = frame.endIndex
                
                // Find ETX or ETB
                if let etxIndex = frame.firstIndex(of: ASTMControlCharacter.ETX.character) {
                    contentEnd = etxIndex
                    print("🔚 Last frame detected (ETX)")
                } else if let etbIndex = frame.firstIndex(of: ASTMControlCharacter.ETB.character) {
                    contentEnd = etbIndex
                    print("➡️ Intermediate frame detected (ETB)")
                }
                
                if contentStart < contentEnd {
                    let frameContent = String(frame[contentStart..<contentEnd])
                    print("📄 Frame Content: \(frameContent)")
                    
                    // Store frame content
                    receivedFrameBuffer.append(frameContent)
                    
                    // Send ACK for the received frame
                    sendControlCharacter(.ACK) { [weak self] success in
                        if success {
                            print("✅ ACK sent for frame")
                            DispatchQueue.main.async {
                                self?.receivedMessages.append("📤 ACK sent for received frame")
                            }
                        } else {
                            print("❌ Failed to send ACK for frame")
                            DispatchQueue.main.async {
                                self?.updateError("Failed to send ACK for received frame")
                            }
                        }
                    }
                    
                    // Check if this was the last frame (ETX)
                    if frame.contains(String(ASTMControlCharacter.ETX.character)) {
                        completeFrameReception()
                    }
                }
            }
        }
    }
    
    private func completeFrameReception() {
        print("🎯 Frame reception complete - Processing received data")
        
        // Combine all received frames
        let completeMessage = receivedFrameBuffer.joined()
        print("📋 Complete Message: \(completeMessage)")
        
        DispatchQueue.main.async {
            self.receivedMessages.append("📥 Complete Server Message: \(completeMessage)")
        }
        
        // Reset state
        isReceivingFrames = false
        receivedFrameBuffer.removeAll()
        
        // Parse and display the complete ASTM message
        parseCompleteASTMMessage(completeMessage)
    }
    
    private func parseCompleteASTMMessage(_ message: String) {
        print("🔍 Parsing complete ASTM message:")
        
        let records = message.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        
        for (index, record) in records.enumerated() {
            if record.hasPrefix("H|") {
                print("   📋 Header Record \(index + 1): \(record)")
            } else if record.hasPrefix("P|") {
                print("   👤 Patient Record \(index + 1): \(record)")
            } else if record.hasPrefix("O|") {
                print("   📝 Order Record \(index + 1): \(record)")
            } else if record.hasPrefix("R|") {
                print("   🧪 Result Record \(index + 1): \(record)")
            } else if record.hasPrefix("C|") {
                print("   💬 Comment Record \(index + 1): \(record)")
            } else if record.hasPrefix("L|") {
                print("   🔚 Terminator Record \(index + 1): \(record)")
            } else {
                print("   ❓ Unknown Record \(index + 1): \(record)")
            }
        }
        
        print("✅ ASTM message parsing complete")
    }
}