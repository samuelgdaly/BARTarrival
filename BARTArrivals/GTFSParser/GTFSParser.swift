import Foundation

/// A parser for GTFS (General Transit Feed Specification) data files
class GTFSParser {
    
    // MARK: - Properties
    
    /// The directory containing GTFS files
    private let directory: URL
    
    // MARK: - Initialization
    
    /// Initialize with the directory containing GTFS files
    /// - Parameter directory: URL to the directory containing the GTFS data files
    init(directory: URL) {
        self.directory = directory
    }
    
    // MARK: - Parsing Methods
    
    /// Parse routes.txt file
    /// - Returns: Array of route data
    func parseRoutes() throws -> [GTFSRoute] {
        var routes: [GTFSRoute] = []
        let fileURL = directory.appendingPathComponent("routes.txt")
        
        let routesData = try String(contentsOf: fileURL, encoding: .utf8)
        let routesLines = routesData.components(separatedBy: .newlines)
        
        if routesLines.isEmpty {
            throw GTFSError.emptyFile(name: "routes.txt")
        }
        
        // Get header indices
        let headers = routesLines[0].components(separatedBy: ",")
        guard let routeIdIndex = headers.firstIndex(of: "route_id"),
              let routeLongNameIndex = headers.firstIndex(of: "route_long_name"),
              let routeShortNameIndex = headers.firstIndex(of: "route_short_name"),
              let routeColorIndex = headers.firstIndex(of: "route_color"),
              let routeTextColorIndex = headers.firstIndex(of: "route_text_color") else {
            throw GTFSError.missingColumns(name: "routes.txt", columns: ["route_id", "route_long_name", "route_short_name", "route_color", "route_text_color"])
        }
        
        // Parse route lines
        for i in 1..<routesLines.count {
            let line = routesLines[i]
            if line.isEmpty { continue }
            
            let columns = line.components(separatedBy: ",")
            if columns.count <= max(routeIdIndex, routeLongNameIndex, routeShortNameIndex, routeColorIndex, routeTextColorIndex) {
                continue // Skip invalid lines
            }
            
            let routeId = columns[routeIdIndex]
            let longName = columns[routeLongNameIndex].replacingOccurrences(of: "\"", with: "")
            let shortName = columns[routeShortNameIndex].replacingOccurrences(of: "\"", with: "")
            let routeColor = columns[routeColorIndex]
            let textColor = columns[routeTextColorIndex]
            
            // Determine BART line color and direction
            let (lineColor, direction) = determineLineColorAndDirection(routeId: routeId, longName: longName, shortName: shortName)
            
            let route = GTFSRoute(
                id: routeId,
                longName: longName,
                shortName: shortName,
                lineColor: lineColor,
                textColor: textColor,
                direction: direction
            )
            
            routes.append(route)
        }
        
        return routes
    }
    
    /// Parse stops.txt file
    /// - Returns: Array of stop data
    func parseStops() throws -> [GTFSStop] {
        var stops: [GTFSStop] = []
        let fileURL = directory.appendingPathComponent("stops.txt")
        
        let stopsData = try String(contentsOf: fileURL, encoding: .utf8)
        let stopsLines = stopsData.components(separatedBy: .newlines)
        
        if stopsLines.isEmpty {
            throw GTFSError.emptyFile(name: "stops.txt")
        }
        
        // Get header indices
        let headers = stopsLines[0].components(separatedBy: ",")
        guard let stopIdIndex = headers.firstIndex(of: "stop_id"),
              let stopNameIndex = headers.firstIndex(of: "stop_name"),
              let stopLatIndex = headers.firstIndex(of: "stop_lat"),
              let stopLonIndex = headers.firstIndex(of: "stop_lon") else {
            throw GTFSError.missingColumns(name: "stops.txt", columns: ["stop_id", "stop_name", "stop_lat", "stop_lon"])
        }
        
        // Parse stop lines
        for i in 1..<stopsLines.count {
            let line = stopsLines[i]
            if line.isEmpty { continue }
            
            let columns = line.components(separatedBy: ",")
            if columns.count <= max(stopIdIndex, stopNameIndex, stopLatIndex, stopLonIndex) {
                continue // Skip invalid lines
            }
            
            let stopId = columns[stopIdIndex]
            let stopName = columns[stopNameIndex].replacingOccurrences(of: "\"", with: "")
            let latitude = Double(columns[stopLatIndex]) ?? 0.0
            let longitude = Double(columns[stopLonIndex]) ?? 0.0
            
            let stop = GTFSStop(
                id: stopId,
                name: stopName,
                latitude: latitude,
                longitude: longitude
            )
            
            stops.append(stop)
        }
        
        return stops
    }
    
