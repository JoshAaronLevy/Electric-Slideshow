I’m building a macOS-only SwiftUI app called **Electric Slideshow**. The MVP of the app does the following:

1. Requests permission to access the user’s Apple Photo Library
   (PhotoKit: PHPhotoLibrary / PHAsset / PHAssetCollection).

2. Shows a sidebar with all albums (smart albums + user albums).

3. When an album is selected, displays a grid of thumbnail images.
   Use PHCachingImageManager to load thumbnails efficiently.

4. When a user clicks a photo, open a simple detail view showing a larger version.
   (Full resolution loading can be a placeholder for now.)

Architecture preferences:

* Use **Swift + SwiftUI** only.

* Use a clean structure with:

  * `/Services` (e.g., `PhotoLibraryService`)
  * `/ViewModels` (e.g., `AlbumListViewModel`, `PhotoGridViewModel`)
  * `/Views` (SwiftUI screens)
  * `/Models` (simple structs representing albums and assets)

* Use modern Swift Concurrency (`async/await`) where possible.

* Keep PhotoKit access inside a service that exposes async methods.

* Keep view models observable (`@MainActor`, `Observable`, `@Published` style modeling).

* Build a split-view layout:
  Left: Album list
  Right: Photos grid

What I need from you:

1. **Analyze the existing project structure** as created by Xcode.
2. Suggest the **base folder structure** to add (Services, ViewModels, Views, Models).
3. Generate the **initial scaffolding code** for:

   * `PhotoLibraryService`
   * `AlbumListViewModel`
   * `AlbumListView`
   * `PhotoGridViewModel`
   * `PhotoGridView`
4. Modify `Electric_SlideshowApp.swift` and `ContentView.swift` to integrate the split-view layout.
5. Tell me if there are additional files that should be added early (helpers, constants, etc.).
6. Provide all code carefully in separate blocks so I can paste each file in the right place.

Do NOT generate test files yet.
Do NOT create complex metadata extraction yet.
Just scaffold the MVP cleanly and simply.

When you’re ready, start by confirming the folder structure you recommend, then output the initial code files.