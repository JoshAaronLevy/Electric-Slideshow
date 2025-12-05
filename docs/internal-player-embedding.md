# Internal Player Embedding

- Build `ElectricSlideshowInternalPlayer.app` from the `electric-slideshow-internal-player` Electron project.
- Add the helper app to the main target with a Copy Files phase so it ends up at `Electric Slideshow.app/Contents/Resources/ElectricSlideshowInternalPlayer.app`.
- `InternalPlayerManager` resolves the executable at:

  ```swift
  Bundle.main.url(forResource: "ElectricSlideshowInternalPlayer", withExtension: "app")
      ?.appendingPathComponent("Contents/MacOS/ElectricSlideshowInternalPlayer")
  ```

- The manager launches the helper with `SPOTIFY_ACCESS_TOKEN`, `ELECTRIC_SLIDESHOW_MODE=internal-player`, and optional `ELECTRIC_BACKEND_BASE_URL` environment variables.