    /// Parse calendar.txt to identify weekday/weekend service IDs
    /// - Returns: Dictionary mapping service IDs to weekday/weekend information
    func parseCalendar() throws -> [String: (isWeekday: Bool, isWeekend: Bool)] {
        var serviceIds: [String: (isWeekday: Bool, isWeekend: Bool)] = [:]
        let fileURL = directory.appendingPathComponent("calendar.txt")
        
        let calendarData = try String(contentsOf: fileURL, encoding: .utf8)
        let calendarLines = calendarData.components(separatedBy: .newlines)
        
        if calendarLines.isEmpty {
            throw GTFSError.emptyFile(name: "calendar.txt")
        }
        
        // Get header indices
        let headers = calendarLines[0].components(separatedBy: ",")
        guard let serviceIdIndex = headers.firstIndex(of: "service_id"),
              let mondayIndex = headers.firstIndex(of: "monday"),
              let tuesdayIndex = headers.firstIndex(of: "tuesday"),
              let wednesdayIndex = headers.firstIndex(of: "wednesday"),
              let thursdayIndex = headers.firstIndex(of: "thursday"),
              let fridayIndex = headers.firstIndex(of: "friday"),
              let saturdayIndex = headers.firstIndex(of: "saturday"),
              let sundayIndex = headers.firstIndex(of: "sunday") else {
            throw GTFSError.missingColumns(name: "calendar.txt", columns: ["service_id", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])
        }
        
        // Parse calendar lines
        for i in 1..<calendarLines.count {
            let line = calendarLines[i]
            if line.isEmpty { continue }
            
            let columns = line.components(separatedBy: ",")
            if columns.count <= max(serviceIdIndex, mondayIndex, tuesdayIndex, wednesdayIndex, thursdayIndex, fridayIndex, saturdayIndex, sundayIndex) {
                continue // Skip invalid lines
            }
            
            let serviceId = columns[serviceIdIndex]
            let monday = columns[mondayIndex] == "1"
            let tuesday = columns[tuesdayIndex] == "1"
            let wednesday = columns[wednesdayIndex] == "1"
            let thursday = columns[thursdayIndex] == "1"
            let friday = columns[fridayIndex] == "1"
            let saturday = columns[saturdayIndex] == "1"
            let sunday = columns[sundayIndex] == "1"
            
            let isWeekday = monday || tuesday || wednesday || thursday || friday
            let isWeekend = saturday || sunday
            
            serviceIds[serviceId] = (isWeekday: isWeekday, isWeekend: isWeekend)
        }
        
        return serviceIds
    }
    
