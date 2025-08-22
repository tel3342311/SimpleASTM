import Foundation
import Network

// Simple ASTM TCP Client for macOS
class SimpleASTMClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "ASTMClient")
    
    func connect(to host: String, port: Int) {
        print("🔗 Connecting to \(host):\(port)...")
        
        guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
            print("❌ Invalid port number")
            return
        }
        
        connection = NWConnection(host: NWEndpoint.Host(host), port: portNumber, using: .tcp)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Connected successfully!")
                self.sendSampleMessage()
            case .failed(let error):
                print("❌ Connection failed: \(error)")
            case .cancelled:
                print("🔌 Connection cancelled")
            default:
                print("🔄 Connection state: \(state)")
            }
        }
        
        connection?.start(queue: queue)
        startReceiving()
    }
    
    func sendSampleMessage() {
        print("📤 Sending sample ASTM message...")
        
        let records = [
            "H|\\^&|||SimpleASTM^1.0.0|||||P|1|20230823020000",
            "P|1||TEST001||Test Patient||^5^Year|M|||||||Test Owner|Canine||20^Kg||||||||||||||||",
            "O|1|000001||^^^LiverPanel|A|20230823020000|||||N||||||||||||||",
            "R|1|^^^ALB|3.0|g/dL|2.3-4.0|N||||F||20230823020000",
            "R|2|^^^ALT|35|U/L|10-100|N||||F||20230823020000",
            "L|1|N"
        ]
        
        // Send ENQ first
        sendControlCharacter(0x05) // ENQ
        
        // Wait a bit, then send frames
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for (index, record) in records.enumerated() {
                let frame = self.buildFrame(record: record, frameNumber: index + 1, isLast: index == records.count - 1)
                self.sendFrame(frame)
                Thread.sleep(forTimeInterval: 0.1) // Small delay between frames
            }
            
            // Send EOT
            self.sendControlCharacter(0x04) // EOT
            print("📡 All messages sent!")
        }
    }
    
    private func sendControlCharacter(_ char: UInt8) {
        guard let connection = connection else { return }
        
        let data = Data([char])
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Control char send error: \(error)")
            } else {
                let charName = char == 0x05 ? "ENQ" : char == 0x04 ? "EOT" : "0x\(String(format: "%02X", char))"
                print("✅ Sent control: \(charName)")
            }
        })
    }
    
    private func buildFrame(record: String, frameNumber: Int, isLast: Bool) -> String {
        let frameNum = String(frameNumber % 8)
        let endChar = isLast ? "\u{03}" : "\u{17}" // ETX or ETB
        let frameContent = "\u{02}\(frameNum)\(record)\(endChar)" // STX + frame + record + end
        
        // Simple checksum calculation
        var checksum: UInt8 = 0
        for char in frameContent {
            if let ascii = char.asciiValue {
                checksum = checksum &+ ascii
            }
        }
        
        let c1 = (checksum >> 4) & 0x0F
        let c2 = checksum & 0x0F
        let checksumStr = String(format: "%X%X", c1, c2)
        
        return "\(frameContent)\(checksumStr)\r\n"
    }
    
    private func sendFrame(_ frame: String) {
        guard let connection = connection,
              let data = frame.data(using: .ascii) else { return }
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Frame send error: \(error)")
            } else {
                let displayFrame = frame.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\u{02}", with: "<STX>")
                    .replacingOccurrences(of: "\u{03}", with: "<ETX>")
                    .replacingOccurrences(of: "\u{17}", with: "<ETB>")
                print("✅ Sent frame: \(displayFrame)")
            }
        })
    }
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                if let message = String(data: data, encoding: .ascii) {
                    let displayMessage = message
                        .replacingOccurrences(of: "\u{06}", with: "<ACK>")
                        .replacingOccurrences(of: "\u{15}", with: "<NAK>")
                        .replacingOccurrences(of: "\u{04}", with: "<EOT>")
                    print("📥 Received: \(displayMessage)")
                }
            }
            
            if let error = error {
                print("❌ Receive error: \(error)")
            }
            
            if !isComplete {
                self.startReceiving()
            }
        }
    }
    
    func disconnect() {
        print("🔌 Disconnecting...")
        connection?.cancel()
    }
}

// Main program
print("🏥 SimpleASTM Medical Device Simulator")
print("📋 ASTM E1381/E1394 Protocol Implementation")
print("==========================================")
print("📝 Sample ASTM Message:")
print("   H - Header Record (System Info)")
print("   P - Patient Record (Demographics)")  
print("   O - Order Record (Test Panel)")
print("   R - Result Records (Lab Values)")
print("   L - Terminator Record")
print("==========================================")

let client = SimpleASTMClient()

// Connect to default localhost:3000
client.connect(to: "localhost", port: 3000)

// Keep the program running for a bit to see results
DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
    client.disconnect()
    print("💯 Demo completed!")
    exit(0)
}

RunLoop.main.run()