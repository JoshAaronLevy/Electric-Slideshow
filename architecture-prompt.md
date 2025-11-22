I want you to make a very focused, minimal set of changes to clean up the photo permission flow and import statements.
Do NOT do any large refactors, do NOT touch slideshow playback code, music/Spotify views, or anything unrelated to photo permissions.
Only modify the following files:

* `Electric_SlideshowApp.swift`
* `AppShellView.swift`
* `PermissionViewModel.swift`
* `PhotoLibraryService.swift`

---

## Goal 1: Use a single, consistent photo authorization path

Right now there are **two** ways to request Photos permission:

1. `PermissionViewModel.requestAuthorization()` → calls `photoService.requestAuthorization()`
2. `PermissionViewModel.requestAuthorizationSync()` → calls `PHPhotoLibrary.requestAuthorization(for: .readWrite)` directly and then manually updates `photoService.authorizationStatus`.

I want to **standardize on ONE path**:

**All permission requests should go through `PhotoLibraryService.requestAuthorization()`**, and UI should call `PermissionViewModel.requestAuthorization()` only.

Please do the following:

1. In `PermissionViewModel.swift`:

   * Remove (or fully comment out) the `requestAuthorizationSync()` method.
   * Make sure there is **only one** method responsible for requesting permission:
     `func requestAuthorization() async` which calls `photoService.requestAuthorization()`, then uses the returned status to update `state` via `updateState(from:)`.
   * Do NOT call `PHPhotoLibrary.requestAuthorization` directly inside the view model anymore. All direct calls to `PHPhotoLibrary.requestAuthorization` should live only inside `PhotoLibraryService.requestAuthorization()`.
2. In `AppShellView.swift`:

   * In `PermissionNotificationBar`, the “Grant Access” button currently uses `permissionVM.requestAuthorizationSync()` via the closure passed as `onRequestAccess`.
   * Change this so that when the user taps **Grant Access** in the notification bar, it uses the async `requestAuthorization()` method instead:

     ```swift
     onRequestAccess: {
         Task {
             await permissionVM.requestAuthorization()
         }
     }
     ```
   * Make sure there are no remaining references to `requestAuthorizationSync()` anywhere in `AppShellView`.
3. In `PhotoLibraryService.swift`:

   * Leave `requestAuthorization()` as the **sole** place where `PHPhotoLibrary.requestAuthorization(for: .readWrite)` is called.
   * Keep its logging and the `authorizationStatus` update, that’s fine. Just confirm that no other parts of the app directly mutate `authorizationStatus` except within this class.
4. After this, there should be:

   * No calls to `PHPhotoLibrary.requestAuthorization` outside of `PhotoLibraryService`.
   * No remaining `requestAuthorizationSync()` method or references.

---

## Goal 2: Normalize imports in these core files

In the following files:

* `Electric_SlideshowApp.swift`
* `AppShellView.swift`
* `PermissionViewModel.swift`
* `PhotoLibraryService.swift`

Please:

1. Replace any `import SwiftUI` with:

   ```swift
   import SwiftUI
   ```
2. Replace any `import Photos` with:

   ```swift
   import Photos
   ```

Do not add any new frameworks or change other imports. Just normalize these to standard `import` statements.

---

## Constraints

* Do NOT touch any slideshow-related models, view models, or views in this step.
* Do NOT touch any Spotify-related services or views in this step.
* Do NOT introduce new files.
* Keep logging as-is unless it blocks compilation.