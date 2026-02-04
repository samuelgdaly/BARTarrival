//
//  SchedulesView.swift
//  BARTArrivals
//
//  Created by Samuel Daly on 3/17/25.
//

import SwiftUI

struct SchedulesView: View {
    @StateObject private var scheduleService = BARTScheduleService()
    @State private var selectedLine: BARTRoute?
    @State private var isWeekday = true
    @State private var direction: Direction = .northbound
    
    // Enum for direction
    enum Direction: String, CaseIterable, Identifiable {
        case northbound = "Northbound"
        case southbound = "Southbound"
        
        var id: String { self.rawValue }
    }
    
    // BART Line colors for the picker
    let lineColors: [(name: String, color: Color, id: String)] = [
        ("Yellow", .yellow, "Yellow"),
        ("Red", .red, "Red"),
        ("Blue", .blue, "Blue"),
        ("Green", .green, "Green"),
        ("Orange", Color.orange, "Orange")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header controls
            VStack(spacing: 0) {
                // Weekday/Weekend & Direction Selection
                HStack {
                    // Weekday/Weekend Selector
                    Menu {
                        Button(action: { isWeekday = true }) {
                            Label(
                                "Weekday",
                                systemImage: isWeekday ? "checkmark" : ""
                            )
                        }
                        Button(action: { isWeekday = false }) {
                            Label(
                                "Weekend",
                                systemImage: !isWeekday ? "checkmark" : ""
                            )
                        }
                    } label: {
                        HStack {
                            Text(isWeekday ? "Weekday" : "Weekend")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white)
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Direction Selector
                    Menu {
                        ForEach(Direction.allCases) { dir in
                            Button(action: { direction = dir }) {
                                Label(
                                    dir.rawValue,
                                    systemImage: direction == dir ? "checkmark" : ""
                                )
                            }
                        }
                    } label: {
                        HStack {
                            Text(direction.rawValue)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white)
                        }
                        .padding()
                    }
                }
                .background(Color.red)
                
                // Line color selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(lineColors, id: \.id) { line in
                            lineButton(name: line.name, color: line.color)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.white)
            }

            if scheduleService.isLoading {
                // Loading view
                LoadingView(message: "Loading schedules...")
            } else if selectedLine == nil {
                // No line selected
                NoSelectionView(message: "Select a line to view schedules")
            } else {
                // Timetable view
                LineTimetableView(
                    selectedLine: selectedLine!,
                    isWeekday: isWeekday,
                    direction: direction
                )
                .environmentObject(scheduleService)
            }
        }
        .onAppear {
            scheduleService.initialize()
        }
    }
    
    // Line selection button
    private func lineButton(name: String, color: Color) -> some View {
        let isSelected = selectedLine?.lineColor.lowercased() == name.lowercased()
        
        return Button(action: {
            if isSelected {
                // If already selected, deselect
                selectedLine = nil
            } else {
                // Find and select the route with this color
                selectedLine = scheduleService.routes.first(where: { 
                    $0.lineColor.lowercased() == name.lowercased() && 
                    (direction == .northbound ? $0.direction == "N" : $0.direction == "S")
                })
            }
        }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isSelected ? Color(.systemGray4) : Color(.systemGray6))
            .cornerRadius(20)
        }
    }
}

// Line Timetable View showing all stations along a line
struct LineTimetableView: View {
    @EnvironmentObject var scheduleService: BARTScheduleService
    let selectedLine: BARTRoute
    let isWeekday: Bool
    let direction: SchedulesView.Direction
    
