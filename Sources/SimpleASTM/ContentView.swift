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
                
                // Status monitoring
                statusMonitoringSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("SimpleASTM Simulator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    } else {
                        connectToServer()
                    }
                }) {
                    Text(tcpClient.connectionStatus == .connected ? "Disconnect" : "Connect")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 100, height: 36)
                        .background(tcpClient.connectionStatus == .connected ? Color.red : Color.blue)
                        .cornerRadius(8)
                }
                .disabled(tcpClient.connectionStatus == .connecting)
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
                
                MessageHistoryTab(
                    title: "Received (\(tcpClient.receivedMessages.count))",
                    messages: tcpClient.receivedMessages,
                    color: .green
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
                Text("No messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

#Preview {
    ContentView()
}