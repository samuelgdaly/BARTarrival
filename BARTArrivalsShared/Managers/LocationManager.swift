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
        guard locationManager.authorizationStatus != .notDetermined else {
            locationManager.requestWhenInUseAuthorization()
            print("BARTArrivals: Location requested (awaiting authorization)")
            return
        }
        print("BARTArrivals: Requesting location...")
        locationManager.requestLocation()
    }
    
    func startUpdatingLocation() {
        if !isUpdatingContinuously {
            isUpdatingContinuously = true
            locationManager.startUpdatingLocation()
            print("BARTArrivals: Location updates started")
        }
    }
    
    func stopUpdatingLocation() {
        if isUpdatingContinuously {
            isUpdatingContinuously = false
            locationManager.stopUpdatingLocation()
            print("BARTArrivals: Location updates stopped")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.lastKnownLocation = location
        }
        print("BARTArrivals: Location received (\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude)))")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("BARTArrivals: Location failed - \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            requestLocationOnce()
        }
    }
}
