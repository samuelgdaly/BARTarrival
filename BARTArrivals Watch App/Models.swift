import Foundation
import CoreLocation
import SwiftUI

// NOTE: BARTStation, Arrival, BARTLine, BARTAPIResponse, and Color+Hex are now in separate files
// This file only contains LocationManager for Watch App

// Simplified LocationManager for Watch App
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocation?
    private var isUpdatingContinuously = false
    
    private var locationRequestCompletion: ((CLLocation?) -> Void)?
    private var isRequestingLocation = false
    private var pendingCompletions: [(CLLocation?) -> Void] = []
    
    override private init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = 50 // meters
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
