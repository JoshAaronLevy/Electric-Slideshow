import SwiftUI

struct SettingsDashboardView: View {
    @State private var showingDevicesSheet = false
    @State private var showingInternalPlayerSheet = false
    @ObservedObject private var devicesViewModel: SpotifyDevicesViewModel  // ← changed
    @EnvironmentObject private var internalPlayerManager: InternalPlayerManager

    init(devicesViewModel: SpotifyDevicesViewModel) {
        self.devicesViewModel = devicesViewModel
    }

    private let tiles: [SettingsTile] = [
        SettingsTile(
            title: "Playback Devices",
            subtitle: "View Available Spotify Connected Devices",
            icon: "hifispeaker.and.homepod",
            action: .playbackDevices
        ),
        SettingsTile(
            title: "Internal Player (Dev)",
            subtitle: "Launch Electron Internal Player for Testing",
            icon: "play.circle.fill",
            action: .internalPlayer
        )
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 24)
                    .padding(.leading, 16)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4),
                    spacing: 20
                ) {
                    ForEach(tiles) { tile in
                        Button {
                            handleTileAction(tile.action)
                        } label: {
                            SettingsTileView(tile: tile)
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .sheet(isPresented: $showingDevicesSheet) {
                SpotifyDevicesSheetView(viewModel: devicesViewModel)
            }
            .sheet(isPresented: $showingInternalPlayerSheet) {
                InternalPlayerDebugSheet()
                    .environmentObject(internalPlayerManager)
            }
        }
    }

    private func handleTileAction(_ action: SettingsTile.Action) {
        print("[SettingsDashboardView] handleTileAction called with: \(action)")
        switch action {
        case .playbackDevices:
            print("[SettingsDashboardView] Setting showingDevicesSheet = true")
            showingDevicesSheet = true
        case .internalPlayer:
            print("[SettingsDashboardView] Setting showingInternalPlayerSheet = true")
            showingInternalPlayerSheet = true
        }
    }
}

struct SettingsTile: Identifiable {
    enum Action {
        case playbackDevices
        case internalPlayer
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
                    .pointingHandCursor()
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
}

// MARK: - Internal Player Debug Sheet

struct InternalPlayerDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var internalPlayerManager: InternalPlayerManager
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @State private var isStarting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.headline)
                    HStack {
                        Circle()
                            .fill(internalPlayerManager.isRunning ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                        Text(internalPlayerManager.isRunning ? "Running" : "Not Running")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Error Message
                if let error = errorMessage ?? internalPlayerManager.lastError {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Controls
                VStack(spacing: 12) {
                    Button {
                        startInternalPlayer()
                    } label: {
                        HStack {
                            if isStarting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                            Text("Start Internal Player")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(internalPlayerManager.isRunning || isStarting)
                    
                    Button {
                        internalPlayerManager.stopInternalPlayer()
                        errorMessage = nil
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Internal Player")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!internalPlayerManager.isRunning)
                }
                
                // Info Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    Text("This launches the Electron-based internal player from your local development repository. Make sure you've run `npm install` in the electric-slideshow-internal-player directory first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding()
            .navigationTitle("Internal Player Debug")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func startInternalPlayer() {
        isStarting = true
        errorMessage = nil
        
        Task {
            do {
                // Get valid access token
                let token = try await spotifyAuthService.getValidAccessToken()
                
                // Start the internal player
                try internalPlayerManager.ensureInternalPlayerRunning(
                    accessToken: token,
                    backendBaseURL: SpotifyConfig.backendBaseURL
                )
                
                isStarting = false
            } catch {
                errorMessage = "Failed to start: \(error.localizedDescription)"
                isStarting = false
                print("[InternalPlayerDebugSheet] Error starting player: \(error)")
            }
        }
    }
}

#Preview {
    SettingsDashboardView(devicesViewModel: SpotifyDevicesViewModel())
}
