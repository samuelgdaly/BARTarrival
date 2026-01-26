import Foundation
import CoreLocation
import SwiftUI

// Simplified BARTViewModel for Watch App
class BARTViewModel: ObservableObject {
    @Published var nearestStation: BARTStation?
    @Published var arrivals: [Arrival] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userLocation: CLLocation?
    
    private var refreshTimer: Timer?
    private var lastArrivalsHash: String = "" // For change detection
    private var userSelectedStation: BARTStation?
    private var userSelectionTime: Date?
    private let userSelectionDuration: TimeInterval = 600 // 10 minute timeout
    private var selectionTimeoutTimer: Timer?
    private let apiKey: String = {
        // Try to get from configuration, fallback to hardcoded key
        if let configKey = Bundle.main.infoDictionary?["BART_API_KEY"] as? String, !configKey.isEmpty {
            return configKey
        }
        // Fallback to hardcoded key (should be moved to configuration in production)
        return "MW9S-E7SL-26DU-VV8V"
    }()
    private var lastAPICall: Date?
    private let minimumAPIInterval: TimeInterval = 15 // Minimum 15 seconds between API calls
    
    // NEW: Fast startup optimization
    private var hasInitialized = false
    private var lastKnownStationCode: String?
    
    // BART API Codable structs
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
    
    init() {
        // NEW: Try to restore from last known station immediately
        restoreLastKnownStation()
        
        // Start periodic location checks when the view model is initialized
        startPeriodicLocationChecks()
    }
    
    // NEW: Fast startup - restore last known station immediately
    private func restoreLastKnownStation() {
        if let lastStationCode = UserDefaults.standard.string(forKey: "WatchLastKnownStation"),
           let station = BARTStation.allStations.first(where: { $0.code == lastStationCode }) {
            print("🚀 Watch: Fast startup - restoring last known station: \(station.displayName)")
            self.nearestStation = station
            self.lastKnownStationCode = lastStationCode
            
            // Immediately fetch arrivals for this station
            fetchArrivals(for: station, forceRefresh: true)
        }
    }
    
    // NEW: Save current station for fast startup
    private func saveCurrentStation(_ station: BARTStation) {
        UserDefaults.standard.set(station.code, forKey: "WatchLastKnownStation")
        self.lastKnownStationCode = station.code
    }
    
    func findNearestStation(to userLocation: CLLocation) {
        self.userLocation = userLocation
        
        // Check if we're still in user selection mode
        if let userSelectionTime = userSelectionTime,
           let userSelectedStation = userSelectedStation {
            let timeElapsed = Date().timeIntervalSince(userSelectionTime)
            
            if timeElapsed < userSelectionDuration {
                self.nearestStation = userSelectedStation
                fetchArrivals(for: userSelectedStation, forceRefresh: true)
                return
            } else {
                self.userSelectedStation = nil
                self.userSelectionTime = nil
                self.selectionTimeoutTimer?.invalidate()
            }
        }
        
        // Find the closest station
        let stations = BARTStation.allStations
        var closestStation: BARTStation?
        var shortestDistance = Double.infinity
        
        for station in stations {
            let distance = userLocation.distance(from: station.location)
            if distance < shortestDistance {
                shortestDistance = distance
                closestStation = station
            }
        }
        
        if let station = closestStation {
            print("Watch: Finding nearest station to location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
            print("Watch: Closest station is \(station.displayName) (\(Int(shortestDistance))m away)")
            
            // Only fetch arrivals if the station actually changed
            if self.nearestStation?.code != station.code {
                print("Watch: Station changed from \(self.nearestStation?.displayName ?? "none") to \(station.displayName) - fetching arrivals")
                self.nearestStation = station
                
                // NEW: Save for fast startup
                saveCurrentStation(station)
                
                fetchArrivals(for: station, forceRefresh: true)
            }
        }
    }
    
    // NEW: Fast location-based station detection
    func fastLocationUpdate() {
        print("🚀 Watch: Fast location update requested")
        
        // If we have a recent location, use it immediately
        if let location = self.userLocation {
            print("🚀 Watch: Using cached location for immediate station detection")
            self.findNearestStation(to: location)
        } else {
            print("🚀 Watch: No cached location, checking LocationManager")
            // Try to get location immediately from LocationManager
            if let immediateLocation = LocationManager.shared.getLocationImmediately() {
                print("🚀 Watch: Got immediate location from LocationManager")
                self.userLocation = immediateLocation
                self.findNearestStation(to: immediateLocation)
            } else {
                print("🚀 Watch: No immediate location available, will wait for location update")
                // Don't request location here - let the app handle it
            }
        }
    }
    
    // NEW: Handle location updates from LocationManager
    func handleLocationUpdate(_ location: CLLocation) {
        print("🚀 Watch: Handling location update from LocationManager")
        self.userLocation = location
        self.findNearestStation(to: location)
    }
    
    func selectStation(_ station: BARTStation) {
        print("Watch: Manually selecting station: \(station.displayName)")
        DispatchQueue.main.async {
            self.nearestStation = station
            self.userSelectedStation = station
            self.userSelectionTime = Date()
            
            // NEW: Save for fast startup
            self.saveCurrentStation(station)
            
            self.fetchArrivals(for: station, forceRefresh: true)
            
            // Start timeout timer
            self.selectionTimeoutTimer?.invalidate()
            self.selectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.userSelectionDuration, repeats: false) { [weak self] _ in
                self?.userSelectedStation = nil
                self?.userSelectionTime = nil
            }
        }
    }
    
