import Foundation
import CoreLocation

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
        return lhs.code == rhs.code
    }
    
    // MARK: - JSON Loading
    
    static func loadStations() -> [BARTStation] {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ Failed to load stations.json")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let stationsData = try decoder.decode(StationsResponse.self, from: data)
            print("✅ Loaded \(stationsData.stations.count) stations from JSON")
            return stationsData.stations
        } catch {
            print("❌ Failed to decode stations.json: \(error)")
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
