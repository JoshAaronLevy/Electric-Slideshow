### 1. Clarifying Questions for Josh (answered)
- Clip-length hierarchy: custom clip → playlist default clip length → global Now Playing default (Music section clip picker). Per-answer, playlist default overrides global, but custom clip always wins.
- Data fields: New enum/fields are fine; prefer milliseconds for clip boundaries.
- Metadata: OK to cache for 30 days, but if complexity is high we can fetch fresh on every open (favor fetch-first with a thin optional cache for later).
- Playback path for clip editor: use whichever backend is currently initialized (external Spotify device via `SpotifyAPIService` or internal WKWebView). Later we can offer a picker if it misbehaves.
- Track reordering: desired, but treat as stretch after core flow.
- Missing/removed tracks: do the simplest thing first; defer robust handling.
- Slideshow precedence: custom clip overrides playlist default and global default; MVP assumes custom always wins.
- Additional notes: number songs in the table; allow add/remove tracks from the detail view as a stretch goal (try if time permits).

### 2. Current Behavior and Code Summary
- **Playlist storage:** `AppPlaylist` (`Electric Slideshow/Models/AppPlaylist.swift`) stores `id`, `name`, `[trackURIs]`, timestamps. Persistence lives in `PlaylistsStore` (`Services/PlaylistsStore.swift`), which loads/saves `app-playlists.json` in the user Documents folder. No track metadata or per-track settings are persisted.
- **Playlist creation & display:** `NewPlaylistFlowView` (`Views/NewPlaylistFlowView.swift`) + `NewPlaylistViewModel` builds playlists from selected track URIs via `MusicLibraryViewModel` (`ViewModels/MusicLibraryViewModel.swift`), which fetches saved tracks/playlists through `SpotifyAPIService`. `PlaylistsView` (`Views/MusicView.swift`) shows a simple `List` of `PlaylistRow` entries; tap currently does nothing, delete works via `onDelete`. A sheet opens `NewPlaylistFlowView` for creation.
- **Navigation shell:** `AppMainView` (`Views/AppMainView.swift`) hosts top-level sections; the Music section embeds `PlaylistsView` inside its own `NavigationStack`. There is no detail navigation for playlists today.
- **Playback & clip handling:** Slideshows can link to an app playlist via `SlideshowSettings.linkedPlaylistId`. `SlideshowPlaybackViewModel` (`ViewModels/SlideshowPlaybackViewModel.swift`) resolves that playlist, sends its `trackURIs` to Spotify with `SpotifyAPIService.startPlayback`, and manages clip timers using `MusicClipMode` (config in `Config/MusicClipMode.swift`, default `.seconds60`). Clip logic is global: a timer advances to the next track after 30/45/60 seconds, with optional random seek; `.fullSong` disables clipping. No per-track overrides exist.
- **Playback plumbing:** `MusicPlaybackBackend` defines backend-agnostic controls; default factory (via `PlaybackBackendFactory`) currently produces `SpotifyExternalPlaybackBackend` (thin wrapper around `SpotifyAPIService` pause/seek/skip). `NowPlayingPlaybackBridge` exposes clip mode/shuffle/repeat state to `NowPlayingView`, which lets the user change global clip mode; `SlideshowPlaybackView` wires those callbacks into `SlideshowPlaybackViewModel`.

### 3. Target UX and Behavior Overview
- Add `PlaylistDetailView` reachable from the playlist list. Left/main pane shows playlist name, playlist-level default clip selector, computed total duration (HH:MM:SS) honoring hierarchy (custom > playlist default > global), and a numbered track table with columns: `#`, title, artist/album, clip mode badge (`Default`/`Custom`), effective clip info (e.g., `0:45` or `1:02 → 1:34`). Selecting a row drives a right-hand inspector.
- Right/inspector pane: empty-state teaching panel when nothing is selected; active clip editor when a track is selected with song info, album art, Clip Mode toggle (Default vs Custom), timeline/scrubber, play/pause, mark start/end, live start/end/duration labels, preview clip, reset-to-default, and inline validation for invalid ranges.
- Playback controls in the editor use whichever backend is initialized (external Spotify via `SpotifyAPIService` or internal WKWebView backend). If no backend/device is ready, show a clear inline error/disabled state.
- Track reordering and add/remove from this view are stretch items: include UI affordances if time permits (drag handles and add/search action), but keep core flow stable without them.
- Total duration updates live when defaults or per-track settings change; effective durations clamp to real track duration.

