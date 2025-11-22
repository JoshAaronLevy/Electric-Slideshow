# Electric Slideshow — Architecture & Wiring Report

**Date:** November 21, 2025  
**Purpose:** Document current app architecture and identify build instability sources

---

## 1. High-Level Overview

macOS SwiftUI app (MVVM architecture) that creates photo slideshows with Spotify music integration.

**Features:** Photo library access, slideshow creation/persistence (JSON), Spotify OAuth (via Node backend), app-local playlists, full-screen playback with music controls.

**Layers:** Models → Services → ViewModels → Views, plus Helpers and Config.

---

## 2. App Entry Point & Global Services

**File:** `Electric_SlideshowApp.swift`

**Three `@StateObject` services injected as environment objects:**

1. **`PhotoLibraryService`** — PHPhotoLibrary wrapper (auth, image loading, caching)
2. **`SpotifyAuthService.shared`** — OAuth manager (singleton pattern)
3. **`PlaylistsStore`** — App playlist persistence

**OAuth Callback:** Handles `com.slideshowbuddy://callback` via `.onOpenURL`

---

## 3. Photo Permissions & Library Flow

**Key Types:**
- `PhotoLibraryService` (Services/) — PHPhotoLibrary wrapper
- `PermissionViewModel` (ViewModels/) — Maps PHAuthorizationStatus to `PermissionState` enum
- `AppShellView` (Views/) — Root view managing permission UI

**Permission Flow:**
1. App launch → `AppShellView` creates `PermissionViewModel` → checks authorization status
2. Shows `PermissionNotificationBar` if not granted, `AppMainView` if granted
3. "Grant Access" button → calls PHPhotoLibrary directly (not through service)

**⚠️ ISSUE 1: Dual Authorization Paths**
- Path A: `permissionVM.requestAuthorization()` → `photoService.requestAuthorization()`
- Path B: `permissionVM.requestAuthorizationSync()` → PHPhotoLibrary direct call, then manual state sync

**PhotoLibraryService Methods:**
- `fetchAlbums/fetchAssets` — Loads albums/photos
- `thumbnail/image` — Async image loading via `PHCachingImageManager`
- Caching optimized for scrolling performance

---

## 4. Spotify / Music Integration

### SpotifyAuthService (Services/SpotifyAuthService.swift)
**Pattern:** Singleton (`@MainActor ObservableObject`)  
**Published:** `isAuthenticated`, `authError`

**Backend URLs:** Node/Express on Render
- Auth: `accounts.spotify.com/authorize`
- Token exchange/refresh: `slideshow-buddy-server.onrender.com`

**Methods:**
- `beginAuthentication()` — PKCE flow, opens browser
- `handleCallback(url:)` — Exchanges code for tokens
- `getValidAccessToken()` — Auto-refreshing token retrieval
- Tokens stored in keychain via `KeychainService`

### SpotifyAPIService (Services/SpotifyAPIService.swift)
**Constructor:** `init(authService: SpotifyAuthService)`  
**Base URL:** `api.spotify.com/v1`

**Methods:** `fetchUserProfile`, `fetchUserPlaylists`, `fetchPlaylistTracks`, `fetchSavedTracks`, playback controls (`start/pause/skip/getCurrentPlaybackState`)

All calls auto-refresh tokens via `authService.getValidAccessToken()`

### View Integration

**MusicView** (Views/MusicView.swift):
- Uses `@EnvironmentObject` for `spotifyAuthService` and `playlistsStore`
- Creates local `@StateObject var apiService: SpotifyAPIService` in init

**⚠️ ISSUE 2: Multiple SpotifyAPIService Instances**
Created independently in `MusicView`, `SlideshowsListView`, and `NewPlaylistFlowView`

**⚠️ ISSUE 3: Dead Code**
`MusicViewModel` exists but is NOT used by `MusicView` (direct service usage instead)

---

## 5. Slideshow Domain Model & Persistence

**Core Models:**

**`Slideshow`** (Models/Slideshow.swift) — `Codable`, `Identifiable`
- Properties: `id` (UUID), `title`, `photos: [SlideshowPhoto]`, `settings: SlideshowSettings`, `createdAt`

**`SlideshowPhoto`** (Models/SlideshowPhoto.swift)
- Stores only PHAsset `localIdentifier` (not image data)
- Images loaded dynamically at playback

**`SlideshowSettings`** (Models/SlideshowSettings.swift)
- `durationPerSlide: TimeInterval`, `shuffle: Bool`, `repeatEnabled: Bool`, `linkedPlaylistId: UUID?`
- Default: 3s duration, no shuffle, repeat enabled