    @State private var timetableData: LineScheduleData?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Timetable header
            VStack {
                Text("\(selectedLine.lineColor) Line")
                    .font(.headline)
                    .padding(.top, 8)
                
                Text("\(direction.rawValue) • \(isWeekday ? "Weekday" : "Weekend") Schedule")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            
            if isLoading {
                LoadingView(message: "Loading timetable...")
            } else if let timetableData = timetableData, !timetableData.trips.isEmpty {
                // Timetable Grid
                ScrollView([.horizontal, .vertical]) {
                    GridTimetableView(timetableData: timetableData)
                }
            } else {
                NoSelectionView(message: "No schedules available for the selected options")
            }
        }
        .onAppear {
            loadScheduleData()
        }
        .onChange(of: selectedLine) { _ in loadScheduleData() }
        .onChange(of: isWeekday) { _ in loadScheduleData() }
        .onChange(of: direction) { _ in loadScheduleData() }
    }
    
    private func loadScheduleData() {
        isLoading = true
        
        // Get the direction string for the BART API
        let directionStr = direction == .northbound ? "N" : "S"
        
        // Load the timetable for the selected line, direction, and day
        scheduleService.getLineSchedule(
            forLine: selectedLine.lineColor,
            direction: directionStr,
            isWeekday: isWeekday
        ) { result in
            switch result {
            case .success(let data):
                self.timetableData = data
                self.isLoading = false
            case .failure(let error):
                print("Error loading schedule: \(error)")
                self.timetableData = nil
                self.isLoading = false
            }
        }
    }
}

// Grid-based Timetable View showing stations and times
struct GridTimetableView: View {
    let timetableData: LineScheduleData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers - Trip IDs or Times
            HStack(alignment: .top, spacing: 0) {
                // First column - Station names
                Text("Stations")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(width: 130, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color.white)
                
                // Trip columns
                ForEach(timetableData.trips) { trip in
                    Text(trip.displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(width: 80, alignment: .center)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(trip.isLimited ? Color(.systemTeal).opacity(0.2) : 
                                    trip.isExpress ? Color.red.opacity(0.2) : Color.white)
                }
            }
            
            Divider()
            
            // Station rows
            ForEach(timetableData.stations) { station in
                HStack(alignment: .center, spacing: 0) {
                    // Station name
                    Text(station.name)
                        .font(.caption)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                        .frame(width: 130, alignment: .leading)
                    
                    // Times for each trip
                    ForEach(timetableData.trips) { trip in
                        if let time = timetableData.getTripTimeForStation(tripId: trip.id, stationId: station.id) {
                            Text(time)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .frame(width: 80, alignment: .center)
                                .padding(.vertical, 12)
                                .background(trip.isLimited ? Color(.systemTeal).opacity(0.2) : 
                                            trip.isExpress ? Color.red.opacity(0.2) : Color.white)
                        } else {
                            Text("--")
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.gray)
                                .frame(width: 80, alignment: .center)
                                .padding(.vertical, 12)
                                .background(trip.isLimited ? Color(.systemTeal).opacity(0.2) : 
                                            trip.isExpress ? Color.red.opacity(0.2) : Color.white)
                        }
                    }
                }
                Divider()
            }
            
            // Legend
            HStack(spacing: 16) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                    Text("Local")
                        .font(.caption)
                }
                
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemTeal).opacity(0.2))
                        .frame(width: 16, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                    Text("Limited")
                        .font(.caption)
                }
                
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 16, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                    Text("Express")
                        .font(.caption)
                }
            }
            .padding()
            
            // Effective date
            Text("Timetable Effective \(timetableData.effectiveDate)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
                .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}

// View shown when no line is selected
struct NoSelectionView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "train.side.front.car")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding(.bottom, 16)
            Text(message)
                .font(.headline)
            Spacer()
        }
    }
}

// Loading view
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding(.bottom, 16)
            Text(message)
                .font(.headline)
            Spacer()
        }
    }
}

// Data model for the line timetable
struct LineScheduleData {
    struct Station: Identifiable {
        let id: String
        let name: String
        let index: Int
    }
    
    struct Trip: Identifiable {
        let id: String
        let displayName: String
        let isLimited: Bool
        let isExpress: Bool
    }
    
    struct TripStop {
        let tripId: String
        let stationId: String
        let time: String // Format: "HH:MM AM/PM"
    }
    
    let stations: [Station]
    let trips: [Trip]
    let tripStops: [TripStop]
    let effectiveDate: String
    
    func getTripTimeForStation(tripId: String, stationId: String) -> String? {
        tripStops.first(where: { $0.tripId == tripId && $0.stationId == stationId })?.time
    }
}

struct SchedulesView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulesView()
    }
} 