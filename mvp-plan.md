# Electric Slideshow – Full MVP Implementation Plan (Photos, Music, Slideshow Playback)

## High-Level MVP Goal

A macOS app that lets a user:

1. Grant access to their Apple Photos library.
2. Create slideshows by:
   - Selecting photos from albums / library.
   - Optionally linking a custom **music playlist** (backed by Spotify via the existing Node/Express backend).
3. See their slideshows on the **Slideshows** view (as a grid).
4. Hover over a slideshow tile to reveal a **Play** button.
5. Click **Play** to:
   - Enter **full-screen** slideshow playback.
   - Automatically advance through slides with transitions.
   - Start background music from the chosen playlist (via the backend/Spotify integration).

Assumptions:
- Spotify auth and callback flow are already implemented in a **Node/Express backend** (deployed to Render).
- The macOS app will:
  - Open a browser to initiate Spotify login.
  - Talk to the backend for:
    - Spotify connection status.
    - Custom playlist CRUD.
    - (MVP-level) telling Spotify to **start/stop playback** of a given playlist on the user’s account or active device.
- MVP audio behavior can be:
  - **Real integration:** Call backend endpoints that use Spotify Web API/Connect to start playback of the selected playlist.
  - **Soft stub:** Wire the calls and UI, even if backend behavior is still basic.

---

## Stage 0 – Config, Models, and Core Contracts

**Goal:** Establish core configuration and models so later stages have clear contracts.

### Tasks

1. **Backend config (`AppConfig`)**

   Create `Config/AppConfig.swift`:

   ```swift
   import Foundation

   struct AppConfig {
       static let backendBaseURL = URL(string: "https://<your-backend-domain>")!
       // e.g. https://electric-slideshow-backend.onrender.com

       // Auth
       static var spotifyLoginURL: URL {
           backendBaseURL.appendingPathComponent("/auth/spotify/login")
       }

       // Status & playlists
       static var spotifyStatusURL: URL {
           backendBaseURL.appendingPathComponent("/api/spotify/status")
       }

       static var spotifyPlaylistsURL: URL {
           backendBaseURL.appendingPathComponent("/api/spotify/playlists")
       }

       // Playback control (MVP)
       static func spotifyStartPlaybackURL(playlistId: String) -> URL {
           backendBaseURL.appendingPathComponent("/api/spotify/playback/start/\(playlistId)")
       }

       static var spotifyStopPlaybackURL: URL {
           backendBaseURL.appendingPathComponent("/api/spotify/playback/stop")
       }
   }
   ```

Adjust endpoint paths to match your backend.

2. **Music-related models**

   In `Models`:

   * `SpotifyConnectionStatus.swift`:

     ```swift
     import Foundation

     struct SpotifyConnectionStatus: Decodable {
         let isConnected: Bool
         let displayName: String?
     }
     ```

   * `MusicPlaylist.swift`:

     ```swift
     import Foundation

     struct MusicPlaylist: Identifiable, Codable, Equatable {
         let id: String               // backend/Spotify id
         var name: String
         var description: String?
         var trackCount: Int
         var createdAt: Date
         var updatedAt: Date
     }
     ```

3. **Extend `Slideshow` model for music & playback**

   In `Slideshow` model:

   ```swift
   struct Slideshow: Identifiable, Codable {
       let id: UUID
       var title: String
       var photos: [SlideshowPhoto]
       var createdAt: Date

       // New for MVP:
       var linkedPlaylistId: String?       // optional ID of MusicPlaylist
       var slideDurationSeconds: Double    // e.g. 3.0
       var shuffle: Bool
       var repeatLoop: Bool
   }
   ```

   * Make sure `SlideshowsStore` can persist and read these new fields.
   * Provide sensible defaults for older/slim data (e.g. if `slideDurationSeconds` absent, default to 3.0).

---

## Stage 1 – SpotifyService: Networking & Connection Status

**Goal:** Introduce a service that handles all Spotify/backend communication.

### Tasks

