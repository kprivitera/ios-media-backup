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
            } else {
                LoginView(onLoginSuccess: {
                    viewModel.isLoggedIn = true
                })
                .environmentObject(viewModel)
            }
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .home:
                HomeView(viewModel: viewModel, path: $path)
            case .details(let mediaItem):
                DetailsView(mediaItem: mediaItem)
            default:
                EmptyView()
            }
        }
    }
}
