# Electric Slideshow – Spotify UX & Transparency Plan

Goal:
Make Spotify integration **predictable, transparent, and non-creepy** by:

* Explaining requirements (Spotify app + Premium) early.
* Making it clear that Electric Slideshow **only tells Spotify what to play**, never modifies the user’s library.
* Preventing “WTF why did Spotify just open?” moments.

This plan assumes the existing integration:

* Spotify auth via `SpotifyAuthService`
* Playlist browsing in the **Music** view
* Playback via `SlideshowPlaybackViewModel` + `SpotifyAPIService`
* Basic “ensure Spotify desktop app is installed/launched” logic already wired into `startMusic()`.

We’ll implement this in **stages**, so each step is small and testable.

---

## Stage 0 – Plumbing & State

**Objective:** Introduce the minimal shared state needed to drive the UX, without changing any UI yet.

### 0.1. New integration flags

Add these persistent flags (likely in `SpotifyAuthService` or a new `MusicEnvironmentStore`):

* `spotifyDesktopInstalled: Bool`

  * Updated at app launch via a `NSWorkspace` check for `com.spotify.client`.
* `hasSeenSpotifyDesktopInfo: Bool`

  * Whether the user has already been shown the “you need the Spotify app + Premium” info in the Music view.
* `hasConsentedToLaunchingSpotify: Bool`

  * Whether the user has explicitly agreed to Electric Slideshow opening Spotify to play music.

**Recommended location:**
`SpotifyAuthService` (since it already handles auth and is an `EnvironmentObject`), e.g.:

```swift
@Published var spotifyDesktopInstalled: Bool = false
@Published var hasSeenSpotifyDesktopInfo: Bool = false
@Published var hasConsentedToLaunchingSpotify: Bool = false
```

### 0.2. Launch-time desktop app detection

At app launch (in `AppShellView` or similar root view):

* Perform a one-time check:

  ```swift
  let bundleId = "com.spotify.client"
  let isInstalled = (NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil)
  spotifyAuthService.spotifyDesktopInstalled = isInstalled
  ```

* No UI yet. Just record the fact.

**Acceptance criteria:**

* `spotifyDesktopInstalled` is correctly `true` on your Mac once Spotify is installed.
* Changes immediately reflect if the app is uninstalled (not critical for v1, but nice).

---

## Stage 1 – Music View Requirements Card (Early Transparency)

**Objective:** When the user visits the **Music** view, clearly explain that they’ll need the Spotify desktop app + Premium for slideshow music.

### 1.1. Conditions for showing the card

Show the “requirements” card when:

* User is **not connected** to Spotify (`!spotifyAuthService.isAuthenticated`), and
* `spotifyDesktopInstalled == false`.

Optionally, you can ignore `hasSeenSpotifyDesktopInfo` at first and always show it while the app is missing; later we can add a “Don’t show again” toggle.

### 1.2. UI content (copy draft)

In the Music view (e.g., `PlaylistsView` or `MusicDashboardView`), above your existing “Connect to Spotify” block:

> 🔊 **Want music with your slideshows?**
>
> To play Spotify music during Electric Slideshow, you’ll also need:
>
> * The **Spotify app** installed on this Mac
> * A **Spotify Premium** subscription
>
> Electric Slideshow will never create, edit, or delete anything in your Spotify library.
> It only tells Spotify *which songs to play* while your slideshow is running.
>
> [Download Spotify for macOS] [Learn more]

**Behavior:**

* **Download Spotify** → opens Spotify’s macOS download page in the default browser.
* **Learn more** → either:

  * Opens a small sheet with more details, or
  * Navigates to a “Music & Spotify” section in Settings (to be implemented in a later stage).

Existing “Connect to Spotify” block stays unchanged and still appears below this card.

### 1.3. Implementation notes

* Use a visually distinct card style (border, subtle accent background) so it’s clearly a “special info” block.
* Keep the card **non-blocking**: user can ignore it and still connect their account.

**Acceptance criteria:**

* With Spotify not installed + not connected: Music view shows the requirements card + existing connect card.
* With Spotify installed + not connected: Only the connect card is shown.
* With Spotify installed + connected: Playlists behave as today; requirements card is hidden.

---

## Stage 2 – First-Time “Use Spotify for Music?” Consent

**Objective:** Before the app opens Spotify for the first time to play slideshow music, explicitly tell the user what’s about to happen and give them a clear choice.

### 2.1. When to show the consent dialog

Show this dialog when:

* User clicks **Play** on a slideshow **that has a playlist assigned**.
* `spotifyAuthService.isAuthenticated == true`.
* `spotifyAuthService.spotifyDesktopInstalled == true`.
* `hasConsentedToLaunchingSpotify == false`.

Trigger point:

* The best place is **before** routing to `NowPlayingView` and **before** calling `startMusic()`.
* That likely means in the closure that handles “Start playback” from `SlideshowsListView`:

  * Today: it sets `NowPlayingStore.activeSlideshow` and navigates to `.nowPlaying`.
  * After Stage 2: it checks the flags and, if necessary, presents a dialog first.

### 2.2. Dialog copy draft

> **Use Spotify to play music with your slideshows?**
>
> Electric Slideshow uses the Spotify app on this Mac to play music during slideshows.
> When you start a slideshow with music, the app will:
>
> * Open Spotify in the background (if it’s not already open)
> * Tell Spotify *which playlist to play*
>
> Electric Slideshow will **never create, edit, or delete** anything in your Spotify library.
>
> If you prefer not to allow this, your slideshows will still play — just without Spotify music.
>
> [Allow & continue] [Play without music]

### 2.3. Behavior

