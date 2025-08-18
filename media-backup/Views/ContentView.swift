import SwiftUI

enum Route: Hashable {
    case login
    case home
    case details(MediaItem)
}

struct ContentView: View {
    @StateObject private var viewModel = MediaViewModel()
    @State private var path: [Route] = [] // Navigation path

    var body: some View {
        NavigationStack(path: $path) {
            if viewModel.isLoggedIn {
                HomeView(viewModel: viewModel, path: $path)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .home:
                            HomeView(viewModel: viewModel, path: $path)
                                .onAppear {
                                    print("📍 ContentView: Navigated to HomeView")
                                }
                        case .details(let mediaItem):
                            DetailsView(mediaItem: mediaItem)
                                .onAppear {
                                    print("🎯 ContentView: About to create DetailsView for mediaItem: \(mediaItem.id)")
                                    print("📍 ContentView: DetailsView appeared for mediaItem: \(mediaItem.id)")
                                }
                        default:
                            EmptyView()
                                .onAppear {
                                    print("⚠️ ContentView: Unknown route triggered")
                                }
                        }
                    }
            } else {
                LoginView(onLoginSuccess: {
                    viewModel.isLoggedIn = true
                })
                .environmentObject(viewModel)
            }
        }
        .onChange(of: path) { newPath in
            print("🔄 ContentView: Path changed to: \(newPath)")
            print("🔄 ContentView: Path count: \(newPath.count)")
        }
    }
}
