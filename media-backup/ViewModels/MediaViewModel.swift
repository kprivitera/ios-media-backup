import Foundation
import SwiftUI
import Photos
import PhotosUI
import CryptoKit


@MainActor
class MediaViewModel: ObservableObject {
    @Published var mediaItems: [MediaItem] = []
    @Published var errorMessage: String?
    @Published var availableMonths: [MonthYear] = [] // Stores the months and years for the dropdown
    @Published var isLoggedIn: Bool = false // Track login state
    private var token: String?

    // UserDefaults key for last backup
    private let lastBackupKey = "lastSuccessfulBackup"

    var lastSuccessfulBackup: Date? {
        get {
            UserDefaults.standard.object(forKey: lastBackupKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastBackupKey)
        }
    }

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

    func uploadImage(_ imageData: Data, filename: String = "photo.jpg") async {
        guard let token = token else {
            errorMessage = "User is not authenticated"
            return
        }

        guard let url = URL(string: "\(baseURL)\(apiEndpoint)") else {
            errorMessage = "Invalid upload URL"
            return
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Upload status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("✅ Upload successful for \(filename)")
                    // Update last backup date
                    self.lastSuccessfulBackup = Date()
                } else {
                    let serverMessage = String(data: data, encoding: .utf8) ?? "No message"
                    print("❌ Upload failed: \(serverMessage)")
                }
            }
        } catch {
            print("❌ Upload error: \(error.localizedDescription)")
        }
    }

    func computeHash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func fetchHashesForMonthYear(month: Int, year: Int, token: String) async -> Set<String> {
        let urlString = "\(baseURL)\(apiEndpoint)?month=\(month)&year=\(year)"
        print("Fetching hashes for month/year: \(month)/\(year)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL for month/year: \(month)/\(year)")
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(MediaResponse.self, from: data)
            let hashes = response.media.compactMap { $0.fileHash }
            print("📋 Found \(hashes.count) hashes for \(month)/\(year)")
            return Set(hashes)
        } catch {
            print("❌ Failed to fetch hashes for \(month)/\(year): \(error.localizedDescription)")
            return []
        }
    }

    private func generateDateRange(from startDate: Date, to endDate: Date) -> [(month: Int, year: Int)] {
        var dateRange: [(month: Int, year: Int)] = []
        let calendar = Calendar.current
        var currentComponents = calendar.dateComponents([.year, .month], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: endDate)

        while let currentYear = currentComponents.year, let currentMonth = currentComponents.month,
            let endYear = endComponents.year, let endMonth = endComponents.month {
                let isBeforeEndYear = currentYear < endYear
                let isSameYearAndBeforeEndMonth = currentYear == endYear && currentMonth <= endMonth

                if !(isBeforeEndYear || isSameYearAndBeforeEndMonth) {
                    break
                }
                dateRange.append((month: currentMonth, year: currentYear))

                // Move to the next month
                if currentMonth == 12 {
                    currentComponents.month = 1
                    currentComponents.year = currentYear + 1
                } else {
                    currentComponents.month = currentMonth + 1
                }
            }
        return dateRange
    }

    func fetchExistingHashes() async -> Set<String> {
        guard let token = token else { return [] }

        if let lastBackup = lastSuccessfulBackup {
            let currentDate = Date()
            let dateRange = generateDateRange(from: lastBackup, to: currentDate)

            var allHashes: Set<String> = []

            for (month, year) in dateRange {
                let hashes = await fetchHashesForMonthYear(month: month, year: year, token: token)
                allHashes.formUnion(hashes)
            }

            return allHashes
        } else {
            print("No lastSuccessfulBackup date found. Fetching all hashes from server.")

            // Send request without month/year parameters
            let urlString = "\(baseURL)\(apiEndpoint)"
            guard let url = URL(string: urlString) else {
                print("Invalid URL for fetching all hashes.")
                return []
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                print("Raw server response: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")

                let response = try JSONDecoder().decode(MediaResponse.self, from: data)
                let hashes = response.media.compactMap { $0.fileHash }
                print("📋 Found \(hashes.count) hashes from server.")
                return Set(hashes)
            } catch {
                print("❌ Failed to fetch all hashes: \(error.localizedDescription)")
                return []
            }
        }
    }

    func fetchAllImageAssets(completion: @escaping ([PHAsset]) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                completion([])
                return
            }
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let assets = PHAsset.fetchAssets(with: fetchOptions)
            var result: [PHAsset] = []
            assets.enumerateObjects { (asset, _, _) in
                result.append(asset)
            }
            completion(result)
        }
    }
}