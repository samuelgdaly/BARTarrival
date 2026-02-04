import Foundation

// MARK: - BART API Response Models
// Shared between iOS and Watch apps

struct BARTETDResponse: Codable {
    let root: BARTETDRoot
}

struct BARTETDRoot: Codable {
    let station: [BARTETDStation]
}

struct BARTETDStation: Codable {
    let name: String
    let abbr: String
    let etd: [BARTETD]?
}

struct BARTETD: Codable {
    let destination: String
    let abbreviation: String?
    let limited: String?
    let estimate: [BARTETDEstimate]
}

struct BARTETDEstimate: Codable {
    let minutes: String
    let platform: String
    let direction: String
    let length: String
    let color: String
    let hexcolor: String
    let bikeflag: String
    let delay: String
}
