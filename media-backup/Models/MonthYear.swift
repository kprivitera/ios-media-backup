import Foundation

struct MonthYear: Identifiable, Hashable, Codable {
    let id = UUID() // Generate a unique ID locally
    let month: String
    let year: String

    private enum CodingKeys: String, CodingKey {
        case month
        case year
    }
}

struct MetadataResponse: Codable {
    let data: [MonthYear]
}
