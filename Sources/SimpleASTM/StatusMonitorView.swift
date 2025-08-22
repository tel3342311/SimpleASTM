import SwiftUI
import Combine

struct StatusMonitorView: View {
    @ObservableObject var tcpClient: TCPClientService
    @State private var isAutoScrollEnabled = true
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            statusHeader
            
            // Real-time status indicators
            realTimeStatusRow
            
            // Message monitoring tabs
            messageTabs
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status Monitor")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Real-time ASTM communication monitoring")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Toggle("Auto-scroll", isOn: $isAutoScrollEnabled)
                    .font(.caption)
                
                Button("Clear All") {
                    tcpClient.clearMessages()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    // MARK: - Real-Time Status Row
    
    private var realTimeStatusRow: some View {
        HStack(spacing: 20) {
            statusIndicator(
                title: "Connection",
                value: tcpClient.connectionStatus.rawValue,
                color: colorForConnectionStatus(tcpClient.connectionStatus),
                icon: "network"
            )
            
            statusIndicator(
                title: "Transmission",
                value: tcpClient.isTransmitting ? "Active" : "Idle",
                color: tcpClient.isTransmitting ? .orange : .gray,
                icon: tcpClient.isTransmitting ? "arrow.up.arrow.down" : "pause.circle"
            )
            
            statusIndicator(
                title: "Messages Sent",
                value: "\(tcpClient.sentMessages.count)",
                color: .blue,
                icon: "arrow.up.circle"
            )
            
            statusIndicator(
                title: "Messages Received",
                value: "\(tcpClient.receivedMessages.count)",
                color: .green,
                icon: "arrow.down.circle"
            )
        }
        .padding()
        .background(Color.gray.opacity(0.02))
    }
    
    // MARK: - Message Tabs
    
    private var messageTabs: some View {
        TabView(selection: $selectedTab) {
            MessageListView(
                title: "Sent Messages",
                messages: tcpClient.sentMessages,
                color: .blue,
                icon: "arrow.up.circle.fill",
                autoScroll: isAutoScrollEnabled
            )
            .tabItem {
                Label("Sent", systemImage: "arrow.up.circle")
            }
            .tag(0)
            
            MessageListView(
                title: "Received Messages",
                messages: tcpClient.receivedMessages,
                color: .green,
                icon: "arrow.down.circle.fill",
                autoScroll: isAutoScrollEnabled
            )
            .tabItem {
                Label("Received", systemImage: "arrow.down.circle")
            }
            .tag(1)
            
            ProtocolAnalysisView(tcpClient: tcpClient)
                .tabItem {
                    Label("Analysis", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
        }
        .frame(minHeight: 300)
    }
    
    // MARK: - Status Indicator
    
    private func statusIndicator(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func colorForConnectionStatus(_ status: ConnectionStatus) -> Color {
        switch status {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

// MARK: - Message List View

struct MessageListView: View {
    let title: String
    let messages: [String]
    let color: Color
    let icon: String
    let autoScroll: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // List header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(messages.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(color.opacity(0.05))
            
            // Message list
            if messages.isEmpty {
                emptyStateView
            } else {
                messageScrollView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color.opacity(0.5))
            
            Text("No \(title.lowercased()) yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Messages will appear here when the client communicates with the server")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.02))
    }
    
    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                        MessageRowView(
                            index: index + 1,
                            message: message,
                            color: color
                        )
                        .id(index)
                    }
                }
            }
            .onChange(of: messages.count) { _ in
                if autoScroll && !messages.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(messages.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Message Row View

struct MessageRowView: View {
    let index: Int
    let message: String
    let color: Color
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Index number
                Text("\(index)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 20)
                    .background(color)
                    .cornerRadius(4)
                
                // Timestamp
                Text(getCurrentTimestamp())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                // Message preview
                Text(messagePreview)
                    .font(.caption)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(isExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Expand/collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Full message when expanded
            if isExpanded {
                Text(message)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    private var messagePreview: String {
        let preview = message.prefix(60)
        return message.count > 60 ? "\(preview)..." : String(preview)
    }
    
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Protocol Analysis View

struct ProtocolAnalysisView: View {
    @ObservableObject var tcpClient: TCPClientService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Protocol Analysis")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    analysisCard(
                        title: "Connection Health",
                        value: connectionHealthStatus,
                        color: connectionHealthColor,
                        details: connectionHealthDetails
                    )
                    
                    analysisCard(
                        title: "Message Statistics",
                        value: "\(tcpClient.sentMessages.count + tcpClient.receivedMessages.count) Total",
                        color: .blue,
                        details: messageStatistics
                    )
                    
                    analysisCard(
                        title: "Protocol Compliance",
                        value: "ASTM E1381/E1394",
                        color: .green,
                        details: protocolCompliance
                    )
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func analysisCard(title: String, value: String, color: Color, details: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .cornerRadius(6)
            }
            
            Text(details)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var connectionHealthStatus: String {
        switch tcpClient.connectionStatus {
        case .connected: return "Healthy"
        case .connecting: return "Establishing"
        case .disconnected: return "Offline"
        case .error: return "Error"
        }
    }
    
    private var connectionHealthColor: Color {
        switch tcpClient.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private var connectionHealthDetails: String {
        switch tcpClient.connectionStatus {
        case .connected: return "TCP connection established and ASTM handshake completed. Ready for data transmission."
        case .connecting: return "Establishing TCP connection to remote server. Waiting for handshake completion."
        case .disconnected: return "No active connection. Click Connect to establish communication with the server."
        case .error: return tcpClient.lastError ?? "Connection error occurred. Check server availability and network settings."
        }
    }
    
    private var messageStatistics: String {
        let sent = tcpClient.sentMessages.count
        let received = tcpClient.receivedMessages.count
        let ratio = received > 0 ? Double(sent) / Double(received) : 0
        
        return "Sent: \(sent) messages\nReceived: \(received) messages\nRatio: \(String(format: "%.2f", ratio))"
    }
    
    private var protocolCompliance: String {
        """
        • Low-level protocol: ASTM E1381-95 (TCP transport)
        • High-level format: ASTM E1394-97 (message structure)
        • Frame structure: STX + FN + Text + ETB/ETX + Checksum
        • Control characters: ENQ, ACK, NAK, EOT for handshaking
        """
    }
}

#Preview {
    StatusMonitorView(tcpClient: TCPClientService())
}