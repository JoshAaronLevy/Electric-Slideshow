# Electric Slideshow – UI Implementation Plan (macOS, SwiftUI, Dark Mode First)

Target: macOS (Tahoe 26.1), SwiftUI, Swift, PhotoKit  
Scope: **UI and UX for slideshow creation & customization only**  
Out of scope (for now): Actual slideshow playback, transitions, Spotify/audio integrations, advanced persistence logic.

The user experience to implement:

1. App checks Photos permission on launch.
2. If not granted, shows system Photos permission prompt.
3. After permission is granted, user sees the main **Slideshows** screen listing saved slideshows.
4. User can create a new slideshow.
5. New slideshow flow:
   - User can select photos from their library, optionally filtering by album.
   - User customizes slideshow settings (title, per-slide duration, shuffle, repeat).
6. User saves the slideshow.
7. User is taken back to the main **Slideshows** page and sees the new slideshow in the list.

For now, **only dark mode styling** needs to be considered.

---

## High-Level Architecture

- **Views**
  - `RootView` / `AppShellView` – permission gate + navigation shell.
  - `SlideshowsListView` – main landing page listing slideshows.
  - `NewSlideshowFlowView` – multi-step UI for:
    - Photo selection view (`PhotoSelectionView`).
    - Slideshow settings view (`SlideshowSettingsView`).
- **ViewModels**
  - `PermissionViewModel` – manages Photos permission state.
  - `SlideshowsListViewModel` – manages list of slideshows.
  - `NewSlideshowViewModel` – holds state for the slideshow being created.
  - `PhotoLibraryViewModel` – handles albums and photo assets for selection.
- **Models**
  - `Slideshow`
  - `SlideshowSettings`
  - `SlideshowPhoto` (lightweight reference to the asset, not full image data).
- **Services**
  - `PhotoLibraryService` – Photos/PhotoKit access, authorization, albums, assets, thumbnails.
  - `SlideshowsStore` – minimal persistence for slideshows (e.g., `UserDefaults` or JSON file) so they show up on relaunch. (Details can be basic for now.)

This plan is broken into stages that can be implemented one at a time.

---

## Stage 1 – Project Cleanup & App Shell + Permission Gate

### Goal

Create a clean app shell that:

- Starts in a **permission-aware state**.
- Shows:
  - a “checking permissions” loading state,
  - a “permissions required” view if Photos access is not granted,
  - the main “Slideshows” shell once Photos access is authorized.

### What to implement

1. **Folder Structure**

Create these groups/folders in the project:

- `Sources/Models`
- `Sources/ViewModels`
- `Sources/Views`
- `Sources/Services`
- `Sources/Helpers` (optional)
  
(Actual path names can be adapted to Xcode’s conventions, but keep the logical grouping.)

2. **PermissionViewModel**

Create `PermissionViewModel` in `Sources/ViewModels`:

- Responsibilities:
  - Track Photos authorization status:
    - `.notDetermined`, `.authorized`, `.denied`, `.restricted`, `.limited` (if needed).
  - On app startup:
    - Check current status.
    - If `.notDetermined`, provide a method to trigger permission request.
- Expose simple, UI-friendly state:
  - `enum PermissionState { case checking, notDetermined, granted, denied }`
  - `@Published var state: PermissionState`

3. **PhotoLibraryService (authorization only for now)**

Create `PhotoLibraryService` in `Sources/Services`:

- For Stage 1, implement only:
  - `func currentAuthorizationStatus() -> PHAuthorizationStatus`
  - `func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void)`
- Later stages will add album/asset APIs.

4. **RootView / AppShellView**

Replace `ContentView` (or wrap it) with a new `AppShellView` in `Sources/Views` that:

- Reads `PermissionViewModel` via `@StateObject` or `@EnvironmentObject`.
- Uses a simple `switch` on `permissionVM.state`:
  - `.checking` → a loading indicator (“Checking Photos permission…”).
  - `.notDetermined` → a view explaining why access is needed with a “Grant Access” button.
  - `.denied` → a view explaining that access is required, with instructions to open System Settings (no need to implement deep linking yet).
  - `.granted` → shows the main `SlideshowsListView` (placeholder for now).

5. **App Entry Integration**

Update `Electric_SlideshowApp` to:

- Create `PhotoLibraryService` and `PermissionViewModel` at app level.
- Inject `PermissionViewModel` into the environment for the views that need it.
- Display `AppShellView` as the root content.

### Notes to Copilot

- Use SwiftUI, no UIKit/AppKit views directly.
- Keep the UI simple and use **dark mode-friendly colors** (system defaults are fine for now).
- Do **not** implement any slideshow list logic yet—just have `SlideshowsListView` as a placeholder view with a title (“Slideshows”).

---

## Stage 2 – Slideshow Domain Models & Basic List UI

### Goal

Define the core data structures and display a basic list of slideshows on the main “Slideshows” page.  
Persistence can be simple but should be wired up so slideshows are visible across app launches.

### What to implement

1. **Models**

In `Sources/Models`:

