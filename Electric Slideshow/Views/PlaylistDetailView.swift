import SwiftUI

/// Playlist detail with read-only metadata and a playlist-level clip selector (Stage 2).
struct PlaylistDetailView: View {
    let playlistId: UUID
    
    @EnvironmentObject private var playlistsStore: PlaylistsStore
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @StateObject private var apiService = SpotifyAPIService(authService: SpotifyAuthService.shared)
    
    @State private var trackRows: [PlaylistTrackRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRowIndex: Int?
    @State private var playlistClipMode: MusicClipMode?
    
    /// Temporary global default; in later stages we will source this from shared playback state.
    private let globalDefaultClipMode: MusicClipMode = .seconds60
    
    private var playlist: AppPlaylist? {
        playlistsStore.getPlaylist(byId: playlistId)
    }
    
    private var effectiveClipMode: MusicClipMode {
        playlistClipMode ?? globalDefaultClipMode
    }
    
    private var selectedRow: PlaylistTrackRow? {
        guard let index = selectedRowIndex, index < trackRows.count else { return nil }
        return trackRows[index]
    }
    
    private var totalEffectiveDurationMs: Int? {
        let durations = trackRows.compactMap { effectiveClipDurationMs(for: $0.metadata) }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }
    
    var body: some View {
        Group {
            if let playlist {
                VStack(alignment: .leading, spacing: 16) {
                    header(for: playlist)
                    
                    HStack(alignment: .top, spacing: 16) {
                        tracksTable
                            .frame(minWidth: 460)
                        
                        inspector
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .padding()
                .navigationTitle(playlist.name)
                .task(id: playlist.trackURIs) {
                    await loadTracks()
                }
                .onChange(of: trackRows.count) { _ in
                    guard let index = selectedRowIndex, index < trackRows.count else {
                        selectedRowIndex = nil
                        return
                    }
                    selectedRowIndex = index
                }
                .onAppear {
                    playlistClipMode = playlist.playlistDefaultClipMode
                }
                .onChange(of: playlist.playlistDefaultClipMode) { newValue in
                    playlistClipMode = newValue
                }
                .onChange(of: playlistClipMode) { newValue in
                    updatePlaylistClipMode(newValue)
                }
            } else {
                ContentUnavailableView {
                    Label("Playlist not found", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("This playlist could not be loaded.")
                }
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func header(for playlist: AppPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(playlist.name)
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Label("\(playlist.trackCount) songs", systemImage: "music.note.list")
                    .foregroundStyle(.secondary)
                
                Divider()
                    .frame(height: 16)
                
                if let totalMs = totalEffectiveDurationMs {
                    Label("Total \(formatDuration(ms: totalMs))", systemImage: "clock")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Total duration unavailable", systemImage: "clock")
                        .foregroundStyle(.secondary)
                }
            }
            
            clipModePicker
        }
    }
    
    private var clipModePicker: some View {
        HStack(spacing: 12) {
            Text("Playlist clip length")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Picker("Playlist clip length", selection: $playlistClipMode) {
                Text("Use global default (\(globalDefaultClipMode.displayName))")
                    .tag(nil as MusicClipMode?)
                ForEach(MusicClipMode.allCases) { mode in
                    Text(mode.displayName).tag(Optional(mode))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)
        }
    }
    
    // MARK: - Tracks table
    
    private var tracksTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            tableHeader
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView("Loading tracks…")
                    if let message = errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if !spotifyAuthService.isAuthenticated {
                ContentUnavailableView {
                    Label("Connect Spotify", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Sign in to Spotify to load track details.")
                }
            } else if trackRows.isEmpty {
                ContentUnavailableView {
                    Label("No tracks", systemImage: "music.note")
                } description: {
                    Text("This playlist has no tracks yet.")
                }
            } else {
                List(selection: $selectedRowIndex) {
                    ForEach(Array(trackRows.enumerated()), id: \.offset) { index, row in
                        trackRowView(row, index: index)
                            .tag(index as Int?)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("#")
                .frame(width: 26, alignment: .trailing)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Title")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Clip")
                .frame(width: 110, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Effective")
                .frame(width: 100, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private func trackRowView(_ row: PlaylistTrackRow, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .frame(width: 26, alignment: .trailing)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(row.metadata?.name ?? "Unknown Track")
                    .font(.body)
                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            clipBadge(text: "Default")
                .frame(width: 110, alignment: .leading)
            
            Text(effectiveClipText(for: row.metadata))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
    
    private func clipBadge(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.blue.opacity(0.12))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
    
    // MARK: - Inspector placeholder
    
    private var inspector: some View {
        Group {
            if let row = selectedRow {
                inspectorDetail(for: row)
            } else {
                ContentUnavailableView {
                    Label("Select a track", systemImage: "cursorarrow.click")
                } description: {
                    Text("Choose a track on the left to see its info here.")
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.12))
        )
    }
    
    @ViewBuilder
    private func inspectorDetail(for row: PlaylistTrackRow) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                albumArtView(for: row.metadata?.album.imageURL)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.metadata?.name ?? "Unknown Track")
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(row.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        clipBadge(text: "Default")
                        if let duration = row.metadata?.durationMs {
                            Text("Full \(formatDuration(ms: duration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Clip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(clipDescription())
                    .font(.body)
                Text("Effective: \(effectiveClipText(for: row.metadata))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            ContentUnavailableView {
                Label("Editing coming soon", systemImage: "slider.horizontal.3")
            } description: {
                Text("Selection is wired up. Clip editing and playback controls arrive in later stages.")
            }
        }
    }
    
    private func clipDescription() -> String {
        if let playlistMode = playlistClipMode {
            return "Default · Playlist: \(playlistMode.displayName)"
        } else {
            return "Default · Global: \(globalDefaultClipMode.displayName)"
        }
    }
    
    @ViewBuilder
    private func albumArtView(for url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.08))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderArt
                @unknown default:
                    placeholderArt
                }
            }
        } else {
            placeholderArt
        }
    }
    
    private var placeholderArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
            Image(systemName: "music.note")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Data loading
    
    @MainActor
    private func loadTracks() async {
        guard let playlist else { return }
        guard spotifyAuthService.isAuthenticated else {
            errorMessage = "Connect Spotify to load track details."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let tracks = try await apiService.fetchTracks(forURIs: playlist.trackURIs)
            let trackMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.uri, $0) })
            trackRows = playlist.trackURIs.map { uri in
                PlaylistTrackRow(id: uri, metadata: trackMap[uri])
            }
        } catch {
            errorMessage = "Failed to load tracks: \(error.localizedDescription)"
            print("[PlaylistDetailView] ERROR loading tracks: \(error)")
            trackRows = []
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func updatePlaylistClipMode(_ mode: MusicClipMode?) {
        guard var playlist else { return }
        // Avoid unnecessary saves when the value hasn't changed.
        if playlist.playlistDefaultClipMode == mode { return }
        playlist.playlistDefaultClipMode = mode
        playlistsStore.updatePlaylist(playlist)
    }
    
    private func effectiveClipDurationMs(for metadata: SpotifyTrack?) -> Int? {
        guard let track = metadata else { return nil }
        if let clipSeconds = effectiveClipMode.clipDuration {
            return min(track.durationMs, Int(clipSeconds * 1000))
        } else {
            return track.durationMs
        }
    }
    
    private func effectiveClipText(for metadata: SpotifyTrack?) -> String {
        guard let durationMs = effectiveClipDurationMs(for: metadata) else {
            return "—"
        }
        
        if effectiveClipMode.clipDuration == nil, let fullDuration = metadata?.durationMs {
            return formatDuration(ms: fullDuration)
        } else {
            return formatDuration(ms: durationMs)
        }
    }
    
    private func formatDuration(ms: Int) -> String {
        let totalSeconds = ms / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Row model

private struct PlaylistTrackRow: Identifiable {
    let id: String
    let metadata: SpotifyTrack?
    
    var subtitle: String {
        guard let meta = metadata else { return id }
        let artist = meta.artistNames
        let album = meta.album.name
        if artist.isEmpty { return album }
        if album.isEmpty { return artist }
        return "\(artist) • \(album)"
    }
}

#Preview {
    let store = PlaylistsStore()
    let sample = AppPlaylist(
        name: "Sample Playlist",
        trackURIs: [
            "spotify:track:0",
            "spotify:track:1"
        ]
    )
    store.addPlaylist(sample)
    
    return NavigationStack {
        PlaylistDetailView(playlistId: sample.id)
            .environmentObject(store)
            .environmentObject(SpotifyAuthService.shared)
    }
}
