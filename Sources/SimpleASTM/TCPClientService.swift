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
        sendDisconnectMessage()
        
        connection?.cancel()
        connection = nil
        
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.isEstablished = false
            self.frameNumber = 1
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
                // Wait for ACK, then send message frames
                self?.sendMessageFrames(message)
            } else {
                DispatchQueue.main.async {
                    self?.isTransmitting = false
                    self?.updateError("Failed to establish transmission")
                }
            }
        }
    }
    
    private func sendMessageFrames(_ message: ASTMMessage) {
        let records = message.buildCompleteMessage()
        
        for (index, record) in records.enumerated() {
            let isLastFrame = (index == records.count - 1)
            let frame = buildASTMFrame(record: record, frameNumber: frameNumber, isLast: isLastFrame)
            
            sendFrame(frame) { [weak self] success in
                if success {
                    self?.frameNumber += 1
                    if isLastFrame {
                        // Send EOT to end transmission
                        self?.sendControlCharacter(.EOT) { _ in
                            DispatchQueue.main.async {
                                self?.isTransmitting = false
                                self?.frameNumber = 1
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.isTransmitting = false
                        self?.updateError("Failed to send frame")
                    }
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
        
        let checksum = sum & 0xFF
        let c1 = String(format: "%02X", checksum >> 4)
        let c2 = String(format: "%02X", checksum & 0x0F)
        
        return c1 + c2
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
                    DispatchQueue.main.async {
                        self?.receivedMessages.append("Received: \(message)")
                        self?.handleReceivedMessage(message)
                    }
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.updateError("Receive error: \(error.localizedDescription)")
                }
            }
            
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    private func handleReceivedMessage(_ message: String) {
        // Handle ACK, NAK, EOT responses
        if message.contains(String(ASTMControlCharacter.ACK.character)) {
            // Received ACK - continue transmission
        } else if message.contains(String(ASTMControlCharacter.NAK.character)) {
            // Received NAK - retransmit
        } else if message.contains(String(ASTMControlCharacter.EOT.character)) {
            // Received EOT - transmission complete
        }
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
}