    func fetchArrivals(for station: BARTStation, forceRefresh: Bool = false) {
        // Rate limiting check - but allow forced refreshes for manual station selections
        if !forceRefresh, let lastCall = lastAPICall {
            let timeSinceLastCall = Date().timeIntervalSince(lastCall)
            if timeSinceLastCall < minimumAPIInterval {
                return
            }
        }
        
        // 🚀 NEW: Check for updated location before fetching arrivals
        // This ensures we're always showing departures for the nearest station
        print("🚀 Watch: Checking for updated location before fetching arrivals")
        checkForUpdatedLocation()
        
        // CRITICAL: Verify the station code being used in the API call
        let apiUrl = "https://api.bart.gov/api/etd.aspx?cmd=etd&orig=\(station.code)&key=\(apiKey)&json=y"
        
        guard let url = URL(string: apiUrl) else {
            print("❌ Watch: Invalid URL constructed")
            return
        }
        
        self.lastAPICall = Date()
        self.isLoading = true
        
        print("🚉 Watch: Fetching arrivals for \(station.displayName) (code: \(station.code))")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("❌ Watch: Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("❌ Watch: No data received")
                    return
                }
                
                print("📥 Watch: Received \(data.count) bytes from API")
                self.parseArrivalsData(data, for: station)
            }
        }.resume()
    }
    
    // 🚀 NEW: Check for updated location and update station if needed
    func checkForUpdatedLocation() {
        print("🚀 Watch: Checking for updated location")
        
        // Get current location from LocationManager
        if let currentLocation = LocationManager.shared.lastKnownLocation {
            // Check if location has changed significantly (more than 100 meters)
            if let lastLocation = self.userLocation {
                let distance = currentLocation.distance(from: lastLocation)
                if distance > 100 { // 100 meter threshold
                    print("🚀 Watch: Location changed significantly (\(Int(distance))m), updating station")
                    self.userLocation = currentLocation
                    self.findNearestStation(to: currentLocation)
                    return
                } else {
                    print("🚀 Watch: Location hasn't changed significantly (\(Int(distance))m), keeping current station")
                }
            } else {
                // First time getting location
                print("🚀 Watch: First location update, setting station")
                self.userLocation = currentLocation
                self.findNearestStation(to: currentLocation)
            }
        } else {
            print("🚀 Watch: No current location available")
        }
    }
    
    // 🚀 NEW: Force location check and station update
    func forceLocationCheck() {
        print("🚀 Watch: Force location check requested")
        
        // Request fresh location update
        LocationManager.shared.requestLocationOnce { [weak self] location in
            if let location = location {
                print("🚀 Watch: Got fresh location, updating station")
                self?.userLocation = location
                self?.findNearestStation(to: location)
            } else {
                print("🚀 Watch: Failed to get fresh location")
            }
        }
    }
    
    private func parseArrivalsData(_ data: Data, for station: BARTStation) {
        do {
            let decoder = JSONDecoder()
            let bartResponse = try decoder.decode(BARTETDResponse.self, from: data)
            guard let stationData = bartResponse.root.station.first else {
                print("❌ Watch: No station found in response")
                self.arrivals = []
                self.errorMessage = "No upcoming departures"
                return
            }
            
            // CRITICAL: Verify the returned station matches what we requested
            if stationData.abbr != station.code {
                print("🚨 Watch: WARNING: Requested station code '\(station.code)' but API returned data for '\(stationData.abbr)'!")
                self.errorMessage = "Data mismatch: Requested \(station.displayName), got \(stationData.name)"
                return // Stop processing if there's a mismatch
            }
            
            guard let etds = stationData.etd else {
                print("❌ Watch: No ETD data found for station")
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
                        line: lineColor
                    )
                    newArrivals.append(arrival)
                }
            }
            let sortedArrivals = newArrivals.sorted { $0.minutes < $1.minutes }
            
            // Create a hash of the arrivals to detect changes
            let arrivalsHash = sortedArrivals.map { "\($0.destination)-\($0.minutes)-\($0.line)" }.joined(separator: "|")
            
            // Only update the UI if there are actual changes
            if arrivalsHash != self.lastArrivalsHash {
                print("✅ Watch: Updated arrivals - \(sortedArrivals.count) arrivals with changes")
                self.arrivals = sortedArrivals
                self.lastArrivalsHash = arrivalsHash
            } else {
                print("ℹ️ Watch: No changes in arrivals data")
            }
            
            if self.arrivals.isEmpty {
                self.errorMessage = "No upcoming departures"
            } else {
                self.errorMessage = nil
                self.startAutoRefresh()
            }
        } catch {
            print("❌ Watch: Error parsing BART API JSON: \(error)")
            self.errorMessage = "Error parsing data"
            self.arrivals = []
        }
    }
    
    func startPeriodicLocationChecks() {
        // NEW: For Watch app, we check location immediately when app opens/becomes visible
        // This is more responsive and battery-friendly than continuous monitoring
        
        // If we already have a location, use it immediately
        if let location = self.userLocation {
            print("🚀 Watch: Using existing location for immediate station detection")
            self.findNearestStation(to: location)
        } else {
            // NEW: Check if LocationManager has a recent location
            if LocationManager.shared.hasRecentLocation() {
                print("🚀 Watch: LocationManager has recent location, using it")
                if let location = LocationManager.shared.lastKnownLocation {
                    self.userLocation = location
                    self.findNearestStation(to: location)
                }
            } else {
                // NEW: Only request location if we don't have any recent location
                print("🚀 Watch: No recent location available, will wait for app to request it")
                // Don't request location here - let the app handle it
            }
        }
    }
    
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        print("Watch: Starting auto-refresh timer (60 second interval)")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self, let station = self.nearestStation else { 
                print("Watch: Auto-refresh skipped - no station available")
                return 
            }
            print("Watch: Auto-refresh: fetching arrivals for \(station.displayName)")
            
            // 🚀 NEW: Check for location updates before auto-refresh
            self.checkForUpdatedLocation()
            
            // Fetch arrivals (this will also check location again, but that's fine)
            self.fetchArrivals(for: station, forceRefresh: false)
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        refreshTimer?.invalidate()
        selectionTimeoutTimer?.invalidate()
    }
}
