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
    private let userSelectionDuration: TimeInterval = 600 // 10 minutes
    private var selectionTimeoutTimer: Timer?
    private let apiKey: String = {
        Bundle.main.infoDictionary?["BART_API_KEY"] as? String ?? "MW9S-E7SL-26DU-VV8V"
    }()
    private var lastAPICall: Date?
    private let minimumAPIInterval: TimeInterval = 15 // seconds
    private let autoRefreshInterval: TimeInterval = 60 // seconds
    
    private var hasInitialized = false
    private var lastKnownStationCode: String?
    private var hasRestoredStation = false
    
    init() {
        restoreLastKnownStation()
        startPeriodicLocationChecks()
    }
    
    private func restoreLastKnownStation() {
        guard !hasRestoredStation else { return }
        hasRestoredStation = true
        
        if let lastStationCode = UserDefaults.standard.string(forKey: "WatchLastKnownStation"),
           let station = BARTStation.allStations.first(where: { $0.code == lastStationCode }) {
            print("🚀 Watch: Fast startup - restoring last known station: \(station.displayName)")
            self.nearestStation = station
            self.lastKnownStationCode = lastStationCode
            
            // Immediately fetch arrivals for this station
            fetchArrivals(for: station, forceRefresh: true)
        }
    }
    
    private func saveCurrentStation(_ station: BARTStation) {
        UserDefaults.standard.set(station.code, forKey: "WatchLastKnownStation")
        self.lastKnownStationCode = station.code
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
        print("Watch: Closest station is \(station.displayName) (\(distance)m away)")
        
        // Only fetch arrivals if the station actually changed
        guard self.nearestStation?.code != station.code else { return }
        print("Watch: Station changed from \(self.nearestStation?.displayName ?? "none") to \(station.displayName)")
        self.nearestStation = station
        saveCurrentStation(station)
        fetchArrivals(for: station, forceRefresh: true)
    }
    
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
    
    private var lastLocationUpdateTime: Date?
    private let locationUpdateThrottle: TimeInterval = 2.0 // seconds
    
    func handleLocationUpdate(_ location: CLLocation) {
        // Throttle location updates to prevent excessive processing
        if let lastUpdate = lastLocationUpdateTime,
           Date().timeIntervalSince(lastUpdate) < locationUpdateThrottle {
            return
        }
        lastLocationUpdateTime = Date()
        
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
    
    private var lastLocationCheckTime: Date?
    private let locationCheckThrottle: TimeInterval = 5.0 // seconds
    
    func checkForUpdatedLocation() {
        // Throttle location checks to prevent excessive calls
        if let lastCheck = lastLocationCheckTime,
           Date().timeIntervalSince(lastCheck) < locationCheckThrottle {
            return
        }
        lastLocationCheckTime = Date()
        
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
            
            let newArrivals = etds.flatMap { etd in
                etd.estimate.map { estimate in
                    let minutesInt = estimate.minutes == "Leaving" ? 0 : (Int(estimate.minutes) ?? 0)
                    return Arrival(
                        destination: etd.destination,
                        minutes: minutesInt,
                        direction: estimate.direction,
                        line: estimate.color.uppercased(),
                        cars: Int(estimate.length) ?? 0,
                        platform: estimate.platform,
                        delayed: (Int(estimate.delay) ?? 0) > 0,
                        delayMinutes: (Int(estimate.delay) ?? 0) / 60
                    )
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
                // Only start auto-refresh if we have arrivals and timer isn't running
                if refreshTimer == nil {
                    self.startAutoRefresh()
                }
            }
        } catch {
            print("❌ Watch: Error parsing BART API JSON: \(error)")
            self.errorMessage = "Error parsing data"
            self.arrivals = []
        }
    }
    
    func startPeriodicLocationChecks() {
        if let location = self.userLocation {
            self.findNearestStation(to: location)
        } else if LocationManager.shared.hasRecentLocation(),
                  let location = LocationManager.shared.lastKnownLocation {
            self.userLocation = location
            self.findNearestStation(to: location)
        }
    }
    
    func startAutoRefresh() {
        // Prevent starting multiple timers
        guard refreshTimer == nil else { return }
        
        print("Watch: Starting auto-refresh timer (\(Int(autoRefreshInterval)) second interval)")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self, let station = self.nearestStation else { 
                print("Watch: Auto-refresh skipped - no station available")
                return 
            }
            print("Watch: Auto-refresh: fetching arrivals for \(station.displayName)")
            
            // Check for location updates before auto-refresh
            self.checkForUpdatedLocation()
            
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
