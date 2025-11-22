You are helping debug Spotify integration in a macOS SwiftUI app called Electric Slideshow.

### Context

The app uses a Node/Express backend for Spotify OAuth PKCE and Web API calls.

Current behavior:

- When I click “Connect to Spotify” in the app, it opens the Spotify consent page in my browser.
- I click “Agree” and the app is brought back to the foreground via the custom URL scheme.
- At the top of the app, the UI now says I am “Connected to Spotify”.
- However:
  - When I click the button to create a new slideshow playlist from my Spotify account/library, the modal shows: **“Failed to load Spotify Library”**.
  - When I click the user icon in the top navbar, the modal that should show my name/email/account info instead shows: **“Failed to Load Profile”**.
- In my Spotify account page (in Chrome), under connected apps, I can see **Electric Slideshow** listed.
- The original Spotify consent web page is still sitting on the “Agree” screen; it doesn’t redirect to a nice success page, which might or might not be relevant.

So: the app thinks I’m connected, but all subsequent Spotify data calls fail.

### Files and components you should inspect

In this Swift project, please:

1. Examine `SpotifyAuthService.swift` and find:
   - The `handleCallback(url:)` implementation that processes the redirect from Spotify.
   - How the authorization `code`, `state`, and any `error` are extracted from the callback URL.
   - The method that calls the backend token endpoint (for exchanging the code for access/refresh tokens).
   - Where and how access/refresh tokens are stored (in memory, Keychain, UserDefaults, etc.).
   - Where `isAuthenticated` is set to `true`.

2. Examine `SpotifyAPIService.swift` and:
   - Identify the methods used to fetch:
     - User profile (for the “profile” modal).
     - Spotify library / playlists (for the “Failed to load Spotify Library” modal).
   - Check what base URL they use to call the backend (and confirm it matches the new backend hostname).
   - Check how the access token is passed along (Authorization headers, query params, etc.).
   - Confirm they are using the same token that `SpotifyAuthService` receives/stores.

3. Find the Swift views / view models that show:
   - “Connected to Spotify”
   - “Failed to load Spotify Library”
   - “Failed to Load Profile”
   Those views likely depend on some `@EnvironmentObject` or `ObservableObject` (such as `SpotifyAuthService` and/or `SpotifyAPIService`) and may have logic to display those error states.

### What I want you to do

1. **Trace the whole flow in the Swift code path:**
   - From callback URL (`onOpenURL` or equivalent) → `SpotifyAuthService.handleCallback(url:)` → token-exchange request → token storage → API calls to load profile/library → UI state in the Music/playlist/profile views.

2. **Verify the following and fix if needed:**
   - `handleCallback(url:)`:
     - Must only treat the flow as successful if the token exchange backend call actually succeeds and returns valid tokens.
     - Should NOT set `isAuthenticated = true` just because a code exists; it should set it only after a successful token exchange.
   - Token storage:
     - Ensure the access/refresh tokens returned by the backend are stored in a way that `SpotifyAPIService` actually reads/uses.
   - API calls:
     - Ensure that requests made from `SpotifyAPIService` to fetch profile and library are passing whatever token / credentials the backend expects (or hitting the correct backend routes).
     - Ensure the base URL matches the new backend service, and there are no leftover references to the old server.

3. Improve logging / error visibility:
   - For the profile/library fetch methods, make sure they log (or propagate) the actual error message returned by the backend (HTTP status code and body), not just a generic “Failed to load Spotify Library/Profile”.
   - This will help confirm whether the problem is:
     - Bad tokens,
     - Wrong endpoint,
     - Backend returning 401/403/500, etc.

4. Apply minimal, surgical changes:
   - Do NOT redesign the architecture.
   - Only adjust:
     - The callback handling,
     - Token state and storage,
     - The wiring between `SpotifyAuthService` and `SpotifyAPIService`,
     - Error handling in the views, if necessary.

After you modify the code, please summarize:
- What was wrong, and
- What changes you made (ideally show a diff or code snippets).