import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MediaViewModel()
    @State private var selectedMonthYear: MonthYear? // Tracks the selected month and year

    var body: some View {
        NavigationView {
            VStack {
                Picker("Select Month", selection: $selectedMonthYear) {
                    ForEach(viewModel.availableMonths) { monthYear in
                        Text("\(monthYear.month)/\(monthYear.year)")
                            .tag(monthYear as MonthYear?)
                    }
                }
                .pickerStyle(MenuPickerStyle()) // Dropdown style 
                .padding()
                .onChange(of: selectedMonthYear) {
                    if let selected = selectedMonthYear {
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
                  selectedMonthYear = firstMonthYear // Set the default selection
                  await viewModel.fetchMedia(for: firstMonthYear) // Fetch media for the default selection
                }
            }
            .refreshable {
                await viewModel.fetchMetadata()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
