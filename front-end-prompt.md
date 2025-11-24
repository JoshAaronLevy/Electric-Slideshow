I’m getting a Spotify playback error from the backend when I try to play a slideshow that has an associated Spotify playlist.

The backend returns a Spotify error payload like:

{
  "error": {
    "status": 404,
    "message": "Player command failed: No active device found",
    "reason": "NO_ACTIVE_DEVICE"
  }
}

In the macOS SwiftUI app:

- I can log in with Spotify.
- I can create slideshows and associate them with a Spotify playlist.
- When I click Play on a slideshow, the app:
  - Enters a full-screen slideshow playback view.
  - Calls the backend to start playback of the playlist.
- But if there is no active Spotify device, the backend responds with NO_ACTIVE_DEVICE and playback fails.

I also added a debug button in the Settings/Music area that opens a sheet to show available Spotify devices, but the sheet currently appears blank (no devices or message).

I want you to:

1) Make the devices sheet robust and informative.
2) Surface NO_ACTIVE_DEVICE errors to the user in a friendly way.
3) Ensure slideshow playback continues even if music fails.
4) Avoid layout recursion issues in the sheet.

Here’s what I want you to implement:

---

1) Devices sheet + view model

- Find the view model and view responsible for the Spotify devices sheet. If they don’t exist yet, create them. Suggested names:

  - View model: `SpotifyDevicesViewModel`
  - View: `SpotifyDevicesSheetView`

- The view model should:

  - Depend on `SpotifyService` (or whatever service already talks to the backend).
  - Have:

    ```swift
    @Published var devices: [SpotifyDevice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    ```

  - Define a `SpotifyDevice` struct that matches the backend’s device JSON, for example:

    ```swift
    struct SpotifyDevice: Identifiable, Decodable {
        let id: String
        let name: String
        let type: String
        let isActive: Bool
        let isRestricted: Bool
        let volumePercent: Int?
    }
    ```

    Adjust field names and coding keys to match the backend response.

  - Implement a `loadDevices()` async method that:

    - Calls the backend endpoint (e.g. `GET /api/spotify/devices`) via `SpotifyService`.
    - Updates `devices`, `isLoading`, and `errorMessage` appropriately.
    - Does NOT crash if the backend returns an empty array.

- The devices sheet SwiftUI view should:

  - Use `@StateObject var viewModel: SpotifyDevicesViewModel`.
  - In `.task` (or `.onAppear`) call `await viewModel.loadDevices()`.
  - Show:

    - A loading spinner when `isLoading == true`.
    - If `devices` is non-empty:
      - A List or Table of devices showing name, type, and whether it’s active.
    - If `devices` is empty and not loading:
      - A friendly message, e.g.:

        > “No active Spotify devices found. To use Spotify playback, open Spotify on this Mac (or another device), start playing something in Spotify once, then come back and refresh.”

    - A “Refresh” button that re-runs `loadDevices()`.

  - Avoid any custom layout calls that could trigger layout recursion. Use standard VStack/HStack/List/ScrollView and avoid manual calls like `layoutSubtreeIfNeeded`.

---

2) Wire the devices sheet into Settings/Music UI

- Find the Settings/Music view where you added the debug button to show Spotify devices.
- Update that button so it presents the `SpotifyDevicesSheetView` using `.sheet` with a binding.
- Pass the existing `SpotifyService` instance down into the sheet/view model so that `loadDevices()` can call the backend.

---

3) Handle NO_ACTIVE_DEVICE in slideshow playback

- Find the view or view model that handles slideshow playback and triggers playlist playback via the backend. It might be something like `SlideshowPlaybackView` or a related view model.

- Wherever the app calls the backend “start playback” endpoint (through `SpotifyService`):

  - Update the call so that it can inspect the backend’s response:

    - If the backend indicates success, continue as normal.
    - If the backend returns a structured error with something like `code: "NO_ACTIVE_DEVICE"` or similar:

      - Show a non-blocking alert/banner/toast in the UI with a message along the lines of:

        > “We couldn’t find an active Spotify device. Open Spotify on this Mac (or another device), start playing something once, then try again.”

      - Do **not** crash the app.
      - Do **not** stop the slideshow. The slideshow should keep showing photos even if music fails.

  - If the backend returns some other error, show a generic “Couldn’t start Spotify playback.” message, but still keep the slideshow running.

---

4) Avoid layout recursion warning in the devices sheet

The logs include:

> It's not legal to call -layoutSubtreeIfNeeded on a view which is already being laid out. … This may break in the future.

- Inspect the code for the devices sheet and remove anything that might trigger recursive layout during view body evaluation, such as:

  - Custom NSViewRepresentable calls that force layout.
  - Calls to AppKit layout methods inside `body` or SwiftUI layout callbacks.

- Use standard SwiftUI layout primitives (VStack, HStack, List, ScrollView) and rely on the system to lay things out instead of forcing layout passes.

---

5) Constraints

- Do NOT change or break the slideshow creation flow, photo permission logic, or photo selection.
- Keep changes focused on:
  - The Spotify devices debug sheet.
  - The Spotify playback error handling in the slideshow playback path.
  - The Music/Settings area where the devices sheet is triggered.
- Keep using the existing `SpotifyService` abstraction for network calls; just extend it as needed to:

  - Call the devices endpoint.
  - Surface structured errors from the playback start endpoint.

When you’re done, please provide an overview for me on:

- The updated `SpotifyService` methods used for devices and playback.
- The new or updated `SpotifyDevicesViewModel` and devices sheet view.
- The updated slideshow playback logic that surfaces the NO_ACTIVE_DEVICE error to the user without breaking playback.