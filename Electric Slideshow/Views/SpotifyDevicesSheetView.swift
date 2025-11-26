import SwiftUI

struct SpotifyDevicesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SpotifyDevicesViewModel   // ← changed

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading Spotify devices...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)

                        Text("Unable to load devices")
                            .font(.headline)

                        Text(error)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Try Again") {
                            Task { await viewModel.loadDevices() }
                        }
                    }
                    .padding()
                } else {
                    List(viewModel.devices) { device in
                        HStack(spacing: 12) {
                            Image(systemName: device.is_active ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(device.is_active ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if device.is_active {
                                Text("Active")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Spotify Devices")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            print("[SpotifyDevicesSheetView] View appeared, starting loadDevices task")
            await viewModel.loadDevices()
        }
        .onAppear {
            print("[SpotifyDevicesSheetView] onAppear called")
        }
    }
}
