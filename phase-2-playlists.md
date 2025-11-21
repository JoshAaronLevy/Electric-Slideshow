# Phase 2: Spotify API Integration & App-Local Playlists

**Prerequisites**: Phase 1 (Spotify Authentication from `spotify-integration.md`) must be complete and working.

**Goal**: Build the infrastructure to fetch Spotify data and create/manage app-local playlists that pull songs from the user's Spotify library.

---

## Overview

This phase adds:
1. **SpotifyAPIService** - Direct calls to Spotify Web API for playlists, tracks, user library
2. **AppPlaylist Model** - App-local playlist structure (stored locally, not synced to Spotify)
3. **PlaylistsStore** - Local persistence for app playlists (JSON file)
4. **Music Creation Flow** - UI for selecting songs from Spotify and creating app playlists
5. **MusicView** - Display app playlists with ability to create/edit/delete

---

## Stage 1: Spotify API Service

### Create `Services/SpotifyAPIService.swift`

```swift
import Foundation

@MainActor
final class SpotifyAPIService: ObservableObject {
    private let authService: SpotifyAuthService
    private let baseURL = URL(string: "https://api.spotify.com/v1")!
    
    init(authService: SpotifyAuthService) {
        self.authService = authService
    }
    
    // MARK: - User Profile
    
    func fetchUserProfile() async throws -> SpotifyUser {
        let url = baseURL.appendingPathComponent("me")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(SpotifyUser.self, from: data)
    }
    
    // MARK: - Playlists
    
    func fetchUserPlaylists() async throws -> [SpotifyPlaylist] {
        let url = baseURL.appendingPathComponent("me/playlists")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        
        let response = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
        return response.items
    }
    
    func fetchPlaylistTracks(playlistId: String) async throws -> [SpotifyTrack] {
        let url = baseURL.appendingPathComponent("playlists/\(playlistId)/tracks")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        
        let response = try JSONDecoder().decode(SpotifyTracksResponse.self, from: data)
        return response.items.map { $0.track }
    }
    
    // MARK: - Saved Tracks
    
    func fetchSavedTracks(limit: Int = 50, offset: Int = 0) async throws -> [SpotifyTrack] {
        var components = URLComponents(url: baseURL.appendingPathComponent("me/tracks"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        let token = try await authService.getValidAccessToken()
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        
        let response = try JSONDecoder().decode(SpotifySavedTracksResponse.self, from: data)
        return response.items.map { $0.track }
    }
    
    // MARK: - Playback
    
    func startPlayback(trackURIs: [String], deviceId: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("me/player/play")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["uris": trackURIs]
        if let deviceId = deviceId {
            body["device_id"] = deviceId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.playbackFailed
        }
    }
    
    func pausePlayback() async throws {
        let url = baseURL.appendingPathComponent("me/player/pause")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.playbackFailed
        }
    }
    
    func skipToNext() async throws {
        let url = baseURL.appendingPathComponent("me/player/next")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.playbackFailed
        }
    }
    
    func skipToPrevious() async throws {
        let url = baseURL.appendingPathComponent("me/player/previous")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.playbackFailed
        }
    }
    
    func getCurrentPlaybackState() async throws -> SpotifyPlaybackState? {
        let url = baseURL.appendingPathComponent("me/player")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }
        
        // 204 means no active playback
        if httpResponse.statusCode == 204 {
            return nil
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(SpotifyPlaybackState.self, from: data)
    }
    
    enum APIError: Error {
        case requestFailed
        case playbackFailed
    }
}
```

---

## Stage 2: Spotify API Models

### Create `Models/SpotifyUser.swift`
```swift
struct SpotifyUser: Codable {
    let id: String
    let displayName: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
    }
}
```

### Create `Models/SpotifyPlaylist.swift`
```swift
struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let tracks: TracksInfo
    let images: [SpotifyImage]
    
    struct TracksInfo: Codable {
        let total: Int
    }
    
    var imageURL: URL? {
        images.first?.url
    }
}

struct SpotifyPlaylistsResponse: Codable {
    let items: [SpotifyPlaylist]
}
```

