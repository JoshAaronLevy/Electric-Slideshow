# Electric Slideshow – New Top Navigation UI Plan

Goal: Introduce a custom **top navigation bar** for the macOS SwiftUI app that:

- Shows the **app name** on the left (“Electric” on top, “Slideshow” underneath).
- Shows the **current view title** in the center (e.g., “Slideshows”, “Music”, “Settings”).
- Shows a row of **navigation icons** on the right:
  - Slideshows
  - Music
  - Settings
  - User (click does nothing for now)
- Supports switching between primary sections:
  - Slideshows (existing)
  - Music (new placeholder)
  - Settings (new placeholder)
- Keeps the existing slideshow creation and photo selection flows working inside the “Slideshows” section.
- Looks good in **dark mode**.

This plan is broken into stages so I can ask Copilot to implement them one at a time.

---

## Stage 1 – Define Navigation Model & Root Shell View

### Goal

Create a single **root shell view** that manages which “section” of the app is active and will host the new navigation bar and content below it.

### Tasks

1. **Create a navigation enum**

In a suitable place (e.g., `Models/AppSection.swift` or inside a new `Navigation` folder), define:

```swift
enum AppSection: String, CaseIterable, Identifiable {
    case slideshows
    case music
    case settings
    case user

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slideshows: return "Slideshows"
        case .music: return "Music"
        case .settings: return "Settings"
        case .user: return "User"
        }
    }

    var systemImageName: String {
        switch self {
        case .slideshows: return "photo.on.rectangle"
        case .music: return "music.note"
        case .settings: return "gearshape"
        case .user: return "person.crop.circle"
        }
    }
}
````

2. **Create a new root “main content” view**

Add a new view, e.g. `AppMainView`, that:

* Owns a `@State var selectedSection: AppSection = .slideshows`.
* Renders the **top navigation bar** and the **active section content** below it.
* For now, the section content can be simple placeholders:

  * Slideshows: use the existing `SlideshowsListView`.
  * Music: a simple text placeholder.
  * Settings: a simple text placeholder.
  * User: a simple text placeholder (even though the icon won’t navigate to it yet, we can still support it as a section).

3. **Wire `AppMainView` into the existing app**

Update the part of the app that currently shows `SlideshowsListView` after permissions are granted (likely in `AppShellView`) so that, instead, it shows `AppMainView` and passes any necessary environment objects (e.g., `PhotoLibraryService`).

**Important Constraint:**
Do not break the photo library and slideshow creation flows. Those should continue to live under the **Slideshows** section.

---

## Stage 2 – Implement `AppNavigationBar` View

### Goal

Create a reusable **top navigation bar** view that:

* Shows the stacked app name on the left.
* Shows the current section title in the center.
* Shows the nav icons on the right.

### Tasks

1. **Create `AppNavigationBar`**

Create a new view, e.g. `AppNavigationBar`, with an API similar to:

```swift
struct AppNavigationBar: View {
    let appTitleTop: String
    let appTitleBottom: String
    let currentSectionTitle: String
    let sections: [AppSection]
    let selectedSection: AppSection
    let onSectionSelected: (AppSection) -> Void

