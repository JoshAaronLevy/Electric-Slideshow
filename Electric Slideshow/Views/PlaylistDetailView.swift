import SwiftUI

/// Playlist detail with metadata, playlist-level clip selector, and per-track clip editing (Stage 4).
struct PlaylistDetailView: View {
    let playlistId: UUID
    
    @EnvironmentObject private var playlistsStore: PlaylistsStore
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = SpotifyAPIService(authService: SpotifyAuthService.shared)
    
    @State private var trackRows: [PlaylistTrackRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRowIndex: Int?
    @State private var playlistClipMode: MusicClipMode?
    @State private var startText: String = ""
    @State private var endText: String = ""
    @State private var inspectorError: String?
    
    @State private var playbackBackend: MusicPlaybackBackend?
    @State private var playbackState: PlaybackState = .idle
    @State private var playbackDeviceId: String?
    @State private var playbackProgressTimer: Timer?
    @State private var previewTimer: Timer?
    @State private var playbackMessage: String?
    @State private var showingAddTrackSheet = false
    @State private var newTrackURI: String = ""
    @State private var addTrackError: String?
    
    /// Temporary global default; in later stages we will source this from shared playback state.
    private let globalDefaultClipMode: MusicClipMode = .seconds60
    private let minCustomClipDeltaMs = 500
    
    private var playlist: AppPlaylist? {
        playlistsStore.getPlaylist(byId: playlistId)
    }
    
    private var effectiveClipMode: MusicClipMode {
        playlistClipMode ?? .fullSong
    }
    
    private var selectedRow: PlaylistTrackRow? {
        guard let index = selectedRowIndex, index < trackRows.count else { return nil }
        return trackRows[index]
    }
    
    private var totalEffectiveDurationMs: Int? {
        let durations = trackRows.compactMap { effectiveClipDurationMs(for: $0) }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }
    
    var body: some View {
        Group {
            if let playlist {
                VStack(alignment: .leading, spacing: 16) {
                    header(for: playlist)

                    GeometryReader { proxy in
                        HStack(alignment: .top, spacing: 16) {
                            tracksTable
                                .frame(width: max(proxy.size.width * 0.65, 460))
                            
                            inspector
                                .frame(width: max(proxy.size.width * 0.35, 300), alignment: .topLeading)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    }
                }
                .padding()
                .navigationTitle(playlist.name)
                .task(id: playlist.trackURIs) {
                    await loadTracks()
                }
                .onAppear {
                    playlistClipMode = playlist.playlistDefaultClipMode ?? .fullSong
                    syncInspectorFields()
                    preparePlaybackBackendIfNeeded()
                }
                .onChange(of: playlist.playlistDefaultClipMode) { newValue in
                    playlistClipMode = newValue ?? .fullSong
                }
                .onChange(of: playlistClipMode) { newValue in
                    updatePlaylistClipMode(newValue)
                }
                .onChange(of: trackRows.count) { _ in
                    guard let index = selectedRowIndex, index < trackRows.count else {
                        selectedRowIndex = nil
                        return
                    }
                    selectedRowIndex = index
                    syncInspectorFields()
                }
                .onChange(of: selectedRowIndex) { _ in
                    syncInspectorFields()
                }
                .onChange(of: playbackState.isPlaying) { isPlaying in
                    if isPlaying {
                        startPlaybackProgressTimer()
                    } else {
                        stopPlaybackProgressTimer()
                    }
                }
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            removeSelectedTrack()
                        } label: {
                            Label("Remove Track", systemImage: "trash")
                        }
                        .disabled(selectedRowIndex == nil)
                        
                        Button {
                            showingAddTrackSheet = true
                            addTrackError = nil
                            newTrackURI = ""
                        } label: {
                            Label("Add Track", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddTrackSheet) {
                    addTrackSheet
                }
                .onDisappear {
                    stopPlaybackProgressTimer()
                    previewTimer?.invalidate()
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
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                
                Text(playlist.name)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 16) {
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
                
                Divider()
                    .frame(height: 16)

                HStack(spacing: 4) {
                    Text("Song duration:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $playlistClipMode) {
                        ForEach(MusicClipMode.allCases) { mode in
                            Text(mode.displayName).tag(Optional(mode))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                }
            }
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
                    .onMove(perform: moveRows)
                    .onDelete(perform: deleteRows)
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
                .frame(width: 120, alignment: .leading)
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
                Text(row.title)
                    .font(.body)
                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            clipBadge(for: row.track.clipMode)
                .frame(width: 110, alignment: .leading)
            
            Text(effectiveClipText(for: row))
                .font(.callout)
                .foregroundColor(row.validationError == nil ? Color.secondary : Color.red)
                .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
    
    private func clipBadge(for mode: PlaylistTrack.ClipMode) -> some View {
        let isCustom = mode == .custom
        let color: Color = isCustom ? .purple : .blue
        
        return Text(isCustom ? "Custom" : "Default")
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
    
    // MARK: - Inspector
    
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
                albumArtView(for: row.metadata?.album.imageURL ?? row.track.albumArtURL)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(row.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        clipBadge(for: row.track.clipMode)
                        if let duration = row.metadata?.durationMs ?? row.track.durationMs {
                            Text("Full \(formatDuration(ms: duration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Clip mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Clip mode", selection: Binding(
                    get: { row.track.clipMode },
                    set: { setClipMode($0) }
                )) {
                    Text("Default").tag(PlaylistTrack.ClipMode.default)
                    Text("Custom").tag(PlaylistTrack.ClipMode.custom)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                
                if row.track.clipMode == .custom {
                    customClipEditor(for: row)
                } else {
                    Text(defaultClipDescription())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Effective clip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(effectiveClipText(for: row))
                    .font(.body)
                    .foregroundColor(row.validationError == nil ? Color.primary : Color.red)
                if let warning = row.validationError ?? inspectorError {
                    Text(warning)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            playbackControls(for: row)
        }
    }
    
    @ViewBuilder
    private func customClipEditor(for row: PlaylistTrackRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("mm:ss", text: $startText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: startText) { _ in
                            handleCustomFieldChange()
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("mm:ss", text: $endText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: endText) { _ in
                            handleCustomFieldChange()
                        }
                }
                
                Button("Reset to default") {
                    resetToDefault()
                }
                .buttonStyle(.borderless)
            }
            
            if let duration = row.metadata?.durationMs ?? row.track.durationMs {
                Text("Track length \(formatDuration(ms: duration)). Use mm:ss or hh:mm:ss.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Use mm:ss or hh:mm:ss. End must be after start.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func defaultClipDescription() -> String {
        if let playlistMode = playlistClipMode {
            return "Uses playlist default (\(playlistMode.displayName))"
        } else {
            return "Uses global default (\(globalDefaultClipMode.displayName))"
        }
    }

    private var addTrackSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Track")
                .font(.headline)
            
            TextField("Spotify track URI", text: $newTrackURI)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    handleAddTrack()
                }
            
            if let error = addTrackError {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    showingAddTrackSheet = false
                }
                Button("Add") {
                    handleAddTrack()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
    }
    
    @ViewBuilder
    private func playbackControls(for row: PlaylistTrackRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Playback")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let reason = playbackUnavailableReason(for: row) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Button(playPauseLabel) {
                        togglePlayPause(for: row)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canControlPlayback)
                    
                    Button("Mark Start") {
                        Task { await markCurrentPosition(as: .start) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canControlPlayback)
                    
                    Button("Mark End") {
                        Task { await markCurrentPosition(as: .end) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canControlPlayback)
                    
                    Button("Back 10s") {
                        Task { await jumpBackward() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canControlPlayback || playbackState.trackUri != row.track.uri)
                    
                    Button("Preview") {
                        previewClip(for: row)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canControlPlayback)
                }
                
                playbackProgress(for: row)
                
                if let message = playbackMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func playbackProgress(for row: PlaylistTrackRow) -> some View {
        if playbackState.trackUri == row.track.uri, playbackState.durationMs > 0 {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(
                    value: Double(playbackState.positionMs),
                    total: Double(playbackState.durationMs)
                )
                
                HStack {
                    Text(formatTimestamp(ms: playbackState.positionMs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        Task { await jumpBackward() }
                    } label: {
                        Label("Back 10s", systemImage: "gobackward.10")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canControlPlayback)
                    
                    Spacer()
                    
                    Text(formatTimestamp(ms: playbackState.durationMs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
    
    // MARK: - Playback helpers
    
    private var canControlPlayback: Bool {
        guard let backend = playbackBackend else { return false }
        return backend.isReady
    }
    
    private var playPauseLabel: String {
        playbackState.isPlaying ? "Pause" : "Play"
    }
    
    private func playbackUnavailableReason(for row: PlaylistTrackRow) -> String? {
        guard spotifyAuthService.isAuthenticated else {
            return "Connect Spotify to enable preview and marking."
        }
        guard let backend = playbackBackend else {
            return "Player not initialized yet."
        }
        if !backend.isReady {
            return "Player is starting up…"
        }
        return nil
    }
    
    private func preparePlaybackBackendIfNeeded() {
        guard playbackBackend == nil else { return }
        guard spotifyAuthService.isAuthenticated else { return }
        
        if let backend = PlaybackBackendFactory.makeBackend(mode: PlaybackBackendFactory.defaultMode, spotifyAPIService: apiService) {
            backend.onStateChanged = { state in
                DispatchQueue.main.async {
                    self.playbackState = state
                    state.isPlaying ? self.startPlaybackProgressTimer() : self.stopPlaybackProgressTimer()
                }
            }
            backend.onError = { error in
                DispatchQueue.main.async {
                    self.playbackMessage = "Playback error: \(error)"
                }
            }
            backend.initialize()
            playbackBackend = backend
        } else {
            playbackMessage = "No playback backend available."
        }
    }
    
    private func togglePlayPause(for row: PlaylistTrackRow) {
        preparePlaybackBackendIfNeeded()
        guard let backend = playbackBackend else { return }
        
        previewTimer?.invalidate()
        
        if playbackState.isPlaying {
            backend.pause()
            stopPlaybackProgressTimer()
            playbackState = PlaybackState(
                trackUri: playbackState.trackUri,
                trackName: playbackState.trackName,
                artistName: playbackState.artistName,
                positionMs: playbackState.positionMs,
                durationMs: playbackState.durationMs,
                isPlaying: false,
                isBuffering: playbackState.isBuffering
            )
            Task { await refreshPlaybackState() }
        } else {
            Task {
                guard backend.isReady else {
                    await MainActor.run { playbackMessage = "Player is starting up…" }
                    return
                }
                guard let deviceId = await ensurePlaybackDevice() else { return }
                let startMs = row.track.customStartMs ?? 0
                backend.playTrack(row.track.uri, startPositionMs: startMs, deviceId: deviceId)
                await MainActor.run {
                    playbackState = PlaybackState(
                        trackUri: row.track.uri,
                        trackName: row.title,
                        artistName: primaryArtist(for: row),
                        positionMs: startMs,
                        durationMs: row.metadata?.durationMs ?? row.track.durationMs ?? 0,
                        isPlaying: true,
                        isBuffering: false
                    )
                    startPlaybackProgressTimer()
                }
                await refreshPlaybackState()
            }
        }
    }
    
    private func startPlaybackProgressTimer() {
        playbackProgressTimer?.invalidate()
        playbackProgressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { await self.refreshPlaybackState() }
        }
    }
    
    private func stopPlaybackProgressTimer() {
        playbackProgressTimer?.invalidate()
        playbackProgressTimer = nil
    }
    
    @MainActor
    private func refreshPlaybackState() async {
        guard spotifyAuthService.isAuthenticated else { return }
        
        do {
            if let playback = try await apiService.getCurrentPlaybackState(),
               let item = playback.item {
                playbackState = PlaybackState(
                    trackUri: item.uri,
                    trackName: item.name,
                    artistName: item.artists.first?.name,
                    positionMs: playback.progressMs ?? 0,
                    durationMs: item.durationMs,
                    isPlaying: playback.isPlaying,
                    isBuffering: false
                )
            } else {
                playbackState = .idle
            }
        } catch {
            // Avoid spamming the UI on transient failures.
        }
    }
    
    private func ensurePlaybackDevice() async -> String? {
        if let existing = playbackDeviceId {
            return existing
        }
        
        guard spotifyAuthService.isAuthenticated else {
            await MainActor.run {
                playbackMessage = "Connect Spotify to control playback."
            }
            return nil
        }
        
        do {
            let devices = try await apiService.fetchAvailableDevices()
            guard !devices.isEmpty, let target = selectPreferredDevice(from: devices) else {
                await MainActor.run {
                    playbackMessage = "Open Spotify on this Mac or phone, then try again."
                }
                return nil
            }
            
            await MainActor.run {
                playbackDeviceId = target.deviceId
            }
            return target.deviceId
        } catch {
            await MainActor.run {
                playbackMessage = "Could not find a Spotify playback device."
            }
            return nil
        }
    }
    
    private func selectPreferredDevice(from devices: [SpotifyDevice]) -> SpotifyDevice? {
        devices.first(where: { $0.name == "Electric Slideshow Internal Player" }) ??
        devices.first(where: { $0.is_active }) ??
        devices.first(where: { $0.type.lowercased() == "computer" }) ??
        devices.first
    }
    
    private func primaryArtist(for row: PlaylistTrackRow) -> String? {
        if let artists = row.metadata?.artistNames, !artists.isEmpty {
            return artists
        }
        return row.track.artist
    }
    
    private func jumpBackward(seconds: Int = 10) async {
        guard let backend = playbackBackend, backend.isReady else {
            playbackMessage = "Player not ready."
            return
        }
        guard playbackState.durationMs > 0 else { return }
        
        let deltaMs = seconds * 1000
        let newPosition = max(playbackState.positionMs - deltaMs, 0)
        backend.seek(to: newPosition)
        await MainActor.run {
            playbackState = PlaybackState(
                trackUri: playbackState.trackUri,
                trackName: playbackState.trackName,
                artistName: playbackState.artistName,
                positionMs: newPosition,
                durationMs: playbackState.durationMs,
                isPlaying: playbackState.isPlaying,
                isBuffering: playbackState.isBuffering
            )
        }
        await refreshPlaybackState()
    }
    
    private enum MarkPositionTarget {
        case start
        case end
    }
    
    private func markCurrentPosition(as target: MarkPositionTarget) async {
        guard spotifyAuthService.isAuthenticated else {
            playbackMessage = "Connect Spotify to mark clips."
            return
        }
        
        guard let backend = playbackBackend, backend.isReady else {
            playbackMessage = "Player not ready."
            return
        }
        
        do {
            guard let state = try await apiService.getCurrentPlaybackState(),
                  let uri = state.item?.uri else {
                playbackMessage = "No active playback to mark."
                return
            }
            
            guard let index = selectedRowIndex else { return }
            guard uri == trackRows[index].track.uri else {
                playbackMessage = "Active track is different; start playback here first."
                return
            }
            
            let positionMs = state.progressMs ?? 0
            applyMark(positionMs: positionMs, target: target, index: index)
            playbackMessage = "Marked \(target == .start ? "start" : "end") at \(formatTimestamp(ms: positionMs))."
        } catch {
            playbackMessage = "Failed to read playback position."
        }
    }
    
    private func applyMark(positionMs: Int, target: MarkPositionTarget, index: Int) {
        switch target {
        case .start:
            startText = formatTimestamp(ms: positionMs)
        case .end:
            endText = formatTimestamp(ms: positionMs)
        }
        handleCustomFieldChange()
    }
    
    private func previewClip(for row: PlaylistTrackRow) {
        preparePlaybackBackendIfNeeded()
        guard let backend = playbackBackend else {
            playbackMessage = "Player not initialized."
            return
        }
        guard backend.isReady else {
            playbackMessage = "Player not ready."
            return
        }
        
        previewTimer?.invalidate()
        playbackMessage = nil
        
        let startMs: Int
        let endMs: Int
        switch row.track.clipMode {
        case .custom:
            startMs = row.track.customStartMs ?? 0
            endMs = row.track.customEndMs ?? (row.metadata?.durationMs ?? row.track.durationMs ?? 0)
        case .default:
            startMs = 0
            endMs = defaultClipEndMs(for: row) ?? (row.metadata?.durationMs ?? row.track.durationMs ?? 0)
        }
        
        let trackDuration = row.metadata?.durationMs ?? row.track.durationMs ?? endMs
        let duration = max(endMs - startMs, minCustomClipDeltaMs)
        
        Task {
            guard let deviceId = await ensurePlaybackDevice() else { return }
            backend.playTrack(row.track.uri, startPositionMs: startMs, deviceId: deviceId)
            
            await MainActor.run {
                playbackState = PlaybackState(
                    trackUri: row.track.uri,
                    trackName: row.title,
                    artistName: primaryArtist(for: row),
                    positionMs: startMs,
                    durationMs: trackDuration,
                    isPlaying: true,
                    isBuffering: false
                )
                startPlaybackProgressTimer()
                
                previewTimer = Timer.scheduledTimer(withTimeInterval: Double(duration) / 1000.0, repeats: false) { _ in
                    backend.pause()
                    DispatchQueue.main.async {
                        self.playbackState = PlaybackState(
                            trackUri: row.track.uri,
                            trackName: row.title,
                            artistName: primaryArtist(for: row),
                            positionMs: min(endMs, trackDuration),
                            durationMs: trackDuration,
                            isPlaying: false,
                            isBuffering: false
                        )
                        self.stopPlaybackProgressTimer()
                    }
                }
            }
            
            await refreshPlaybackState()
        }
    }
    
    // MARK: - Data loading
    
    @MainActor
    private func loadTracks() async {
        guard let playlist else { return }
        
        isLoading = true
        errorMessage = nil
        
        var updatedTracks = playlist.playlistTracks
        var metadataMap: [String: SpotifyTrack] = [:]
        
        if spotifyAuthService.isAuthenticated, !playlist.trackURIs.isEmpty {
            do {
                let tracks = try await apiService.fetchTracks(forURIs: playlist.trackURIs)
                metadataMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.uri, $0) })
            } catch {
                errorMessage = "Failed to load tracks: \(error.localizedDescription)"
                print("[PlaylistDetailView] ERROR loading tracks: \(error)")
            }
        }
        
        var rows: [PlaylistTrackRow] = []
        var didUpdateMetadata = false
        
        for index in updatedTracks.indices {
            var track = updatedTracks[index]
            if let meta = metadataMap[track.uri] {
                let prevSnapshot = (track.name, track.artist, track.album, track.durationMs, track.albumArtURL)
                track.name = meta.name
                track.artist = meta.artistNames
                track.album = meta.album.name
                track.durationMs = meta.durationMs
                track.albumArtURL = meta.album.imageURL
                track.fetchedAt = Date()
                
                let newSnapshot = (track.name, track.artist, track.album, track.durationMs, track.albumArtURL)
                if prevSnapshot != newSnapshot { didUpdateMetadata = true }
            }
            updatedTracks[index] = track
            rows.append(PlaylistTrackRow(track: track, metadata: metadataMap[track.uri]))
        }
        
        trackRows = rows
        
        if didUpdateMetadata {
            var updatedPlaylist = playlist
            updatedPlaylist.playlistTracks = updatedTracks
            playlistsStore.updatePlaylist(updatedPlaylist)
        }
        
        isLoading = false
    }
    
    // MARK: - Persistence and selection handling
    
    private func updatePlaylistClipMode(_ mode: MusicClipMode?) {
        guard var playlist else { return }
        if playlist.playlistDefaultClipMode == mode { return }
        playlist.playlistDefaultClipMode = mode
        playlistsStore.updatePlaylist(playlist)
    }
    
    private func persistPlaylistTracks() {
        guard var playlist else { return }
        playlist.playlistTracks = trackRows.map { $0.track }
        playlistsStore.updatePlaylist(playlist)
    }
    
    private func handleAddTrack() {
        let uri = newTrackURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uri.isEmpty else {
            addTrackError = "Enter a Spotify track URI."
            return
        }
        guard !trackRows.contains(where: { $0.track.uri == uri }) else {
            addTrackError = "Track is already in this playlist."
            return
        }
        
        Task {
            var newTrack = PlaylistTrack(uri: uri)
            var metaResult: SpotifyTrack?
            if spotifyAuthService.isAuthenticated {
                do {
                    let tracks = try await apiService.fetchTracks(forURIs: [uri])
                    if let meta = tracks.first {
                        newTrack.name = meta.name
                        newTrack.artist = meta.artistNames
                        newTrack.album = meta.album.name
                        newTrack.durationMs = meta.durationMs
                        newTrack.albumArtURL = meta.album.imageURL
                        newTrack.fetchedAt = Date()
                        metaResult = meta
                    }
                } catch {
                    // Ignore metadata failures; still add track.
                }
            }
            
            await MainActor.run {
                trackRows.append(PlaylistTrackRow(track: newTrack, metadata: metaResult))
                persistPlaylistTracks()
                selectedRowIndex = trackRows.count - 1
                showingAddTrackSheet = false
                newTrackURI = ""
                addTrackError = nil
            }
        }
    }
    
    private func deleteRows(at offsets: IndexSet) {
        let selectedId = selectedRow?.id
        trackRows.remove(atOffsets: offsets)
        persistPlaylistTracks()
        selectedRowIndex = selectedId.flatMap { id in
            trackRows.firstIndex(where: { $0.id == id })
        }
    }
    
    private func moveRows(from source: IndexSet, to destination: Int) {
        let selectedId = selectedRow?.id
        trackRows.move(fromOffsets: source, toOffset: destination)
        persistPlaylistTracks()
        selectedRowIndex = selectedId.flatMap { id in
            trackRows.firstIndex(where: { $0.id == id })
        }
    }
    
    private func removeSelectedTrack() {
        guard let selected = selectedRowIndex else { return }
        deleteRows(at: IndexSet(integer: selected))
    }
    
    private func syncInspectorFields() {
        guard let row = selectedRow else {
            startText = ""
            endText = ""
            inspectorError = nil
            return
        }
        
        switch row.track.clipMode {
        case .default:
            startText = formatTimestamp(ms: 0)
            if let defaultEnd = defaultClipEndMs(for: row) {
                endText = formatTimestamp(ms: defaultEnd)
            } else {
                endText = ""
            }
            inspectorError = nil
        case .custom:
            let startMs = row.track.customStartMs ?? 0
            let endMs = row.track.customEndMs ?? defaultClipEndMs(for: row) ?? 0
            startText = formatTimestamp(ms: startMs)
            endText = formatTimestamp(ms: endMs)
            inspectorError = row.validationError
        }
    }
    
    private func setClipMode(_ mode: PlaylistTrack.ClipMode) {
        guard let index = selectedRowIndex else { return }
        trackRows[index].track.clipMode = mode
        
        if mode == .default {
            trackRows[index].track.customStartMs = nil
            trackRows[index].track.customEndMs = nil
            trackRows[index].validationError = nil
            inspectorError = nil
        } else {
            if trackRows[index].track.customStartMs == nil {
                trackRows[index].track.customStartMs = 0
            }
            if trackRows[index].track.customEndMs == nil {
                trackRows[index].track.customEndMs = defaultClipEndMs(for: trackRows[index]) ?? (trackRows[index].track.durationMs ?? 0)
            }
        }
        
        persistPlaylistTracks()
        syncInspectorFields()
    }
    
    private func handleCustomFieldChange() {
        guard let index = selectedRowIndex else { return }
        let row = trackRows[index]
        
        switch validateCustomFields(for: row, startText: startText, endText: endText) {
        case .success(let range):
            trackRows[index].track.clipMode = .custom
            trackRows[index].track.customStartMs = range.start
            trackRows[index].track.customEndMs = range.end
            trackRows[index].validationError = nil
            inspectorError = nil
            persistPlaylistTracks()
        case .failure(let validationError):
            let message = validationError.message
            trackRows[index].validationError = message
            inspectorError = message
        }
    }
    
    private func resetToDefault() {
        setClipMode(.default)
    }
    
    // MARK: - Clip calculations
    
    private func validateCustomFields(for row: PlaylistTrackRow, startText: String, endText: String) -> Result<(start: Int, end: Int), ClipValidationError> {
        guard let startMs = parseTimestampMs(startText), let endMs = parseTimestampMs(endText) else {
            return .failure(.message("Enter start and end in mm:ss (or hh:mm:ss)."))
        }
        if startMs < 0 || endMs < 0 {
            return .failure(.message("Times must be positive."))
        }
        
        let trackDuration = row.metadata?.durationMs ?? row.track.durationMs
        if let duration = trackDuration, startMs >= duration {
            return .failure(.message("Start must be before the track ends."))
        }
        
        var clampedEnd = endMs
        if let duration = trackDuration {
            clampedEnd = min(endMs, duration)
        }
        
        if clampedEnd <= startMs {
            return .failure(.message("End must be after start."))
        }
        
        if clampedEnd - startMs < minCustomClipDeltaMs {
            return .failure(.message("Clip must be at least \(minCustomClipDeltaMs / 1000)s long."))
        }
        
        return .success((start: startMs, end: clampedEnd))
    }
    
    private func defaultClipEndMs(for row: PlaylistTrackRow) -> Int? {
        guard let clipSeconds = effectiveClipMode.clipDuration else {
            return row.metadata?.durationMs ?? row.track.durationMs
        }
        let clipMs = Int(clipSeconds * 1000)
        if let duration = row.metadata?.durationMs ?? row.track.durationMs {
            return min(duration, clipMs)
        } else {
            return clipMs
        }
    }
    
    private func effectiveClipDurationMs(for row: PlaylistTrackRow) -> Int? {
        switch row.track.clipMode {
        case .default:
            return defaultClipDurationMs(for: row)
        case .custom:
            guard let start = row.track.customStartMs, let end = row.track.customEndMs else { return nil }
            let trackDuration = row.metadata?.durationMs ?? row.track.durationMs
            if let duration = trackDuration {
                let clampedStart = max(0, min(start, duration))
                let clampedEnd = max(clampedStart, min(end, duration))
                return clampedEnd - clampedStart
            } else {
                return end - start
            }
        }
    }
    
    private func defaultClipDurationMs(for row: PlaylistTrackRow) -> Int? {
        if let clipSeconds = effectiveClipMode.clipDuration {
            let clipMs = Int(clipSeconds * 1000)
            if let duration = row.metadata?.durationMs ?? row.track.durationMs {
                return min(duration, clipMs)
            } else {
                return clipMs
            }
        } else {
            return row.metadata?.durationMs ?? row.track.durationMs
        }
    }
    
    private func effectiveClipText(for row: PlaylistTrackRow) -> String {
        switch row.track.clipMode {
        case .default:
            if let durationMs = defaultClipDurationMs(for: row) {
                return formatDuration(ms: durationMs)
            } else {
                return "—"
            }
        case .custom:
            guard let start = row.track.customStartMs, let end = row.track.customEndMs else {
                return "Custom —"
            }
            let endMs = row.metadata?.durationMs ?? row.track.durationMs ?? end
            let clampedStart = max(0, min(start, endMs))
            let clampedEnd = max(clampedStart, min(end, endMs))
            return "\(formatTimestamp(ms: clampedStart)) → \(formatTimestamp(ms: clampedEnd))"
        }
    }
    
    // MARK: - Formatting helpers
    
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
    
    private func formatTimestamp(ms: Int) -> String {
        let totalSeconds = max(ms, 0) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func parseTimestampMs(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let parts = trimmed.split(separator: ":").map { String($0) }
        guard !parts.isEmpty else { return nil }
        
        var secondsTotal = 0
        
        if parts.count == 1 {
            guard let seconds = Int(parts[0]) else { return nil }
            secondsTotal = seconds
        } else if parts.count == 2 {
            guard let minutes = Int(parts[0]), let seconds = Int(parts[1]) else { return nil }
            secondsTotal = minutes * 60 + seconds
        } else if parts.count == 3 {
            guard let hours = Int(parts[0]), let minutes = Int(parts[1]), let seconds = Int(parts[2]) else { return nil }
            secondsTotal = hours * 3600 + minutes * 60 + seconds
        } else {
            return nil
        }
        
        return secondsTotal * 1000
    }
}

// MARK: - Row model

private struct PlaylistTrackRow: Identifiable, Equatable {
    var track: PlaylistTrack
    var metadata: SpotifyTrack?
    var validationError: String?
    
    var id: String { track.id }
    
    var title: String {
        metadata?.name ?? track.name ?? "Unknown Track"
    }
    
    var subtitle: String {
        if let meta = metadata {
            let artist = meta.artistNames
            let album = meta.album.name
            if artist.isEmpty { return album }
            if album.isEmpty { return artist }
            return "\(artist) • \(album)"
        }
        
        if let artist = track.artist, let album = track.album, !artist.isEmpty {
            return "\(artist) • \(album)"
        } else if let artist = track.artist {
            return artist
        } else if let album = track.album {
            return album
        } else {
            return track.uri
        }
    }

    static func == (lhs: PlaylistTrackRow, rhs: PlaylistTrackRow) -> Bool {
        lhs.track == rhs.track &&
        lhs.validationError == rhs.validationError &&
        lhs.metadata?.uri == rhs.metadata?.uri
    }
}

// MARK: - Errors

private enum ClipValidationError: Error {
    case message(String)
    
    var message: String {
        switch self {
        case .message(let text): return text
        }
    }
}

#Preview {
    let store = PlaylistsStore()
    let sample = AppPlaylist(
        name: "Sample Playlist",
        playlistTracks: [
            PlaylistTrack(uri: "spotify:track:0"),
            PlaylistTrack(uri: "spotify:track:1")
        ]
    )
    store.addPlaylist(sample)
    
    return NavigationStack {
        PlaylistDetailView(playlistId: sample.id)
            .environmentObject(store)
            .environmentObject(SpotifyAuthService.shared)
    }
}