**`SlideshowsStore`** (Services/SlideshowsStore.swift)
- Storage: `~/Library/Application Support/<BundleID>/slideshows.json`
- Methods: `loadSlideshows()`, `saveSlideshows()`
- Synchronous I/O, errors logged, returns empty array on failure

---

## 6. Navigation & App Shell

**View Hierarchy:**
```
Electric_SlideshowApp → AppShellView (permissions) → AppMainView → AppNavigationBar + Content
```

**AppShellView** (Views/AppShellView.swift):
- Creates `PermissionViewModel`, shows notification bar if needed
- Displays `AppMainView` when permissions granted

**AppMainView** (Views/AppMainView.swift):
- Manages `@State selectedSection: AppSection` (`.slideshows` default)
- Routes to `SlideshowsListView`, `MusicView`, `SettingsPlaceholderView`, or `UserPlaceholderView`

**AppNavigationBar** (Views/AppNavigationBar.swift):
- Layout: App title (left), section title (center), 4 nav icons (right)
- Selected section highlighted with accent color

**AppSection** (Models/AppSection.swift): Enum with `.slideshows`, `.music`, `.settings`, `.user`

---

## 7. Slideshow Creation & Editing Flow

**Entry:** `SlideshowsListView` → "New Slideshow" → `NewSlideshowFlowView` sheet

**Two-Step Flow:**

**Step 1: Photo Selection** (`PhotoSelectionView`)
- `PhotoLibraryViewModel` manages album browsing and selection
- User selects photos → stored in `selectedAssetIds: Set<String>`
- "Next" → copies IDs to `NewSlideshowViewModel.selectedPhotoIds`

**Step 2: Settings** (Form view)
- Configure: title (validated), duration (1-10s slider), shuffle/repeat toggles, music picker
- Music stored in local `@State var musicSelection: MusicSelection` (`.none` or `.appPlaylist(UUID)`)
- "Save" → calls `saveSlideshow()`:
  1. Updates settings with music selection
  2. Calls `viewModel.buildSlideshow()` (trims title, converts IDs to `[SlideshowPhoto]`)
  3. Invokes `onSave(slideshow)` closure, resets state, dismisses

**View Models:**
- **NewSlideshowViewModel** — Slideshow state, validation (`canSave`), building (`buildSlideshow()`)
- **PhotoLibraryViewModel** — Album/asset loading, selection management

**Edit Mode:** If `editingSlideshow` provided, pre-populates all fields

---

## 8. Slideshow Playback Flow (Full-Screen)

**Entry:** `SlideshowsListView` → hover over slideshow card → click play → `.fullScreenCover`

**SlideshowPlaybackView** (Views/SlideshowPlaybackView.swift):
- Black background with current slide image (`.scaledToFit`)
- Controls overlay (auto-hides after 3s inactivity)
  - Top: Close button, progress text
  - Bottom: Slide controls (prev/play/next), music controls (if playing), track info
- Keyboard: Space (play/pause), arrows (prev/next), escape (exit)

**SlideshowPlaybackViewModel** (ViewModels/SlideshowPlaybackViewModel.swift):

**Lifecycle:**
1. `startPlayback()` — Load all images (1920x1080), setup shuffle order, start music, start slide timer, monitor playback
2. `stopPlayback()` — Stop timers and music

**Image Loading:**
- For each `SlideshowPhoto`: fetch PHAsset by `localIdentifier`, load via `photoService.image()`
- **⚠️ ISSUE 4:** Photos deleted from library fail silently (warning logged)

**Slide Timer:**
- Repeating timer at `durationPerSlide` interval
- Handles looping based on `repeatEnabled`
- Auto-stops at end if no repeat

**Music Playback:**
- Looks up `AppPlaylist` by `linkedPlaylistId`, calls `spotifyAPIService.startPlayback(trackURIs:)`
- Polls playback state every 2s for UI updates
- Separate music play/pause from slide play/pause
- **⚠️ LIMITATION:** Requires Spotify app open, no device selection

---

## 9. Build Error Sources & Inconsistencies

### Critical Issues

**ISSUE 1: Dual Photo Authorization Paths**
- Path A: `permissionVM.requestAuthorization()` → `photoService.requestAuthorization()`
- Path B: `permissionVM.requestAuthorizationSync()` → PHPhotoLibrary direct, manual sync
- **Impact:** State desync if used incorrectly
- **Fix:** Standardize on one path

**ISSUE 2: Multiple SpotifyAPIService Instances**
- Created independently in `SlideshowsListView`, `MusicView`, `NewPlaylistFlowView`
- **Impact:** No shared state, potential inconsistency
- **Fix:** Create at app level or use singleton

