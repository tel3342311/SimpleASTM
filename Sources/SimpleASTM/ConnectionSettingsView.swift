import SwiftUI

struct QuickConnectSetting: Identifiable, Codable {
    var id = UUID()
    var name: String
    var host: String
    var port: String
    var isDefault: Bool = false
}

class QuickConnectManager: ObservableObject {
    @Published var settings: [QuickConnectSetting] = []
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "QuickConnectSettings"
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([QuickConnectSetting].self, from: data) {
            settings = decoded
        } else {
            // Load default settings
            settings = [
                QuickConnectSetting(name: "Local Development", host: "localhost", port: "3000", isDefault: true),
                QuickConnectSetting(name: "Test Server", host: "192.168.1.100", port: "3000", isDefault: true),
                QuickConnectSetting(name: "ASTM Standard", host: "localhost", port: "1200", isDefault: true)
            ]
            saveSettings()
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }
    
    func addSetting(_ setting: QuickConnectSetting) {
        settings.append(setting)
        saveSettings()
    }
    
    func deleteSetting(_ setting: QuickConnectSetting) {
        if !setting.isDefault {
            settings.removeAll { $0.id == setting.id }
            saveSettings()
        }
    }
    
    func updateSetting(_ setting: QuickConnectSetting) {
        if let index = settings.firstIndex(where: { $0.id == setting.id }) {
            settings[index] = setting
            saveSettings()
        }
    }
}

struct ConnectionSettingsView: View {
    @Binding var hostAddress: String
    @Binding var portNumber: String
    @Binding var isPresented: Bool
    
    @StateObject private var quickConnectManager = QuickConnectManager()
    @State private var tempHost: String = ""
    @State private var tempPort: String = ""
    @State private var validationError: String? = nil
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingDiscardAlert: Bool = false
    @State private var showingAddDialog: Bool = false
    @State private var newSettingName: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Compact header
            Text("Connection Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.top)
            
            VStack(spacing: 16) {
                // Connection inputs
                VStack(alignment: .leading, spacing: 12) {
                    // Host Address
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Host Address")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("localhost", text: $tempHost)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: tempHost) { _ in
                                updateChangeStatus()
                                validateInput()
                            }
                    }
                    
                    // Port Number 
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port Number")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("3000", text: $tempPort)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: tempPort) { _ in
                                updateChangeStatus()
                                validateInput()
                            }
                    }
                    
                    // Validation Error
                    if let error = validationError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Dynamic Quick Settings
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quick Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddDialog = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Settings grid - adaptive layout
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(quickConnectManager.settings) { setting in
                            quickSettingButton(setting)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 8)
            }
            
            // Compact bottom buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    handleCancel()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                .frame(minWidth: 70)
                
                Button("OK") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isInputValid)
                .frame(minWidth: 70)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            tempHost = hostAddress
            tempPort = portNumber
            hasUnsavedChanges = false
            validateInput()
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                isPresented = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .sheet(isPresented: $showingAddDialog) {
            AddQuickSettingDialog(
                quickConnectManager: quickConnectManager,
                currentHost: tempHost,
                currentPort: tempPort,
                isPresented: $showingAddDialog
            )
        }
    }
    
    private func quickSettingButton(_ setting: QuickConnectSetting) -> some View {
        Button(action: {
            tempHost = setting.host
            tempPort = setting.port
            updateChangeStatus()
            validateInput()
        }) {
            VStack(spacing: 3) {
                HStack {
                    Text(setting.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !setting.isDefault {
                        Button(action: {
                            quickConnectManager.deleteSetting(setting)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Text("\(setting.host):\(setting.port)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(setting.isDefault ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Validation and Actions
    
    private var isInputValid: Bool {
        return validationError == nil && 
               !tempHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
               !tempPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func updateChangeStatus() {
        hasUnsavedChanges = (tempHost != hostAddress) || (tempPort != portNumber)
    }
    
    private func validateInput() {
        let trimmedHost = tempHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = tempPort.trimmingCharacters(in: .whitespacesAndNewlines)
        
        validationError = nil
        
        if trimmedHost.isEmpty {
            validationError = "Host required"
            return
        }
        
        if trimmedPort.isEmpty {
            validationError = "Port required"
            return
        }
        
        guard let port = Int(trimmedPort) else {
            validationError = "Invalid port number"
            return
        }
        
        if port < 1 || port > 65535 {
            validationError = "Port must be 1-65535"
            return
        }
        
        if trimmedHost.contains(" ") {
            validationError = "Invalid host address"
            return
        }
    }
    
    private func handleCancel() {
        updateChangeStatus()
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            isPresented = false
        }
    }
    
    private func saveSettings() {
        guard isInputValid else { return }
        
        let trimmedHost = tempHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = tempPort.trimmingCharacters(in: .whitespacesAndNewlines)
        
        hostAddress = trimmedHost.isEmpty ? "localhost" : trimmedHost
        portNumber = trimmedPort.isEmpty ? "3000" : trimmedPort
        isPresented = false
    }
}

// MARK: - Add Quick Setting Dialog

struct AddQuickSettingDialog: View {
    @ObservedObject var quickConnectManager: QuickConnectManager
    let currentHost: String
    let currentPort: String
    @Binding var isPresented: Bool
    
    @State private var settingName: String = ""
    @State private var settingHost: String = ""
    @State private var settingPort: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Quick Setting")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Name:") {
                    TextField("Enter setting name", text: $settingName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                LabeledContent("Host:") {
                    TextField("Host address", text: $settingHost)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                LabeledContent("Port:") {
                    TextField("Port number", text: $settingPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("Use Current") {
                    settingHost = currentHost
                    settingPort = currentPort
                }
                .buttonStyle(.bordered)
                .disabled(currentHost.isEmpty || currentPort.isEmpty)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Add") {
                    addSetting()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 350, height: 280)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            settingName = ""
            settingHost = currentHost
            settingPort = currentPort
        }
    }
    
    private var isValid: Bool {
        !settingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settingHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settingPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(settingPort.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }
    
    private func addSetting() {
        let newSetting = QuickConnectSetting(
            name: settingName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: settingHost.trimmingCharacters(in: .whitespacesAndNewlines),
            port: settingPort.trimmingCharacters(in: .whitespacesAndNewlines),
            isDefault: false
        )
        quickConnectManager.addSetting(newSetting)
        isPresented = false
    }
}

#Preview {
    ConnectionSettingsView(
        hostAddress: .constant("localhost"),
        portNumber: .constant("3000"),
        isPresented: .constant(true)
    )
}