### Create `Models/SpotifyTrack.swift`
```swift
struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let name: String
    let uri: String
    let durationMs: Int
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    
    enum CodingKeys: String, CodingKey {
        case id, name, uri, artists, album
        case durationMs = "duration_ms"
    }
    
    var artistNames: String {
        artists.map { $0.name }.joined(separator: ", ")
    }
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
}

struct SpotifyAlbum: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    
    var imageURL: URL? {
        images.first?.url
    }
}

struct SpotifyImage: Codable {
    let url: URL
    let height: Int?
    let width: Int?
}

struct SpotifyTracksResponse: Codable {
    let items: [TrackItem]
    
    struct TrackItem: Codable {
        let track: SpotifyTrack
    }
}

struct SpotifySavedTracksResponse: Codable {
    let items: [SavedTrackItem]
    
    struct SavedTrackItem: Codable {
        let track: SpotifyTrack
    }
}
```

### Create `Models/SpotifyPlaybackState.swift`
```swift
struct SpotifyPlaybackState: Codable {
    let isPlaying: Bool
    let item: SpotifyTrack?
    let progressMs: Int?
    
    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
        case progressMs = "progress_ms"
    }
}
```

---

## Stage 3: App-Local Playlist Models

### Create `Models/AppPlaylist.swift`
```swift
import Foundation

struct AppPlaylist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var trackURIs: [String]  // Spotify track URIs
    let createdAt: Date
    var updatedAt: Date
    
    // Computed
    var trackCount: Int {
        trackURIs.count
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        trackURIs: [String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.trackURIs = trackURIs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

---

## Stage 4: App Playlists Store

### Create `Services/PlaylistsStore.swift`
```swift
import Foundation

@MainActor
final class PlaylistsStore: ObservableObject {
    @Published private(set) var playlists: [AppPlaylist] = []
    
    private let fileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documentsPath.appendingPathComponent("app-playlists.json")
        loadPlaylists()
    }
    
    // MARK: - CRUD Operations
    
    func addPlaylist(_ playlist: AppPlaylist) {
        playlists.append(playlist)
        savePlaylists()
    }
    
    func updatePlaylist(_ playlist: AppPlaylist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            var updated = playlist
            updated.updatedAt = Date()
            playlists[index] = updated
            savePlaylists()
        }
    }
    
    func deletePlaylist(_ playlist: AppPlaylist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        savePlaylists()
    }
    
    // MARK: - Persistence
    
    private func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            playlists = try JSONDecoder().decode([AppPlaylist].self, from: data)
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }
    
    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save playlists: \(error)")
        }
    }
}
```

---

## Stage 5: Music Creation Flow UI

Similar to photo selection flow, but for songs from Spotify.

### Create `ViewModels/NewPlaylistViewModel.swift`
```swift
import Foundation

@MainActor
final class NewPlaylistViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var selectedTrackURIs: Set<String> = []
    @Published var errorMessage: String?
    
    private let playlistsStore: PlaylistsStore
    
    init(playlistsStore: PlaylistsStore) {
        self.playlistsStore = playlistsStore
    }
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedTrackURIs.isEmpty
    }
    
    func buildPlaylist() -> AppPlaylist? {
        guard canSave else { return nil }
        
        return AppPlaylist(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            trackURIs: Array(selectedTrackURIs)
        )
    }
    
    func reset() {
        name = ""
        selectedTrackURIs.removeAll()
        errorMessage = nil
    }
}
```

### Create `Views/NewPlaylistFlowView.swift`
```swift
import SwiftUI

struct NewPlaylistFlowView: View {
    @StateObject private var viewModel: NewPlaylistViewModel
    @StateObject private var musicLibraryVM: MusicLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: FlowStep = .trackSelection
    
    let onSave: (AppPlaylist) -> Void
    
