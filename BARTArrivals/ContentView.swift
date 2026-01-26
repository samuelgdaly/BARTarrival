//
//  ContentView.swift
//  BARTArrivals
//
//  Created by Samuel Daly on 3/13/25.
//

import SwiftUI
import CoreLocation

// Basic ContentView structure to use our models
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
            print("ContentView appeared")
            LocationManager.shared.startUpdatingLocation()
        }
        .onDisappear {
            LocationManager.shared.stopUpdatingLocation()
            viewModel.stopAutoRefresh()
        }
        .onChange(of: locationManager.lastKnownLocation) { oldValue, newValue in
            if let location = newValue {
                print("Location updated in ContentView: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                viewModel.findNearestStation(to: location)
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
