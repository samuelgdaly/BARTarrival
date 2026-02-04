//
//  BARTArrivalsApp.swift
//  BARTArrivals
//
//  Created by Samuel Daly on 3/13/25.
//

import SwiftUI

@main
struct BARTArrivalsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bartViewModel = BARTViewModel()
    @State private var lastBackgroundTime: Date?
    private let inactiveResetThreshold: TimeInterval = 600 // 10 minutes
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bartViewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // If app hasn't been used for 10+ minutes, reset and do fresh location check
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