    init(
        spotifyAPIService: SpotifyAPIService,
        playlistsStore: PlaylistsStore,
        onSave: @escaping (AppPlaylist) -> Void
    ) {
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: NewPlaylistViewModel(playlistsStore: playlistsStore))
        self._musicLibraryVM = StateObject(wrappedValue: MusicLibraryViewModel(apiService: spotifyAPIService))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .trackSelection:
                    TrackSelectionView(viewModel: musicLibraryVM)
                case .settings:
                    playlistSettingsView
                }
            }
            .navigationTitle(currentStep.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigation) {
                    if currentStep == .settings {
                        Button {
                            currentStep = .trackSelection
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    primaryActionButton
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private var playlistSettingsView: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.title)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.selectedTrackURIs.count) Songs Selected")
                            .font(.headline)
                        Text("Ready to create your playlist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change Selection") {
                        currentStep = .trackSelection
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Section("Playlist Name") {
                TextField("My Playlist", text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
    }
    
    @ViewBuilder
    private var primaryActionButton: some View {
        switch currentStep {
        case .trackSelection:
            Button("Next") {
                viewModel.selectedTrackURIs = musicLibraryVM.selectedTrackURIs
                currentStep = .settings
            }
            .disabled(musicLibraryVM.selectedTrackURIs.isEmpty)
            
        case .settings:
            Button("Save") {
                savePlaylist()
            }
            .disabled(!viewModel.canSave)
        }
    }
    
    private func savePlaylist() {
        guard let playlist = viewModel.buildPlaylist() else { return }
        onSave(playlist)
        viewModel.reset()
        musicLibraryVM.clearSelection()
        dismiss()
    }
    
    enum FlowStep {
        case trackSelection
        case settings
        
        var title: String {
            switch self {
            case .trackSelection: return "Select Songs"
            case .settings: return "Playlist Settings"
            }
        }
    }
}
```

### Create `ViewModels/MusicLibraryViewModel.swift`
```swift
import Foundation

@MainActor
final class MusicLibraryViewModel: ObservableObject {
    @Published var spotifyPlaylists: [SpotifyPlaylist] = []
    @Published var savedTracks: [SpotifyTrack] = []
    @Published var selectedTrackURIs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: SpotifyAPIService
    
    init(apiService: SpotifyAPIService) {
        self.apiService = apiService
    }
    
    func loadLibrary() async {
        isLoading = true
        errorMessage = nil
        
        async let playlistsResult = apiService.fetchUserPlaylists()
        async let tracksResult = apiService.fetchSavedTracks()
        
        do {
            spotifyPlaylists = try await playlistsResult
            savedTracks = try await tracksResult
            isLoading = false
        } catch {
            errorMessage = "Failed to load Spotify library"
            isLoading = false
        }
    }
    
    func toggleTrack(_ uri: String) {
        if selectedTrackURIs.contains(uri) {
            selectedTrackURIs.remove(uri)
        } else {
            selectedTrackURIs.insert(uri)
        }
    }
    
    func clearSelection() {
        selectedTrackURIs.removeAll()
    }
}
```

### Create `Views/TrackSelectionView.swift`
```swift
import SwiftUI

struct TrackSelectionView: View {
    @ObservedObject var viewModel: MusicLibraryViewModel
    
    var body: some View {
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
        .task {
            await viewModel.loadLibrary()
        }
    }
}

struct TrackRow: View {
    let track: SpotifyTrack
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(track.name)
                    .font(.body)
                Text(track.artistNames)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

---

## Stage 6: Update Music View

### Update `Views/MusicView.swift`
```swift
import SwiftUI

struct MusicView: View {
    @EnvironmentObject private var authService: SpotifyAuthService
    @EnvironmentObject private var playlistsStore: PlaylistsStore
    @StateObject private var apiService: SpotifyAPIService
    @State private var showingNewPlaylistFlow = false
    
    init(authService: SpotifyAuthService) {
        self._apiService = StateObject(wrappedValue: SpotifyAPIService(authService: authService))
    }
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                playlistsView
            } else {
                notConnectedView
            }
        }
    }
    
    private var playlistsView: some View {
        NavigationStack {
            List {
                Section("App Playlists") {
                    if playlistsStore.playlists.isEmpty {
                        Text("No playlists yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(playlistsStore.playlists) { playlist in
                            PlaylistRow(playlist: playlist)
                        }
                        .onDelete { offsets in
                            playlistsStore.deletePlaylist(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Music")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewPlaylistFlow = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                }
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
    }
    
    private var notConnectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Connect Spotify")
                .font(.title)
            
            Text("Connect your Spotify account to create playlists for your slideshows")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button("Connect with Spotify") {
                authService.beginAuthentication()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct PlaylistRow: View {
    let playlist: AppPlaylist
    
    var body: some View {
        HStack {
            Image(systemName: "music.note.list")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text(playlist.name)
                    .font(.headline)
                Text("\(playlist.trackCount) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

---

## Testing Checklist

1. ✓ Spotify user profile loads after authentication
2. ✓ User's Spotify playlists appear in track selection
3. ✓ User's saved tracks appear in track selection
4. ✓ Can select/deselect multiple tracks
5. ✓ Can create app playlist with selected tracks
6. ✓ App playlists persist across app restarts
7. ✓ Can delete app playlists
8. ✓ App playlists are stored locally (not in Spotify account)

---

## Next Steps

Once Phase 2 is complete, proceed to **Phase 3: UI Updates** which includes:
- Grid layout for slideshows
- Context menu for edit/delete
- Linking playlists to slideshows in settings
