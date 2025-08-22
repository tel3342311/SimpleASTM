#!/bin/bash

# Create a simple command-line version without SwiftUI complexities
echo "Creating simplified command-line ASTM simulator..."

mkdir -p simple_build
cd simple_build

cat > main.swift << 'EOF'
import Foundation
import Network

// Simple ASTM TCP Client for macOS
class SimpleASTMClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "ASTMClient")
    
    func connect(to host: String, port: Int) {
        print("🔗 Connecting to \(host):\(port)...")
        
        let endpoint = NWEndpoint.host(NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: .tcp)
        
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
        
        for (index, record) in records.enumerated() {
            let frame = buildFrame(record: record, frameNumber: index + 1, isLast: index == records.count - 1)
            sendFrame(frame)
            Thread.sleep(forTimeInterval: 0.1) // Small delay between frames
        }
        
        print("📡 All messages sent!")
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
        
        let checksumHex = String(format: "%02X", checksum)
        return "\(frameContent)\(checksumHex)\r\n"
    }
    
    private func sendFrame(_ frame: String) {
        guard let connection = connection,
              let data = frame.data(using: .ascii) else { return }
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Send error: \(error)")
            } else {
                print("✅ Sent: \(frame.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        })
    }
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                if let message = String(data: data, encoding: .ascii) {
                    print("📥 Received: \(message)")
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

let client = SimpleASTMClient()

// Connect to default localhost:3000
client.connect(to: "localhost", port: 3000)

// Keep the program running
print("\n⌨️  Press Ctrl+C to exit...")
RunLoop.main.run()
EOF

echo "✅ Simple build created!"
echo "🏃 Running: swift main.swift"
swift main.swift