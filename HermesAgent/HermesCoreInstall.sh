#!/bin/bash
set -Eeuo pipefail

TMP="$(mktemp)"
cleanup(){ rm -f "$TMP"; }
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

# Use Hermes's own official stage protocol instead of patching its source.
# We intentionally omit ONLY `node-deps`: our research build installs Camofox
# separately, so the repo-root npm/browser bootstrap is unnecessary on the VPS.
run_stage prerequisites
run_stage repository
run_stage venv
run_stage python-deps
# node-deps intentionally skipped
run_stage path
run_stage config
run_stage setup
run_stage complete
