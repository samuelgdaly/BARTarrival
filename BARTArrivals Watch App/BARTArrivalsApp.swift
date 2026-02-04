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
    @State private var lastBackgroundTime: Date?
    private let inactiveResetThreshold: TimeInterval = 600 // 10 minutes
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bartViewModel)
                .onAppear {
                    _ = BARTComplicationController()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if let lastBackground = lastBackgroundTime,
                   Date().timeIntervalSince(lastBackground) >= inactiveResetThreshold {
                    bartViewModel.resetForFreshStart()
                }
                LocationManager.shared.startUpdatingLocation()
                LocationManager.shared.requestLocationOnce()
                bartViewModel.startPeriodicLocationChecks()
                if let location = LocationManager.shared.lastKnownLocation {
                    bartViewModel.handleLocationUpdate(location)
                }
                if !bartViewModel.arrivals.isEmpty {
                    bartViewModel.startAutoRefresh()
                }
                
            case .background:
                lastBackgroundTime = Date()
                bartViewModel.stopAutoRefresh()
                bartViewModel.stopPeriodicLocationChecks()
                LocationManager.shared.stopUpdatingLocation()
                
            case .inactive:
                break
                
            @unknown default:
                break
            }
        }
    }
}
