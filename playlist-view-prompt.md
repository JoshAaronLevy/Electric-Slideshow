You are Antigravity, helping me work on a macOS app written in Swift called **Electric Slideshow**.

## High-Level Context

Electric Slideshow lets users:
- Create custom playlists from their Spotify library.
- Assign those playlists to slideshows.
- Choose global clip behavior (e.g. play 30s/45s/60s snippets or full songs) during a slideshow.

Right now, the app shows a **list of custom playlists**, but clicking on a playlist entry does **nothing**:
- I cannot navigate into a playlist.
- I cannot see which songs are in that playlist.
- I cannot edit or delete a playlist.
- I cannot define per-song custom clip ranges.

I want to add a new **Playlist Detail view** and related logic.

---

## New Feature: Playlist Detail View with Clip Editor Side Panel

### Desired UX Flow

1. When the user clicks a playlist in the existing playlist list view:
   - They are **navigated to a new Playlist Detail view**.

2. Playlist Detail View (main / left side):
   - Shows the **playlist name** at the top.
   - Shows a **global default clip length control**, something like:
     - `Default Clip Length: [ 30s | 45s | 60s | Full Song ]`
   - Shows a **calculated total playlist duration** based on the current clip rules, displayed in `HH:MM:SS`.
     - This duration should update dynamically if:
       - The global default clip length changes.
       - A track’s clip mode changes from default → custom or vice versa.
       - A track’s custom start/end points change.
   - Shows a **table/list of the songs in this playlist**, with columns similar to:
     - Song title
     - Artist (and optionally album)
     - Clip mode (e.g. `Default` or `Custom`)
     - Effective clip info, e.g.:
       - `0:45` for default clips
       - `1:02 → 1:34` or `0:32` for custom clips

   The table should stay visually uniform. Clicking on a row selects that song and updates the side panel on the right.

3. Playlist Detail View (right / side panel inspector):

   - When **no song is selected**:
     - The panel shows a friendly **empty state**, something like:
       - Title: “Customize Song Playback”
       - Copy: “Select a song from the playlist to set a custom clip range and adjust song-specific settings.”
     - This is there to:
       - Teach users that this feature exists.
       - Make it clear that song-specific options live here.
       - Avoid a blank, confusing panel.

   - When a **song is selected**:
     - The panel switches into an **active clip editor** for that song.
     - It shows:
       - Song title, artist, and album art.
       - A **Clip Mode** control:
         - `Clip Mode: [ Default | Custom ]` (exact UI is up to you, but it should be obvious).
       - If `Clip Mode == Default`:
         - Show a read-only indication of the effective clip duration (based on the global default or full song mode).
       - If `Clip Mode == Custom`:
         - Show a **large playback timeline / scrubber** with:
           - A playhead (current position).
           - Start and end of the track labeled (e.g. 0:00 and full song duration).
         - Provide **transport controls** integrated with the app’s internal playback backend:
           - Play / pause (and optionally previous/next if that makes sense reusing existing code).
         - Provide **Mark Start** and **Mark End** buttons:
           - When the song is playing, pressing **Mark Start** captures the current playback time as the custom start.
           - Pressing **Mark End** captures the current playback time as the custom end.
         - Display live values:
           - `Start: mm:ss`
           - `End: mm:ss`
           - `Duration: mm:ss`
         - Provide a **Preview Clip** button:
           - Plays the song from the selected start time to the selected end time, then stops.
         - Provide a **Reset to Default** button:
           - Clears any custom clip, returns the track to default behavior, updates the playlist state, and updates the table on the left.

   - Custom clips should be validated and clamped appropriately:
     - Start and end must be within the actual track duration.
     - End must be > start (and ideally at least a small minimum duration).
     - If invalid, show clear inline error messaging instead of crashing or silently failing.

4. Data model expectations:
   - Each track in a playlist should support at least:
     - A clip mode field (e.g. `default` vs `custom` — if you need more enum variants, you can propose them).
     - Custom clip start and end times (probably in milliseconds or seconds).
     - A derived/computed “effective clip duration” used for:
       - The playlist duration summary.
       - The values shown in the song table.
   - Any persistence (e.g. local database, Core Data, JSON, etc.) should be updated accordingly so that:
     - Custom clips are saved and survive app relaunch.
     - The slideshow player later uses these values correctly (this can be part of a later stage, but keep it in mind).

---

## What I Want You to Produce First

**Do not start modifying app code yet.**

1. **Carefully scan the codebase** I’ve attached:
   - Understand how playlists are currently modeled, loaded, and stored.
   - Understand how navigation is set up and how views are structured (SwiftUI or AppKit).
   - Understand what currently exists for:
     - Playlist list UI.
     - Internal Spotify playback / audio services.
     - Any existing “clip” concepts or length settings.

2. In the root of the repository, create a new Markdown file:

   **`playlist-view-plan.md`**