    /// Parse trips.txt file
    /// - Parameter serviceIds: Dictionary of service IDs to weekday/weekend information
    /// - Returns: Array of trip data
    func parseTrips(serviceIds: [String: (isWeekday: Bool, isWeekend: Bool)]) throws -> [GTFSTrip] {
        var trips: [GTFSTrip] = []
        let fileURL = directory.appendingPathComponent("trips.txt")
        
        let tripsData = try String(contentsOf: fileURL, encoding: .utf8)
        let tripsLines = tripsData.components(separatedBy: .newlines)
        
        if tripsLines.isEmpty {
            throw GTFSError.emptyFile(name: "trips.txt")
        }
        
        // Get header indices
        let headers = tripsLines[0].components(separatedBy: ",")
        guard let routeIdIndex = headers.firstIndex(of: "route_id"),
              let serviceIdIndex = headers.firstIndex(of: "service_id"),
              let tripIdIndex = headers.firstIndex(of: "trip_id"),
              let tripHeadsignIndex = headers.firstIndex(of: "trip_headsign") else {
            throw GTFSError.missingColumns(name: "trips.txt", columns: ["route_id", "service_id", "trip_id", "trip_headsign"])
        }
        
        // Direction ID is optional in GTFS
        let directionIdIndex = headers.firstIndex(of: "direction_id")
        
        // Parse trip lines
        for i in 1..<tripsLines.count {
            let line = tripsLines[i]
            if line.isEmpty { continue }
            
            let columns = line.components(separatedBy: ",")
            if columns.count <= max(routeIdIndex, serviceIdIndex, tripIdIndex, tripHeadsignIndex) {
                continue // Skip invalid lines
            }
            
            let routeId = columns[routeIdIndex]
            let serviceId = columns[serviceIdIndex]
            let tripId = columns[tripIdIndex]
            let headsign = columns[tripHeadsignIndex].replacingOccurrences(of: "\"", with: "")
            
            // Direction ID is optional
            let direction = directionIdIndex != nil && columns.count > directionIdIndex! ? columns[directionIdIndex!] : "0"
            
            // Get weekday/weekend status
            let serviceInfo = serviceIds[serviceId] ?? (isWeekday: true, isWeekend: false)
            
            let trip = GTFSTrip(
                id: tripId,
                routeId: routeId,
                serviceId: serviceId,
                headsign: headsign,
                direction: direction,
                isWeekdayService: serviceInfo.isWeekday,
                isWeekendService: serviceInfo.isWeekend
            )
            
            trips.append(trip)
        }
        
        return trips
    }
    
    /// Parse stop_times.txt file
    /// - Returns: Array of stop time data
    func parseStopTimes() throws -> [GTFSStopTime] {
        var stopTimes: [GTFSStopTime] = []
        let fileURL = directory.appendingPathComponent("stop_times.txt")
        
        let stopTimesData = try String(contentsOf: fileURL, encoding: .utf8)
        let stopTimesLines = stopTimesData.components(separatedBy: .newlines)
        
        if stopTimesLines.isEmpty {
            throw GTFSError.emptyFile(name: "stop_times.txt")
        }
        
        // Get header indices
        let headers = stopTimesLines[0].components(separatedBy: ",")
        guard let tripIdIndex = headers.firstIndex(of: "trip_id"),
              let arrivalTimeIndex = headers.firstIndex(of: "arrival_time"),
              let departureTimeIndex = headers.firstIndex(of: "departure_time"),
              let stopIdIndex = headers.firstIndex(of: "stop_id"),
              let stopSequenceIndex = headers.firstIndex(of: "stop_sequence") else {
            throw GTFSError.missingColumns(name: "stop_times.txt", columns: ["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence"])
        }
        
        // Parse stop times lines
        for i in 1..<stopTimesLines.count {
            let line = stopTimesLines[i]
            if line.isEmpty { continue }
            
            let columns = line.components(separatedBy: ",")
            if columns.count <= max(tripIdIndex, arrivalTimeIndex, departureTimeIndex, stopIdIndex, stopSequenceIndex) {
                continue // Skip invalid lines
            }
            
            let tripId = columns[tripIdIndex]
            let arrivalTime = columns[arrivalTimeIndex]
            let departureTime = columns[departureTimeIndex]
            let stopId = columns[stopIdIndex]
            let stopSequence = Int(columns[stopSequenceIndex]) ?? 0
            
            let stopTime = GTFSStopTime(
                id: UUID().uuidString,
                tripId: tripId,
                stopId: stopId,
                arrivalTime: arrivalTime,
                departureTime: departureTime,
                stopSequence: stopSequence
            )
            
            stopTimes.append(stopTime)
        }
        
        return stopTimes
    }
    