- `Slideshow`
  - `id: UUID`
  - `title: String`
  - `photoIds: [String]` or `[SlideshowPhoto]` (for now, this can just store `localIdentifier` strings from `PHAsset`)
  - `settings: SlideshowSettings`
  - `createdAt: Date`
- `SlideshowSettings`
  - `durationPerSlide: TimeInterval` (e.g. seconds; default could be 3.0)
  - `shuffle: Bool`
  - `repeatEnabled: Bool`
- `SlideshowPhoto`
  - `id: String` (PhotoKit `localIdentifier`)
  - Future fields can be added later (e.g. caption).

2. **SlideshowsStore (simple persistence)**

In `Sources/Services`:

- A basic service responsible for:
  - In-memory storage of `[Slideshow]`.
  - Simple persistence using `UserDefaults` or a JSON file in the app’s documents directory.
  - API methods:
    - `loadSlideshows() -> [Slideshow]`
    - `saveSlideshows(_ slideshows: [Slideshow])`
- For now, a naive implementation is fine: read/write the whole array.

3. **SlideshowsListViewModel**

In `Sources/ViewModels`:

- Responsibilities:
  - Hold `[Slideshow]`.
  - Load slideshows on init.
  - Provide a method `addSlideshow(_:)` that:
    - Appends to the array.
    - Calls the store to persist.
- Expose properties:
  - `@Published var slideshows: [Slideshow]`
  - Possibly a simple “empty state” derived from the array.

4. **SlideshowsListView**

In `Sources/Views`:

- A SwiftUI view that:
  - Shows a navigation title “Slideshows”.
  - Displays:
    - An “empty state” message if there are no slideshows yet.
    - Otherwise, a list of slideshows showing:
      - Title
      - Photo count
      - Created date
  - Includes a primary button (e.g. “New Slideshow”) that will later trigger the New Slideshow flow (for now, it can just be a stub action).

5. **AppShellView Integration**

- Once permissions are `granted`, show `SlideshowsListView` with an attached `SlideshowsListViewModel`.

### Notes to Copilot

- Focus on clean, composable SwiftUI.
- Style for **dark mode** with system colors; avoid hard-coded light backgrounds.
- It’s okay if the slideshows list is static until Stage 4/5 when the creation flow is wired in.

---

## Stage 3 – New Slideshow Flow Container (Navigation Only)

### Goal

Add the UI scaffolding for the “New Slideshow” flow without implementing PhotoKit or actual selection yet.  
This is about flow and data propagation.

### What to implement

1. **NewSlideshowViewModel**

In `Sources/ViewModels`:

- Holds temporary state for slideshow creation:
  - `title: String`
  - `selectedPhotoIds: [String]`
  - `settings: SlideshowSettings` (with sensible defaults)
- Expose methods:
  - `reset()` – reset to defaults when starting a new slideshow.
  - Later: `toSlideshow()` to convert into a final `Slideshow`.

2. **NewSlideshowFlowView**

In `Sources/Views`:

- A container view (could be a sheet/modal, or a navigation push) that:
  - Has a two-step or multi-step flow:
    1. **Photo selection step** (placeholder view for now).
    2. **Slideshow settings step** (fields for title, duration, shuffle, repeat).
- For Stage 3, the “photo selection” step can just show mock placeholders or a “TODO” message.

3. **Wiring into SlideshowsListView**

- In `SlideshowsListView`, make the “New Slideshow” button:
  - Present `NewSlideshowFlowView` via `.sheet` or `.navigationDestination`.
  - Inject `NewSlideshowViewModel` to the flow.

### Notes to Copilot

- Do *not* implement real photo selection yet.
- Focus on the navigation and state flow between:
  - `SlideshowsListView`
  - `NewSlideshowFlowView`
  - `NewSlideshowViewModel`
- Make sure the flow can be cancelled cleanly (close sheet, discard changes).

---

## Stage 4 – Photo Library & Album Selection UI

### Goal

Implement the UI for browsing the photo library and selecting photos for the slideshow:

- Show albums.
- Show photos in the selected album.
- Allow multi-selection.

### What to implement

1. **Extend PhotoLibraryService**

In `Sources/Services/PhotoLibraryService`:

- Add methods for:
  - Fetching albums:
    - e.g. `func fetchAlbums() -> [PhotoAlbum]`
  - Fetching assets in an album:
    - e.g. `func fetchAssets(in album: PhotoAlbum) -> [PhotoAsset]`
  - Fetching a thumbnail image:
    - e.g. `func requestThumbnail(for asset: PhotoAsset, size: CGSize, completion: @escaping (NSImage?) -> Void)`
- Define lightweight structs in `Sources/Models`:
  - `PhotoAlbum { id: String, title: String, count: Int, collection: PHAssetCollection }`
  - `PhotoAsset { id: String, localIdentifier: String, underlying: PHAsset }`
- For UI/VM use, abstract away PH-specific details as much as possible while still allowing `localIdentifier` to be stored.

2. **PhotoLibraryViewModel**

In `Sources/ViewModels`:

- Responsibilities:
  - Load albums (on init or on demand).
  - Track selected album.
  - Load assets for the selected album.
  - Track selected asset IDs for the new slideshow.