    var body: some View {
        // TODO: Implement layout
    }
}
```

2. **Layout requirements**

Inside `AppNavigationBar`:

* **Left side**:

  * A VStack with:

    * `Text("Electric")` (headline / bold)
    * `Text("Slideshow")` (smaller / secondary)
  * Align vertically and keep it tight so it doesn’t use too much horizontal space.
* **Center**:

  * `Text(currentSectionTitle)` styled as the **view title** (e.g. `.title3` or `.headline`), centered.
* **Right side**:

  * An HStack of buttons for each section in `sections`:

    * Use SF Symbols from `AppSection.systemImageName`.
    * The **User** icon should still be rendered but its tap handler can be either:

      * no-op, or
      * call a closure that currently does nothing (will be used later for a modal).
  * The selected section should be visually indicated (e.g., accent color, or a capsule background).

3. **Styling**

* Make sure the bar looks good in dark mode:

  * Use system colors: `Color(nsColor: .windowBackgroundColor)` or `Color.background` equivalents.
  * Use subtle borders (e.g. `Divider()` at the bottom).
* Use a fixed height for the bar (e.g., 44–56 points).
* Add horizontal padding.

---

## Stage 3 – Integrate `AppNavigationBar` into `AppMainView`

### Goal

Compose `AppNavigationBar` and the current section’s content into a single cohesive layout.

### Tasks

1. **Use a vertical layout**

In `AppMainView`:

* Wrap everything in a `VStack`:

  * Top: `AppNavigationBar`
  * Bottom: a content area (the current section view).

Something like:

```swift
VStack(spacing: 0) {
    AppNavigationBar(
        appTitleTop: "Electric",
        appTitleBottom: "Slideshow",
        currentSectionTitle: selectedSection.title,
        sections: [.slideshows, .music, .settings, .user],
        selectedSection: selectedSection,
        onSectionSelected: { section in
            // We'll define behavior here
        }
    )

    Divider()

    ZStack {
        switch selectedSection {
        case .slideshows:
            SlideshowsListView()
                .environmentObject(photoService) // if needed
        case .music:
            MusicPlaceholderView()
        case .settings:
            SettingsPlaceholderView()
        case .user:
            UserPlaceholderView()
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

2. **Provide placeholder views**

Create simple placeholder views, e.g.:

```swift
struct MusicPlaceholderView: View {
    var body: some View {
        Text("Music view loaded!")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        Text("Settings view loaded!")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}

struct UserPlaceholderView: View {
    var body: some View {
        Text("User view loaded!")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}
```

These should be dark-mode-friendly and centered in the available space.

---

## Stage 4 – Navigation Behavior & User Icon Rules

### Goal

Wire up the icon interactions so:

* Slideshows, Music, and Settings icons switch the `selectedSection`.
* The User icon **does not** change the section yet (it will be wired to a modal later).

### Tasks

1. **AppSection filtering**

When building the right-side nav icons:

* Still show all four icons visually.
* In the `onSectionSelected` closure (or similar in `AppMainView`), only change `selectedSection` for:

  * `.slideshows`
  * `.music`
  * `.settings`
* For `.user`:

  * For now, either ignore taps or keep the action empty.
  * Example:

  ```swift
  onSectionSelected: { section in
      switch section {
      case .user:
          // TODO: will trigger a modal later, do nothing for now
          break
      default:
          selectedSection = section
      }
  }
  ```

2. **Visual selection state**

In `AppNavigationBar`, visually highlight the `selectedSection` icon:

* For example, use:

  * `.foregroundStyle(.accentColor)` for selected, `.secondary` for unselected.
  * Or a capsule background with `.background(Color.accentColor.opacity(0.2))`.

This should make it obvious which section is active.

---

## Stage 5 – UX Polish & Dark Mode Tweaks

### Goal

Ensure the new top navigation and layout look cohesive and polished on macOS in dark mode.

### Tasks

1. **Spacing & alignment**

* Make sure:

  * Left app title block is tight and aligned.
  * Center title is actually centered across the width.
  * Right icons are right-aligned and evenly spaced.

2. **Colors & typography**

* Use system fonts and colors where possible:

  * App title: `.font(.headline)` for “Electric”, `.font(.caption)` for “Slideshow”.
  * View title: `.font(.headline)` or `.title3`.
  * Use `.foregroundStyle(.primary)` for main text, `.secondary` for supporting text.

3. **Window resizing behavior**

* Confirm the layout behaves well when:

  * The window is resized narrow.
  * The window is expanded wide.
* Ensure the nav bar components don’t overlap or truncate in an awkward way.

4. **Remove temporary debug UI**

* If any temporary debug prints or placeholder layout hacks were added, either:

  * Clean them up, or
  * Comment them clearly as TODOs.