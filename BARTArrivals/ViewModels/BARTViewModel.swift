import Foundation
import CoreLocation
import SwiftUI

class BARTViewModel: ObservableObject {
    @Published var nearestStation: BARTStation?
    @Published var arrivals: [Arrival] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userLocation: CLLocation?
    

    
    private var userSelectedStation: BARTStation?
    private var userSelectionTime: Date?
    private let userSelectionDuration: TimeInterval = 600 // 10 minute timeout
    private var refreshTimer: Timer?
    private var selectionTimeoutTimer: Timer?
    private var lastArrivalsHash: String = "" // For change detection
    private let apiKey: String = {
        Bundle.main.infoDictionary?["BART_API_KEY"] as? String ?? "MW9S-E7SL-26DU-VV8V"
    }()
    private var lastAPICall: Date?
    private let minimumAPIInterval: TimeInterval = 15 // Minimum 15 seconds between API calls
    
    // --- BART API Codable structs ---
    struct BARTETDResponse: Codable {
        let root: BARTETDRoot
    }
    struct BARTETDRoot: Codable {
        let station: [BARTETDStation]
    }
    struct BARTETDStation: Codable {
        let name: String
        let abbr: String
        let etd: [BARTETD]?
    }
    struct BARTETD: Codable {
        let destination: String
        let abbreviation: String?
        let limited: String?
        let estimate: [BARTETDEstimate]
    }
    struct BARTETDEstimate: Codable {
        let minutes: String
        let platform: String
        let direction: String
        let length: String
        let color: String
        let hexcolor: String
        let bikeflag: String
        let delay: String
    }
    // --- End BART API Codable structs ---
    
    init() {
        // Start periodic location checks when the view model is initialized
        startPeriodicLocationChecks()
    }
    
