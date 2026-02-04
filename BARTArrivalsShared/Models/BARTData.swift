import Foundation
import CoreLocation
import SwiftUI

// MARK: - BART Station (from Resources/stations.json)
// Edit displayName in JSON to customize how stations appear (e.g., "12th St. Oakland" vs API's "12th St. Oakland City Center")
struct BARTStation: Identifiable, Equatable, Codable {
    let id = UUID()
    let apiName: String
    let displayName: String
    let code: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case apiName, displayName, code, latitude, longitude
    }

    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    static var allStations: [BARTStation] {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let response = try? JSONDecoder().decode(StationsResponse.self, from: data) else {
            return []
        }
        return response.stations
    }
}

// MARK: - BART Line (from Resources/lines.json)
// Edit displayName in JSON to customize line labels (e.g., "SFO Airport" vs "Millbrae")
struct BARTLine: Identifiable, Equatable, Codable {
    let id = UUID()
    let destination: String
    let abbreviation: String
    let lineColor: String
    let direction: String
    let description: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case destination, abbreviation, lineColor, direction, description, displayName
    }

    var color: Color { Color(hex: lineColor) ?? .gray }

    static var allLines: [BARTLine] {
        guard let url = Bundle.main.url(forResource: "lines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let response = try? JSONDecoder().decode(LinesResponse.self, from: data) else {
            return []
        }
        return response.lines
    }

    static func findLine(by abbreviation: String) -> BARTLine? {
        allLines.first { $0.abbreviation.uppercased() == abbreviation.uppercased() }
    }
}

// MARK: - JSON Response Wrappers
private struct StationsResponse: Codable { let stations: [BARTStation] }
private struct LinesResponse: Codable { let lines: [BARTLine] }
