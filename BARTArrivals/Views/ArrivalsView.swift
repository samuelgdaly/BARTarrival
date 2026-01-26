import SwiftUI

// View for displaying arrivals at a station
struct ArrivalsView: View {
    @EnvironmentObject var viewModel: BARTViewModel
    @State private var showingStationPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Station header with station name and change button
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(viewModel.nearestStation?.displayName ?? "Finding Nearest Station...")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer()
                    
                    Button(action: {
                        showingStationPicker = true
                    }) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
                

            }
            .padding(.top, 44)
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
            .background(Color.white)
            
            // Main content - scrollable list of arrivals
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.gray)
                            .padding()
                    } else if viewModel.arrivals.isEmpty {
                        Text("No arrivals found for this station.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        destinationListView
                    }
                }
            }
        }
        .sheet(isPresented: $showingStationPicker) {
            StationPickerView(showingStationPicker: $showingStationPicker)
        }
    }
    
    var destinationListView: some View {
        VStack(spacing: 0) {
            let groupedArrivals = Dictionary(grouping: viewModel.arrivals) { "\($0.destination)|\($0.line)" }
            
            let sortedKeys = groupedArrivals.keys.sorted { key1, key2 in
                let time1 = groupedArrivals[key1]?.min(by: { $0.minutes < $1.minutes })?.minutes ?? Int.max
                let time2 = groupedArrivals[key2]?.min(by: { $0.minutes < $1.minutes })?.minutes ?? Int.max
                return time1 < time2
            }
            
            ForEach(sortedKeys, id: \.self) { key in
                if let arrivals = groupedArrivals[key],
                   let firstArrival = arrivals.first {
                    // Inline destination row
                    HStack(alignment: .center, spacing: 0) {
                        // Left color bar
                        Rectangle()
                            .fill(firstArrival.lineColor)
                            .frame(width: 8)
                            .frame(maxHeight: .infinity)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Destination name
                            Text(firstArrival.destination)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                            
                            // Arrival times
                            Text(formattedTimes(for: arrivals))
                                .font(.system(size: 17))
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .padding(.vertical, 12)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    
                    if key != sortedKeys.last {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }
    
    private func formattedTimes(for arrivals: [Arrival]) -> String {
        let times = arrivals
            .sorted { $0.minutes < $1.minutes }
            .map { $0.minutes == 0 ? "Now" : "\($0.minutes)" }
        return times.joined(separator: ", ") + " mins"
    }
}
