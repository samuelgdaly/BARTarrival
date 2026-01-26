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
    
    // Exclude id from Codable since it's auto-generated
    enum CodingKeys: String, CodingKey {
        case apiName, displayName, code, latitude, longitude
    }
    
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
    
    private static var _cachedStations: [BARTStation]?
    
    static var allStations: [BARTStation] {
        if let cached = _cachedStations {
            return cached
        }
        let stations = loadStations()
        _cachedStations = stations
        return stations
    }
}

// MARK: - JSON Response Models
struct StationsResponse: Codable {
    let stations: [BARTStation]
}
