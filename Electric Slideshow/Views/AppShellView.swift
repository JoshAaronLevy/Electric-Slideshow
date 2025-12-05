//
//  AppShellView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Root view that manages the permission flow and navigation
struct AppShellView: View {
    @StateObject private var permissionVM: PermissionViewModel
    @State private var showingPermissionInstructions = false

    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @StateObject private var spotifyAPIService = SpotifyAPIService(authService: SpotifyAuthService.shared)
    @State private var showingSpotifyReauthAlert = false
    @State private var spotifyReauthMessage: String?
    @State private var prewarmedPlaybackBackend: MusicPlaybackBackend?
    
    // Player initialization error alert
    @State private var showingPlayerInitError = false
    @State private var playerInitErrorMessage: String = ""
    @State private var playerInitLogs: String = ""

    init(photoService: PhotoLibraryService) {
        _permissionVM = StateObject(wrappedValue: PermissionViewModel(photoService: photoService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Show notification bar if permission is not granted
            if permissionVM.state == .notDetermined || permissionVM.state == .denied {
                PermissionNotificationBar(
                    state: permissionVM.state,
                    onRequestAccess: {
                        Task {
                            await permissionVM.requestAuthorization()
                        }
                    },
                    onShowInstructions: {
                        showingPermissionInstructions = true
                    }
                )
            }
            
            // Main content - always show (even if permissions not granted)
            if permissionVM.state == .checking {
                CheckingPermissionView()
            } else {
                AppMainView()
            }
        }
        .sheet(isPresented: $showingPermissionInstructions) {
            PermissionInstructionsSheet(permissionVM: permissionVM)
        }
        .onAppear {
            permissionVM.checkAuthorizationStatus()

            Task {
                await validateSpotifyConnectionOnLaunch()
            }

            // If already authenticated at launch, pre-warm the internal player
            prewarmInternalPlayerIfNeeded()
        }
        .onChange(of: spotifyAuthService.isAuthenticated) { isAuthed in
            if isAuthed {
                prewarmInternalPlayerIfNeeded()
            }
        }
        .alert("Spotify Connection Issue", isPresented: $showingSpotifyReauthAlert) {
            Button("Not Now", role: .cancel) {
                // User can keep using slideshows without Spotify.
            }
            .pointingHandCursor()
            Button("Reconnect") {
                spotifyAuthService.beginAuthentication()
            }
            .pointingHandCursor()
        } message: {
            Text(spotifyReauthMessage ?? "Your Spotify account is not connected. Would you like to connect now?")
        }
        .alert("Spotify Player Initialization Failed", isPresented: $showingPlayerInitError) {
            Button("Dismiss", role: .cancel) {
                PlayerInitLogger.shared.clearLogs()
            }
            .pointingHandCursor()
        } message: {
            PlayerInitErrorAlertContent(
                errorMessage: playerInitErrorMessage,
                logs: playerInitLogs
            )
        }
    }

    // MARK: - Spotify Connection Validation

    /// Initializes the internal web player early so it is ready when a slideshow starts.
    private func prewarmInternalPlayerIfNeeded() {
        // Only prewarm when the internal player is the selected backend.
        guard PlaybackBackendFactory.defaultMode == .internalWebPlayer else {
            print("[AppShellView] Skipping player pre-warm: Backend mode is not internal web player")
            PlayerInitLogger.shared.log(
                "Skipping player pre-warm: Backend mode is not internal web player",
                source: "AppShellView"
            )
            return
        }
        guard spotifyAuthService.isAuthenticated else {
            print("[AppShellView] Skipping player pre-warm: User is not authenticated")
            PlayerInitLogger.shared.log(
                "Skipping player pre-warm: User is not authenticated",
                source: "AppShellView"
            )
            return
        }
        guard prewarmedPlaybackBackend == nil else {
            print("[AppShellView] Skipping player pre-warm: Backend already prewarmed")
            PlayerInitLogger.shared.log(
                "Skipping player pre-warm: Backend already prewarmed",
                source: "AppShellView"
            )
            return
        }
        print("[AppShellView] Triggering internal player pre-warm")
        PlayerInitLogger.shared.log(
            "Triggering internal player pre-warm",
            source: "AppShellView"
        )
        
        // Clear previous logs before starting new initialization
        PlayerInitLogger.shared.clearLogs()
        
        // Create backend and set up error callback
        let backend = PlaybackBackendFactory.prewarmInternalBackend(spotifyAPIService: spotifyAPIService)
        
        // Wire up error callback to show alert with logs
        if let internalBackend = backend as? SpotifyInternalPlaybackBackend {
            internalBackend.onError = { error in
                Task { @MainActor in
                    self.handlePlayerInitError(error)
                }
            }
        }
        
        prewarmedPlaybackBackend = backend
    }
    
    private func handlePlayerInitError(_ error: PlaybackError) {
        let errorMessage: String
        switch error {
        case .backend(let message):
            errorMessage = message
        case .notReady:
            errorMessage = "Player not ready"
        case .unauthorized:
            errorMessage = "Spotify authorization failed"
        case .network:
            errorMessage = "Network error while initializing player"
        }
        
        playerInitErrorMessage = errorMessage
        playerInitLogs = PlayerInitLogger.shared.formattedLogs()
        showingPlayerInitError = true
        
        print("[AppShellView] Player initialization failed: \(errorMessage)")
    }

    private func validateSpotifyConnectionOnLaunch() async {
        // Only bother checking if we already *think* we’re authenticated.
        guard spotifyAuthService.isAuthenticated else {
            return
        }

        do {
            // Uses the same API call the user sheet uses to load profile.
            let profile = try await spotifyAPIService.fetchUserProfile()
            print("[AppShell] Verified Spotify profile for \(profile.displayName ?? profile.id)")
        } catch {
            print("[AppShell] Spotify profile check failed on launch: \(error.localizedDescription)")

            await MainActor.run {
                // Make absolutely sure we don't keep a stale "connected" state.
                spotifyAuthService.signOut()

                spotifyReauthMessage =
                    "Your Spotify connection appears to be invalid or has expired. " +
                    "Would you like to reconnect now?"

                showingSpotifyReauthAlert = true
            }
        }
    }
}


// MARK: - Permission States

/// Shown while checking permission status
private struct CheckingPermissionView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking Photos permission…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when permission is not yet determined
private struct RequestPermissionView: View {
    @ObservedObject var permissionVM: PermissionViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.bounce, options: .speed(0.5))
            
