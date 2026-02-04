import Foundation

/// Utility for manually downloading and extracting GTFS data
class GTFSDownloader {
    
    /// Download and extract the BART GTFS data
    /// - Parameter completion: Completion handler with success/failure result
    static func downloadAndExtractBARTGTFS(completion: @escaping (Result<URL, Error>) -> Void) {
        // BART GTFS URL
        guard let url = URL(string: "https://www.bart.gov/dev/schedules/google_transit.zip") else {
            completion(.failure(GTFSDownloaderError.invalidURL))
            return
        }
        
        // Get documents directory for storage
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localZipFilename = "google_transit.zip"
        let localDataDirectory = "bart_schedules"
        
        // Create session for download
        let session = URLSession(configuration: .default)
        let task = session.downloadTask(with: url) { (tempLocalUrl, response, error) in
            if let error = error {
                print("Download error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let tempLocalUrl = tempLocalUrl else {
                print("Error: Downloaded file could not be found")
                completion(.failure(GTFSDownloaderError.downloadFailed))
                return
            }
            
            // Destination for the zip file
            let zipDestination = documentsDirectory.appendingPathComponent(localZipFilename)
            
            // Destination directory for extracted files
            let extractDestination = documentsDirectory.appendingPathComponent(localDataDirectory)
            
            do {
                // Remove existing zip if present
                if FileManager.default.fileExists(atPath: zipDestination.path) {
                    try FileManager.default.removeItem(at: zipDestination)
                }
                
                // Copy downloaded file to zip destination
                try FileManager.default.copyItem(at: tempLocalUrl, to: zipDestination)
                print("GTFS zip file saved to: \(zipDestination.path)")
                
                // Create extraction directory if needed
                if !FileManager.default.fileExists(atPath: extractDestination.path) {
                    try FileManager.default.createDirectory(at: extractDestination, withIntermediateDirectories: true, attributes: nil)
                }
                
                do {
                    // Try to extract zip file
                    try ZipUtility.extractZip(at: zipDestination, to: extractDestination)
                    print("GTFS files extracted to: \(extractDestination.path)")
                } catch {
                    print("ZIP extraction failed: \(error.localizedDescription)")
                    print("Please manually extract the GTFS files to: \(extractDestination.path)")
                    
                    // Create a flag file to indicate manual extraction is needed
                    let flagURL = extractDestination.appendingPathComponent("_EXTRACTION_NEEDED.txt")
                    try "Please manually extract the GTFS files from \(zipDestination.path) to this directory.".write(to: flagURL, atomically: true, encoding: .utf8)
                }
                
                // Return the path to the extracted directory
                completion(.success(extractDestination))
            } catch {
                print("Error saving/extracting file: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Helper method to manually place GTFS files for testing
    /// Call this method if you've manually extracted the GTFS files and want to test the parser
    static func setupManualGTFSFiles(sampleFiles: [String: String], completion: @escaping (Result<URL, Error>) -> Void) {
        // Get documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let gtfsDirectory = documentsDirectory.appendingPathComponent("bart_schedules")
        
        do {
            // Create the directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: gtfsDirectory.path) {
                try FileManager.default.createDirectory(at: gtfsDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Create sample GTFS files with minimal data for testing
            for (fileName, content) in sampleFiles {
                let fileURL = gtfsDirectory.appendingPathComponent(fileName)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                print("Created sample file: \(fileName)")
            }
            
            completion(.success(gtfsDirectory))
        } catch {
            print("Error setting up manual GTFS files: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    /// Setup sample minimal GTFS data for testing
    static func setupSampleGTFSData(completion: @escaping (Result<URL, Error>) -> Void) {
        // Create minimal sample GTFS files
        let sampleFiles: [String: String] = [
            "routes.txt": """
            route_id,route_long_name,route_short_name,route_color,route_text_color
            1,Antioch to SFO Airport/Millbrae,Yellow-S,FFFF33,000000
            2,SFO Airport/Millbrae to Antioch,Yellow-N,FFFF33,000000
            3,Berryessa/North San Jose to Richmond,Orange-N,FF9933,000000
            4,Richmond to Berryessa/North San Jose,Orange-S,FF9933,000000
            """,
            
            "stops.txt": """
            stop_id,stop_name,stop_lat,stop_lon
            12TH,12th St Oakland City Center,37.803768,-122.271450
            16TH,16th St Mission,37.765228,-122.419478
            19TH,19th St Oakland,37.808350,-122.268602
            24TH,24th St Mission,37.752470,-122.418143
            CIVC,Civic Center,37.779732,-122.414123
            """,
            
            "calendar.txt": """
            service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date
            WEEKDAY,1,1,1,1,1,0,0,20250101,20251231
            WEEKEND,0,0,0,0,0,1,1,20250101,20251231
            """,
            
            "trips.txt": """
            route_id,service_id,trip_id,trip_headsign,direction_id
            1,WEEKDAY,101,SFO/Millbrae,0
            2,WEEKDAY,102,Antioch,1
            """,
            
            "stop_times.txt": """
            trip_id,arrival_time,departure_time,stop_id,stop_sequence
            101,08:00:00,08:00:00,CIVC,1
            101,08:05:00,08:05:00,16TH,2
            101,08:10:00,08:10:00,24TH,3
            102,08:00:00,08:00:00,24TH,1
            102,08:05:00,08:05:00,16TH,2
            102,08:10:00,08:10:00,CIVC,3
            """
        ]
        
        setupManualGTFSFiles(sampleFiles: sampleFiles, completion: completion)
    }
    
    /// Run a test to download GTFS data
    static func runTest() {
        print("Starting GTFS download test...")
        
        downloadAndExtractBARTGTFS { result in
            switch result {
            case .success(let directory):
                print("SUCCESS: GTFS data downloaded and extracted to \(directory)")
                
                // Test the parser with the downloaded data
                let parser = GTFSParser(directory: directory)
                do {
                    let routes = try parser.parseRoutes()
                    print("Found \(routes.count) routes")
                    
                    for route in routes.prefix(5) {
                        print("Route: \(route.id) - \(route.longName) (\(route.lineColor) line, direction: \(route.direction))")
                    }
                    
                    let stops = try parser.parseStops()
                    print("Found \(stops.count) stops")
                    
                    let serviceIds = try parser.parseCalendar()
                    print("Found \(serviceIds.count) service IDs")
                    
                    let trips = try parser.parseTrips(serviceIds: serviceIds)
                    print("Found \(trips.count) trips")
                    
                    let stopTimes = try parser.parseStopTimes()
                    print("Found \(stopTimes.count) stop times")
                    
                    if let effectiveDate = parser.getEffectiveDate() {
                        print("Schedule effective date: \(effectiveDate)")
                    }
                    
                } catch {
                    print("Error parsing GTFS data: \(error)")
                }
                
            case .failure(let error):
                print("ERROR: \(error.localizedDescription)")
            }
        }
    }
    
    /// Run a test with sample GTFS data
    static func runTestWithSampleData() {
        print("Starting GTFS test with sample data...")
        
        setupSampleGTFSData { result in
            switch result {
            case .success(let directory):
                print("SUCCESS: Sample GTFS data created at \(directory)")
                
                // Test the parser with the sample data
                let parser = GTFSParser(directory: directory)
                do {
                    let routes = try parser.parseRoutes()
                    print("Found \(routes.count) routes")
                    
                    for route in routes {
                        print("Route: \(route.id) - \(route.longName) (\(route.lineColor) line, direction: \(route.direction))")
                    }
                    
                    let stops = try parser.parseStops()
                    print("Found \(stops.count) stops")
                    
                    let serviceIds = try parser.parseCalendar()
                    print("Found \(serviceIds.count) service IDs")
                    
                    let trips = try parser.parseTrips(serviceIds: serviceIds)
                    print("Found \(trips.count) trips")
                    
                    let stopTimes = try parser.parseStopTimes()
                    print("Found \(stopTimes.count) stop times")
                } catch {
                    print("Error parsing sample GTFS data: \(error)")
                }
                
            case .failure(let error):
                print("ERROR: \(error.localizedDescription)")
            }
        }
    }
}

/// Errors that can occur during GTFS download operations
enum GTFSDownloaderError: Error {
    case invalidURL
    case downloadFailed
} 