import SwiftUI
import AppKit

struct LoggingView: View {
    @StateObject private var logger = MessageLogger.shared
    @State private var selectedLevel: MessageLogger.LogLevel? = nil
    @State private var selectedCategory: MessageLogger.LogCategory? = nil
    @State private var showingExportAlert = false
    @State private var exportURL: URL?
    @State private var searchText = ""
    
    private var filteredLogs: [MessageLogger.LogEntry] {
        var logs = logger.getFilteredLogs(level: selectedLevel, category: selectedCategory)
        
        if !searchText.isEmpty {
            logs = logs.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.details?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return logs.reversed() // Show newest first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            loggingHeader
            
            // Filters
            filterSection
            
            // Statistics
            statisticsSection
            
            // Log entries
            logEntriesSection
        }
        .alert("Log Exported", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            if let url = exportURL {
                Text("Log file saved to: \(url.lastPathComponent)")
            } else {
                Text("Failed to export log file")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var loggingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Message Logging")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Detailed ASTM communication logs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Export") {
                    exportLogs()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(6)
                
                Button("Clear") {
                    logger.clearLogs()
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
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Level and category filters
            HStack(spacing: 16) {
                // Level filter
                Menu {
                    Button("All Levels") {
                        selectedLevel = nil
                    }
                    
                    ForEach(MessageLogger.LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue) {
                            selectedLevel = level
                        }
                    }
                } label: {
                    HStack {
                        Text("Level: \(selectedLevel?.rawValue ?? "All")")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Category filter
                Menu {
                    Button("All Categories") {
                        selectedCategory = nil
                    }
                    
                    ForEach(MessageLogger.LogCategory.allCases, id: \.self) { category in
                        Button(category.rawValue) {
                            selectedCategory = category
                        }
                    }
                } label: {
                    HStack {
                        Text("Category: \(selectedCategory?.rawValue ?? "All")")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer()
                
                // Results count
                Text("\(filteredLogs.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        let stats = logger.getLogStatistics()
        
        return HStack(spacing: 16) {
            statItem(title: "Total", value: "\(stats.totalEntries)", color: .blue)
            statItem(title: "Errors", value: "\(stats.errorCount)", color: .red)
            statItem(title: "Warnings", value: "\(stats.warningCount)", color: .orange)
            statItem(title: "Session", value: stats.formattedSessionDuration, color: .green)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Log Entries Section
    
    private var logEntriesSection: some View {
        Group {
            if filteredLogs.isEmpty {
                emptyStateView
            } else {
                logListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No log entries")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "Start using the simulator to see logs appear here" : "No logs match your search criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.02))
    }
    
    private var logListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                }
            }
        }
        .background(Color.gray.opacity(0.02))
    }
    
    // MARK: - Helper Methods
    
    private func exportLogs() {
        if let url = logger.exportLogToFile() {
            exportURL = url
            showingExportAlert = true
        } else {
            exportURL = nil
            showingExportAlert = true
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: MessageLogger.LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Timestamp
                Text(entry.formattedTimestamp)
                    .font(.caption2)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                // Level indicator
                HStack(spacing: 4) {
                    Image(systemName: entry.level.icon)
                        .font(.caption2)
                    Text(entry.level.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(colorForLevel(entry.level))
                .frame(width: 60, alignment: .leading)
                
                // Category
                HStack(spacing: 4) {
                    Image(systemName: entry.category.icon)
                        .font(.caption2)
                    Text(entry.category.rawValue)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
                
                // Message
                Text(entry.message)
                    .font(.caption)
                    .lineLimit(isExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Expand button
                if entry.details != nil {
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Details section (when expanded)
            if isExpanded, let details = entry.details {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Details:")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Text(details)
                        .font(.caption2)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    private func colorForLevel(_ level: MessageLogger.LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    LoggingView()
}