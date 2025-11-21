# Implementation Plan Files

This directory contains the phased implementation plan for Electric Slideshow MVP.

## File Structure

### Main Overview
- **`mvp-plan.md`** - High-level overview of the MVP goals, architecture, and phase breakdown

### Implementation Phases (In Order)

1. **`spotify-integration.md`** - Phase 1: Spotify OAuth PKCE Authentication
   - Keychain token storage
   - Custom URL scheme callback handling
   - Basic Music view UI

2. **`phase-2-playlists.md`** - Phase 2: Spotify API & App-Local Playlists
   - Direct Spotify Web API integration
   - App-local playlist models and storage
   - Music creation flow (select songs from Spotify)

3. **`phase-3-ui.md`** - Phase 3: Grid Layout & Music Integration
   - Card-based 3-column grid
   - Edit/delete with context menu
   - Link playlists to slideshows in settings

4. **`phase-4-playback.md`** - Phase 4: Full-Screen Slideshow Playback
   - Full-screen playback view
   - Auto-advancing slides with fade transitions
   - Spotify music playback with controls
   - Auto-hiding UI

## How to Use

1. **Start with `mvp-plan.md`** to understand the overall architecture and goals
2. **Proceed through phases in order** - each phase builds on the previous
3. **Complete all stages in a phase** before moving to the next phase
4. **Test thoroughly** after each phase using the provided checklists

## Key Clarifications

- **Backend**: `https://slideshow-buddy-server.onrender.com` only handles OAuth token exchange
- **App Playlists**: Stored locally in the app, NOT synced to Spotify account
- **Naming**: References to `slideshowbuddy` / `slideshow-buddy` are correct (will be renamed later)
- **Direct API Calls**: App calls Spotify Web API directly for all music operations

## Implementation Notes

Each phase file includes:
- ✅ Clear goals and prerequisites
- ✅ Stage-by-stage implementation details
- ✅ Complete code examples
- ✅ Testing checklists
- ✅ What the next phase covers

Work through systematically and you'll have a complete MVP!
