//
//  ContentView.swift
//  BARTArrivals Watch App
//
//  Created by Samuel Daly on 3/13/25.
//

import SwiftUI
import CoreLocation

// Simple Watch App ContentView that uses shared models
struct ContentView: View {
    @EnvironmentObject var viewModel: BARTViewModel
    @StateObject private var locationManager = LocationManager.shared
    @State private var showingStationPicker = false
    
    var body: some View {
        NavigationView {
        ScrollView {
                VStack(spacing: 12) {
                    // Station name - BIG and LEFT-justified
                    HStack {
                        Text(viewModel.nearestStation?.displayName ?? "Finding Station...")
                            .font(.system(size: 20, weight: .bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    
                    // Arrivals display
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    } else if viewModel.arrivals.isEmpty {
                        Text("No arrivals")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        } else {
                        arrivalsView
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingStationPicker) {
            StationPickerView()
        }
        .onAppear {
            LocationManager.shared.startUpdatingLocation()
        }
        .onDisappear {
            LocationManager.shared.stopUpdatingLocation()
            viewModel.stopAutoRefresh()
        }
        .onChange(of: locationManager.lastKnownLocation) { location in
            guard let location = location else { return }
            
            // Let handleLocationUpdate do the station finding - it has throttling
            viewModel.handleLocationUpdate(location)
        }
        .environmentObject(viewModel)
    }
    
    var arrivalsView: some View {
        VStack(spacing: 8) {
            let groupedArrivals = Dictionary(grouping: viewModel.arrivals) { "\($0.destination)|\($0.line)" }
            
            let sortedKeys = groupedArrivals.keys.sorted { key1, key2 in
                let time1 = groupedArrivals[key1]?.min(by: { $0.minutes < $1.minutes })?.minutes ?? Int.max
                let time2 = groupedArrivals[key2]?.min(by: { $0.minutes < $1.minutes })?.minutes ?? Int.max
                return time1 < time2
            }
            
            ForEach(Array(sortedKeys), id: \.self) { key in
                if let arrivals = groupedArrivals[key],
                   let firstArrival = arrivals.first {
                    WatchArrivalRow(
                        destination: firstArrival.destination,
                        lineColor: firstArrival.lineColor,
                        arrivals: arrivals
                    )
                }
            }
            
            // Change Station Button
            Button(action: {
                showingStationPicker = true
            }) {
                HStack {
                    Image(systemName: "location.circle")
                        .font(.system(size: 14))
                    Text("Change Station")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// Simple arrival row for the watch
struct WatchArrivalRow: View {
    let destination: String
    let lineColor: Color
    let arrivals: [Arrival]
    
    var body: some View {
        HStack(spacing: 8) {
            // Color indicator
            Rectangle()
                .fill(lineColor)
                .frame(width: 4, height: 24)
                .cornerRadius(2)
            
            // Destination and times
            VStack(alignment: .leading, spacing: 4) {
                Text(destination)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                Text(formattedTimes)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    var formattedTimes: String {
        let times = arrivals
            .sorted { $0.minutes < $1.minutes }
            .map { $0.minutes == 0 ? "Now" : "\($0.minutes)" }
        return times.joined(separator: ", ") + " min"
    }
}

// Station Picker View for Watch App
struct StationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject private var viewModel: BARTViewModel
    
    var body: some View {
        NavigationView {
                List {
                ForEach(sortedStations, id: \.id) { station in
                        Button(action: {
                        // Select the station
                        viewModel.selectStation(station)
                            dismiss()
                        }) {
                            HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(station.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if let location = locationManager.lastKnownLocation {
                                    let distance = location.distance(from: station.location)
                                    Text(formatDistance(distance))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var sortedStations: [BARTStation] {
        guard let location = locationManager.lastKnownLocation else {
            return BARTStation.allStations
        }
        return BARTStation.allStations.sorted {
            location.distance(from: $0.location) < location.distance(from: $1.location)
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        guard distance >= 1000 else {
            return "\(Int(distance))m away"
        }
        return String(format: "%.1f mi away", distance / 1609.34)
    }
}

#Preview {
    ContentView()
}
