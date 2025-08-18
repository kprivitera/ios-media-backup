import SwiftUI

struct DetailsView: View {
    let mediaItem: MediaItem
    @StateObject private var viewModel = MediaViewModel()
    
    init(mediaItem: MediaItem) {
        self.mediaItem = mediaItem
        print("🔥 DetailsView INIT called with mediaItem: \(mediaItem)")
    }

    var body: some View {
        VStack {
            if let url = viewModel.imageURL(for: mediaItem) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .onAppear { print("AsyncImage: Loading state") }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .onAppear { print("AsyncImage: Success - image loaded") }
                    case .failure(let error):
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .foregroundColor(.gray)
                            .onAppear { print("AsyncImage: Failed to load image - \(error)") }
                    @unknown default:
                        EmptyView()
                            .onAppear { print("AsyncImage: Unknown state") }
                    }
                }
                .onAppear { print("URL created successfully: \(url)") }
            } else {
                Text("Invalid file path")
                    .onAppear { print("Failed to create URL from filepath: \(mediaItem.filepath)") }
            }
            
            Text("Media ID: \(mediaItem.id)")
            Text("Date: \(mediaItem.metadataDate)")
        }
        .padding()
        .navigationTitle("Details")
        .onAppear {
            print("=== DetailsView onAppear ===")
            print("MediaItem ID: \(mediaItem.id)")
            print("MediaItem filepath: \(mediaItem.filepath)")
            print("MediaItem date: \(mediaItem.metadataDate)")
            print("========================")
        }
    }
}