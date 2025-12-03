#!/usr/bin/env bash
set -euo pipefail

# Simple helper to fetch the macOS CEF minimal distribution we’ll use for the
# internal Spotify player prototype. Adjust CEF_VERSION / CEF_BUILD as needed.

CEF_VERSION="120.0.1+g1234567"
CEF_PLATFORM="macosx64"
CEF_FILENAME="cef_binary_${CEF_VERSION}_${CEF_PLATFORM}_minimal"
CEF_ZIP="${CEF_FILENAME}.zip"
CEF_URL="https://cef-builds.spotifycdn.com/${CEF_ZIP}"
CACHE_DIR="$(cd "$(dirname "$0")/.." && pwd)/ThirdParty/CEF/.cache"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/ThirdParty/CEF/${CEF_FILENAME}"
SHA_FILE="${OUT_DIR}.sha256"

mkdir -p "${CACHE_DIR}"
mkdir -p "$(dirname "${OUT_DIR}")"

ZIP_PATH="${CACHE_DIR}/${CEF_ZIP}"

if [[ -f "${OUT_DIR}/README.txt" ]]; then
  echo "[download_cef] CEF already extracted at ${OUT_DIR}"
  exit 0
fi

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "[download_cef] Downloading ${CEF_URL}"
  curl -#fLo "${ZIP_PATH}" "${CEF_URL}"
else
  echo "[download_cef] Using cached archive ${ZIP_PATH}"
fi

if [[ -f "${SHA_FILE}" ]]; then
  echo "[download_cef] Existing SHA recorded: $(cat "${SHA_FILE}")"
else
  echo "[download_cef] Computing SHA256"
  shasum -a 256 "${ZIP_PATH}" | tee "${SHA_FILE}"
fi

echo "[download_cef] Extracting into ${OUT_DIR}"
rm -rf "${OUT_DIR}"
unzip -q "${ZIP_PATH}" -d "$(dirname "${OUT_DIR}")"

# Archive contains a folder named cef_binary_*; ensure path matches OUT_DIR
if [[ ! -d "${OUT_DIR}" ]]; then
  echo "[download_cef] ERROR: expected directory ${OUT_DIR} not found after unzip" >&2
  exit 1
fi

echo "[download_cef] Done."
