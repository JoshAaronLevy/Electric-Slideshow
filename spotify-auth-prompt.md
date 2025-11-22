I need help fixing a specific macOS SwiftUI behavior in this project.

### **🧩 The Problem**

After the Spotify OAuth callback (via the custom URL scheme `com.electricslideshow://callback`):

* The app creates a **new tab/window**, starting at the default Slideshow screen.
* The original Music tab still shows “Connect to Spotify”.
* The new tab's Music view shows “Connected to Spotify”, meaning the right state is being updated but **in a different window**.

This happens because the app uses **`WindowGroup`**, which allows multiple windows/tabs, and macOS treats a URL-open event as a request to spawn a new scene.

### **🎯 What I need you to do**

1. **Replace `WindowGroup` with a single `Window` scene** in
   **`Electric_SlideshowApp.swift`** (path: `/mnt/data/Electric_SlideshowApp.swift`).

   * The new scene should look like:

     ```swift
     Window("Electric Slideshow", id: "mainWindow") {
         AppShellView(photoService: photoService)
             .environmentObject(photoService)
             .environmentObject(spotifyAuthService)
             .environmentObject(playlistsStore)
             .onOpenURL { url in
                 if url.scheme == "com.electricslideshow" {
                     Task {
                         await spotifyAuthService.handleCallback(url: url)
                     }
                 }
             }
     }
     ```

   * Ensure the `.commands` modifier remains intact.

   * Remove or adjust the existing `WindowGroup` so that only one main window is ever created.

2. **Verify that MusicView (and its parent views) read the authentication state directly from the existing `@EnvironmentObject var spotifyAuthService: SpotifyAuthService`.**

   * Do NOT introduce any new singletons or new instances of the service.
   * Ensure MusicView does NOT cache `isAuthenticated` in local `@State`.

3. **Do NOT create any new windows, scenes, or tabs in response to the URL callback.**
   The callback must update the **existing** window only.

4. Make the minimal required code edits and show me the diff.
   If anything is unclear or you detect multiple possible fixes, ask before applying.