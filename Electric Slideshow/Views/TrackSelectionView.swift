import SwiftUI

/// View for selecting songs from Spotify library
struct TrackSelectionView: View {
    @ObservedObject var viewModel: MusicLibraryViewModel
    
    var body: some View {
        Group {
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
                tracksList
            }
        }
    }
    
    private var tracksList: some View {
        List {
            if !viewModel.savedTracks.isEmpty {
                Section("Liked Songs") {
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
            
            ForEach(viewModel.spotifyPlaylists) { playlist in
                Section(playlist.name) {
                    // Would need to fetch tracks for each playlist
                    // This is simplified for MVP
                    Text("\(playlist.tracks.total) songs")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

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
    }
}
