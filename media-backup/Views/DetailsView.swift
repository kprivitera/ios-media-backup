import SwiftUI

struct DetailsView: View {
    let mediaItem: MediaItem

    var body: some View {
        VStack {
            if let url = URL(string: mediaItem.filepath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    case .failure:
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            Text("Media ID: \(mediaItem.id)")
            Text("Date: \(mediaItem.metadataDate)")
        }
        .padding()
        .navigationTitle("Details")
    }
}
