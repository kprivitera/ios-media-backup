import Foundation
import SwiftUI

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

@MainActor
class MediaViewModel: ObservableObject {
    @Published var mediaItems: [MediaItem] = []
    @Published var errorMessage: String?
    @Published var availableMonths: [MonthYear] = [] // Stores the months and years for the dropdown

    private let baseURL = "http://localhost:4000" // Your server URL
    private let apiEndpoint = "/api/backups"
    private let metadataEndpoint = "/api/backups/metadata"
    
    func fetchMedia(for monthYear: MonthYear) async {
        guard let url = URL(string: "\(baseURL + apiEndpoint)?month=\(monthYear.month)&year=\(monthYear.year)") else {
            errorMessage = "Invalid URL"
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(MediaResponse.self, from: data)
            mediaItems = response.media.filter { $0.mediaType == "image" }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to fetch media: \(error.localizedDescription)"
        }
    }
    
    func imageURL(for item: MediaItem) -> URL? {
        let urlString = baseURL + item.filepath
        return URL(string: urlString)
    }

    func fetchMetadata() async {
        guard let url = URL(string: baseURL + metadataEndpoint) else {
            errorMessage = "Invalid Metadata URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("Raw Metadata Response: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")
            
            // Decode the JSON into the MetadataResponse struct
            let response = try JSONDecoder().decode(MetadataResponse.self, from: data)
            print("Decoded Metadata Response: \(response)")
            
            // Directly assign the decoded data to availableMonths
            availableMonths = response.data
            print("Fetched Metadata: \(availableMonths)")
        } catch {
            errorMessage = "Failed to fetch metadata: \(error.localizedDescription)"
            print("Error decoding metadata: \(error.localizedDescription)")
        }
    }
}