    func selectStation(_ station: BARTStation) {
        print("iOS: Manually selecting station: \(station.displayName)")
        DispatchQueue.main.async {
            self.nearestStation = station
            self.userSelectedStation = station
            self.userSelectionTime = Date()
            self.fetchArrivals(for: station, forceRefresh: true)
            
            // Start timeout timer
            self.selectionTimeoutTimer?.invalidate()
            self.selectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.userSelectionDuration, repeats: false) { [weak self] _ in
                self?.userSelectedStation = nil
                self?.userSelectionTime = nil
            }
        }
    }
    
    func findNearestStation(to userLocation: CLLocation) {
        self.userLocation = userLocation
        
        // Check if we're still in user selection mode
        if let userSelectionTime = userSelectionTime,
           let userSelectedStation = userSelectedStation,
           Date().timeIntervalSince(userSelectionTime) < userSelectionDuration {
            self.nearestStation = userSelectedStation
            fetchArrivals(for: userSelectedStation, forceRefresh: true)
            return
        } else {
            // Clear expired selection
            userSelectedStation = nil
            userSelectionTime = nil
            selectionTimeoutTimer?.invalidate()
        }
        
        // Find nearest station
        guard let station = BARTStation.allStations.min(by: {
            userLocation.distance(from: $0.location) < userLocation.distance(from: $1.location)
        }) else { return }
        
        let distance = Int(userLocation.distance(from: station.location))
        print("iOS: Closest station is \(station.displayName) (\(distance)m away)")
        
        // Only fetch arrivals if the station actually changed
        guard self.nearestStation?.code != station.code else { return }
        print("iOS: Station changed from \(self.nearestStation?.displayName ?? "none") to \(station.displayName)")
        self.nearestStation = station
        fetchArrivals(for: station)
    }
    
    func fetchArrivals(for station: BARTStation, forceRefresh: Bool = false) {
        // Rate limiting check - but allow forced refreshes for manual station selections
        if !forceRefresh, let lastCall = lastAPICall {
            let timeSinceLastCall = Date().timeIntervalSince(lastCall)
            if timeSinceLastCall < minimumAPIInterval {
                return
            }
        }
        
        // CRITICAL: Verify the station code being used in the API call
        let apiUrl = "https://api.bart.gov/api/etd.aspx?cmd=etd&orig=\(station.code)&key=\(apiKey)&json=y"
        
        guard let url = URL(string: apiUrl) else {
            print("❌ iOS: Invalid URL constructed")
            return
        }
        
        self.lastAPICall = Date()
        self.isLoading = true
        
        print("🚉 iOS: Fetching arrivals for \(station.displayName) (code: \(station.code))")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("❌ iOS: Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("❌ iOS: No data received")
                    return
                }
                
                print("📥 iOS: Received \(data.count) bytes from API")
                self.parseArrivalsData(data, for: station)
            }
        }.resume()
    }
    
    private func parseArrivalsData(_ data: Data, for station: BARTStation) {
        do {
            let decoder = JSONDecoder()
            let bartResponse = try decoder.decode(BARTETDResponse.self, from: data)
            
            guard let stationData = bartResponse.root.station.first else {
                print("❌ iOS: No station found in response")
                self.arrivals = []
                self.errorMessage = "No upcoming departures"
                return
            }
            
            // CRITICAL: Verify the returned station matches what we requested
            if stationData.abbr != station.code {
                print("🚨 iOS: CRITICAL ERROR: Station code mismatch!")
                print("  Requested departures for: \(station.displayName) (\(station.code))")
                print("  But API returned data for: \(stationData.name) (\(stationData.abbr))")
                return // Stop processing if there's a mismatch
            }
            
            guard let etds = stationData.etd else {
                print("❌ iOS: No ETD data found for station \(stationData.name)")
                self.arrivals = []
                self.errorMessage = "No upcoming departures"
                return
            }
            
            var newArrivals: [Arrival] = []
            for etd in etds {
                for estimate in etd.estimate {
                    // Convert minutes string to Int
                    let minutesInt: Int
                    if estimate.minutes == "Leaving" {
                        minutesInt = 0
                    } else {
                        minutesInt = Int(estimate.minutes) ?? 0
                    }
                    // Map color to line
                    let lineColor = estimate.color.uppercased()
                    let arrival = Arrival(
                        destination: etd.destination,
                        minutes: minutesInt,
                        direction: estimate.direction,
                        line: lineColor,
                        cars: Int(estimate.length) ?? 0,
                        platform: estimate.platform,
                        delayed: (Int(estimate.delay) ?? 0) > 0,
                        delayMinutes: (Int(estimate.delay) ?? 0) / 60
                    )
                    newArrivals.append(arrival)
                }
            }
            let sortedArrivals = newArrivals.sorted { $0.minutes < $1.minutes }
            
            // Create a hash of the arrivals to detect changes
            let arrivalsHash = sortedArrivals.map { "\($0.destination)-\($0.minutes)-\($0.line)" }.joined(separator: "|")
            
            // Only update the UI if there are actual changes
            if arrivalsHash != self.lastArrivalsHash {
                print("✅ iOS: Updated arrivals - \(sortedArrivals.count) arrivals with changes")
                self.arrivals = sortedArrivals
                self.lastArrivalsHash = arrivalsHash
            } else {
                print("ℹ️ iOS: No changes in arrivals data")
            }
            
            if self.arrivals.isEmpty {
                self.errorMessage = "No upcoming departures"
            } else {
                self.errorMessage = nil
                self.startAutoRefresh()
            }
        } catch {
            print("❌ iOS: Error parsing BART API JSON: \(error)")
            self.errorMessage = "Error parsing data"
            self.arrivals = []
        }
    }
    
    func startPeriodicLocationChecks() {
        // For iOS app, we check location periodically and also on significant location changes
        // This provides a good balance between responsiveness and battery life
        
        // If we already have a location, use it immediately
        if let location = self.userLocation {
            self.findNearestStation(to: location)
        }
        
        // Start a timer to check for location updates every 30 seconds
        // This ensures we don't miss location changes
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            if let location = self?.userLocation {
                self?.findNearestStation(to: location)
            }
        }
    }
    
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        print("iOS: Starting auto-refresh timer (60 second interval)")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self, let station = self.nearestStation else { 
                print("iOS: Auto-refresh skipped - no station available")
                return 
            }
            print("iOS: Auto-refresh: fetching arrivals for \(station.displayName)")
            self.fetchArrivals(for: station, forceRefresh: true)
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func minutesUntilArrival(timeString: String) -> Int {
                            let dateFormatter = ISO8601DateFormatter()
                            dateFormatter.formatOptions = [.withInternetDateTime]
                            
        guard let arrivalDate = dateFormatter.date(from: timeString) else {
            return 0
        }
        
        let timeInterval = arrivalDate.timeIntervalSince(Date())
        return max(0, Int(round(timeInterval / 60)))
    }
    
    deinit {
        selectionTimeoutTimer?.invalidate()
        refreshTimer?.invalidate()
    }
}
