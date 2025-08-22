import SwiftUI

@main
struct SimpleASTMApp: App {
    @StateObject private var logger = MessageLogger.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(logger)
                .onAppear {
                    setupApplication()
                }
        }
    }
    
    private func setupApplication() {
        logger.logSystem(message: "SimpleASTM Simulator started", details: "Version 1.0.0 - ASTM E1381/E1394 Protocol Support")
    }
}

struct MainTabView: View {
    @EnvironmentObject var logger: MessageLogger
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Simulator", systemImage: "network")
                }
            
            StatusMonitorView(tcpClient: TCPClientService())
                .tabItem {
                    Label("Monitor", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            LoggingView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
            
            TestDataView()
                .tabItem {
                    Label("Test Data", systemImage: "testtube.2")
                }
        }
    }
}