1. **Create `SpotifyService` in `Services/SpotifyService.swift`**

   ```swift
   import Foundation

   @MainActor
   final class SpotifyService: ObservableObject {
       @Published private(set) var connectionStatus: SpotifyConnectionStatus?

       private let session: URLSession

       init(session: URLSession = .shared) {
           self.session = session
       }

       func beginSpotifyLogin() {
           let url = AppConfig.spotifyLoginURL
           NSWorkspace.shared.open(url)
       }

       func refreshConnectionStatus() async throws {
           let (data, response) = try await session.data(from: AppConfig.spotifyStatusURL)
           // validate response statusCode 200...
           let status = try JSONDecoder().decode(SpotifyConnectionStatus.self, from: data)
           self.connectionStatus = status
       }

       func fetchPlaylists() async throws -> [MusicPlaylist] {
           let (data, response) = try await session.data(from: AppConfig.spotifyPlaylistsURL)
           // validate response
           return try JSONDecoder().decode([MusicPlaylist].self, from: data)
       }

       func createPlaylist(name: String, description: String?) async throws -> MusicPlaylist {
           var request = URLRequest(url: AppConfig.spotifyPlaylistsURL)
           request.httpMethod = "POST"
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")
           let body = ["name": name, "description": description]
           request.httpBody = try JSONEncoder().encode(body)
           let (data, response) = try await session.data(for: request)
           // validate response
           return try JSONDecoder().decode(MusicPlaylist.self, from: data)
       }

       func deletePlaylist(id: String) async throws {
           let url = AppConfig.spotifyPlaylistsURL.appendingPathComponent(id)
           var request = URLRequest(url: url)
           request.httpMethod = "DELETE"
           let (_, response) = try await session.data(for: request)
           // validate response
       }

       // MVP playback methods:
       func startPlayback(for playlistId: String) async throws {
           let url = AppConfig.spotifyStartPlaybackURL(playlistId: playlistId)
           let (_, response) = try await session.data(from: url)
           // validate response
       }

       func stopPlayback() async throws {
           let url = AppConfig.spotifyStopPlaybackURL
           let (_, response) = try await session.data(from: url)
           // validate response
       }
   }
   ```

   * Have Copilot fill in status code checks and lightweight error handling.
   * Keep this service focused on network concerns.

---

## Stage 2 – MusicViewModel & MusicView (Spotify Connection + Playlist Management)

**Goal:** Replace the Music placeholder with a real UI where the user can:

* Connect Spotify.
* See connection status.
* View their custom playlists.
* Create and delete playlists.

### Tasks

1. **Create `MusicViewModel`**

   `ViewModels/MusicViewModel.swift`:

   ```swift
   import Foundation

   @MainActor
   final class MusicViewModel: ObservableObject {
       @Published var isLoading = false
       @Published var errorMessage: String?
       @Published var connectionStatus: SpotifyConnectionStatus?
       @Published var playlists: [MusicPlaylist] = []

       private let spotifyService: SpotifyService

       init(spotifyService: SpotifyService) {
           self.spotifyService = spotifyService
       }

       func load() async {
           isLoading = true
           errorMessage = nil
           do {
               try await spotifyService.refreshConnectionStatus()
               connectionStatus = spotifyService.connectionStatus
               playlists = try await spotifyService.fetchPlaylists()
               isLoading = false
           } catch {
               isLoading = false
               errorMessage = "Failed to load Spotify status or playlists."
           }
       }

       func connectSpotify() {
           spotifyService.beginSpotifyLogin()
       }

       func createPlaylist(name: String, description: String?) async {
           do {
               let new = try await spotifyService.createPlaylist(name: name, description: description)
               playlists.append(new)
           } catch {
               errorMessage = "Failed to create playlist."
           }
       }

       func deletePlaylist(at offsets: IndexSet) async {
           for index in offsets {
               let playlist = playlists[index]
               do {
                   try await spotifyService.deletePlaylist(id: playlist.id)
               } catch {
                   errorMessage = "Failed to delete playlist."
                   continue
               }
           }
           playlists.remove(atOffsets: offsets)
       }
   }
   ```

