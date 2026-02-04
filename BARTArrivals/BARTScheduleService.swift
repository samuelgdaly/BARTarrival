//
//  BARTScheduleService.swift
//  BARTArrivals
//
//  Created by Samuel Daly on 3/17/25.
//

import Foundation
import SwiftUI
import Combine

class BARTScheduleService: ObservableObject {
    @Published var routes: [BARTRoute] = []
    @Published var stops: [BARTStop] = []
    @Published var trips: [BARTTrip] = []
    @Published var stopTimes: [BARTStopTime] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Pre-filter frequently used data
    private var routeMap: [String: BARTRoute] = [:]
    private var stopMap: [String: BARTStop] = [:]
    private var tripMap: [String: BARTTrip] = [:]
    
    // MARK: - Public Methods
    
    // Initialize and load data
    func initialize() {
        isLoading = true
        
        // Create simple mock data
        createMockData()
        
        isLoading = false
    }
    
    // Get schedule for a specific station - simplified placeholder
    func getSchedule(forStation stationId: String, isWeekday: Bool = true, direction: String? = nil, lineColor: String? = nil) -> [BARTScheduleItem] {
        guard let station = stopMap[stationId] else {
            return []
        }
        
        // Return some placeholder items
        var items: [BARTScheduleItem] = []
        
        // Create a few dummy schedule items
        if let route = routes.first {
            let now = Date()
            let calendar = Calendar.current
            
            // Create 5 example departures at 10-minute intervals
            for i in 0..<5 {
                // Create a departure time 10*i minutes from now
                let departureTime = calendar.date(byAdding: .minute, value: 10 * (i + 1), to: now) ?? now
                let hour = calendar.component(.hour, from: departureTime)
                let minute = calendar.component(.minute, from: departureTime)
                let departureTimeString = String(format: "%02d:%02d:00", hour, minute)
                
                let trip = BARTTrip(
                    id: "trip\(i)",
                    routeId: route.id,
                    serviceId: "WEEKDAY",
                    headsign: "Example Destination",
                    direction: "N",
                    isWeekdayService: true,
                    isWeekendService: false
                )
                
                let stopTime = BARTStopTime(
                    id: UUID().uuidString,
                    tripId: trip.id,
                    stopId: station.id,
                    arrivalTime: departureTimeString,
                    departureTime: departureTimeString,
                    stopSequence: 1
                )
                
                let item = BARTScheduleItem(
                    id: UUID().uuidString,
                    station: station,
                    destination: "Placeholder Destination",
                    route: route,
                    trip: trip,
                    stopTime: stopTime
                )
                
                items.append(item)
            }
        }
        
        return items
    }
    
    // Get all stations as array
    func getStations() -> [BARTStop] {
        return stops.sorted { $0.name < $1.name }
    }
    
    // Filter stations by name (for search)
    func searchStations(query: String) -> [BARTStop] {
        if query.isEmpty {
            return getStations()
        }
        
        let lowercasedQuery = query.lowercased()
        return stops.filter { 
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.id.lowercased().contains(lowercasedQuery)
        }.sorted { $0.name < $1.name }
    }
    
    // Get stations sorted by proximity to location
    func getStationsByProximity(location: (latitude: Double, longitude: Double)) -> [BARTStop] {
        return stops.sorted { station1, station2 in
            let distance1 = calculateDistance(
                lat1: location.latitude, lon1: location.longitude,
                lat2: station1.latitude, lon2: station1.longitude
            )
            
            let distance2 = calculateDistance(
                lat1: location.latitude, lon1: location.longitude,
                lat2: station2.latitude, lon2: station2.longitude
            )
            
            return distance1 < distance2
        }
    }
    
    // Calculate distance between two points using Haversine formula
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0 // kilometers
        
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
    }
    
    // Simple placeholder for line schedule
    func getLineSchedule(forLine lineColor: String, direction: String, isWeekday: Bool, completion: @escaping (Result<LineScheduleData, Error>) -> Void) {
        print("Schedule placeholder for \(lineColor) line, direction: \(direction)")
        
        // Create a simple placeholder schedule
        let stations = stops.prefix(5).enumerated().map { index, stop in
            return LineScheduleData.Station(id: stop.id, name: stop.name, index: index)
        }
        
        let trips = [
            LineScheduleData.Trip(id: "trip1", displayName: "1", isLimited: false, isExpress: false)
        ]
        
        var tripStops: [LineScheduleData.TripStop] = []
        
        // Add some example times
        for station in stations {
            tripStops.append(
                LineScheduleData.TripStop(
                    tripId: "trip1",
                    stationId: station.id,
                    time: "9:00 AM"
                )
            )
        }
        
        let mockData = LineScheduleData(
            stations: stations,
            trips: trips,
            tripStops: tripStops,
            effectiveDate: "Placeholder - Schedule Temporarily Unavailable"
        )
        
        completion(.success(mockData))
    }
    
    // MARK: - Data Creation Methods
    
    // Create simple mock data
    private func createMockData() {
        // Create a few basic routes
        routes = [
            BARTRoute(id: "1", longName: "Yellow Line", shortName: "Yellow", lineColor: "Yellow", textColor: "Black", direction: "S"),
            BARTRoute(id: "2", longName: "Red Line", shortName: "Red", lineColor: "Red", textColor: "White", direction: "N")
        ]
        
        // Create a subset of stops (stations)
        stops = [
            BARTStop(id: "12TH", name: "12th St Oakland City Center", latitude: 37.803768, longitude: -122.271450),
            BARTStop(id: "16TH", name: "16th St Mission", latitude: 37.765228, longitude: -122.419478),
            BARTStop(id: "19TH", name: "19th St Oakland", latitude: 37.808350, longitude: -122.268602),
            BARTStop(id: "24TH", name: "24th St Mission", latitude: 37.752470, longitude: -122.418143),
            BARTStop(id: "CIVC", name: "Civic Center", latitude: 37.779732, longitude: -122.414123),
            BARTStop(id: "EMBR", name: "Embarcadero", latitude: 37.792874, longitude: -122.396778),
            BARTStop(id: "MONT", name: "Montgomery St", latitude: 37.789405, longitude: -122.401066),
            BARTStop(id: "POWL", name: "Powell St", latitude: 37.784471, longitude: -122.407974)
        ]
        
        // Create basic lookup maps
        routeMap = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
        stopMap = Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0) })
    }
} 