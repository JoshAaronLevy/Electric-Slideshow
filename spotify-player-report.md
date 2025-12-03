# Spotify Player Implementation Report

## Overview
The application implements an internal Spotify player using a `WKWebView` that hosts the Spotify Web Playback SDK. This allows the app to play music directly within the application context, controlled via a Swift-JS bridge.

## Architecture
- **Core Component**: `InternalSpotifyPlayer` (Swift) wraps a `WKWebView`.
- **Playback Backend**: `SpotifyInternalPlaybackBackend` implements the `MusicPlaybackBackend` protocol, managing the player instance and handling events.
- **Source**: The HTML/JS content for the player is hosted remotely at `https://electric-slideshow-server.onrender.com/internal-player`. It is *not* bundled with the app.
- **Authentication**: `SpotifyAuthService` handles OAuth PKCE flow and token management. Tokens are injected into the WebView to authenticate the SDK.

## Current Implementation Status

### ✅ Implemented Features
1.  **Authentication**:
    -   Full OAuth PKCE flow implemented in `SpotifyAuthService`.
    -   Token storage in Keychain.
    -   Token refresh mechanism.
    -   Token injection into the WebView (`setAccessToken`).

2.  **Player Controls (Swift -> JS)**:
    -   `play()`
    -   `pause()`
    -   `nextTrack()`
    -   `previousTrack()`
    -   `seek(to:)`
    -   `setVolume(_:)`

3.  **Event Handling (JS -> Swift)**:
    -   The player listens for `playerEvent` messages from JS.
    -   Handles `ready` (device active), `stateChanged` (playback updates), and `error` events.
    -   Maps internal events to the app's `PlaybackState` model.

4.  **API Integration**:
    -   `SpotifyAPIService` covers User Profile, Playlists, Saved Tracks, and Playback State.
    -   Includes a backend proxy for fetching available devices.

### ⚠️ Missing or Incomplete
1.  **Shuffle & Repeat**:
    -   `SpotifyInternalPlaybackBackend.setShuffleEnabled(_:)` is a stub (prints "not wired yet").
    -   `SpotifyInternalPlaybackBackend.setRepeatMode(_:)` is a stub (prints "not wired yet").
    -   *Note*: `SpotifyAPIService` has methods for these, but they are not connected to the internal player backend logic.

2.  **Offline/Local Handling**:
    -   The player relies entirely on the remote URL. If the server is down or the user is offline, the player will not load.

3.  **Error Handling**:
    -   Basic error propagation is in place, but robust recovery (e.g., auto-reloading the WebView on failure) is not evident.

4.  **Device Switching**:
    -   The code handles the "ready" event which provides a Device ID, but explicit device switching logic within the internal player context is limited.

## Recommendations
1.  **Implement Shuffle/Repeat**: Wire up the `setShuffleEnabled` and `setRepeatMode` methods in `SpotifyInternalPlaybackBackend` to call the appropriate API endpoints or JS methods.
2.  **Offline Fallback**: Consider bundling a fallback HTML file or handling offline states more gracefully.
3.  **Unified Control**: Clarify the role of `SpotifyAPIService` playback controls vs. `InternalSpotifyPlayer` controls. If playing locally, the SDK (WebView) should likely be the primary driver, but API calls might be needed for some actions (like shuffle/repeat if the SDK doesn't support them directly in the version used).

## File Reference
-   `Electric Slideshow/Services/InternalSpotifyPlayer.swift`
-   `Electric Slideshow/Services/SpotifyInternalPlaybackBackend.swift`
-   `Electric Slideshow/Services/SpotifyAPIService.swift`
-   `Electric Slideshow/Services/SpotifyAuthService.swift`
-   `Electric Slideshow/Config/SpotifyConfig.swift`
