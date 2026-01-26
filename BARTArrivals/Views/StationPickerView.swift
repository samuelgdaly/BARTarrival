import SwiftUI
import CoreLocation

// Separate view for station picker
struct StationPickerView: View {
    @EnvironmentObject var viewModel: BARTViewModel
    @Binding var showingStationPicker: Bool
    @State private var searchText = ""
    
    var filteredStations: [BARTStation] {
        guard !searchText.isEmpty else { return BARTStation.allStations }
        let searchLower = searchText.lowercased()
        return BARTStation.allStations.filter { $0.displayName.lowercased().contains(searchLower) }
    }
    
    var sortedStations: [BARTStation] {
        guard let userLocation = viewModel.userLocation else {
            return filteredStations.sorted { $0.displayName < $1.displayName }
        }
        return filteredStations.sorted {
            userLocation.distance(from: $0.location) < userLocation.distance(from: $1.location)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search Stations", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                List {
                    ForEach(sortedStations, id: \.id) { station in
                        Button(action: {
                            viewModel.selectStation(station)
                            showingStationPicker = false
                        }) {
                HStack {
                                Text(station.displayName)
                                    .foregroundColor(.primary)
            
                                Spacer()
            
                                if let userLocation = viewModel.userLocation {
                                    let distance = userLocation.distance(from: station.location) / 1609.34
                                    Text(String(format: "%.1f mi", distance))
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Change Station")
            .navigationBarItems(trailing: Button("Done") {
                showingStationPicker = false
            })
        }
    }
}
