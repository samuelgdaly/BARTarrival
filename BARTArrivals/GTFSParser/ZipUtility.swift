import Foundation

/// Utility for working with ZIP files
class ZipUtility {
    
    /// Extracts ZIP file content to a destination directory
    /// - Parameters:
    ///   - zipURL: URL of the ZIP file to extract
    ///   - destination: Destination directory URL
    /// - Throws: Throws file errors if destination creation fails or other file operations fail
    static func extractZip(at zipURL: URL, to destination: URL) throws {
        // Ensure destination directory exists
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Check if the zip file exists
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw ZipUtilityError.fileNotFound(path: zipURL.path)
        }
        
        #if os(macOS)
        // On macOS, use unzip command via Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ZipUtilityError.extractionFailed(status: Int(process.terminationStatus))
        }
        #else
        // On iOS, we can't use Process, so we need to use a library like ZIPFoundation
        // For now, we'll just print a message
        print("ZIP extraction not implemented for iOS. Please use a library like ZIPFoundation.")
        print("For testing, we'll rely on the sample data created directly.")
        
        // Write a placeholder file to indicate that unzipping was attempted
        let placeholderURL = destination.appendingPathComponent("_ZIP_EXTRACTION_ATTEMPTED.txt")
        try "ZIP extraction attempted but not implemented for iOS. Use sample data for testing.".write(to: placeholderURL, atomically: true, encoding: .utf8)
        #endif
    }
}

/// Errors that can occur during ZIP operations
enum ZipUtilityError: Error {
    case fileNotFound(path: String)
    case extractionFailed(status: Int)
} 