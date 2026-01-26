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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bartViewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                print("App became active - refreshing location")
                // Refresh location when app becomes active
                LocationManager.shared.requestLocationOnce()
                // If we already have a location, find the nearest station
                if let location = LocationManager.shared.lastKnownLocation {
                    bartViewModel.findNearestStation(to: location)
                }
            case .background:
                // Stop timers when entering background
                bartViewModel.stopAutoRefresh()
                LocationManager.shared.stopUpdatingLocation()
            case .inactive:
                // App is inactive
                break
            @unknown default:
                break
            }
        }
    }
}
