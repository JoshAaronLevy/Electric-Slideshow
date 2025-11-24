import SwiftUI

struct SettingsDashboardView: View {
    @State private var showingDevicesSheet = false
    private let tiles: [SettingsTile] = [
        SettingsTile(
            title: "Playback Devices",
            subtitle: "View Available Spotify Connected Devices",
            icon: "hifispeaker.and.homepod",
            action: .playbackDevices
        ),
        // Future tiles can be added here
    ]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 24)
                    .padding(.leading, 16)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4), spacing: 20) {
                    ForEach(tiles) { tile in
                        Button {
                            handleTileAction(tile.action)
                        } label: {
                            SettingsTileView(tile: tile)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                Spacer()
            }
            .sheet(isPresented: $showingDevicesSheet) {
                SpotifyDevicesSheet()
            }
        }
    }
    
    private func handleTileAction(_ action: SettingsTile.Action) {
        switch action {
        case .playbackDevices:
            showingDevicesSheet = true
        }
    }
}

struct SettingsTile: Identifiable {
    enum Action {
        case playbackDevices
        // Add more actions here
    }
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let action: Action
}

struct SettingsTileView: View {
    let tile: SettingsTile
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tile.icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(tile.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(tile.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Spotify Devices Sheet

private struct SpotifyDevicesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = SpotifyAPIService(authService: SpotifyAuthService.shared)
    @State private var devices: [SpotifyDevice] = []
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading Spotify devices...")
                        .padding()
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if devices.isEmpty {
                    ContentUnavailableView {
                        Label("No Devices Found", systemImage: "desktopcomputer")
                    } description: {
                        Text("No available Spotify playback devices were found. Make sure Spotify is open on your computer or another device.")
                    }
                } else {
                    List(devices) { device in
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
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                do {
                    isLoading = true
                    devices = try await apiService.fetchAvailableDevices()
                    isLoading = false
                } catch {
                    print("[SpotifyDevicesSheet] Device fetch error: \(error)")
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    SettingsDashboardView()
}