### 4. Data Model & Persistence Changes
- Introduce `PlaylistTrack` (new struct) with:
  - `uri: String`, `clipMode: ClipMode` (`default` | `custom`), `customStartMs: Int?`, `customEndMs: Int?`.
  - Optional metadata cache: `name`, `artist`, `album`, `durationMs`, `albumArtURL`, `fetchedAt` (Date) to support simple freshness checks (30-day TTL). If TTL handling is too heavy, start with fetch-on-open and keep the struct optional fields to add caching later.
  - Computed helpers: `effectiveDurationMs(globalDefault: MusicClipMode, playlistDefault: MusicClipMode)`, `effectiveStartMs`, `effectiveEndMs` (clamped to duration if known).
- Extend `AppPlaylist` to hold `[PlaylistTrack]` (replace/augment `trackURIs`) and `playlistDefaultClipMode: MusicClipMode?` (nil means defer to global). Maintain `trackURIs` for migration compatibility if needed, but prefer `[PlaylistTrack]` as the authoritative source.
- Migration: when decoding old JSON with only `trackURIs`, map to `PlaylistTrack` entries with `clipMode = .default`, `customStartMs = nil`, `customEndMs = nil`, `playlistDefaultClipMode = nil` (or `.seconds60` if we want a deterministic default), and metadata empty. Persist back in new format on first save.
- Persistence format remains JSON via `PlaylistsStore`; ensure Codable compatibility and backward-safe decoding (custom init to handle both schemas).
- Validation: clamp `customStartMs`/`customEndMs` into `[0, durationMs]` when duration is known; require `end > start` and enforce a minimal delta (e.g., 500ms) to avoid zero-length clips. Reject invalid edits with inline errors; persist only sanitized values.

- **Stage 1: Navigation + Placeholder Detail**
  - Files: `Views/MusicView.swift`, new `Views/PlaylistDetailView.swift` (or similar), routing plumbing if needed.
  - Work: Tap on `PlaylistRow` pushes/presents `PlaylistDetailView` with playlist name and track count placeholder; include back affordance in `NavigationStack`. Ensure playlist IDs pass through.
  - Acceptance: clicking a playlist opens a detail screen with correct name/count; back/navigation works; no editing yet.

- **Stage 2: Detail Layout & Data Binding (read-only)**
  - Files: new detail view + possible `PlaylistDetailViewModel`; `PlaylistsStore` read helpers.
  - Work: Layout split view (table + side panel). Table shows numbered rows, title, artist, album (if available), clip mode badge (all `Default` for now), effective clip info from playlist/global default; total duration displayed in HH:MM:SS; playlist default clip selector bound to `playlistDefaultClipMode` (nil means “use global”). Load track metadata via Spotify for stored URIs (fetch-on-open; optional TTL hook). Duration recalculates when selector changes.
  - Acceptance: real track data populates table; numbering present; changing playlist default clip mode updates effective durations and total; empty state visible in inspector when nothing selected.

- **Stage 3: Selection + Inspector Empty/Info States**
  - Files: detail view components.
  - Work: Row selection state drives inspector. Empty state shows teaching copy. When selected, show song title/artist/album art, read-only clip info (from current mode), and space for controls (disabled for now).
  - Acceptance: selecting a row updates inspector with correct metadata; empty state appears when deselected; no editing yet.

