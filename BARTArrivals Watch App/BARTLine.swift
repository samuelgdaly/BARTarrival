import Foundation
import SwiftUI

// BART Line structure for Watch App - represents a line by its destination
struct BARTLine: Identifiable, Equatable, Codable {
    let id = UUID()
    let destination: String           // Final destination (e.g., "Millbrae", "SFO Airport")
    let abbreviation: String         // BART API abbreviation (e.g., "MLBR", "SFIA")
    let lineColor: String            // Hex color code from BART API
    let direction: String            // "North" or "South"
    let description: String          // User-friendly description
    
    // Computed property for SwiftUI Color
    var color: Color {
        return Color(hex: lineColor) ?? .gray
    }
    
    // User-friendly display name (customizable)
    var displayName: String {
        // Try to load custom name from JSON, fallback to destination
        if let customLine = BARTLine.loadCustomLines().first(where: { $0.abbreviation == abbreviation }) {
            return customLine.displayName
        }
        return destination
    }
    
    init(destination: String, abbreviation: String, lineColor: String, direction: String, description: String = "") {
        self.destination = destination
        self.abbreviation = abbreviation
        self.lineColor = lineColor
        self.direction = direction
        self.description = description
    }
    
    static func == (lhs: BARTLine, rhs: BARTLine) -> Bool {
        return lhs.abbreviation == rhs.abbreviation
    }
    
    // MARK: - JSON Loading for Custom Names
    
    static func loadCustomLines() -> [CustomLine] {
        guard let url = Bundle.main.url(forResource: "custom_lines", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ Watch: Failed to load custom_lines.json")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let customResponse = try decoder.decode(CustomLinesResponse.self, from: data)
            print("✅ Watch: Loaded \(customResponse.lines.count) custom line names from JSON")
            return customResponse.lines
        } catch {
            print("❌ Watch: Failed to decode custom_lines.json: \(error)")
            return []
        }
    }
    
    // Helper method to find line by abbreviation
    static func findLine(by abbreviation: String) -> BARTLine? {
        return BARTLine.allLines.first { $0.abbreviation.uppercased() == abbreviation.uppercased() }
    }
    
    // MARK: - Static Line Definitions
    
    static var allLines: [BARTLine] {
        return [
            // Northbound lines
            BARTLine(destination: "Richmond", abbreviation: "RICH", lineColor: "#ff0000", direction: "North", description: "Richmond to Daly City via Oakland"),
            BARTLine(destination: "Antioch", abbreviation: "ANTC", lineColor: "#ffff33", direction: "North", description: "Antioch to SFO Airport via San Francisco"),
            BARTLine(destination: "Dublin/Pleasanton", abbreviation: "DUBL", lineColor: "#0099cc", direction: "North", description: "Dublin/Pleasanton to Daly City via Oakland"),
            BARTLine(destination: "Pittsburg/Bay Point", abbreviation: "PITT", lineColor: "#ffff33", direction: "North", description: "Pittsburg/Bay Point to SFO Airport via San Francisco"),
            BARTLine(destination: "Berryessa", abbreviation: "BERY", lineColor: "#339933", direction: "North", description: "Berryessa to Dublin/Pleasanton via Oakland"),
            
            // Southbound lines
            BARTLine(destination: "Millbrae", abbreviation: "MLBR", lineColor: "#ff0000", direction: "South", description: "Millbrae to Richmond via San Francisco"),
            BARTLine(destination: "SFO Airport", abbreviation: "SFIA", lineColor: "#ffff33", direction: "South", description: "SFO Airport to Antioch via San Francisco"),
            BARTLine(destination: "Daly City", abbreviation: "DALY", lineColor: "#339933", direction: "South", description: "Daly City to Dublin/Pleasanton via Oakland"),
            BARTLine(destination: "Fremont", abbreviation: "FRMT", lineColor: "#0099cc", direction: "South", description: "Fremont to Dublin/Pleasanton via Oakland"),
            BARTLine(destination: "Warm Springs", abbreviation: "WARM", lineColor: "#339933", direction: "South", description: "Warm Springs to Berryessa via Oakland")
        ]
    }
}

// MARK: - Custom Line Names (User Editable)
struct CustomLine: Codable {
    let abbreviation: String     // BART API abbreviation (e.g., "MLBR")
    let displayName: String     // Your custom name (e.g., "My Commute Route")
    let description: String     // Optional custom description
}

struct CustomLinesResponse: Codable {
    let lines: [CustomLine]
}

// MARK: - Color Extension for Hex Support
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

