# Electric Slideshow

## Internal Spotify Player Instructions

# 1. Download/extract the CEF minimal bundle (skip if already done)

```bash
chmod +x ./scripts/download_cef.sh
./scripts/download_cef.sh
```

# 2. Launch the prototype browser pointing at the internal player

```bash
chmod +x ./Prototypes/CEFPlayer/run_cef_player.sh
./Prototypes/CEFPlayer/run_cef_player.sh
```

# 3. (First time only) install prototype tooling dependencies

```bash
cd Prototypes/CEFPlayer
npm install
```

# 4. Inject your Spotify token via DevTools (replace <token> with a valid Premium access token)

```bash
SPOTIFY_ACCESS_TOKEN="<token>" npm run inject-token
```