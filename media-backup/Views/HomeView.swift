import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: MediaViewModel
    @Binding var path: [Route]

    @State private var selectedMonthYear: MonthYear?

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
                                            path.append(.details(item)) // Navigate to details
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
