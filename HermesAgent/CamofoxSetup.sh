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

# The Hermes setup wizard can enable the Docker egress firewall before iron-proxy
# has actually been configured. With enforce_on_docker=true that blocks all Docker
# tool sessions, including browser-related work. For the default research setup we
# keep egress disabled until the user intentionally configures it later.
info "Отключаю незавершённый Egress firewall, чтобы Docker Tools не блокировались..."
hermes egress disable >/dev/null 2>&1 || hermes config set proxy.enabled false >/dev/null 2>&1 || true
ok "Egress firewall выключен до отдельной ручной настройки"

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

cd "$CAMOFOX_DIR"
info "Собираю Camofox anti-detection browser..."
make build

IMAGE="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep '^camofox-browser:' | head -n1 || true)"
[ -n "$IMAGE" ] || { err "Docker image Camofox не найден после сборки."; exit 1; }

if docker ps -a --format '{{.Names}}' | grep -qx 'camofox-browser'; then
  docker rm -f camofox-browser >/dev/null 2>&1 || true
fi

info "Запускаю Camofox только на localhost:9377..."
docker run -d \
  --restart unless-stopped \
  --name camofox-browser \
  --shm-size=2g \
  -p 127.0.0.1:9377:9377 \
  "$IMAGE" >/dev/null

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

# Camofox is a local anti-detection backend for Hermes built-in browser tools.
hermes config set browser.cloud_provider camofox
hermes config set browser.backend off

ok "Hermes переключён на Camofox anti-detection browser"
warn "Camofox уменьшает обычные headless-фингерпринты, но не гарантирует обход любой CAPTCHA/Cloudflare challenge."
echo
echo "Проверка через Telegram после включения Browser Automation для Telegram:"
echo
echo 'Используй Browser Automation, не Web Search. Открой https://www.coingecko.com и скажи, загрузилась настоящая главная страница или страница проверки Cloudflare.'
echo
echo "Для отдельной CLI-диагностики можно принудительно дать browser toolset:"
echo 'hermes chat --toolsets browser -q "Use Browser Automation, not web search. Open https://www.coingecko.com and tell me whether the real homepage loaded or a verification page appeared."'