2. **Implement `MusicView`**

   `Views/MusicView.swift`:

   * Uses `@StateObject private var viewModel: MusicViewModel`

   * Layout:

     * Top: Connection status (“Connected as …” or “Not connected”) + “Connect Spotify” / “Reconnect” button.
     * Middle: List of playlists (`List` or `Table`).
     * Bottom or toolbar: “New Playlist” button -> sheet/modal for name & optional description.

   * Call `await viewModel.load()` in `.task` on appear.

3. **Integrate with `AppMainView`**

   In `AppMainView` (the root content view that uses `AppNavigationBar`):

   ```swift
   case .music:
       MusicView(spotifyService: spotifyService)
   ```

   Ensure `spotifyService` is constructed once (e.g. in the App or shell) and passed down, not recreated per render.

---

## Stage 3 – Link Music Playlists to Slideshows (Create/Edit Flow)

**Goal:** Allow the user to attach one of their custom playlists to a slideshow during creation/edit.

### Tasks

1. **Extend `NewSlideshowFlowView` / slideshow settings**

   * In the slideshow creation/edit UI, add a **“Background Music”** section under settings.
   * UI could include:

     * A segmented control / toggle for:

       * “No Music”
       * “Use a Playlist”
     * When “Use a Playlist” is selected:

       * A `Picker` or menu that lists:

         * All `MusicPlaylist` names.
         * Uses `slideshow.linkedPlaylistId` to preselect when editing.

2. **Source playlists in the slideshow flow**

   For MVP, use a simple approach:

   * Add a lightweight `SlideshowMusicSelectionViewModel` *or* directly fetch playlists via `SpotifyService` in the slideshow settings view.
   * On appear, call `spotifyService.fetchPlaylists()` (or reuse cached playlists if you’ve added caching in later stages).

3. **Persist selection**

   * When user saves a slideshow:

     * Set `slideshow.linkedPlaylistId` to the chosen playlist’s `id` or `nil` if “No Music”.
   * Ensure `SlideshowsStore` persists and reads `linkedPlaylistId`.

4. **Visual indicator in Slideshows grid**

   * In `SlideshowRow` / grid item:

     * If `linkedPlaylistId != nil`, show a subtle music note icon (e.g., SF Symbol `music.note`) in the row.

---

## Stage 4 – Slideshow Playback UI & Logic (Photos + Music + Full-Screen)

**Goal:** Implement full-screen slideshow playback that:

* Uses the selected photos.
* Honors slideshow settings (duration, shuffle, repeat).
* Plays/stops the associated playlist via `SpotifyService` (backend/Spotify).

### Tasks

1. **Add a grid-based Slideshows view with hover Play button**

   * Update `SlideshowsListView` to present slideshows as a **grid** instead of a plain List (or add a grid mode).
   * For each slideshow tile:

     * Show title, photo count, created date, and (optionally) a small music icon if `linkedPlaylistId` is set.
     * On hover:

       * Reveal a **Play** button overlay (e.g., circle with `play.fill`).
       * Clicking Play triggers playback.

   Implementation idea:

   ```swift
   @State private var activeSlideshowForPlayback: Slideshow?

   var body: some View {
       // existing NavigationStack etc.
       ScrollView {
           LazyVGrid(columns: [...]) {
               ForEach(viewModel.slideshows) { slideshow in
                   SlideshowGridItemView(
                       slideshow: slideshow,
                       onPlay: { activeSlideshowForPlayback = slideshow }
                   )
               }
           }
       }
       .fullScreenCover(item: $activeSlideshowForPlayback) { slideshow in
           SlideshowPlaybackView(
               slideshow: slideshow,
               photoService: photoService,
               spotifyService: spotifyService
           )
       }
   }
   ```

