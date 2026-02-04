//
//  ContentView.swift
//  BARTArrivals
//
//  Created by Samuel Daly on 3/13/25.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var viewModel = BARTViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Next Train Tab
            NavigationView {
                ArrivalsView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Next Train", systemImage: "location.fill")
            }
            .tag(0)
            
            // System Map Tab
            NavigationView {
                SystemView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("System Map", systemImage: "map")
            }
            .tag(1)
        }
        .onAppear {
            LocationManager.shared.startUpdatingLocation()
            LocationManager.shared.requestLocationOnce()
            viewModel.startPeriodicLocationChecks()
        }
        .onDisappear {
            LocationManager.shared.stopUpdatingLocation()
            viewModel.stopAutoRefresh()
            viewModel.stopPeriodicLocationChecks()
        }
        .onChange(of: locationManager.lastKnownLocation) { _, newValue in
            if let location = newValue {
                viewModel.handleLocationUpdate(location)
            }
        }
        .environmentObject(viewModel)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
