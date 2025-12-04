# Chromium Embedded Framework (CEF) Bundle

This directory stores the macOS CEF build used for the internal Spotify player prototype and future embedded browser work.

## Download instructions
1. Visit https://cef-builds.spotifycdn.com/ and locate the macOS **minimal** build you want (e.g. `cef_binary_123.0.4+g15c09fa_macosx64_minimal.zip`).
2. Record the version string (e.g. `123.0.4+g15c09fa`) in `ThirdParty/CEF/version.txt` **or** export it inline when running the script: `CEF_VERSION="123.0.4+g15c09fa" ./scripts/download_cef.sh`.
	- Alternatively, set `CEF_DOWNLOAD_URL` to the full ZIP URL if you have a custom mirror.
3. Run `scripts/download_cef.sh` from the repo root. The script downloads into `ThirdParty/CEF/.cache/` and extracts to `ThirdParty/CEF/cef_binary_<version>_macosx64_minimal/`.
4. SHA256 of the downloaded archive is saved alongside the extracted folder for reproducibility.

> **Note:** The actual binaries are not committed to git. Each developer should run the script locally. If we adopt Git LFS or an artifacts bucket later, update this doc accordingly.

## Updating CEF
- Edit `scripts/download_cef.sh` to bump `CEF_VERSION` and adjust the URL if the upstream download location changes.
- Re-run the script and update any references to helper names in the Xcode project.

## References
- Official builds: https://cef-builds.spotifycdn.com/
- Docs: https://bitbucket.org/chromiumembedded/cef/wiki/Home
