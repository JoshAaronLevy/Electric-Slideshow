☁  Electric Slideshow [playlist-view] chmod +x ./scripts/download_cef.sh
./scripts/download_cef.sh
[download_cef] Downloading https://cef-builds.spotifycdn.com/cef_binary_120.0.1+g1234567_macosx64_minimal.zip
curl: (22) The requested URL returned error: 404

☁  Electric Slideshow [playlist-view] chmod +x ./Prototypes/CEFPlayer/run_cef_player.sh
./Prototypes/CEFPlayer/run_cef_player.sh
[download_cef] Downloading https://cef-builds.spotifycdn.com/cef_binary_120.0.1+g1234567_macosx64_minimal.zip
curl: (22) The requested URL returned error: 404

☁  Electric Slideshow [playlist-view] cd Prototypes/CEFPlayer
npm install

up to date, audited 4 packages in 1s

found 0 vulnerabilities
☁  CEFPlayer [playlist-view] SPOTIFY_ACCESS_TOKEN="a5420653f68e4295b5a8fbca7b98cd3a" npm run inject-token

> cefplayer-prototype@0.1.0 inject-token
> node inject_token.js

[inject_token] Waiting for DevTools target on localhost:9223
file:///Users/joshlevy/Desktop/Electric%20Slideshow/Prototypes/CEFPlayer/inject_token.js:26
  throw new Error(`Timed out waiting for DevTools target containing "${TARGET_URL_MATCH}"`);
        ^

Error: Timed out waiting for DevTools target containing "internal-player"
    at waitForTarget (file:///Users/joshlevy/Desktop/Electric%20Slideshow/Prototypes/CEFPlayer/inject_token.js:26:9)
    at async file:///Users/joshlevy/Desktop/Electric%20Slideshow/Prototypes/CEFPlayer/inject_token.js:39:18

Node.js v20.17.0
☁  CEFPlayer [playlist-view]