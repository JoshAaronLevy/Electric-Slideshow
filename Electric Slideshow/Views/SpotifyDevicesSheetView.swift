import SwiftUI

struct SpotifyDevicesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: SpotifyDevicesViewModel
    
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
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if viewModel.devices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "desktopcomputer")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No active Spotify devices found. To use Spotify playback, open Spotify on this Mac (or another device), start playing something in Spotify once, then come back and refresh.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        Task { await viewModel.loadDevices() }
                    }
                }
            }
        }
        .task { await viewModel.loadDevices() }
    }
}