- **Stage 4: Data Model Migration + Custom Clip Editing (no playback)**
  - Files: `Models/AppPlaylist.swift`, new `Models/PlaylistTrack.swift`, `PlaylistsStore`, `MusicClipMode` helpers, detail VM/UI.
  - Work: Implement new models and Codable migration from legacy `[trackURIs]`. Wire `playlistDefaultClipMode` property. Add per-track `clipMode` toggle and editable start/end fields (ms or mm:ss inputs) with validation and inline errors. Persist via `PlaylistsStore.updatePlaylist`. Update table badges/effective clip info/total duration accordingly. Keep hierarchy: custom > playlist default > global.
  - Acceptance: migrated playlists load without loss; toggling Default/Custom and editing times persists, survives reload, and updates table/total; invalid ranges show errors and don’t persist.

- **Stage 5: Playback Integration for Mark/Preview**
  - Files: detail view/VM, `MusicPlaybackBackend` usage, possibly helper to wrap seek/preview.
  - Work: Use current backend (external via `SpotifyAPIService` or internal) to play/pause selected track, seek, capture current position for Mark Start/End, and preview from start→end then stop. Disable/inline error if no backend/device ready. Scrubber reflects playback position if available.
  - Acceptance: mark buttons capture live positions; preview plays only the selected window and stops; controls are disabled with clear messaging when playback isn’t available; validation still enforced.

- **Stage 6: Slideshow Integration & Core Polish**
  - Files: `ViewModels/SlideshowPlaybackViewModel.swift`, potentially `SlideshowPlaybackView`, `NowPlayingPlaybackBridge` if needed, and helpers for effective clip duration.
  - Work: When slideshow has a linked playlist, honor per-track settings: if track clipMode is custom, seek to start and stop at end; else use playlist default or global default clip duration (no random start if custom exists). Update clip timer logic to use per-track effective duration. Keep global clip picker in Now Playing as fallback when playlist defaults are nil and no custom set. Ensure duration math consistent with detail view.
  - Acceptance: slideshow playback uses custom clips when present; playlist default overrides global when custom absent; total durations align; no crashes with missing metadata.

- **Stage 7 (Stretch): Track Reordering + Add/Remove**
  - Files: detail view table + VM/store.
  - Work: Enable drag-to-reorder within playlist; persist new order. Provide actions to remove selected tracks and to add tracks (reuse `MusicLibraryViewModel` picker in a modal/sheet). Update duration and inspector after modifications. Handle metadata fetch for newly added tracks.
  - Acceptance: reorder persists across reload; add/remove works and updates UI/durations; existing clips preserved when reordering.

### 6. Edge Cases, Risks, and Acceptance Criteria Summary
- Edge cases: tracks shorter than default/custom clip; missing/failed Spotify metadata; stale URIs removed from Spotify; playlists with many tracks (batch fetch paging); playback device unavailable during preview; invalid ranges (`end <= start` or too small delta); nil playlist default (fall back to global).
- Risks: migration must not drop data; relying on external device for preview may fail—show clear inline errors; metadata fetch latency without caching; ordering/add/remove stretch could destabilize the table if rushed.
- Overall success: users open playlists, see numbered tracks with accurate metadata/effective durations, set per-track custom ranges with validation, preview clips, reset to defaults, and slideshows honor custom > playlist default > global with persistence across relaunches.

### 7. Additional Notes and Future Enhancements
- Consider caching Spotify track metadata locally (including album art) to avoid re-fetching and to support offline display; add a lightweight `TrackMetadataStore`.
- Longer-term: allow track reordering within playlists, per-track volume tweaks, and “must play” pins for slideshow sequencing.
- Potential advanced timing: “fit to playlist length” modes or per-slide music matching could reuse the effective duration calculations from this feature.
- Internal player roadmap: if you switch to the WKWebView backend, we can provide smoother scrubbing and waveform previews; keep `MusicPlaybackBackend` abstraction in mind when wiring the editor so it can swap backends later.
