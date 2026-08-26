#!/bin/bash
set -Eeuo pipefail

TMP="$(mktemp)"
cleanup(){ rm -f "$TMP"; }
trap cleanup EXIT

curl -fsSL -H 'Cache-Control: no-cache' \
  "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh?ts=$(date +%s%N)" \
  -o "$TMP"

python3 - "$TMP" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
old = """    setup_venv
    install_deps
    install_node_deps
    setup_path"""
new = """    setup_venv
    install_deps
    log_info \"Skipping Hermes Node.js dependency bootstrap (Camofox is installed separately)\"
    setup_path"""

if old not in s:
    raise SystemExit("Hermes installer layout changed: patch target not found")

p.write_text(s.replace(old, new, 1))
PY

bash "$TMP" --skip-browser
