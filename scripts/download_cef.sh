#!/usr/bin/env bash
set -euo pipefail

# Simple helper to fetch the macOS CEF minimal distribution we’ll use for the
# internal Spotify player prototype. Adjust CEF_VERSION / CEF_BUILD as needed.

CEF_VERSION=${CEF_VERSION:-}
CEF_DOWNLOAD_URL=${CEF_DOWNLOAD_URL:-}
CEF_PLATFORM="macosx64"

VERSION_FILE="$(cd "$(dirname "$0")/.." && pwd)/ThirdParty/CEF/version.txt"

if [[ -z "${CEF_DOWNLOAD_URL}" ]]; then
  if [[ -z "${CEF_VERSION}" && -f "${VERSION_FILE}" ]]; then
    CEF_VERSION=$(cat "${VERSION_FILE}" | tr -d '\n')
  fi
  if [[ -z "${CEF_VERSION}" ]]; then
    cat <<'EOF' >&2
[download_cef] ERROR: No CEF_VERSION provided.
Set CEF_VERSION env var (e.g. CEF_VERSION="123.0.4+g15c09fa") or create ThirdParty/CEF/version.txt.
Visit https://cef-builds.spotifycdn.com/ to copy a valid version string from the macOS minimal build.
EOF
    exit 1
  fi
  CEF_FILENAME="cef_binary_${CEF_VERSION}_${CEF_PLATFORM}_minimal"
  CEF_DOWNLOAD_URL="https://cef-builds.spotifycdn.com/${CEF_FILENAME}.zip"
else
  CEF_FILENAME=$(basename "${CEF_DOWNLOAD_URL}" .zip)
fi

CEF_ZIP="${CEF_FILENAME}.zip"
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
  echo "[download_cef] Downloading ${CEF_DOWNLOAD_URL}"
  curl -#fLo "${ZIP_PATH}" "${CEF_DOWNLOAD_URL}"
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