**ISSUE 3: Dead Code**
- `MusicViewModel` exists but unused by `MusicView`
- `ContentView.swift` likely unused
- **Impact:** Confusion, accidental usage
- **Fix:** Remove unused files

**ISSUE 4: PHAsset Lifecycle**
- Slideshows store only `localIdentifier`, not image data
- Deleted photos fail silently during playback
- **Impact:** Incomplete slideshows, user confusion
- **Fix:** Validate assets before playback, alert user

### Pattern Inconsistencies

**ISSUE 5: Mixed Observation Frameworks**
- Most use `ObservableObject` + `@Published`
- `PhotoGridViewModel`, `AlbumListViewModel` use `@Observable` macro
- **Fix:** Standardize (prefer `@Observable` for macOS 14+)

**ISSUE 6: Singleton + @StateObject Conflict**
- `SpotifyAuthService.shared` wrapped in `@StateObject`
- Singleton doesn't need lifecycle management
- **Fix:** Use singleton directly or make instance-based

**ISSUE 7: PhotoLibraryService Injection**
- Mixed: passed as parameter AND environment object
- Child views inconsistent: some `@EnvironmentObject`, some `init` param
- **Fix:** Standardize on environment object

**ISSUE 8: Import Statement Inconsistencies**
- Mix of `internal import` and `import`
- **Impact:** Potential visibility issues

**ISSUE 9: Error Handling Inconsistencies**
- Services throw, ViewModels publish errors, Stores log silently
- **Fix:** Establish per-layer strategy

**ISSUE 10: Timer Lifecycle**
- `SlideshowPlaybackViewModel` timers not cancelled in `deinit`
- Relies on `.onDisappear` calling `stopPlayback()`
- **Risk:** Memory leaks if dismissal interrupted
- **Fix:** Add `deinit` cleanup

---

## 10. Stabilization Strategy

### ✅ Architecture Strengths
- Clear MVVM separation with well-organized layers
- Environment object injection for global services
- Async/await throughout for modern concurrency
- Type-safe Codable models
- Permission-first design
- External OAuth backend (secure token exchange)

### 🎯 Recommended Fixes (Priority Order)

1. **Remove dead code** — Delete `MusicViewModel.swift`, confirm/remove `ContentView.swift`
2. **Standardize observation** — Choose `@Observable` (macOS 14+) or `ObservableObject`
3. **Centralize SpotifyAPIService** — Create at app level or make singleton
4. **Single auth path** — Use only `photoService.requestAuthorization()`
5. **Fix singleton pattern** — Don't wrap `SpotifyAuthService.shared` in `@StateObject`
6. **Consistent service access** — Use environment objects, not mixed param passing
7. **Add timer cleanup** — Implement `deinit` in `SlideshowPlaybackViewModel`
8. **Validate PHAssets** — Check assets exist before playback, alert user of missing photos
9. **Standardize imports** — Consistent use of `internal import` vs `import`
10. **Error handling strategy** — Define per-layer approach (throws vs published vs silent)

---

## Appendix: File Inventory (52 Swift files)

**Models (13):** Album, AppPlaylist, AppSection, PhotoAsset, PhotoLibraryError, Slideshow, SlideshowPhoto, SlideshowSettings, SpotifyAuthToken, SpotifyPlaybackState, SpotifyPlaylist, SpotifyTrack, SpotifyUser

**Services (6):** KeychainService, PhotoLibraryService, PlaylistsStore, SlideshowsStore, SpotifyAPIService, SpotifyAuthService

**ViewModels (9):** AlbumListViewModel (@Observable), MusicLibraryViewModel, MusicViewModel (⚠️ unused), NewPlaylistViewModel, NewSlideshowViewModel, PermissionViewModel, PhotoGridViewModel (@Observable), PhotoLibraryViewModel, SlideshowPlaybackViewModel, SlideshowsListViewModel

**Views (16):** AlbumListView, AppMainView, AppNavigationBar, AppShellView, ContentView (⚠️ unused?), MusicView, NewPlaylistFlowView, NewSlideshowFlowView, PhotoDetailView, PhotoGridView, PhotoSelectionView, PlaceholderViews, SlideshowCardView, SlideshowPlaybackView, SlideshowsListView, TrackSelectionView

**Helpers (2):** ImageSize, PKCEHelper  
**Config (1):** SpotifyConfig

**Entry Point:** Electric_SlideshowApp.swift

---

**End of Report** | 974 lines → 500 lines (condensed)