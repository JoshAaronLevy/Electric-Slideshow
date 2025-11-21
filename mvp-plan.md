# Electric Slideshow – MVP Implementation Plan

## Overview

A macOS app for creating and playing photo slideshows with Spotify music integration.

### Core Features

1. **Photo Management** ✓ Already Implemented
   - Access Apple Photos library
   - Browse albums and select photos
   - Create slideshows with selected photos
   - Configure slideshow settings (duration, shuffle, repeat)

2. **Spotify Integration** → See Implementation Phases Below
   - OAuth PKCE authentication
   - Browse Spotify library and playlists
   - Create app-local playlists (not synced to Spotify)
   - Control playback on Mac device

3. **Slideshow Display** → See Implementation Phases Below
   - 3-column card grid layout
   - Thumbnail previews
   - Edit/delete with context menu
   - Music indicator on cards

4. **Playback Experience** → See Implementation Phases Below
   - Full-screen slideshow mode
   - Auto-advancing slides with fade transitions
   - Spotify music playback
   - Auto-hiding controls with song info

---

## Architecture

### Backend (`https://slideshow-buddy-server.onrender.com`)
**Purpose**: Minimal OAuth PKCE token exchange proxy

**Endpoints**:
- `POST /auth/spotify/token` - Exchange authorization code for access/refresh tokens
- `POST /auth/spotify/refresh` - Refresh expired access token

**What backend does NOT do**:
- No playlist management
- No playback control
- No user data storage

### macOS App
- **Spotify Auth**: OAuth PKCE flow with custom URL scheme (`com.slideshowbuddy://callback`)
- **Token Storage**: Keychain for secure token management
- **Spotify API**: Direct calls to `https://api.spotify.com/v1` for all music operations
- **Local Storage**:
  - Slideshows → `SlideshowsStore` (JSON file)
  - App playlists → `PlaylistsStore` (JSON file)
  - Tokens → Keychain

---

## Implementation Phases

### Phase 1: Spotify Authentication → `spotify-integration.md`

Implement OAuth PKCE flow with Keychain token storage.

**Stages**:
1. Configuration & Models
2. Keychain Token Storage
3. PKCE Helper
4. Spotify Auth Service
5. URL Callback Handling
6. Music View UI

**Outcome**: User can connect Spotify account, tokens persist securely.

---

### Phase 2: Spotify API & App Playlists → `phase-2-playlists.md`

Build infrastructure for fetching Spotify data and managing app-local playlists.

**Stages**:
1. Spotify API Service
2. Spotify API Models
3. App-Local Playlist Models
4. App Playlists Store
5. Music Creation Flow UI
6. Update Music View

**Outcome**: User can browse Spotify library, create app playlists by selecting songs.

---

### Phase 3: Grid Layout & Music Integration → `phase-3-ui.md`

Transform list view to card grid, add edit/delete, integrate music selection.

**Stages**:
1. Convert List to Card Grid
2. Slideshow Card Component
3. Update Slideshow Model for Music
4. Add Music Selection to Settings
5. Update ViewModel for Editing
6. Update SlideshowsListViewModel
7. Inject PlaylistsStore

**Outcome**: Slideshows display in grid, can edit/delete, can link playlists to slideshows.

---

### Phase 4: Full-Screen Playback → `phase-4-playback.md`

Implement full-screen slideshow with auto-advancing slides and music playback.

**Stages**:
1. Slideshow Playback View Model
2. Slideshow Playback View
3. Integrate Playback into Grid View
4. Keyboard Shortcuts
5. Error Handling & Edge Cases

**Outcome**: Full-screen slideshows with auto-advance, fade transitions, Spotify playback, auto-hiding controls.

---

## Current Status

### ✅ Completed (Pre-MVP Work)
- Photo library access and permissions
- Photo selection from albums
- Slideshow creation flow
- Slideshow settings configuration
- Local slideshow persistence

### 🚀 Next Steps

**Start with Phase 1**: Review `spotify-integration.md` and implement Spotify authentication.

Once each phase is complete and tested, proceed to the next phase in order.
