import SwiftUI

/// View for selecting songs from Spotify library
struct TrackSelectionView: View {
    @ObservedObject var viewModel: MusicLibraryViewModel
    @State private var selectedTab: LibraryTab = .likedSongs
    @State private var selectedPlaylist: SpotifyPlaylist?
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Loading your music library...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Tab Picker
                Picker("Library View", selection: $selectedTab) {
                    Label("Liked Songs", systemImage: "heart.fill")
                        .tag(LibraryTab.likedSongs)
                    Label("Playlists", systemImage: "music.note.list")
                        .tag(LibraryTab.playlists)
                    Label("Search", systemImage: "magnifyingglass")
                        .tag(LibraryTab.search)
                }
                .pickerStyle(.segmented)
                .pointingHandCursor()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .likedSongs:
                        likedSongsView
                    case .playlists:
                        if let playlist = selectedPlaylist {
                            playlistDetailView(playlist: playlist)
                        } else {
                            playlistsGridView
                        }
                    case .search:
                        searchPlaceholderView
                    }
                }
            }
        }
    }
    
    // MARK: - Liked Songs View
    
    private var likedSongsView: some View {
        Group {
            if viewModel.savedTracks.isEmpty {
                ContentUnavailableView {
                    Label("No Liked Songs", systemImage: "heart")
                } description: {
                    Text("Songs you like on Spotify will appear here")
                }
            } else {
                List {
                    ForEach(viewModel.savedTracks) { track in
                        TrackRow(
                            track: track,
                            isSelected: viewModel.selectedTrackURIs.contains(track.uri)
                        ) {
                            viewModel.toggleTrack(track.uri)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Playlists Grid View
    
    private var playlistsGridView: some View {
        let columns = [
            GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
        ]
        
        return Group {
            if viewModel.spotifyPlaylists.isEmpty {
                ContentUnavailableView {
                    Label("No Playlists", systemImage: "music.note.list")
                } description: {
                    Text("Your Spotify playlists will appear here")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.spotifyPlaylists) { playlist in
                            PlaylistCard(playlist: playlist)
                                .onTapGesture {
                                    selectedPlaylist = playlist
                                    Task {
                                        await viewModel.loadPlaylistTracks(playlistId: playlist.id)
                                    }
                                }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
    
    // MARK: - Playlist Detail View
    
    private func playlistDetailView(playlist: SpotifyPlaylist) -> some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 12) {
                Button {
                    selectedPlaylist = nil
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .pointingHandCursor()
                
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.headline)
                    Text("\(playlist.tracks.total) songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Tracks list
            if viewModel.isLoadingPlaylistTracks {
                ProgressView("Loading playlist tracks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.currentPlaylistTracks.isEmpty {
                ContentUnavailableView {
                    Label("No Tracks", systemImage: "music.note")
                } description: {
                    Text("This playlist is empty")
                }
            } else {
                List {
                    ForEach(viewModel.currentPlaylistTracks) { track in
                        TrackRow(
                            track: track,
                            isSelected: viewModel.selectedTrackURIs.contains(track.uri)
                        ) {
                            viewModel.toggleTrack(track.uri)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Search Placeholder
    
    private var searchPlaceholderView: some View {
        ContentUnavailableView {
            Label("Search Coming Soon", systemImage: "magnifyingglass")
        } description: {
            Text("Search functionality will be available in a future update")
        }
    }
    
    enum LibraryTab {
        case likedSongs
        case playlists
        case search
    }
}

// MARK: - Playlist Card

/// Card displaying a playlist in the grid
private struct PlaylistCard: View {
    let playlist: SpotifyPlaylist
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Playlist icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("\(playlist.tracks.total) song\(playlist.tracks.total == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
    }
}

// MARK: - Track Row

/// Row displaying a single track with selection checkbox
struct TrackRow: View {
    let track: SpotifyTrack
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.body)
                Text(track.artistNames)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .pointingHandCursor()
    }
}
