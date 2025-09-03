import SwiftUI

struct ContentView: View {
    @StateObject private var tcpClient = TCPClientService()
    @State private var hostAddress = "localhost"
    @State private var portNumber = "3000"
    @State private var selectedMessageType = "Normal Liver Panel"
    @State private var showingConnectionSettings = false
    @State private var showingMessageDetails = false
    @State private var selectedMessage: ASTMMessage?
    
    private let messageTypes = Array(ASTMMessageBuilder.sampleMessages.keys).sorted()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with connection status
                connectionStatusSection
                
                // Connection controls
                connectionControlsSection
                
                // Message sending section
                messageSendingSection
                
                // Testing section
                testingSection
                
                // Status monitoring
                statusMonitoringSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("SimpleASTM Simulator")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings") {
                        showingConnectionSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingConnectionSettings) {
                ConnectionSettingsView(
                    hostAddress: $hostAddress,
                    portNumber: $portNumber,
                    isPresented: $showingConnectionSettings
                )
            }
            .sheet(isPresented: $showingMessageDetails) {
                if let message = selectedMessage {
                    MessageDetailView(message: message, isPresented: $showingMessageDetails)
                }
            }
        }
        .onAppear {
            // Clear any previous error
            tcpClient.clearError()
        }
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(colorForStatus(tcpClient.connectionStatus))
                    .frame(width: 12, height: 12)
                
                Text(tcpClient.connectionStatus.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if tcpClient.isTransmitting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Transmitting...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if let error = tcpClient.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        tcpClient.clearError()
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Connection Controls Section
    
    private var connectionControlsSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Connection")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Host: \(hostAddress)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Port: \(portNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    if tcpClient.connectionStatus == .connected {
                        tcpClient.disconnect()
                    } else if tcpClient.connectionStatus == .connecting {
                        tcpClient.disconnect()  // Cancel connection attempt
                    } else {
                        connectToServer()
                    }
                }) {
                    Text(buttonText)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 100, height: 36)
                        .background(buttonColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Message Sending Section
    
    private var messageSendingSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Send ASTM Messages")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Picker("Message Type", selection: $selectedMessageType) {
                    ForEach(messageTypes, id: \.self) { messageType in
                        Text(messageType).tag(messageType)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Button("Preview Message") {
                        previewSelectedMessage()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Send Message") {
                        sendSelectedMessage()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 36)
                    .background(tcpClient.connectionStatus == .connected ? Color.green : Color.gray)
                    .cornerRadius(8)
                    .disabled(tcpClient.connectionStatus != .connected || tcpClient.isTransmitting)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Status Monitoring Section
    
    private var statusMonitoringSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Message History")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear") {
                    tcpClient.clearMessages()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            TabView {
                MessageHistoryTab(
                    title: "Sent (\(tcpClient.sentMessages.count))",
                    messages: tcpClient.sentMessages,
                    color: .blue
                )
                .tabItem {
                    Label("Sent", systemImage: "arrow.up.circle")
                }
                
                ReceivedMessagesTab(
                    title: "Received (\(tcpClient.receivedMessages.count))",
                    messages: tcpClient.receivedMessages,
                    color: .green,
                    tcpClient: tcpClient
                )
                .tabItem {
                    Label("Received", systemImage: "arrow.down.circle")
                }
            }
            .frame(height: 300)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Testing Section
    
    private var testingSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Testing & Simulation")
                    .font(.headline)
                
                Spacer()
                
                Text("Demo Mode")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            HStack {
                Text("Server data simulation moved to 'Received' tab")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                
                Spacer()
                
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            Text("All server simulation controls are now available in the 'Received' tab below")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties
    
    private var buttonText: String {
        switch tcpClient.connectionStatus {
        case .connected: return "Disconnect"
        case .connecting: return "Cancel"
        case .disconnected, .error: return "Connect"
        }
    }
    
    private var buttonColor: Color {
        switch tcpClient.connectionStatus {
        case .connected: return .red
        case .connecting: return .orange
        case .disconnected, .error: return .blue
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForStatus(_ status: ConnectionStatus) -> Color {
        switch status {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private func connectToServer() {
        guard let port = Int(portNumber) else {
            tcpClient.lastError = "Invalid port number"
            return
        }
        
        tcpClient.connect(to: hostAddress, port: port)
    }
    
    private func sendSelectedMessage() {
        guard let messageBuilder = ASTMMessageBuilder.sampleMessages[selectedMessageType] else {
            return
        }
        
        let message = messageBuilder()
        tcpClient.sendASTMMessage(message)
    }
    
    private func previewSelectedMessage() {
        guard let messageBuilder = ASTMMessageBuilder.sampleMessages[selectedMessageType] else {
            return
        }
        
        selectedMessage = messageBuilder()
        showingMessageDetails = true
    }
}

// MARK: - Supporting Views

struct MessageHistoryTab: View {
    let title: String
    let messages: [String]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            if messages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    
                    Text("No messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if title.contains("Received") {
                        Text("Received messages from the server will appear here.\nConnect to a server and send messages to see responses.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .leading)
                                
                                Text(message)
                                    .font(.caption)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Received Messages Tab with Server Simulation

struct ReceivedMessagesTab: View {
    let title: String
    let messages: [String]
    let color: Color
    let tcpClient: TCPClientService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with title
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            if messages.isEmpty {
                // Empty state with server simulation controls
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    
                    Text("No messages received")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Simulate server responses below or connect to a real server")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    // Server simulation controls
                    serverSimulationControls
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    // Messages list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    Text(message)
                                        .font(.caption)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Server simulation controls at bottom
                    serverSimulationControls
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var serverSimulationControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Server Data Simulation")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Button("Simulate ACK") {
                        tcpClient.simulateACKResponse()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    
                    Button("Simulate Results") {
                        tcpClient.simulateResultsResponse()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    
                    Button("Custom Response") {
                        tcpClient.simulateReceivedMessage("Custom test response: OK")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Button("Server ENQ→ACK→Frames") {
                        tcpClient.simulateServerInitiatedTransmission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .foregroundColor(.white)
                    
                    Text("Full ASTM sequence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}