* **Allow & continue**

  * Set `hasConsentedToLaunchingSpotify = true`.
  * Proceed with existing flow:

    * Set `nowPlayingStore.activeSlideshow`.
    * Switch to `.nowPlaying`.
    * Call `startMusic()` → which may open Spotify and start playback.
* **Play without music**

  * Leave `hasConsentedToLaunchingSpotify` as `false` OR record a “declined” flag if you want.
  * Set `nowPlayingStore.activeSlideshow`.
  * Switch to `.nowPlaying`.
  * **Skip** calling `startMusic()` for this play.
  * Optionally show a small banner in Now Playing:

    > “Music is disabled for this slideshow. You can enable Spotify again in Settings → Music & Spotify.”

**Important:**
This dialog is shown **once per app install** (per user) after they accept. It should **not** pop every time.

If you later allow multiple Spotify accounts, you can reset `hasConsentedToLaunchingSpotify` when a new account connects.

**Acceptance criteria:**

* First playback of a music-enabled slideshow shows the dialog exactly once.
* After “Allow & continue”, future music-enabled slideshows start Spotify automatically with no more prompts.
* After “Play without music”, slideshow works visually, but no Spotify playback is attempted for that run.

---

## Stage 3 – Runtime Fallbacks (Already Partially Implemented)

**Objective:** Gracefully handle runtime “oh crap” scenarios even after we’ve done all the up-front UX.

Most of this is already done or partially done:

1. **App not installed at runtime**

   * At `startMusic()` time:

     * If Spotify app is missing → set `requiresSpotifyAppInstall = true`, set `showingMusicError = true` with a clear message, and bail.
   * `SlideshowPlaybackView` alert:

     * If `requiresSpotifyAppInstall == true` → show “Download Spotify” and “Dismiss” buttons.
2. **No active device / no devices at all**

   * If `fetchAvailableDevices()` returns empty → show precise “no devices found – open Spotify on some device” messaging.
   * If Spotify returns `reason = "NO_ACTIVE_DEVICE"` → show messaging explaining that no player is online / available.

This stage is mostly about making sure the **error messages** align with the earlier Music view messaging (so users feel like they’re hearing the *same story*, not new surprises).

**Acceptance criteria:**

* If Spotify app is missing at playback time:

  * A friendly alert explains the problem and offers a “Download Spotify” button.
  * Slideshow still plays visually, just without music.
* If there are zero Spotify devices:

  * User gets a clear message explaining they need to open Spotify on some device first.

---

## Stage 4 – Optional UI Polish & Settings Page

**Objective:** Give users a “control center” for everything Spotify-related, and polish runtime UX.

### 4.1. Music & Spotify settings section

Add a section in `SettingsDashboardView` (or a dedicated screen) like:

> **Music & Spotify**
>
> * Connection: `Connected as josh@example.com` / `Not connected`
> * Spotify app on this Mac: `Detected` / `Not found`
> * Permission to open Spotify: `Allowed` / `Not granted`
>
> Actions:
>
> * [Disconnect Spotify]
> * [Open Spotify app]
> * [Learn how Electric Slideshow uses Spotify]

Behind the scenes, these values map to:

* `spotifyAuthService.isAuthenticated`
* `spotifyAuthService.spotifyDesktopInstalled`
* `spotifyAuthService.hasConsentedToLaunchingSpotify`

### 4.2. “Connecting to Spotify…” status in Now Playing

When `startMusic()` is performing a multi-step process (launch app, wait, find device, start playback):

* Show a small banner / overlay in Now Playing:

  > “Connecting to Spotify…” with a spinner

* Disable music controls while connecting.

* Hide the banner once playback starts or when an error is shown.

**Acceptance criteria:**

* Settings screen accurately reflects all Spotify-related state at a glance.
* Users can see exactly *why* music might not be available (e.g., missing app vs not connected).
* During the initial seconds of “startMusic()”, it’s clear that the app is still “doing something,” not frozen.

---

## Stage 5 – Future Consideration (Not Required Now)

If you ever decide to ship this publicly and want to go beyond “Spotify desktop must be running,” consider:

* Embedding a Spotify Web Playback SDK instance inside a hidden `WKWebView`, making “Electric Slideshow Player” its own Spotify Connect device.
* Letting advanced users choose a target device (Mac, Echo, etc.) from within the app.

That’s a full feature in itself and **not necessary** for your personal v1. The above stages already give you a solid, honest, user-friendly experience for your own laptop.

---

## Summary of Stages

1. **Stage 0 – Plumbing & State**

   * Add `spotifyDesktopInstalled`, `hasSeenSpotifyDesktopInfo`, `hasConsentedToLaunchingSpotify`.
   * Check app install status at launch.

2. **Stage 1 – Music View Requirements Card**

   * Show a “You need Spotify macOS + Premium” info card when not installed + not connected.

3. **Stage 2 – First-Time Consent Dialog**

   * Before first music-enabled slideshow playback, ask: “Use Spotify to play music?” with clear Allow / Play without music options.

4. **Stage 3 – Runtime Fallbacks**

   * Already mostly implemented: runtime alerts for missing app and no devices, with clear messaging and “Download Spotify” where appropriate.

5. **Stage 4 – Settings & Polish**

   * Add a “Music & Spotify” section in Settings.
   * Add a “Connecting to Spotify…” status in Now Playing while startup logic runs.

6. **Stage 5 – (Optional) Web Playback SDK**

   * Only if you want deeper control later.

---

If you want, next time we come back to this we can pick **Stage 1** or **Stage 2** and I’ll turn that piece into file-by-file instructions + concrete SwiftUI changes.