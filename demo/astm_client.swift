import Foundation
import Network

class ASTMClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "ASTMClient")
    
    func connect(to host: String, port: Int) {
        print("🔗 Connecting to \(host):\(port)...")
        
        guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
            print("❌ Invalid port")
            return
        }
        
        connection = NWConnection(host: NWEndpoint.Host(host), port: portNumber, using: .tcp)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Connected! Sending ASTM message...")
                self.sendASTMMessage()
            case .failed(let error):
                print("❌ Failed: \(error)")
                exit(1)
            default:
                print("🔄 State: \(state)")
            }
        }
        
        connection?.start(queue: queue)
        startReceiving()
    }
    
    func sendASTMMessage() {
        let records = [
            "H|\\^&|||SimpleASTM^1.0.0|||||P|1|20230823120000",
            "P|1||PET001||Max||^3^Year|M|||||||Dr. Smith|Canine||15^Kg||||||||||||||||",
            "O|1|000123||^^^LiverPanel|A|20230823120000|||||N||||||||||||||",
            "R|1|^^^ALB|2.8|g/dL|2.3-4.0|N||||F||20230823120000",
            "R|2|^^^ALT|45|U/L|10-100|N||||F||20230823120000",
            "L|1|N"
        ]
        
        // Send ENQ
        sendData(Data([0x05]))
        usleep(100000) // 100ms delay
        
        // Send frames
        for (index, record) in records.enumerated() {
            let frame = buildFrame(record: record, frameNumber: index + 1, isLast: index == records.count - 1)
            sendData(frame.data(using: .ascii)!)
            usleep(50000) // 50ms delay
        }
        
        // Send EOT
        sendData(Data([0x04]))
        print("📤 All ASTM records sent!")
    }
    
    func buildFrame(record: String, frameNumber: Int, isLast: Bool) -> String {
        let fn = String(frameNumber % 8)
        let end = isLast ? "\u{03}" : "\u{17}"
        let content = "\u{02}\(fn)\(record)\(end)"
        
        var checksum: UInt8 = 0
        for char in content {
            checksum = checksum &+ (char.asciiValue ?? 0)
        }
        
        let c1 = String(format: "%X", (checksum >> 4) & 0x0F)
        let c2 = String(format: "%X", checksum & 0x0F)
        
        return "\(content)\(c1)\(c2)\r\n"
    }
    
    func sendData(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }
    
    func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
            if let data = data, !data.isEmpty {
                print("📥 Server response: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
            self.startReceiving()
        }
    }
}

// Main execution
print("🏥 SimpleASTM Client - Medical Device Simulator")
print("📋 Implementing ASTM E1381/E1394 Protocol")
print("==========================================")

let client = ASTMClient()
client.connect(to: "localhost", port: 3000)

DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    print("💯 Demo completed!")
    exit(0)
}

RunLoop.main.run()
