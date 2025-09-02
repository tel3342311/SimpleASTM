import SwiftUI
import Combine
import AppKit

struct StatusMonitorView: View {
    @StateObject private var tcpClient = TCPClientService()
    @State private var isAutoScrollEnabled = true
    @State private var selectedTab = 0
    @State private var customMessage = ""
    @State private var searchText = ""
    @State private var showingExportOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            statusHeader
            
            // Real-time status indicators
            realTimeStatusRow
            
            // Custom message input section
            customMessageSection
            
            // Message monitoring tabs
            messageTabs
        }
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                sentMessages: tcpClient.sentMessages,
                receivedMessages: tcpClient.receivedMessages,
                isPresented: $showingExportOptions
            )
        }
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
                // Search field
                TextField("Search messages...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 150)
                    .font(.caption)
                
                Toggle("Auto-scroll", isOn: $isAutoScrollEnabled)
                    .font(.caption)
                
                Button("Export") {
                    showingExportOptions = true
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(6)
                
                Button("Clear All") {
                    tcpClient.clearMessages()
                    searchText = ""
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
                autoScroll: isAutoScrollEnabled,
                searchText: searchText
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
                autoScroll: isAutoScrollEnabled,
                searchText: searchText
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
    
    // MARK: - Custom Message Section
    
    private var customMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Message")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                TextField("Enter custom message to send", text: $customMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                
                Button("Send") {
                    sendCustomMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tcpClient.connectionStatus != .connected)
                
                Button("Clear") {
                    customMessage = ""
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.blue.opacity(0.05))
    }
    
    private func statusIndicator(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(color.opacity(0.15))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Methods
    
    private func sendCustomMessage() {
        let trimmedMessage = customMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, tcpClient.connectionStatus == .connected else { return }
        
        // Send raw message via TCP client
        tcpClient.sendRawMessage(trimmedMessage)
        
        // Clear the input after sending
        customMessage = ""
    }
    
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
    let searchText: String
    
    private var filteredMessages: [String] {
        if searchText.isEmpty {
            return messages
        } else {
            return messages.filter { message in
                message.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
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
                
                HStack(spacing: 4) {
                    if !searchText.isEmpty && filteredMessages.count != messages.count {
                        Text("\(filteredMessages.count)/\(messages.count)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(filteredMessages.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .cornerRadius(4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(color.opacity(0.05))
            
            // Message list
            if filteredMessages.isEmpty {
                if messages.isEmpty {
                    emptyStateView
                } else {
                    searchEmptyStateView
                }
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
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(color.opacity(0.5))
            
            Text("No matches found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search terms")
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
                    ForEach(Array(filteredMessages.enumerated()), id: \.offset) { index, message in
                        MessageRowView(
                            index: index + 1,
                            message: message,
                            color: color,
                            searchText: searchText
                        )
                        .id(index)
                    }
                }
            }
            .onChange(of: filteredMessages.count) { _ in
                if autoScroll && !filteredMessages.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(filteredMessages.count - 1, anchor: .bottom)
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
    let searchText: String
    
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
        .background(Color(NSColor.controlBackgroundColor))
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
    let tcpClient: TCPClientService
    
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

// MARK: - Export Options View

struct ExportOptionsView: View {
    let sentMessages: [String]
    let receivedMessages: [String]
    @Binding var isPresented: Bool
    
    @State private var exportFormat = "JSON"
    @State private var includeSentMessages = true
    @State private var includeReceivedMessages = true
    @State private var includeTimestamp = true
    @State private var showingFilePicker = false
    
    private let formats = ["JSON", "CSV", "TXT"]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Message History")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.headline)
                    
                    Picker("Format", selection: $exportFormat) {
                        ForEach(formats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Include Messages")
                        .font(.headline)
                    
                    Toggle("Sent Messages (\(sentMessages.count))", isOn: $includeSentMessages)
                    Toggle("Received Messages (\(receivedMessages.count))", isOn: $includeReceivedMessages)
                    Toggle("Include Timestamp", isOn: $includeTimestamp)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Summary")
                        .font(.headline)
                    
                    Text("Format: \(exportFormat)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Total messages: \(totalMessagesCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Export") {
                        exportMessages()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(totalMessagesCount == 0)
                }
            }
            .padding()
            .frame(width: 400, height: 500)
        }
    }
    
    private var totalMessagesCount: Int {
        var count = 0
        if includeSentMessages { count += sentMessages.count }
        if includeReceivedMessages { count += receivedMessages.count }
        return count
    }
    
    private func exportMessages() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText, .plainText]
        panel.nameFieldStringValue = "astm_messages_\(getCurrentDateString()).\(exportFormat.lowercased())"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let content = generateExportContent()
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.isPresented = false
                    }
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }
    
    private func generateExportContent() -> String {
        switch exportFormat {
        case "JSON":
            return generateJSONContent()
        case "CSV":
            return generateCSVContent()
        case "TXT":
            return generateTXTContent()
        default:
            return generateTXTContent()
        }
    }
    
    private func generateJSONContent() -> String {
        var jsonData: [String: Any] = [:]
        
        if includeTimestamp {
            jsonData["exported_at"] = getCurrentDateString()
        }
        
        if includeSentMessages {
            jsonData["sent_messages"] = sentMessages
        }
        
        if includeReceivedMessages {
            jsonData["received_messages"] = receivedMessages
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error generating JSON: \(error)"
        }
    }
    
    private func generateCSVContent() -> String {
        var csv = "Type,Index,Message,Timestamp\n"
        
        if includeSentMessages {
            for (index, message) in sentMessages.enumerated() {
                let timestamp = includeTimestamp ? getCurrentDateString() : ""
                csv += "Sent,\(index + 1),\"\(message.replacingOccurrences(of: "\"", with: "\"\""))\",\(timestamp)\n"
            }
        }
        
        if includeReceivedMessages {
            for (index, message) in receivedMessages.enumerated() {
                let timestamp = includeTimestamp ? getCurrentDateString() : ""
                csv += "Received,\(index + 1),\"\(message.replacingOccurrences(of: "\"", with: "\"\""))\",\(timestamp)\n"
            }
        }
        
        return csv
    }
    
    private func generateTXTContent() -> String {
        var content = ""
        
        if includeTimestamp {
            content += "ASTM Message Export - \(getCurrentDateString())\n"
            content += "=====================================\n\n"
        }
        
        if includeSentMessages && !sentMessages.isEmpty {
            content += "SENT MESSAGES (\(sentMessages.count))\n"
            content += "-----------------\n"
            for (index, message) in sentMessages.enumerated() {
                content += "\(index + 1). \(message)\n"
            }
            content += "\n"
        }
        
        if includeReceivedMessages && !receivedMessages.isEmpty {
            content += "RECEIVED MESSAGES (\(receivedMessages.count))\n"
            content += "---------------------\n"
            for (index, message) in receivedMessages.enumerated() {
                content += "\(index + 1). \(message)\n"
            }
            content += "\n"
        }
        
        return content
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

#Preview {
    StatusMonitorView()
}