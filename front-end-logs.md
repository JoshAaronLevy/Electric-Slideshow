[MusicLibraryVM] Starting to load Spotify library...
[SpotifyAPI] Fetching user playlists from: https://api.spotify.com/v1/me/playlists
[SpotifyAuth] getValidAccessToken() called
[SpotifyAuth] Token found in keychain, checking expiry...
[SpotifyAuth] Token issued at: 2025-11-23 14:39:48 +0000
[SpotifyAuth] Token expires at: 2025-11-23 15:39:48 +0000
[SpotifyAuth] Current time: 2025-11-23 15:04:21 +0000
[SpotifyAuth] Token expiresIn: 3600 seconds
[SpotifyAuth] Expiry threshold (now + 5min): 2025-11-23 15:09:21 +0000
[SpotifyAuth] Is expired? false
[SpotifyAuth] Token is valid, returning access token
[SpotifyAPI] Fetching saved tracks from: https://api.spotify.com/v1/me/tracks?limit=50&offset=0
[SpotifyAuth] getValidAccessToken() called
[SpotifyAuth] Token found in keychain, checking expiry...
[SpotifyAuth] Token issued at: 2025-11-23 14:39:48 +0000
[SpotifyAuth] Token expires at: 2025-11-23 15:39:48 +0000
[SpotifyAuth] Current time: 2025-11-23 15:04:21 +0000
[SpotifyAuth] Token expiresIn: 3600 seconds
[SpotifyAuth] Expiry threshold (now + 5min): 2025-11-23 15:09:21 +0000
[SpotifyAuth] Is expired? false
[SpotifyAuth] Token is valid, returning access token
[MusicLibraryVM] ERROR: Error Domain=NSURLErrorDomain Code=-999 "cancelled" UserInfo={NSErrorFailingURLStringKey=https://api.spotify.com/v1/me/playlists, NSErrorFailingURLKey=https://api.spotify.com/v1/me/playlists, _NSURLErrorRelatedURLSessionTaskErrorKey=(
    "LocalDataTask <93748D3E-A68C-4694-A8E4-918BA829EB11>.<4>"
), _NSURLErrorFailingURLSessionTaskErrorKey=LocalDataTask <93748D3E-A68C-4694-A8E4-918BA829EB11>.<4>, NSLocalizedDescription=cancelled}