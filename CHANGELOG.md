# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog,
and this project adheres to Semantic Versioning.

## [1.2.0] - 2025-11-23

### Added
- Added custom app blue color (#0080C6) for consistent branding
- Added floating action buttons (FAB) in bottom-right corner for creating new slideshows and playlists
- FABs feature prominent blue circular design with shadows for better visibility

### Changed
- Removed toolbar "+" buttons from Slideshows and Music views for better UX
- Updated all primary action buttons to use custom app blue color
- Centered Spotify connection dialog in Music view to match empty state positioning in Slideshows view

### Improved
- Enhanced button visibility and discoverability with floating action buttons
- Improved visual consistency across the app with unified color scheme

## [1.1.0] - 2025-11-22

### Changed
- Updated slideshow grid layout from 3 columns to 4 columns for better use of screen space
- Improved grid spacing with 16-point spacing between cards and 24-point outer padding
- Enhanced slideshow playback view with true full-screen display

### Fixed
- Fixed slideshow cards extending beyond screen edges with proper margins
- Fixed playback view to fill entire screen with black bars for proper aspect ratio (portrait photos fill height with side bars, landscape photos maximize screen usage)

## [1.0.0] - 2025-11-20

### Added
- Initial release with core slideshow functionality
- Photo library integration
- Spotify music integration
- Playlist management
- Slideshow playback with music synchronization
