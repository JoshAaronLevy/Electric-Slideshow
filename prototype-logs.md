# Updated instructions for running the CEF prototype (2025-12-04)

1. **Pick a real CEF build**
  - Visit https://cef-builds.spotifycdn.com/ and copy the version string from a macOS *minimal* build (e.g. `123.0.4+g15c09fa`).
  ```bash
  echo "123.0.4+g15c09fa" > ThirdParty/CEF/version.txt
  # (or run download script with CEF_VERSION="..." prefixed)
  ```

2. **Download & extract CEF**
  ```bash
  ./scripts/download_cef.sh
  ```

3. **Launch the prototype browser**
  ```bash
  ./Prototypes/CEFPlayer/run_cef_player.sh
  ```
  This opens `cefclient` pointed at `https://electric-slideshow-server.onrender.com/internal-player` with DevTools on port 9223.

4. **Install tooling (first run only)**
  ```bash
  cd Prototypes/CEFPlayer
  npm install
  ```

5. **Inject Spotify token automatically**
  ```bash
  SPOTIFY_ACCESS_TOKEN="<oauth-access-token>" npm run inject-token
  ```
  - Token must be a real Spotify OAuth access token (scopes: `streaming`, `user-read-playback-state`, `user-modify-playback-state`).
  - The script waits for `cefclient` to expose its DevTools target and then calls `INTERNAL_PLAYER.setAccessToken(...)`.

6. **Verify**
  - Watch the terminal for `token_sent` and the CEF logs for `connectResult: connected` + device ID.
  - Use Spotify Connect to transfer playback to "Electric Slideshow Internal Player" and capture metrics.