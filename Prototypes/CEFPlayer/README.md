# CEFPlayer Prototype

Goal: verify that the Spotify Web Playback SDK works inside Chromium Embedded Framework (Widevine availability, device registration, playback events).

## Prerequisites
- macOS with Xcode command-line tools installed (for codesign, shasum, unzip).
- Spotify Premium account + valid OAuth access token (retrieve via existing Electric Slideshow flow or `spotify-player-report.md` instructions).
- ~500 MB free disk space.

## Steps
1. **Download CEF**
   ```bash
   ./scripts/download_cef.sh
   ```
   This populates `ThirdParty/CEF/cef_binary_<version>_macosx64_minimal/`.

2. **Launch the prototype**
   ```bash
   ./Prototypes/CEFPlayer/run_cef_player.sh
   ```
   - Opens `cefclient` pointing to `https://electric-slideshow-server.onrender.com/internal-player`.
   - Enables remote debugging on port `9223` for DevTools access.

3. **Inject Spotify token**
   - In the CEF window, press `Cmd+Option+I` (or open Chrome DevTools via `http://localhost:9223` from Chrome) to get a console.
   - Run: `INTERNAL_PLAYER.setAccessToken('YOUR_SPOTIFY_ACCESS_TOKEN')`.
   - Watch the console for `connectResult: connected` and the device ID.

4. **Capture metrics**
   - Note cold-start duration (time from running script to `Spotify Web Playback SDK loaded`).
   - Use Activity Monitor to record memory usage of `cefclient` process.
   - Record device ID + timestamp in `metrics-template.md`.

5. **Validate playback**
   - From Spotify mobile/desktop, transfer playback to "Electric Slideshow Internal Player".
   - Play/pause from the Spotify app and ensure logs reflect `player_state_changed` events.

## Files
- `run_cef_player.sh`: helper script that launches `cefclient` with the right arguments.
- `metrics-template.md`: copy/fill for each test run to document results.

## Cleanup
- To remove downloaded binaries, delete `ThirdParty/CEF/.cache` and the extracted folder.

## Troubleshooting
- If the window stays blank, ensure the backend URL is reachable (Render deployed app status).
- If `setAccessToken` errors, confirm the token has `streaming`, `user-read-playback-state`, `user-modify-playback-state` scopes.
- For Widevine failures, collect logs and confirm you’re running the official CEF build (not the sample app built with Debug configs).
