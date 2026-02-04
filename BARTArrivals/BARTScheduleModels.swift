//
//  BARTScheduleModels.swift
//  BARTArrivals
//
//  Created by Samuel Daly on 3/17/25.
//

import Foundation
import SwiftUI

// MARK: - GTFS Data Models

// BART Route (Line)
struct BARTRoute: Identifiable, Hashable {
    let id: String
    let longName: String
    let shortName: String
    let lineColor: String
    let textColor: String
    let direction: String // "N" or "S" for BART
    
    var color: Color {
        switch lineColor.lowercased() {
        case "yellow": return .yellow
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return Color.orange
        default: return .gray
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BARTRoute, rhs: BARTRoute) -> Bool {
        return lhs.id == rhs.id
    }
}

// BART Station
struct BARTStop: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BARTStop, rhs: BARTStop) -> Bool {
        return lhs.id == rhs.id
    }
}

// BART Trip (specific train journey)
struct BARTTrip: Identifiable, Hashable {
    let id: String
    let routeId: String
    let serviceId: String  // Service calendar identifier
    let headsign: String   // Destination name
    let direction: String  // "0" or "1" for GTFS (e.g., outbound/inbound)
    let isWeekdayService: Bool
    let isWeekendService: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BARTTrip, rhs: BARTTrip) -> Bool {
        return lhs.id == rhs.id
    }
}

// BART Stop Time (when a trip arrives/departs from a station)
struct BARTStopTime: Identifiable, Hashable {
    let id: String
    let tripId: String
    let stopId: String
    let arrivalTime: String    // Format: "HH:MM:SS"
    let departureTime: String  // Format: "HH:MM:SS"
    let stopSequence: Int
    
    // Convert GTFS time string to Date object
    func departureTimeAsDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        // Handle GTFS times >24 hours (e.g., "25:30:00" for 1:30 AM the next day)
        var timeComponents = departureTime.split(separator: ":")
        if timeComponents.count >= 2 {
            var hour = Int(timeComponents[0]) ?? 0
            let minute = Int(timeComponents[1]) ?? 0
            
            // Get the reference date (today at midnight)
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            
            // Adjust for hours > 24
            let dayOffset = hour / 24
            hour = hour % 24
            
            timeComponents[0] = "\(hour)".dropFirst(0) as Substring
            let adjustedTimeString = timeComponents.joined(separator: ":")
            
            // Set time components
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0
            
            // Create date and adjust day if needed
            if let date = calendar.date(from: dateComponents) {
                return calendar.date(byAdding: .day, value: dayOffset, to: date)
            }
        }
        
        return nil
    }
    
    // Format time for display (e.g., "13:45" -> "1:45 PM")
    var formattedTime: String {
        let components = departureTime.split(separator: ":")
        if components.count >= 2 {
            var hour = Int(components[0])!
            let minute = Int(components[1])!
            let isPM = hour >= 12
            
            if hour > 12 {
                hour = hour % 12
            }
            if hour == 0 {
                hour = 12
            }
            
            return String(format: "%d:%02d %@", hour, minute, isPM ? "PM" : "AM")
        }
        return departureTime
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BARTStopTime, rhs: BARTStopTime) -> Bool {
        return lhs.id == rhs.id
    }
}

// Combined object for UI display
struct BARTScheduleItem: Identifiable {
    let id: String
    let station: BARTStop
    let destination: String
    let route: BARTRoute
    let trip: BARTTrip
    let stopTime: BARTStopTime
    
    // Returns the arrival time formatted for display
    var formattedArrivalTime: String {
        return stopTime.formattedTime
    }
    
    // Calculate minutes until departure
    func minutesUntilDeparture(from date: Date = Date()) -> Int? {
        guard let departureDate = stopTime.departureTimeAsDate() else { return nil }
        
        let components = Calendar.current.dateComponents([.minute], from: date, to: departureDate)
        return components.minute
    }
    
    // Get the direction as a user-friendly string
    var directionString: String {
        return route.direction.uppercased() == "N" ? "Northbound" : "Southbound"
    }
}

// GTFS route types
enum GTFSRouteType: Int {
    case lightRail = 0
    case subway = 1
    case rail = 2
    case bus = 3
    case ferry = 4
    case cableCar = 5
    case gondola = 6
    case funicular = 7
}

// MARK: - Helper Extensions

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

extension Date {
    func isInSameDay(as date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isTomorrow() -> Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return Calendar.current.isDate(self, inSameDayAs: tomorrow)
    }
} 