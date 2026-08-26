#!/bin/bash
set -Eeuo pipefail

TMP="$(mktemp)"
ARCHIVE="$(mktemp --suffix=.tar.gz)"
ARCHIVE_FALLBACK=0
cleanup(){ rm -f "$TMP" "$ARCHIVE"; }
trap cleanup EXIT

curl -fsSL -H 'Cache-Control: no-cache, no-store' \
  "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh?ts=$(date +%s%N)" \
  -o "$TMP"
chmod +x "$TMP"

run_stage(){
  local stage="$1"
  echo
  echo "[*] Hermes stage: $stage"
  bash "$TMP" --stage "$stage" --skip-browser
}

archive_repository_fallback(){
  local install_dir
  if [ "$(id -u)" -eq 0 ] && [ "$(uname -s)" = "Linux" ]; then
    install_dir="/usr/local/lib/hermes-agent"
  else
    install_dir="${HERMES_HOME:-$HOME/.hermes}/hermes-agent"
  fi

  echo
  echo "[!] GitHub git clone недоступен (например HTTP 429)."
  echo "[*] Переключаюсь на официальный GitHub codeload archive..."

  rm -rf "$install_dir"
  mkdir -p "$install_dir"

  curl -fL \
    --retry 6 \
    --retry-delay 5 \
    --retry-all-errors \
    -H 'Cache-Control: no-cache, no-store' \
    "https://codeload.github.com/NousResearch/hermes-agent/tar.gz/refs/heads/main?ts=$(date +%s%N)" \
    -o "$ARCHIVE"

  tar -xzf "$ARCHIVE" -C "$install_dir" --strip-components=1

  [ -f "$install_dir/pyproject.toml" ] || {
    echo "[x] Archive downloaded, but Hermes files were not extracted correctly."
    return 1
  }

  # The official 'complete' stage writes git here. Archive installs are not a
  # real git checkout, so we fix the marker after the remaining stages finish.
  ARCHIVE_FALLBACK=1
  echo "[✓] Hermes source downloaded via codeload fallback"
}

# Use Hermes's own official stage protocol and intentionally omit node-deps.
# If GitHub's smart-HTTP clone endpoint rate-limits the VPS, fall back to the
# official GitHub codeload tarball so installation can still continue.
run_stage prerequisites

if ! run_stage repository; then
  archive_repository_fallback
fi

run_stage venv
run_stage python-deps
# node-deps intentionally skipped: Camofox is installed separately.
run_stage path
run_stage config
run_stage setup
run_stage complete

if [ "$ARCHIVE_FALLBACK" = "1" ]; then
  if [ "$(id -u)" -eq 0 ] && [ "$(uname -s)" = "Linux" ]; then
    printf 'unknown\n' > /usr/local/lib/hermes-agent/.install_method
  else
    printf 'unknown\n' > "${HERMES_HOME:-$HOME/.hermes}/hermes-agent/.install_method"
  fi
  echo "[!] Installed from GitHub archive because git clone was rate-limited."
  echo "[!] Hermes itself works normally; use HermesAgent.sh for future repair/update if needed."
fi
