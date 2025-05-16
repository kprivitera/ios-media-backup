import Foundation

struct MediaItem: Codable, Identifiable {
    let filepath: String
    let id: Int
    let mediaType: String
    let metadataDate: String
    
    enum CodingKeys: String, CodingKey {
        case filepath
        case id
        case mediaType = "media_type"
        case metadataDate = "metadata_date"
    }
}

struct MediaResponse: Codable {
    let media: [MediaItem]
}