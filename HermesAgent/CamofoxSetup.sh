#!/bin/bash
set -Eeuo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
CAMOFOX_DIR="${CAMOFOX_DIR:-/opt/camofox-browser}"
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; CYAN="\e[36m"; NC="\e[0m"
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
err(){ echo -e "${RED}[x]${NC} $*" >&2; }
info(){ echo -e "${CYAN}[*]${NC} $*"; }

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

command -v docker >/dev/null 2>&1 || { err "Docker не установлен."; exit 1; }
command -v hermes >/dev/null 2>&1 || { err "Hermes не установлен."; exit 1; }

info "Ставлю зависимости Camofox..."
$SUDO apt-get update -y
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y git make curl ca-certificates

if [ -d "$CAMOFOX_DIR/.git" ]; then
  info "Обновляю существующий Camofox..."
  git -C "$CAMOFOX_DIR" fetch --all --prune
  git -C "$CAMOFOX_DIR" reset --hard origin/master || git -C "$CAMOFOX_DIR" reset --hard origin/main
else
  info "Клонирую Camofox..."
  $SUDO mkdir -p "$(dirname "$CAMOFOX_DIR")"
  $SUDO git clone https://github.com/jo-inc/camofox-browser "$CAMOFOX_DIR"
  if [ "$(id -u)" -ne 0 ]; then
    $SUDO chown -R "$USER":"$USER" "$CAMOFOX_DIR"
  fi
fi

info "Собираю и запускаю anti-detection browser..."
cd "$CAMOFOX_DIR"
if docker ps -a --format '{{.Names}}' | grep -qx 'camofox-browser'; then
  docker rm -f camofox-browser >/dev/null 2>&1 || true
fi
make up

info "Жду Camofox API..."
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:9377/health >/dev/null 2>&1; then
    ok "Camofox API работает на 127.0.0.1:9377"
    break
  fi
  sleep 2
  if [ "$i" -eq 60 ]; then
    err "Camofox не поднялся за 120 секунд."
    docker logs --tail 100 camofox-browser || true
    exit 1
  fi
done

mkdir -p "$HERMES_HOME"
touch "$HERMES_HOME/.env"
if grep -q '^CAMOFOX_URL=' "$HERMES_HOME/.env"; then
  sed -i 's#^CAMOFOX_URL=.*#CAMOFOX_URL=http://localhost:9377#' "$HERMES_HOME/.env"
else
  echo 'CAMOFOX_URL=http://localhost:9377' >> "$HERMES_HOME/.env"
fi

# Camofox uses Hermes built-in browser tools, not browser-use/Chrome harness.
hermes config set browser.cloud_provider camofox
hermes config set browser.backend off

ok "Hermes переключён на Camofox anti-detection browser"
echo
echo "Проверка:"
echo 'hermes chat -q "Use Browser Automation, not web search. Open https://www.coingecko.com and tell me whether the real homepage loaded or a verification page appeared."'