3. In that file, produce a **detailed implementation plan** for this feature, tailored to the current codebase.

   The file should be structured as follows:

   ### 1. Clarifying Questions for Josh
   - A bulleted list of any open questions you have for me.
   - These should be as specific as possible and based on what you see in the code.
   - Examples:
     - “I see `XPlaylistModel` and `YPlaylistModel`; which one is authoritative?”
     - “Should the global default clip length be per-playlist or app-wide?”
     - “Is it acceptable to introduce a new enum `ClipMode` in `Track`?”

   I will answer these questions manually and then ask you to update the plan accordingly.

   ### 2. Current Behavior and Code Summary
   - Summarize, in your own words, how the app currently:
     - Stores playlists.
     - Displays the playlist list.
     - Handles navigation between views.
     - Configures audio playback (especially seeking and stopping).
   - Reference specific types and files (e.g. `PlaylistListView.swift`, `PlaylistStore`, `PlaybackService`, etc.) so I can follow along.

   ### 3. Target UX and Behavior Overview
   - Restate the desired UX and behavior for the Playlist Detail view and side panel **in the context of this codebase**.
   - Call out any assumptions you’re making where behavior isn’t fully specified.
   - If you think any small, reasonable enhancements are necessary to make the UX coherent, note them here.

   ### 4. Data Model & Persistence Changes
   - Propose the exact changes you would make to the data models, with references to the existing types.
   - Describe:
     - New fields (e.g. `clipMode`, `clipStart`, `clipEnd`).
     - Where they live (track vs playlist vs something else).
     - How they are persisted (Core Data, JSON, etc.).
   - Note any backward compatibility / migration considerations.

   ### 5. Implementation Plan — Staged Breakdown
   Break the implementation into **manageable stages** that I can work through with you without biting off too much at once.

   For example (you can adjust these based on the actual code):

   - **Stage 1: Basic Navigation and Placeholder View**
     - Wire up navigation from the existing playlist list to a new `PlaylistDetailView`.
     - Display playlist name and a simple list of tracks (no editing).
     - Add a back button / navigation affordance.
     - Acceptance criteria for this stage.

   - **Stage 2: Playlist Detail Layout & Data Binding**
     - Implement the top section with playlist name, default clip selector, and computed total duration.
     - Implement the main track table layout showing song title, artist, and clip info.
     - Bind the view to the real playlist data models.
     - Update total duration when global clip length changes (assuming all songs use default clips).
     - Acceptance criteria for this stage.

   - **Stage 3: Side Panel Empty State & Song Selection**
     - Implement a right-hand side inspector panel.
     - Add a clear empty state when no song is selected.
     - Update the panel when a track is selected in the table:
       - Show basic song info (no actual editing yet).
     - Acceptance criteria for this stage.

   - **Stage 4: Clip Mode & Custom Clip Fields (Data Only)**
     - Add UI to switch `Clip Mode` between Default and Custom for a selected track.
     - Allow editing of custom start/end times via simple controls (without audio integration yet).
     - Persist these values and reflect them in:
       - The track table (e.g. “Custom” and effective duration).
       - The total playlist duration calculation.
     - Acceptance criteria for this stage.

   - **Stage 5: Integration with Internal Playback for Marking Clips**
     - Hook the side panel up to the internal playback backend so that:
       - Play/pause works for the selected song.
       - Mark Start / Mark End capture the current playback position.
       - Preview Clip plays from start to end.
     - Handle validation and error cases gracefully.
     - Acceptance criteria for this stage.

   - **Stage 6: Final Polish & Slideshow Integration**
     - Ensure the new per-track clip settings are correctly used by slideshow playback.
     - Confirm the playlist duration calculations used elsewhere are consistent.
     - Add any UX refinements (e.g. loading states, disabled states, subtle animations).
     - Acceptance criteria for this stage.

   Each stage should:
   - Reference the specific files / types you expect to touch.
   - List acceptance criteria in bullet form.
   - Be small enough that I can reasonably complete a stage and then ask you for the next set of diffs/changes.

   ### 6. Edge Cases, Risks, and Acceptance Criteria Summary
   - Call out potential tricky areas:
     - Invalid clip ranges.
     - Very short tracks.
     - Missing metadata from Spotify.
     - Playlists with many tracks.
   - Summarize success criteria for the overall feature (end-to-end).

   ### 7. Additional Notes and Future Enhancements
   - Add any architectural suggestions or future ideas you think I should be aware of:
     - How this design could later support “must play” tracks.
     - How it could integrate with more advanced timing modes (“fit to playlist”, etc.).
     - Anything else that jumps out from the code review.

---

## Important Meta-Instructions

- Focus first on **understanding and documenting**. This task is about producing a **clear, high-quality plan**, not about immediately changing the implementation.
- The `playlist-view-plan.md` file should be written so that:
  - I can read it and understand exactly how you want to approach the implementation.
  - We can iterate on it after I answer your clarifying questions.
- Use precise references to existing files, types, and functions where possible.
- If you need to make reasonable assumptions, call them out explicitly.

Once you’ve created `playlist-view-plan.md`, stop and wait. I will:
1. Read the plan.
2. Answer your clarifying questions.
3. Ask you to refine the plan and/or start implementation in small stages.

Please confirm once the file has been created and is fully populated.