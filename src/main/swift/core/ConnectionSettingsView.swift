import SwiftUI

struct ConnectionSettingsView: View {
    @Binding var hostAddress: String
    @Binding var portNumber: String
    @Binding var isPresented: Bool
    
    @State private var tempHost: String = ""
    @State private var tempPort: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    HStack {
                        Text("Host Address")
                        Spacer()
                        TextField("localhost", text: $tempHost)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                    }
                    
                    HStack {
                        Text("Port Number")
                        Spacer()
                        TextField("3000", text: $tempPort)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(width: 200)
                    }
                }
                
                Section(header: Text("Predefined Configurations")) {
                    VStack(spacing: 12) {
                        connectionPreset(name: "Local Development", host: "localhost", port: "3000")
                        connectionPreset(name: "Test Server", host: "192.168.1.100", port: "3000")
                        connectionPreset(name: "ASTM Standard", host: "localhost", port: "1200")
                    }
                }
                
                Section(header: Text("Connection Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow(label: "Protocol", value: "TCP")
                        infoRow(label: "ASTM Standard", value: "E1381-95 (Low-level)")
                        infoRow(label: "Data Format", value: "E1394-97 (High-level)")
                        infoRow(label: "Character Encoding", value: "ASCII")
                    }
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempHost = hostAddress
            tempPort = portNumber
        }
    }
    
    private func connectionPreset(name: String, host: String, port: String) -> some View {
        Button(action: {
            tempHost = host
            tempPort = port
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("\(host):\(port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
    
    private func saveSettings() {
        hostAddress = tempHost.isEmpty ? "localhost" : tempHost
        portNumber = tempPort.isEmpty ? "3000" : tempPort
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