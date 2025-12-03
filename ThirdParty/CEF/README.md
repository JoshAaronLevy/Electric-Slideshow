# Chromium Embedded Framework (CEF) Bundle

This directory stores the macOS CEF build used for the internal Spotify player prototype and future embedded browser work.

## Download instructions
1. Run `scripts/download_cef.sh` from the repo root.
2. The script downloads the macOS minimal distribution (version pinned inside the script) into `ThirdParty/CEF/.cache/` and extracts it to `ThirdParty/CEF/cef_binary_<version>_macosx64_minimal/`.
3. SHA256 of the downloaded archive is saved alongside the extracted folder for reproducibility.

> **Note:** The actual binaries are not committed to git. Each developer should run the script locally. If we adopt Git LFS or an artifacts bucket later, update this doc accordingly.

## Updating CEF
- Edit `scripts/download_cef.sh` to bump `CEF_VERSION` and adjust the URL if the upstream download location changes.
- Re-run the script and update any references to helper names in the Xcode project.

## References
- Official builds: https://cef-builds.spotifycdn.com/
- Docs: https://bitbucket.org/chromiumembedded/cef/wiki/Home