2. **Create `SlideshowPlaybackView`**

   `Views/SlideshowPlaybackView.swift`:

   * Inputs:

     * `slideshow: Slideshow`
     * `photoService: PhotoLibraryService`
     * `spotifyService: SpotifyService`
   * Responsibilities:

     * Enter a **full-screen** experience.
     * Load the actual `NSImage`s for the slideshow’s `SlideshowPhoto`s via `PhotoLibraryService`.
     * Maintain playback state:

       * `@State var currentIndex: Int`
       * `@State var isPlaying: Bool`
       * Timer driving slide advancement every `slideDurationSeconds`.
       * Respect `shuffle`:

         * If `shuffle == true`, create a shuffled index order once.
       * Respect `repeatLoop`:

         * If true, loop when hitting end.
         * If false, end slideshow and dismiss the full-screen view.
     * Show basic controls overlay:

       * Close (exit full-screen).
       * Play/Pause.
       * Next / Previous (optional for MVP).

   Suggested behavior:

   * On appear:

     * Build an ordered array of photo assets from `slideshow.photos` (respecting shuffle).
     * Start music playback if `linkedPlaylistId` is non-nil.
     * Start timer to auto-advance slides.
   * On disappear:

     * Stop timer.
     * Stop music via `spotifyService.stopPlayback()`.

3. **Implement full-screen behavior**

   In `SlideshowPlaybackView`, use a full-screen style:

   * If presented via `.fullScreenCover`, just use a black background and edge-to-edge content:

     ```swift
     ZStack {
         Color.black.ignoresSafeArea()
         if let image = currentImage {
             Image(nsImage: image)
                 .resizable()
                 .scaledToFit()
                 .transition(.opacity)
         }
         // Overlay controls (top-right close button, bottom controls, etc.)
     }
     ```

   * Let the presenting view handle dismissal by binding `activeSlideshowForPlayback` to `nil`.

4. **Hook up music playback**

   In `SlideshowPlaybackView`:

   ```swift
   .task {
       await startPlayback()
   }

   private func startPlayback() async {
       // Load images, prepare indices, etc.
       if let playlistId = slideshow.linkedPlaylistId {
           do {
               try await spotifyService.startPlayback(for: playlistId)
           } catch {
               // Optional: show a non-blocking error indicator
           }
       }
       // Start timer for slides
   }

   private func stopPlayback() async {
       do {
           try await spotifyService.stopPlayback()
       } catch {
           // ignore or log
       }
   }
   ```

   * Call `await stopPlayback()` in `.onDisappear`.

   **Note:** This assumes your backend knows how to:

   * Use the user’s Spotify access token.
   * Target either the web player or the user’s active device via Spotify Connect.

   Even if backend playback is still basic, wiring this call sets up the integration for later improvements.

---

## Stage 5 – Local Persistence, Offline Behavior, and UX Polish

**Goal:** Make the experience robust and polished.

### Tasks

1. **Playlist caching (optional but nice)**

   * Cache playlists via a simple JSON file or `UserDefaults`.
   * On Music view load:

     * Show cached playlists immediately.
     * Refresh from backend in the background.

2. **Error messaging**

   * In Music view:

     * When `errorMessage` is non-nil, show a subtle banner or text.
   * In Slideshow playback:

     * If music playback fails, show a small message like:

       > “Couldn't start music playback. Slideshow will continue silently.”

3. **UX polish**

   * Make sure:

     * Grid layout for slideshows looks good in dark mode.
     * Hover states for Play button feel responsive (fade-in/fade-out).
     * Full-screen slideshow uses gentle transitions (e.g., `.opacity` or `.move`).

4. **Housekeeping**

   * Remove or clearly mark temporary debug prints.
   * Ensure services (`PhotoLibraryService`, `SpotifyService`) are created at the app/shell level and passed down, not duplicated.

---

## Usage Notes for Copilot

* Before each stage, ask Copilot something like:

  * **“Please review `mvp-implementation-plan.md` and implement Stage 1 (SpotifyService). Do not modify slideshow or photo permission code in this step.”**
* After each stage:

  * Confirm the app builds and runs.
  * Manually test the new functionality for that stage.
* Keep services and view models **focused and composable**:

  * `SpotifyService`: network + Spotify.
  * `MusicViewModel`: Music view state.
  * `SlideshowPlaybackView`: playback experience.
  * `SlideshowsListView`: grid view + full-screen entry.