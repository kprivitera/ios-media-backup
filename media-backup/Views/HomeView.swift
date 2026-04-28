import SwiftUI
import PhotosUI

struct HomeView: View {
    @ObservedObject var viewModel: MediaViewModel
    @Binding var path: [Route]

    @State private var selectedMonthYear: MonthYear?
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        VStack {
            Picker("Select Month", selection: $selectedMonthYear) {
                ForEach(viewModel.availableMonths) { monthYear in
                    Text("\(monthYear.month)/\(monthYear.year)")
                        .tag(monthYear as MonthYear?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .onChange(of: selectedMonthYear) { newValue in
                if let selected = newValue {
                    Task {
                        await viewModel.fetchMedia(for: selected)
                    }
                }
            }

            // Button("Back Up Photos") {
            //     Task {
            //         await viewModel.backupPhotos()
            //     }
            // }
            // .padding()

            Button("Back Up All Photos") {
                Task {
                    let existingHashes = await viewModel.fetchExistingHashes()
                    print("🔍 Existing server hashes: \(existingHashes)")
                    
                    viewModel.fetchAllImageAssets { assets in
                        print("Found \(assets.count) images on device")
                        let lastBackup = viewModel.lastSuccessfulBackup
                        for (index, asset) in assets.enumerated() {
                            // Only back up if asset is newer than last backup
                            let assetDate = asset.modificationDate ?? asset.creationDate
                            if let lastBackup = lastBackup, let assetDate = assetDate, assetDate <= lastBackup {
                                print("⏭️ Skipping asset #\(index + 1) — not newer than last backup")
                                continue
                            }

                            let options = PHImageRequestOptions()
                            options.isSynchronous = false
                            options.deliveryMode = .highQualityFormat

                            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, info in
                                guard let imageData = data else {
                                    print("❌ Failed to get data for asset #\(index + 1)")
                                    return
                                }

                                let hash = viewModel.computeHash(for: imageData)
                                print("🔑 Local hash for asset #\(index + 1): \(hash)")

                                if existingHashes.contains(hash) {
                                    print("⏭️ Skipping asset #\(index + 1) — already backed up (hash: \(hash.prefix(12))...)")
                                    return
                                }

                                print("✅ Uploading asset #\(index + 1): \(imageData.count) bytes (hash: \(hash.prefix(12))...)")
                                let filename = "\(asset.localIdentifier.replacingOccurrences(of: "/", with: "_")).jpg"
                                Task {
                                    await viewModel.uploadImage(imageData, filename: filename)
                                }
                            }
                        }
                    }
                }
            }
            .padding()

            // PhotosPicker(
            //     selection: $selectedItems,
            //     matching: .images,
            //     photoLibrary: .shared()
            // ) {
            //     Text("Back Up Photos")
            //         .padding()
            // }
            // .onChange(of: selectedItems) { newItems in
            //     for item in newItems {
            //         Task {
            //             if let data = try? await item.loadTransferable(type: Data.self) {
            //                 await viewModel.backupPhotos()
            //             }
            //         }
            //     }
            // }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.mediaItems.isEmpty {
                ProgressView("Loading...")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.mediaItems) { item in
                            AsyncImage(url: viewModel.imageURL(for: item)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(height: 200)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .padding(.horizontal)
                                        .onTapGesture {
                                            print("🚀 HomeView: Tapping image, navigating to details for item: \(item.id)")
                                            print("🚀 HomeView: Current path before append: \(path)")
                                            path.append(.details(item)) // Navigate to details
                                            print("🚀 HomeView: Path after append: \(path)")
                                        }
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
                    }
                }
            }
        }
        .navigationTitle("Photos")
        .task {
            await viewModel.fetchMetadata()
            if let firstMonthYear = viewModel.availableMonths.first {
                selectedMonthYear = firstMonthYear
                await viewModel.fetchMedia(for: firstMonthYear)
            }
        }
        .refreshable {
            await viewModel.fetchMetadata()
        }
    }
}
