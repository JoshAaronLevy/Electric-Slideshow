import SwiftUI

/// View for displaying Spotify connection and managing app playlists
struct PlaylistsView: View {
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @EnvironmentObject private var playlistsStore: PlaylistsStore
    @StateObject private var apiService: SpotifyAPIService
    @State private var showingNewPlaylistFlow = false
    
    init() {
        self._apiService = StateObject(wrappedValue: SpotifyAPIService(authService: SpotifyAuthService.shared))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if spotifyAuthService.isAuthenticated {
                    if playlistsStore.playlists.isEmpty {
                        emptyStateView
                    } else {
                        playlistsView
                    }
                } else {
                    notConnectedView
                }
            }
        }
    }
    
    private var playlistsView: some View {
        List {
            ForEach(playlistsStore.playlists) { playlist in
                PlaylistRow(playlist: playlist)
            }
            .onDelete { offsets in
                playlistsStore.deletePlaylist(at: offsets)
            }
        }
        .navigationTitle("Playlists")
        .overlay(alignment: .bottomTrailing) {
            floatingActionButton
        }
        .sheet(isPresented: $showingNewPlaylistFlow) {
            NewPlaylistFlowView(
                spotifyAPIService: apiService,
                playlistsStore: playlistsStore
            ) { playlist in
                playlistsStore.addPlaylist(playlist)
            }
        }
    }
    
    // MARK: - Floating Action Button
    
    private var floatingActionButton: some View {
        Button {
            showingNewPlaylistFlow = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.appBlue)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(24)
    }
    
    private var notConnectedView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                Text("Connect Spotify")
                    .font(.title)
                
                Text("Connect your Spotify account to create playlists for your slideshows")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                Button("Connect with Spotify") {
                    spotifyAuthService.beginAuthentication()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appBlue)
                
                if let error = spotifyAuthService.authError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Playlists Yet", systemImage: "music.note.list")
        } description: {
            Text("Create a playlist to add music to your slideshows")
        } actions: {
            Button {
                showingNewPlaylistFlow = true
            } label: {
                Text("Create Playlist")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appBlue)
        }
    }
}

struct PlaylistRow: View {
    let playlist: AppPlaylist
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                Text("\(playlist.trackCount) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlaylistsView()
        .environmentObject(SpotifyAuthService.shared)
        .environmentObject(PlaylistsStore())
}
