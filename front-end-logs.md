[MusicLibraryVM] Starting to load Spotify library...
[SpotifyAPI] Fetching user playlists from: https://api.spotify.com/v1/me/playlists
[SpotifyAuth] getValidAccessToken() called
[SpotifyAuth] Token found in keychain, checking expiry...
[SpotifyAuth] Token issued at: 2025-11-23 13:12:42 +0000
[SpotifyAuth] Token expires at: 2025-11-23 14:12:42 +0000
[SpotifyAuth] Current time: 2025-11-23 14:39:44 +0000
[SpotifyAuth] Token expiresIn: 3600 seconds
[SpotifyAuth] Expiry threshold (now + 5min): 2025-11-23 14:44:44 +0000
[SpotifyAuth] Is expired? true
[SpotifyAuth] Token is expired or expiring soon, refreshing...
[SpotifyAuth] Refreshing access token at: https://electric-slideshow-server.onrender.com/auth/spotify/refresh
[SpotifyAPI] Fetching saved tracks from: https://api.spotify.com/v1/me/tracks?limit=50&offset=0
[SpotifyAuth] getValidAccessToken() called
[SpotifyAuth] Token found in keychain, checking expiry...
[SpotifyAuth] Token issued at: 2025-11-23 13:12:42 +0000
[SpotifyAuth] Token expires at: 2025-11-23 14:12:42 +0000
[SpotifyAuth] Current time: 2025-11-23 14:39:44 +0000
[SpotifyAuth] Token expiresIn: 3600 seconds
[SpotifyAuth] Expiry threshold (now + 5min): 2025-11-23 14:44:44 +0000
[SpotifyAuth] Is expired? true
[SpotifyAuth] Token is expired or expiring soon, refreshing...
[SpotifyAuth] Refreshing access token at: https://electric-slideshow-server.onrender.com/auth/spotify/refresh
[MusicLibraryVM] ERROR: Error Domain=NSURLErrorDomain Code=-999 "cancelled" UserInfo={NSErrorFailingURLStringKey=https://electric-slideshow-server.onrender.com/auth/spotify/refresh, NSErrorFailingURLKey=https://electric-slideshow-server.onrender.com/auth/spotify/refresh, _NSURLErrorRelatedURLSessionTaskErrorKey=(
    "LocalDataTask <88AB3A2B-425C-4590-A0A5-CF241C8098DB>.<1>"
), _NSURLErrorFailingURLSessionTaskErrorKey=LocalDataTask <88AB3A2B-425C-4590-A0A5-CF241C8098DB>.<1>, NSLocalizedDescription=cancelled}