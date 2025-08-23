import SwiftUI

struct TestDataView: View {
    @StateObject private var tcpClient = TCPClientService()
    @State private var selectedPanel = TestPanel.liverPanel
    @State private var customPatientName = "Test Patient"
    @State private var customPatientId = "TEST001"
    @State private var customAge = "5"
    @State private var customWeight = "20"
    @State private var selectedGender = "M"
    @State private var selectedSpecies = "Canine"
    @State private var customOwner = "Test Owner"
    @State private var showingPreview = false
    @State private var generatedMessage: ASTMMessage?
    
    private let genders = ["M", "F"]
    private let species = ["Canine", "Feline", "Equine", "Bovine", "Other"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Test Panel Selection
                        testPanelSection
                        
                        // Patient Information
                        patientInfoSection
                        
                        // Pre-configured Test Messages
                        preConfiguredSection
                        
                        // Custom Message Generation
                        customMessageSection
                        
                        // Bulk Testing
                        bulkTestingSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Test Data Generator")
            .sheet(isPresented: $showingPreview) {
                if let message = generatedMessage {
                    MessageDetailView(message: message, isPresented: $showingPreview)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ASTM Test Data Generator")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                connectionStatusIndicator
            }
            
            Text("Generate realistic ASTM messages for testing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var connectionStatusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tcpClient.connectionStatus == .connected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(tcpClient.connectionStatus.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Test Panel Section
    
    private var testPanelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Panel Selection")
                .font(.headline)
            
            Picker("Test Panel", selection: $selectedPanel) {
                ForEach(TestPanel.allPanels, id: \.id) { panel in
                    Text(panel.name).tag(panel)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Panel details
            VStack(alignment: .leading, spacing: 8) {
                Text("Panel: \(selectedPanel.name)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Tests included:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(selectedPanel.tests, id: \.id) { test in
                        HStack {
                            Text(test.id)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text(test.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Patient Info Section
    
    private var patientInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patient Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    TextField("Patient Name", text: $customPatientName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Patient ID", text: $customPatientId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    TextField("Age (years)", text: $customAge)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Weight (kg)", text: $customWeight)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Picker("Gender", selection: $selectedGender) {
                        ForEach(genders, id: \.self) { gender in
                            Text(gender == "M" ? "Male" : "Female").tag(gender)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Picker("Species", selection: $selectedSpecies) {
                        ForEach(species, id: \.self) { species in
                            Text(species).tag(species)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                TextField("Owner Name", text: $customOwner)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Pre-configured Section
    
    private var preConfiguredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pre-configured Test Messages")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(ASTMMessageBuilder.sampleMessages.keys).sorted(), id: \.self) { messageType in
                    testMessageCard(title: messageType, description: getMessageDescription(messageType)) {
                        sendPreConfiguredMessage(messageType)
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Message Section
    
    private var customMessageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Message Generation")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Button("Generate Random Results") {
                        generateCustomMessage(randomResults: true)
                    }
                    .buttonStyle(ActionButtonStyle(color: .blue))
                    
                    Button("Generate Normal Results") {
                        generateCustomMessage(randomResults: false)
                    }
                    .buttonStyle(ActionButtonStyle(color: .green))
                }
                
                HStack {
                    Button("Preview Message") {
                        previewCustomMessage()
                    }
                    .buttonStyle(ActionButtonStyle(color: .orange))
                    
                    Button("Send Custom Message") {
                        sendCustomMessage()
                    }
                    .buttonStyle(ActionButtonStyle(color: .purple))
                    .disabled(tcpClient.connectionStatus != .connected)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Bulk Testing Section
    
    private var bulkTestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bulk Testing")
                .font(.headline)
            
            VStack(spacing: 12) {
                Text("Send multiple test messages for load testing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Send 5 Messages") {
                        sendBulkMessages(count: 5)
                    }
                    .buttonStyle(ActionButtonStyle(color: .blue))
                    
                    Button("Send 10 Messages") {
                        sendBulkMessages(count: 10)
                    }
                    .buttonStyle(ActionButtonStyle(color: .orange))
                    
                    Button("Send 20 Messages") {
                        sendBulkMessages(count: 20)
                    }
                    .buttonStyle(ActionButtonStyle(color: .red))
                }
                .disabled(tcpClient.connectionStatus != .connected)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Helper Views
    
    private func testMessageCard(title: String, description: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Spacer()
            
            Button("Send") {
                action()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(tcpClient.connectionStatus == .connected ? Color.blue : Color.gray)
            .cornerRadius(6)
            .disabled(tcpClient.connectionStatus != .connected)
        }
        .padding()
        .frame(height: 120)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func getMessageDescription(_ messageType: String) -> String {
        switch messageType {
        case "Normal Liver Panel": return "Complete liver panel with normal results"
        case "Abnormal Results": return "Liver panel with abnormal values (high/low)"
        case "Single Glucose Test": return "Single glucose test with high result"
        case "Random Liver Panel": return "Randomized liver panel results"
        case "Random Kidney Panel": return "Randomized kidney panel results"
        case "Add to Work List": return "Add test order to work list"
        case "Cancel from Work List": return "Cancel test order from work list"
        case "Status Comment": return "Status update comment message"
        default: return "ASTM test message"
        }
    }
    
    private func sendPreConfiguredMessage(_ messageType: String) {
        guard let messageBuilder = ASTMMessageBuilder.sampleMessages[messageType] else { return }
        let message = messageBuilder()
        tcpClient.sendASTMMessage(message)
        
        MessageLogger.shared.logMessage(type: messageType, content: "Pre-configured message sent")
    }
    
    private func generateCustomMessage(randomResults: Bool) {
        let customPatient = ASTMPatientRecord(
            sequenceNumber: 1,
            patientId: customPatientId,
            patientName: customPatientName,
            age: customAge,
            gender: selectedGender,
            species: selectedSpecies,
            weight: customWeight,
            ownerName: customOwner
        )
        
        let header = ASTMHeaderRecord(
            senderInfo: "SimpleASTM Simulator",
            softwareVersion: "1.0.0",
            timestamp: ""
        )
        
        let order = ASTMOrderRecord(
            sequenceNumber: 1,
            specimenId: String(format: "CUSTOM%03d", Int.random(in: 1...999)),
            testPanelId: selectedPanel.id,
            actionCode: "A",
            timestamp: ""
        )
        
        let results: [ASTMResultRecord]
        if randomResults {
            results = selectedPanel.tests.enumerated().map { index, testDef in
                let randomResult = ASTMMessageBuilder.generateRandomTestResult(for: testDef)
                return ASTMResultRecord(
                    sequenceNumber: index + 1,
                    testId: randomResult.testId,
                    value: randomResult.value,
                    unit: randomResult.unit,
                    referenceRange: randomResult.referenceRange,
                    flag: randomResult.flag,
                    timestamp: randomResult.timestamp
                )
            }
        } else {
            results = selectedPanel.tests.enumerated().map { index, testDef in
                let normalValue = (testDef.normalMin + testDef.normalMax) / 2
                return ASTMResultRecord(
                    sequenceNumber: index + 1,
                    testId: testDef.id,
                    value: String(format: "%.1f", normalValue),
                    unit: testDef.unit,
                    referenceRange: testDef.referenceRange,
                    flag: .normal,
                    timestamp: ""
                )
            }
        }
        
        generatedMessage = ASTMMessage(
            messageType: .analyticResult,
            header: header,
            patient: customPatient,
            orders: [order],
            results: results,
            comments: [],
            terminator: ASTMTerminatorRecord(sequenceNumber: 1)
        )
    }
    
    private func previewCustomMessage() {
        generateCustomMessage(randomResults: true)
        showingPreview = true
    }
    
    private func sendCustomMessage() {
        generateCustomMessage(randomResults: true)
        if let message = generatedMessage {
            tcpClient.sendASTMMessage(message)
            MessageLogger.shared.logMessage(type: "Custom Message", content: "Custom generated message sent for \(customPatientName)")
        }
    }
    
    private func sendBulkMessages(count: Int) {
        for i in 1...count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                let message = ASTMMessageBuilder.generateRandomMessage(testPanel: selectedPanel)
                tcpClient.sendASTMMessage(message)
            }
        }
        
        MessageLogger.shared.logSystem(message: "Bulk test initiated", details: "Sending \(count) messages with 0.5s intervals")
    }
}

// MARK: - Custom Button Style

struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    TestDataView()
}