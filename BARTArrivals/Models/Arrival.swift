import SwiftUI

// Arrival information structure
struct Arrival: Identifiable, Equatable {
    let id = UUID()
    let destination: String
    let minutes: Int
    let direction: String
    let line: String
    let cars: Int
    let platform: String
    let delayed: Bool
    let delayMinutes: Int
    
    var displayMinutes: String {
        minutes == 0 ? "Now" : "\(minutes)"
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
