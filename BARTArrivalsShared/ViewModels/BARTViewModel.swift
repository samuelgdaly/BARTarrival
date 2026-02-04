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
    private let userSelectionDuration: TimeInterval = 600 // 10 minutes
    private var refreshTimer: Timer?
    private var selectionTimeoutTimer: Timer?
    private var lastArrivalsHash: String = ""
    private let locationCheckInterval: TimeInterval = 30 // seconds - check location often
    private let apiRefreshInterval: TimeInterval = 60 // seconds - API only every 60s (except manual/station change)
    private let apiKey: String = {
        Bundle.main.infoDictionary?["BART_API_KEY"] as? String ?? "MW9S-E7SL-26DU-VV8V"
    }()
    private var lastAPICall: Date?
    private var lastLocationUpdateTime: Date?
    private let locationUpdateThrottle: TimeInterval = 2.0 // seconds
    
    init() {
        // Location checks and timers are started when app becomes active
    }
    
    /// Call when app hasn't been used for 10+ minutes - reset to fresh location check
    func resetForFreshStart() {
        DispatchQueue.main.async {
            self.userSelectedStation = nil
            self.userSelectionTime = nil
            self.selectionTimeoutTimer?.invalidate()
            self.nearestStation = nil
            self.arrivals = []
            self.errorMessage = nil
        }
    }
    
    func selectStation(_ station: BARTStation) {
        DispatchQueue.main.async {
            self.nearestStation = station
            self.userSelectedStation = station
            self.userSelectionTime = Date()
            self.fetchArrivals(for: station, forceRefresh: true)
            
            // Start 10-minute timer - manual selection stays until this fires
            self.selectionTimeoutTimer?.invalidate()
            self.selectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.userSelectionDuration, repeats: false) { [weak self] _ in
                self?.userSelectedStation = nil
                self?.userSelectionTime = nil
                print("BARTArrivals: Manual selection expired, reverting to location-based")
            }
            print("BARTArrivals: Manual selection set to \(station.displayName) (10 min)")
        }
    }
    
    /// Process location update with throttling. Used by Watch app's onChange(of: lastKnownLocation).
    func handleLocationUpdate(_ location: CLLocation) {
        findNearestStation(to: location)
    }
    
    func findNearestStation(to userLocation: CLLocation) {
        self.userLocation = userLocation
        
        // Manual selection takes precedence - never override for full 10 min window
        if let userSelectionTime = userSelectionTime,
           let userSelectedStation = userSelectedStation,
           Date().timeIntervalSince(userSelectionTime) < userSelectionDuration {
            self.nearestStation = userSelectedStation
            if shouldRefreshArrivals() {
                fetchArrivals(for: userSelectedStation, forceRefresh: false)
            }
            return
        }
        
        // Selection expired or none - clear and use location
        self.userSelectedStation = nil
        self.userSelectionTime = nil
        selectionTimeoutTimer?.invalidate()
        
        // Throttle location-based updates
        if let lastUpdate = lastLocationUpdateTime,
           Date().timeIntervalSince(lastUpdate) < locationUpdateThrottle {
            return
        }
        lastLocationUpdateTime = Date()
        
        // Find nearest station by location
        guard let station = BARTStation.allStations.min(by: {
            userLocation.distance(from: $0.location) < userLocation.distance(from: $1.location)
        }) else { return }
        
        let stationChanged = self.nearestStation?.code != station.code
        self.nearestStation = station
        
        if stationChanged {
            print("BARTArrivals: Nearest station changed to \(station.displayName)")
            fetchArrivals(for: station, forceRefresh: true)
        } else if shouldRefreshArrivals() {
            print("BARTArrivals: Refreshing arrivals for \(station.displayName)")
            fetchArrivals(for: station, forceRefresh: false)
        }
    }
    
    private func shouldRefreshArrivals() -> Bool {
        guard let lastCall = lastAPICall else { return true }
        return Date().timeIntervalSince(lastCall) >= apiRefreshInterval
    }
    
    func fetchArrivals(for station: BARTStation, forceRefresh: Bool = false) {
        if !forceRefresh, !shouldRefreshArrivals() { return }
        
        // CRITICAL: Verify the station code being used in the API call
        let apiUrl = "https://api.bart.gov/api/etd.aspx?cmd=etd&orig=\(station.code)&key=\(apiKey)&json=y"
        
        guard let url = URL(string: apiUrl) else { return }
        
        self.lastAPICall = Date()
        self.isLoading = true
        print("BARTArrivals: Fetching arrivals for \(station.displayName)...")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("BARTArrivals: API failed - \(error.localizedDescription)")
                    self.errorMessage = "Network error"
                    return
                }
                
                guard let data = data else {
                    print("BARTArrivals: API failed - no data received")
                    self.errorMessage = "No data received"
                    return
                }
                self.parseArrivalsData(data, for: station)
            }
        }.resume()
    }
    
    private func parseArrivalsData(_ data: Data, for station: BARTStation) {
        do {
            let decoder = JSONDecoder()
            let bartResponse = try decoder.decode(BARTETDResponse.self, from: data)
            
            guard let stationData = bartResponse.root.station.first else {
                self.arrivals = []
                self.errorMessage = "No upcoming departures"
                return
            }
            
            // CRITICAL: Verify the returned station matches what we requested
            if stationData.abbr != station.code { return }
            
            guard let etds = stationData.etd else {
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
            
            if arrivalsHash != self.lastArrivalsHash {
                self.arrivals = sortedArrivals
                self.lastArrivalsHash = arrivalsHash
            }
            
            if self.arrivals.isEmpty {
                print("BARTArrivals: API OK for \(station.displayName) - no upcoming departures")
                self.errorMessage = "No upcoming departures"
            } else {
                print("BARTArrivals: API OK for \(station.displayName) - \(sortedArrivals.count) arrivals")
                self.errorMessage = nil
            }
        } catch {
            print("BARTArrivals: API parse error - \(error.localizedDescription)")
            self.errorMessage = "Error parsing data"
            self.arrivals = []
        }
    }
    
    func startPeriodicLocationChecks() {
        guard refreshTimer == nil else { return }
        
        // Single timer: check location every 30s, API every 60s (except station change / manual)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: locationCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let location = LocationManager.shared.lastKnownLocation {
                self.findNearestStation(to: location)
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }
    
    func stopPeriodicLocationChecks() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func startAutoRefresh() {
        startPeriodicLocationChecks()
    }
    
    func stopAutoRefresh() {
        stopPeriodicLocationChecks()
    }
    
    deinit {
        selectionTimeoutTimer?.invalidate()
        refreshTimer?.invalidate()
    }
}