            VStack(spacing: 12) {
                Text("Photos Access Required")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Electric Slideshow needs access to your Photos library to create and display slideshows.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            Button {
                Task {
                    await permissionVM.requestAuthorization()
                }
            } label: {
                Label("Grant Access", systemImage: "lock.open")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
            .pointingHandCursor()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Notification bar shown at the top when photo access is not granted
private struct PermissionNotificationBar: View {
    let state: PermissionState
    let onRequestAccess: () -> Void
    let onShowInstructions: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state == .notDetermined ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(state == .notDetermined ? .blue : .orange)
            
            Text(state == .notDetermined ? "Photo access required" : "Photo access denied")
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if state == .notDetermined {
                Button("Grant Access") {
                    onRequestAccess()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .pointingHandCursor()
            } else {
                Button("View Instructions") {
                    onShowInstructions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .pointingHandCursor()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            (state == .notDetermined ? Color.blue : Color.orange)
                .opacity(0.1)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
}

/// Sheet with instructions for granting photo access
private struct PermissionInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var permissionVM: PermissionViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(.top, 20)
            
            // Content
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.gradient)
                    .symbolEffect(.pulse.byLayer)
                
                VStack(spacing: 12) {
                    Text("Photos Access Denied")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Electric Slideshow requires Photos access to work. Please grant access in System Settings.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("To enable access:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text("1")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.blue))
                            Text("Open System Settings")
                        }
                        
                        HStack(spacing: 10) {
                            Text("2")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.blue))
                            Text("Go to Privacy & Security → Photos")
                        }
                        
                        HStack(spacing: 10) {
                            Text("3")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.blue))
                            Text("Enable access for Electric Slideshow")
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 400)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open System Settings", systemImage: "gear")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .pointingHandCursor()
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(minWidth: 500, minHeight: 600)
    }
}

/// Shown when permission is denied or restricted (kept for backward compatibility but no longer used in main flow)
private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange.gradient)
                .symbolEffect(.pulse.byLayer)
            
            VStack(spacing: 12) {
                Text("Photos Access Denied")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Electric Slideshow requires Photos access to work. Please grant access in System Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("To enable access:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("1")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.blue))
                        Text("Open System Settings")
                    }
                    
                    HStack(spacing: 10) {
                        Text("2")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.blue))
                        Text("Go to Privacy & Security → Photos")
                    }
                    
                    HStack(spacing: 10) {
                        Text("3")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.blue))
                        Text("Enable access for Electric Slideshow")
                    }
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open System Settings", systemImage: "gear")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .pointingHandCursor()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Checking") {
    AppShellView(photoService: PhotoLibraryService())
}

#Preview("Granted") {
    let service = PhotoLibraryService()
    AppShellView(photoService: service)
}

// MARK: - Player Init Error Alert Content

/// Custom view for displaying player initialization error with logs
private struct PlayerInitErrorAlertContent: View {
    let errorMessage: String
    let logs: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error: \(errorMessage)")
                .font(.body)
            
            Text("Initialization Logs:")
                .font(.headline)
                .padding(.top, 8)
            
            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)
            }
            .frame(maxHeight: 200)
        }
        .frame(maxWidth: 500)
    }
}
