#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CEF_DIR="${ROOT_DIR}/ThirdParty/CEF"
SCRIPT_DIR="${ROOT_DIR}/scripts"

# Ensure CEF is downloaded
"${SCRIPT_DIR}/download_cef.sh"

CEF_BINARY_DIR=$(find "${CEF_DIR}" -maxdepth 1 -type d -name 'cef_binary_*_macosx64_minimal' | head -n 1)
if [[ -z "${CEF_BINARY_DIR}" ]]; then
  echo "[run_cef_player] Could not find extracted CEF binary folder" >&2
  exit 1
fi

APP_PATH="${CEF_BINARY_DIR}/Release/cefclient.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "[run_cef_player] cefclient.app not found (expected at ${APP_PATH})" >&2
  exit 1
fi

URL="https://electric-slideshow-server.onrender.com/internal-player"
DEBUG_PORT=9223

echo "[run_cef_player] Launching cefclient -> ${URL}"
open -n "${APP_PATH}" --args --url="${URL}" --remote-debugging-port=${DEBUG_PORT}
