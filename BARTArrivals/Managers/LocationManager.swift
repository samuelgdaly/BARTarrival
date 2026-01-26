import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocation?
    private var isUpdatingContinuously = false
    
    override private init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.locationManager.distanceFilter = 200 // Increased to 200 meters to reduce updates
    }
    
    func requestLocationOnce() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("iOS: Requesting one-time location update")
            locationManager.requestLocation()
        }
    }
    
    func startUpdatingLocation() {
        if !isUpdatingContinuously {
            isUpdatingContinuously = true
            print("iOS: Starting continuous location updates")
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdatingLocation() {
        if isUpdatingContinuously {
            isUpdatingContinuously = false
            print("iOS: Stopping continuous location updates")
            locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.lastKnownLocation = location
            print("iOS: Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ iOS: Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            requestLocationOnce()
        }
    }
}
