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
                    _ = BARTComplicationController()
                    bartViewModel.forceLocationCheck()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                bartViewModel.forceLocationCheck()
                // Auto-refresh will start automatically when arrivals are loaded
                // Only start if we already have arrivals but no timer
                if !bartViewModel.arrivals.isEmpty {
                    bartViewModel.startAutoRefresh()
                }
                
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