- Expose:
  - `@Published var albums: [PhotoAlbum]`
  - `@Published var selectedAlbum: PhotoAlbum?`
  - `@Published var assets: [PhotoAsset]`
  - `@Published var selectedAssetIds: Set<String>`

3. **PhotoSelectionView**

In `Sources/Views`:

- UI Structure:
  - Left side: list or picker of albums.
  - Right side: grid of photo thumbnails (multi-select).
- Behavior:
  - Selecting an album refreshes the grid.
  - Clicking a photo toggles selection state.
  - Selected photos should visually indicate selection.
- Integration:
  - Bind `selectedAssetIds` to `NewSlideshowViewModel.selectedPhotoIds` (either directly or via callbacks).

4. **Integrate into NewSlideshowFlowView**

- Replace the placeholder photo selection UI with `PhotoSelectionView` that:
  - Uses `PhotoLibraryViewModel`.
  - On “Next” button, passes the selected photo IDs to `NewSlideshowViewModel`.

### Notes to Copilot

- Use `LazyVGrid` for thumbnails.
- Thumbnails should be loaded asynchronously; avoid blocking the main thread.
- Keep layout dark-mode friendly and visually clear which photos are selected.

---

## Stage 5 – Slideshow Settings UI & Validation (Title Required)

### Goal

Implement the settings step of the new slideshow flow, including:

- Title (required).
- Duration per slide.
- Shuffle toggle.
- Repeat toggle.
- Basic validation and save action.

### What to implement

1. **SlideshowSettingsView**

In `Sources/Views`:

- Bind to `NewSlideshowViewModel`.
- UI fields:
  - Text field for `title` (**required**).
  - Slider / stepper / text field for `durationPerSlide` (e.g., range 1–10 seconds).
  - Toggle for `shuffle`.
  - Toggle for `repeatEnabled`.
- Validation:
  - Disallow saving if `title` is empty.
  - Optionally show inline error or disabled “Save” button.

2. **Integrate with Flow**

In `NewSlideshowFlowView`:

- After photo selection step, move to settings step.
- When “Save” is tapped:
  - Validate title is non-empty.
  - If valid, call a callback or use environment to pass the finalized `Slideshow` back to `SlideshowsListView`.

3. **Finalize NewSlideshowViewModel**

- Add method:
  - `func buildSlideshow() -> Slideshow?` that:
    - Ensures `title` is not empty.
    - Uses `selectedPhotoIds` and `settings` to construct a `Slideshow`.
    - Returns `nil` if validation fails.

### Notes to Copilot

- Keep layout simple and easy to use in dark mode.
- Make sure that closing the flow on successful save clears the temporary state (or call `reset()` when creating a new slideshow next time).

---

## Stage 6 – Wire Creation Flow to Main List & Persistence

### Goal

Make the entire “create slideshow” path functional:

- User creates slideshow.
- Slideshow appears in the main list.
- Slideshow persists across app launches via `SlideshowsStore`.

### What to implement

1. **SlideshowsListView ↔ NewSlideshowFlow Integration**

- In `SlideshowsListView`:
  - When New Slideshow is saved:
    - Receive the new `Slideshow`.
    - Call `SlideshowsListViewModel.addSlideshow(_:)`.
- Close the creation sheet/modal upon successful save.

2. **SlideshowsStore Integration**

- Ensure `SlideshowsListViewModel`:
  - Loads slideshows from `SlideshowsStore` on init.
  - Saves slideshows using `SlideshowsStore` whenever the array changes (e.g., in `addSlideshow` via a `didSet` or explicit call).

3. **Basic UI Refresh**

- Confirm that:
  - Creating a slideshow updates the list immediately.
  - Relaunching the app shows previously created slideshows (permission permitting).

### Notes to Copilot

- Keep persistence implementation simple and robust enough for the MVP.
- Handle basic error cases by logging; no need for complex error UI yet.

---

## Stage 7 – Dark Mode Polish & UX Refinements

### Goal

Make sure the app feels coherent and pleasant in dark mode on macOS Tahoe 26.1.

### What to implement

- Use system colors (`.background`, `.secondaryBackground`, `.label`, etc.) instead of hard-coded colors.
- Ensure:

  - Lists, grids, and buttons look good in dark mode.
  - Selection states in the thumbnail grid are clear (e.g., overlay, border, checkmark).
  - Empty states and error messages are legible and not overly bright.

- Add minor UX touches:
  - Clear headings for each step.
  - “Back” button between steps in `NewSlideshowFlowView`.
  - Short helper text below settings sliders/toggles.

### Notes to Copilot

- Do not implement slideshow playback yet.
- Focus on visual clarity and consistency while staying close to system defaults.

---

## Next Steps (Future Stages – Not for Now)

These are **explicitly out of scope for this plan**, but will be addressed later:

- Slideshow playback UI:
  - Full-screen slideshow.
  - Integration of shuffle/repeat logic.
  - Keyboard shortcuts (start/stop, next/previous).
- Performance optimization for large libraries (pre-caching, paging).
- Advanced settings (transition styles, per-photo durations).
- Deleting/editing existing slideshows.
- Exporting or sharing slideshows.