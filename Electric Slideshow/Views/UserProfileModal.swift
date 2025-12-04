import SwiftUI

/// Modal view for user profile and Spotify connection management
struct UserProfileModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @StateObject private var apiService: SpotifyAPIService
    
    @State private var userProfile: SpotifyUser?
    @State private var isLoadingProfile = false
    @State private var profileError: String?
    
    init() {
        self._apiService = StateObject(wrappedValue: SpotifyAPIService(authService: SpotifyAuthService.shared))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
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
            .padding(.horizontal, 20)
            
            // Content
            Group {
                if spotifyAuthService.isAuthenticated {
                    connectedView
                } else {
                    notConnectedView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 500)
        .onAppear {
            if spotifyAuthService.isAuthenticated {
                loadUserProfile()
            }
        }
    }
    
    // MARK: - Not Connected View
    
    private var notConnectedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 12) {
                Text("Connect to Spotify")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Link your Spotify account to create playlists and add music to your slideshows.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            
            Button {
                spotifyAuthService.beginAuthentication()
                dismiss()
            } label: {
                Label("Connect with Spotify", systemImage: "link")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .pointingHandCursor()
            
            if let error = spotifyAuthService.authError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(40)
    }
    
    // MARK: - Connected View
    
    private var connectedView: some View {
        VStack(spacing: 32) {
            // Profile icon
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            if isLoadingProfile {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading profile...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let error = profileError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    
                    Text("Failed to load profile")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        loadUserProfile()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .pointingHandCursor()
                }
                .padding()
            } else if let profile = userProfile {
                VStack(spacing: 16) {
                    // User info
                    VStack(spacing: 8) {
                        if let displayName = profile.displayName {
                            Text(displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        if let email = profile.email {
                            Text(email)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Connected status badge
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected to Spotify")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
            
            // Disconnect button
            Button(role: .destructive) {
                handleDisconnect()
            } label: {
                Label("Disconnect", systemImage: "link.badge.xmark")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .pointingHandCursor()
        }
        .padding(.top, 20)
    }
    
    // MARK: - Actions
    
    private func loadUserProfile() {
        isLoadingProfile = true
        profileError = nil
        
        Task {
            do {
                let profile = try await apiService.fetchUserProfile()
                await MainActor.run {
                    self.userProfile = profile
                    self.isLoadingProfile = false
                }
            } catch {
                await MainActor.run {
                    self.profileError = error.localizedDescription
                    self.isLoadingProfile = false
                }
            }
        }
    }
    
    private func handleDisconnect() {
        spotifyAuthService.signOut()
        dismiss()
    }
}

#Preview("Not Connected") {
    UserProfileModal()
        .environmentObject(SpotifyAuthService.shared)
}

#Preview("Connected") {
    let authService = SpotifyAuthService.shared
    return UserProfileModal()
        .environmentObject(authService)
}
