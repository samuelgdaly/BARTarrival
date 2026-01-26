import Foundation
import SwiftUI

// BART Line structure - represents a line by its destination
struct BARTLine: Identifiable, Equatable, Codable {
    let id = UUID()
    let destination: String
    let abbreviation: String
    let lineColor: String
    let direction: String
    let description: String
    let displayName: String
    
    // Exclude id from Codable since it's auto-generated
    enum CodingKeys: String, CodingKey {
        case destination, abbreviation, lineColor, direction, description, displayName
    }
    
    var color: Color {
        Color(hex: lineColor) ?? .gray
    }
    
    init(destination: String, abbreviation: String, lineColor: String, direction: String, description: String = "", displayName: String? = nil) {
        self.destination = destination
        self.abbreviation = abbreviation
        self.lineColor = lineColor
        self.direction = direction
        self.description = description
        self.displayName = displayName ?? destination
    }
    
    static func == (lhs: BARTLine, rhs: BARTLine) -> Bool {
        lhs.abbreviation == rhs.abbreviation
    }
    
    // MARK: - JSON Loading
    
    static func loadLines() -> [BARTLine] {
        guard let url = Bundle.main.url(forResource: "lines", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ Failed to load lines.json")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let linesResponse = try decoder.decode(LinesResponse.self, from: data)
            print("✅ Loaded \(linesResponse.lines.count) lines from JSON")
            return linesResponse.lines
        } catch {
            print("❌ Failed to decode lines.json: \(error)")
            return []
        }
    }
    
    private static var _cachedLines: [BARTLine]?
    
    static var allLines: [BARTLine] {
        if let cached = _cachedLines {
            return cached
        }
        let lines = loadLines()
        _cachedLines = lines
        return lines
    }
    
    static func findLine(by abbreviation: String) -> BARTLine? {
        allLines.first { $0.abbreviation.uppercased() == abbreviation.uppercased() }
    }
}

// MARK: - JSON Response Models
struct LinesResponse: Codable {
    let lines: [BARTLine]
}