    /// Get effective date from feed_info.txt (if available)
    /// - Returns: Formatted date string or nil if not available
    func getEffectiveDate() -> String? {
        let feedInfoURL = directory.appendingPathComponent("feed_info.txt")
        
        do {
            let feedInfoData = try String(contentsOf: feedInfoURL, encoding: .utf8)
            let feedInfoLines = feedInfoData.components(separatedBy: .newlines)
            
            if feedInfoLines.count < 2 {
                return nil
            }
            
            // Get header indices
            let headers = feedInfoLines[0].components(separatedBy: ",")
            if let feedStartDateIndex = headers.firstIndex(of: "feed_start_date"),
               feedStartDateIndex < feedInfoLines[1].components(separatedBy: ",").count {
                let startDateString = feedInfoLines[1].components(separatedBy: ",")[feedStartDateIndex]
                
                // Format date string (YYYYMMDD to Month Year)
                if startDateString.count == 8 {
                    let year = String(startDateString.prefix(4))
                    let month = Int(startDateString.dropFirst(4).prefix(2)) ?? 1
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMMM"
                    let monthName = dateFormatter.monthSymbols[month - 1]
                    
                    return "\(monthName) \(year)"
                }
            }
        } catch {
            print("Error reading feed_info.txt: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Determine line color and direction from route data
    /// - Parameters:
    ///   - routeId: The route identifier
    ///   - longName: The long name of the route
    ///   - shortName: The short name of the route
    /// - Returns: Tuple containing line color and direction
    private func determineLineColorAndDirection(routeId: String, longName: String, shortName: String) -> (String, String) {
        // Default values
        var lineColor = "Unknown"
        var direction = "N" // Default to northbound
        
        // Try to extract color from the name or ID
        let lowercaseName = longName.lowercased()
        
        if lowercaseName.contains("antioch") && lowercaseName.contains("sfo") {
            lineColor = "Yellow"
            direction = lowercaseName.contains("antioch to") ? "S" : "N"
        } else if lowercaseName.contains("richmond") && lowercaseName.contains("berryessa") {
            lineColor = "Orange"
            direction = lowercaseName.contains("richmond to") ? "S" : "N"
        } else if lowercaseName.contains("berryessa") && lowercaseName.contains("daly city") {
            lineColor = "Green"
            direction = lowercaseName.contains("berryessa to") ? "S" : "N"
        } else if lowercaseName.contains("richmond") && lowercaseName.contains("millbrae") {
            lineColor = "Red"
            direction = lowercaseName.contains("richmond to") ? "S" : "N"
        } else if lowercaseName.contains("dublin") && lowercaseName.contains("daly city") {
            lineColor = "Blue"
            direction = lowercaseName.contains("dublin to") ? "S" : "N"
        }
        
        // Check shortName as a backup
        if lineColor == "Unknown" && !shortName.isEmpty {
            if shortName.contains("YELLOW") || shortName.contains("YL") {
                lineColor = "Yellow"
            } else if shortName.contains("ORANGE") || shortName.contains("OR") {
                lineColor = "Orange"
            } else if shortName.contains("GREEN") || shortName.contains("GR") {
                lineColor = "Green"
            } else if shortName.contains("RED") || shortName.contains("RD") {
                lineColor = "Red"
            } else if shortName.contains("BLUE") || shortName.contains("BL") {
                lineColor = "Blue"
            }
            
            // Determine direction
            if shortName.contains("-N") || shortName.contains("_N") || shortName.hasSuffix("N") {
                direction = "N"
            } else if shortName.contains("-S") || shortName.contains("_S") || shortName.hasSuffix("S") {
                direction = "S"
            }
        }
        
        return (lineColor, direction)
    }
}

// MARK: - Error Types

/// Errors that can occur during GTFS parsing
enum GTFSError: Error {
    case emptyFile(name: String)
    case missingColumns(name: String, columns: [String])
    case invalidData(description: String)
}

// MARK: - GTFS Data Types

/// Represents a transit route from routes.txt
struct GTFSRoute {
    let id: String
    let longName: String
    let shortName: String
    let lineColor: String
    let textColor: String
    let direction: String
}

/// Represents a transit stop/station from stops.txt
struct GTFSStop {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
}

/// Represents a transit trip from trips.txt
struct GTFSTrip {
    let id: String
    let routeId: String
    let serviceId: String
    let headsign: String
    let direction: String
    let isWeekdayService: Bool
    let isWeekendService: Bool
}

/// Represents a stop time from stop_times.txt
struct GTFSStopTime {
    let id: String
    let tripId: String
    let stopId: String
    let arrivalTime: String
    let departureTime: String
    let stopSequence: Int
} 