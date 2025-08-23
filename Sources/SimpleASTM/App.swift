import SwiftUI
import AppKit

@main
struct SimpleASTMApp: App {
    @StateObject private var logger = MessageLogger.shared
    
    var body: some Scene {
        WindowGroup("SimpleASTM Simulator") {
            MainTabView()
                .environmentObject(logger)
                .onAppear {
                    setupApplication()
                    setupAppForDockAndFocus()
                    activateApp()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 700)
    }
    
    private func setupApplication() {
        logger.logSystem(message: "SimpleASTM Simulator started", details: "Version 1.0.0 - ASTM E1381/E1394 Protocol Support")
    }
    
    private func setupAppForDockAndFocus() {
        // Ensure NSApp is available before configuring
        guard NSApp != nil else {
            print("NSApp not available yet, skipping setup")
            return
        }
        
        // Ensure app appears in Dock and can become active
        NSApp.setActivationPolicy(.regular)
        
        // Configure app properties
        if Bundle.main.infoDictionary != nil {
            // App bundle configuration exists
            NSApp.mainMenu?.title = "SimpleASTM Simulator"
        }
    }
    
    private func activateApp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard NSApp != nil else { return }
            
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            
            // Ensure the main window becomes key and can accept input
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(nil) // Let window decide first responder
                    window.becomeMain()
                    window.orderFrontRegardless()
                }
            }
        }
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
            
            StatusMonitorView()
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
        .frame(minWidth: 800, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Ensure window can receive keyboard input when app becomes active
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard NSApp != nil else { return }
                if let window = NSApp.keyWindow ?? NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.becomeMain()
                    window.orderFrontRegardless()
                }
            }
        }
        .onAppear {
            // Force activation when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard NSApp != nil else { return }
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}