//
//  BARTArrivalsApp.swift
//  BARTArrivals Watch App
//
//  Created by Samuel Daly on 3/13/25.
//

import SwiftUI
import ClockKit

@main
struct BARTArrivalsWatchApp: App {
    @StateObject private var bartViewModel = BARTViewModel()
    @StateObject private var extensionDelegate = ExtensionDelegate()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bartViewModel)
                .onAppear {
                    print("🚀 BARTArrivals: ContentView appeared - starting fast startup sequence")
                    
                    // Simple complication setup - just create the controller
                    // The system will automatically discover it
                    _ = BARTComplicationController()
                    print("BARTArrivals: ComplicationController created")
                    
                    // 🚀 NEW: Force location check on app start
                    // This ensures we always start with the most current location and nearest station
                    print("🚀 Watch: App appeared, forcing location check")
                    bartViewModel.forceLocationCheck()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                print("🚀 BARTArrivals: Watch app became active - starting fast refresh sequence")
                
                // 🚀 NEW: Always force a location check when app becomes active
                // This ensures we have the most current location and nearest station
                print("🚀 Watch: App became active, forcing location check")
                bartViewModel.forceLocationCheck()
                
                // Start auto-refresh
                bartViewModel.startAutoRefresh()
                
            case .background:
                print("BARTArrivals: Watch app entered background")
                
                // Stop timers when entering background
                bartViewModel.stopAutoRefresh()
                LocationManager.shared.stopUpdatingLocation()
                
            case .inactive:
                print("BARTArrivals: Watch app became inactive")
                
                // Don't request location when becoming inactive - this was causing redundancy
                
            @unknown default:
                break
            }
        }
    }
}
