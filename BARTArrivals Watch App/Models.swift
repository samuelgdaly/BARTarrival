import Foundation
import CoreLocation
import SwiftUI

// BART Station structure
struct BARTStation: Identifiable, Equatable, Codable {
    let id = UUID()
    let apiName: String      // Name from BART API (for verification)
    let displayName: String  // User-friendly name for display
    let code: String
    let latitude: Double
    let longitude: Double
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    init(apiName: String, displayName: String, code: String, latitude: Double, longitude: Double) {
        self.apiName = apiName
        self.displayName = displayName
        self.code = code
        self.latitude = latitude
        self.longitude = longitude
    }
    
    static func == (lhs: BARTStation, rhs: BARTStation) -> Bool {
        lhs.code == rhs.code
    }
    
    // MARK: - JSON Loading
    
    static func loadStations() -> [BARTStation] {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ Watch: Failed to load stations.json")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let stationsData = try decoder.decode(StationsResponse.self, from: data)
            print("✅ Watch: Loaded \(stationsData.stations.count) stations from JSON")
            return stationsData.stations
        } catch {
            print("❌ Watch: Failed to decode stations.json: \(error)")
            return []
        }
    }
    
    static var allStations: [BARTStation] {
        loadStations()
    }
}

// MARK: - JSON Response Models
struct StationsResponse: Codable {
    let stations: [BARTStation]
}

// Simplified Arrival structure for Watch App
struct Arrival: Identifiable, Equatable {
    let id = UUID()
    let destination: String
    let minutes: Int
    let direction: String
    let line: String
    
    var timeDisplay: String {
        minutes == 0 ? "Now" : "\(minutes) min"
    }
    
    var lineColor: Color {
        BARTLine.findLine(by: line)?.color ?? fallbackColor
    }
    
    private var fallbackColor: Color {
        switch line.uppercased() {
        case "RED": return .red
        case "YELLOW": return .yellow
        case "BLUE": return .blue
        case "GREEN": return .green
        case "ORANGE": return .orange
        default: return .gray
        }
    }
    
    var lineDisplayName: String {
        BARTLine.findLine(by: line)?.displayName ?? line
    }
    
    static func == (lhs: Arrival, rhs: Arrival) -> Bool {
        lhs.id == rhs.id
    }
}

// Simplified LocationManager for Watch App
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocation?
    private var isUpdatingContinuously = false
    
    // 🚀 NEW: Fast location optimization
    private var locationRequestCompletion: ((CLLocation?) -> Void)?
    private var isRequestingLocation = false
    private var pendingCompletions: [(CLLocation?) -> Void] = []
    
    override private init() {
        super.init()
        self.locationManager.delegate = self
        // 🚀 NEW: Use best accuracy for immediate location
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // 🚀 NEW: Reduce distance filter for more responsive updates
        self.locationManager.distanceFilter = 50 // 50 meters instead of default
        // 🚀 NEW: Request authorization immediately
        self.locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocationOnce(completion: ((CLLocation?) -> Void)? = nil) {
        // Return cached location if recent (< 30 seconds)
        if let cachedLocation = lastKnownLocation,
           Date().timeIntervalSince(cachedLocation.timestamp) < 30 {
            print("🚀 Watch: Using recent cached location")
            completion?(cachedLocation)
            return
        }
        
        // Queue completion if request already in progress
        if isRequestingLocation {
            if let completion = completion {
                pendingCompletions.append(completion)
            }
            return
        }
        
        print("🚀 Watch: Requesting immediate location update")
        isRequestingLocation = true
        if let completion = completion {
            pendingCompletions.append(completion)
        }
        
        locationManager.requestLocation()
        locationManager.startUpdatingLocation()
        
        // Stop continuous updates after 3 seconds to save battery
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.locationManager.stopUpdatingLocation()
        }
    }
    
    func startUpdatingLocation() {
        if !isUpdatingContinuously {
            isUpdatingContinuously = true
            print("Watch: Starting continuous location updates")
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdatingLocation() {
        if isUpdatingContinuously {
            isUpdatingContinuously = false
            print("Watch: Stopping continuous location updates")
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.lastKnownLocation = location
            print("🚀 Watch: Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Complete any pending location requests
            if self.isRequestingLocation {
                self.isRequestingLocation = false
                self.pendingCompletions.forEach { $0(location) }
                self.pendingCompletions.removeAll()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Watch: Location error: \(error.localizedDescription)")
        
        // Complete pending requests with error
        if isRequestingLocation {
            isRequestingLocation = false
            pendingCompletions.forEach { $0(nil) }
            pendingCompletions.removeAll()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            print("🚀 Watch: Location authorized, requesting immediate update")
            requestLocationOnce()
        }
    }
    
    // MARK: - Enhanced Location Monitoring
    
    func startEnhancedLocationMonitoring() {
        // Start continuous updates for more responsive location changes
        startUpdatingLocation()
        
        // Also request a fresh location immediately
        requestLocationOnce()
    }
    
    func stopEnhancedLocationMonitoring() {
        stopUpdatingLocation()
    }
    
    func getLocationImmediately() -> CLLocation? {
        guard let cachedLocation = lastKnownLocation,
              Date().timeIntervalSince(cachedLocation.timestamp) < 60 else {
            return nil
        }
        return cachedLocation
    }
    
    func hasRecentLocation() -> Bool {
        guard let location = lastKnownLocation else { return false }
        return Date().timeIntervalSince(location.timestamp) < 60
    }
}
