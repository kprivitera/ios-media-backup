import Foundation
import SwiftUI

@MainActor
class MediaViewModel: ObservableObject {
    @Published var mediaItems: [MediaItem] = []
    @Published var errorMessage: String?
    @Published var availableMonths: [MonthYear] = [] // Stores the months and years for the dropdown
    @Published var isLoggedIn: Bool = false // Track login state
    private var token: String?

    private let baseURL = "http://localhost:4000" // Your server URL
    private let apiEndpoint = "/api/backups"
    private let metadataEndpoint = "/api/backups/metadata"
    
    func fetchMedia(for monthYear: MonthYear) async {
        guard let url = URL(string: "\(baseURL + apiEndpoint)?month=\(monthYear.month)&year=\(monthYear.year)") else {
            errorMessage = "Invalid URL"
            return
        }
        print("Fetching media from URL: \(url)")

        guard let token = token else {
            errorMessage = "User is not authenticated"
            return
        }
        print("Token: \(token)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Debug: Print the headers being sent
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Add debugging for the response
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
            }
            
            print("Raw response data: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")
            
            let mediaResponse = try JSONDecoder().decode(MediaResponse.self, from: data)
            mediaItems = mediaResponse.media.filter { $0.mediaType == "image" }
            errorMessage = nil
        } catch {
            print("Detailed error: \(error)")
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

        guard let token = token else {
            errorMessage = "User is not authenticated"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
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

    func login(username: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/login") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Debug: Print the raw login response
        print("Raw login response: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")

        // Parse the JSON response to extract the token
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let token = json["token"] as? String {
            let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            self.token = cleanToken
            print("Extracted token: '\(cleanToken)'")
            return cleanToken
        } else {
            // If it's not JSON, treat the entire response as the token
            let token = String(data: data, encoding: .utf8) ?? ""
            let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            self.token = cleanToken
            print("Raw token: '\(cleanToken)'")
            return cleanToken
        }
    }
}
