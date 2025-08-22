import SwiftUI

struct MessageDetailView: View {
    let message: ASTMMessage
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Message Type Header
                    messageTypeHeader
                    
                    // Header Record
                    recordSection(title: "Header Record (H)", content: message.header.toASTMString())
                    
                    // Patient Record
                    if let patient = message.patient {
                        recordSection(title: "Patient Record (P)", content: patient.toASTMString())
                        patientDetailsSection(patient: patient)
                    }
                    
                    // Order Records
                    if !message.orders.isEmpty {
                        ForEach(Array(message.orders.enumerated()), id: \.offset) { index, order in
                            recordSection(title: "Order Record (O) #\(index + 1)", content: order.toASTMString())
                            orderDetailsSection(order: order)
                        }
                    }
                    
                    // Result Records
                    if !message.results.isEmpty {
                        ForEach(Array(message.results.enumerated()), id: \.offset) { index, result in
                            recordSection(title: "Result Record (R) #\(index + 1)", content: result.toASTMString())
                            resultDetailsSection(result: result)
                        }
                    }
                    
                    // Comment Records
                    if !message.comments.isEmpty {
                        ForEach(Array(message.comments.enumerated()), id: \.offset) { index, comment in
                            recordSection(title: "Comment Record (C) #\(index + 1)", content: comment.toASTMString())
                        }
                    }
                    
                    // Terminator Record
                    recordSection(title: "Terminator Record (L)", content: message.terminator.toASTMString())
                    
                    // Complete Message Preview
                    completeMessageSection
                }
                .padding()
            }
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Message Type Header
    
    private var messageTypeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.messageType.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(getCurrentTimestamp())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("ASTM E1394-97 Data Format")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Record Section
    
    private func recordSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - Detail Sections
    
    private func patientDetailsSection(patient: ASTMPatientRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Patient Information")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                GridRow {
                    Text("ID:")
                        .foregroundColor(.secondary)
                    Text(patient.patientId)
                }
                GridRow {
                    Text("Name:")
                        .foregroundColor(.secondary)
                    Text(patient.patientName)
                }
                GridRow {
                    Text("Age:")
                        .foregroundColor(.secondary)
                    Text("\(patient.age) Years")
                }
                GridRow {
                    Text("Gender:")
                        .foregroundColor(.secondary)
                    Text(patient.gender == "M" ? "Male" : "Female")
                }
                GridRow {
                    Text("Species:")
                        .foregroundColor(.secondary)
                    Text(patient.species)
                }
                GridRow {
                    Text("Weight:")
                        .foregroundColor(.secondary)
                    Text("\(patient.weight) Kg")
                }
                GridRow {
                    Text("Owner:")
                        .foregroundColor(.secondary)
                    Text(patient.ownerName)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func orderDetailsSection(order: ASTMOrderRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Order Information")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                GridRow {
                    Text("Specimen ID:")
                        .foregroundColor(.secondary)
                    Text(order.specimenId)
                }
                GridRow {
                    Text("Test Panel:")
                        .foregroundColor(.secondary)
                    Text(order.testPanelId)
                }
                GridRow {
                    Text("Action:")
                        .foregroundColor(.secondary)
                    Text(actionCodeDescription(order.actionCode))
                }
                GridRow {
                    Text("Report Type:")
                        .foregroundColor(.secondary)
                    Text(order.reportType == "N" ? "Normal" : order.reportType)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func resultDetailsSection(result: ASTMResultRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Result Information")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                GridRow {
                    Text("Test:")
                        .foregroundColor(.secondary)
                    Text(result.testId)
                }
                GridRow {
                    Text("Value:")
                        .foregroundColor(.secondary)
                    HStack {
                        Text("\(result.value) \(result.unit)")
                        flagBadge(result.flag)
                    }
                }
                GridRow {
                    Text("Reference:")
                        .foregroundColor(.secondary)
                    Text("\(result.referenceRange) \(result.unit)")
                }
                GridRow {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    Text(result.flag.description)
                        .foregroundColor(flagColor(result.flag))
                }
            }
            .font(.caption)
        }
        .padding()
        .background(flagBackgroundColor(result.flag))
        .cornerRadius(8)
    }
    
    // MARK: - Complete Message Section
    
    private var completeMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Complete ASTM Message")
                .font(.headline)
                .foregroundColor(.primary)
            
            let completeMessage = message.buildCompleteMessage().joined(separator: "\n")
            
            Text(completeMessage)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    private func actionCodeDescription(_ code: String) -> String {
        switch code {
        case "N": return "New Order"
        case "A": return "Add/Update"
        case "C": return "Cancel"
        case "Q": return "Query"
        default: return code
        }
    }
    
    private func flagBadge(_ flag: ResultFlag) -> some View {
        Text(flag.rawValue)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 20, height: 16)
            .background(flagColor(flag))
            .cornerRadius(4)
    }
    
    private func flagColor(_ flag: ResultFlag) -> Color {
        switch flag {
        case .normal: return .green
        case .low, .high: return .orange
        case .critical, .criticalHigh: return .red
        case .abnormal: return .purple
        }
    }
    
    private func flagBackgroundColor(_ flag: ResultFlag) -> Color {
        flagColor(flag).opacity(0.05)
    }
}

#Preview {
    MessageDetailView(
        message: ASTMMessageBuilder.createSampleAnalyticResultMessage(),
        isPresented: .constant(true)
    )
}