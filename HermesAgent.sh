#!/bin/bash
set -Eeuo pipefail

VERSION="1.2.1"
SELF_URL="https://raw.githubusercontent.com/TheGentIeman/Nodes/main/HermesAgent.sh"
BASE_URL="https://raw.githubusercontent.com/TheGentIeman/Nodes/main/HermesAgent"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DIR="$HERMES_HOME/skills"
RESEARCH_DIR="$HERMES_HOME/research-data"
OUTPUT_DIR="$HERMES_HOME/cache/documents"
BACKUP_DIR="$HERMES_HOME/gentleman-backups"
MARKER="managed-by: TheGentleman/HermesAgent"
FRESH_INSTALL=0

GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; RED="\e[31m"; NC="\e[0m"
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
err(){ echo -e "${RED}[x]${NC} $*" >&2; }
info(){ echo -e "${CYAN}[*]${NC} $*"; }
trap 'err "Ошибка на строке $LINENO. Скрипт остановлен."' ERR

[ "$(uname -s)" = Linux ] && command -v apt-get >/dev/null 2>&1 || { err "Нужен Ubuntu/Debian Linux VPS."; exit 1; }
if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else err "Запустите от root."; exit 1; fi

cache_url(){ printf '%s?ts=%s' "$1" "$(date +%s%N)"; }
runtime_path(){ export PATH="$HERMES_HOME/node/bin:$HERMES_HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/local/lib/hermes-agent/bin:$PATH"; }

ui_deps(){
  local missing=()
  for x in figlet whiptail curl wget; do command -v "$x" >/dev/null 2>&1 || missing+=("$x"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    $SUDO apt-get update -y >/dev/null
    $SUDO apt-get install -y "${missing[@]}" >/dev/null
  fi
}

self_update(){
  [ "${HERMES_AGENT_NO_SELF_UPDATE:-0}" = "1" ] && return 0
  [ -f "$0" ] || return 0
  local tmp remote
  tmp="$(mktemp)"
  if curl -fsSL -H 'Cache-Control: no-cache, no-store' "$(cache_url "$SELF_URL")" -o "$tmp"; then
    remote="$(grep -m1 '^VERSION=' "$tmp" | cut -d'"' -f2 || true)"
    if [ -n "$remote" ] && [ "$remote" != "$VERSION" ] && bash -n "$tmp"; then
      info "Найдена новая версия installer: $VERSION -> $remote"
      cp "$tmp" "$0"; chmod +x "$0"; rm -f "$tmp"; exec "$0" "$@"
    fi
  fi
  rm -f "$tmp"
}

logo(){
  clear 2>/dev/null || true
  echo -e "\n${CYAN}$(figlet -w 150 -f standard "Soft by The Gentleman")${NC}"
  echo "================================================================================"
  echo "          Добро пожаловать в мастер установки Hermes Research Agent"
  echo "================================================================================"
  echo -e "${YELLOW}Telegram: https://t.me/GentleChron${NC}"
  echo -e "${CYAN}Installer version: $VERSION${NC}\n"
}

ensure_runtime_deps(){
  info "Устанавливаю системные зависимости..."
  $SUDO apt-get update -y
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y \
    ca-certificates curl wget git gh jq sqlite3 python3 docker.io figlet whiptail \
    tar xz-utils gzip unzip libatomic1 make
  $SUDO systemctl enable --now docker
  $SUDO ldconfig
  command -v xz >/dev/null 2>&1 || { err "xz-utils не установился."; return 1; }
  command -v gh >/dev/null 2>&1 || { err "GitHub CLI (gh) не установился."; return 1; }
  ldconfig -p 2>/dev/null | grep -q 'libatomic\.so\.1' || {
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install --reinstall -y libatomic1
    $SUDO ldconfig
  }
  ldconfig -p 2>/dev/null | grep -q 'libatomic\.so\.1' || { err "libatomic.so.1 не найден."; return 1; }
  ok "Docker и системные зависимости готовы"
  ok "GitHub CLI (gh) установлен"
}

find_hermes(){ runtime_path; command -v hermes >/dev/null 2>&1; }
prepare_managed_node(){
  local node="$HERMES_HOME/node/bin/node"
  if [ -x "$node" ]; then
    if "$node" --version >/dev/null 2>&1; then ok "Hermes-managed Node исправен: $($node --version)"; return 0; fi
    warn "Нашёл битую Hermes Node.js. Очищаю."; rm -rf "$HERMES_HOME/node"
  fi
}

show_first_install_instructions(){
  echo
  echo -e "${CYAN}Сейчас откроется официальный мастер первого запуска Hermes.${NC}"
  echo "Для нашей сборки проходите его так:"
  echo
  echo "  1. How would you like to set up Hermes?"
  echo -e "     ${GREEN}Blank slate — everything off except the bare minimum${NC}"
  echo
  echo "  2. Select provider:"
  echo "     Выберите свою AI-модель прямо здесь."
  echo "     ChatGPT Plus/Pro -> OpenAI -> ChatGPT/Codex Subscription."
  echo "     Либо Nous Portal / OpenRouter / xAI."
  echo
  echo "  3. Select terminal backend:"
  echo -e "     ${GREEN}Docker — isolated container with configurable resources${NC}"
  echo
  echo "  4. Enable egress firewall for Docker sandboxes?"
  echo -e "     ${GREEN}Yes${NC}"
  echo
  echo "  5. Your minimal agent is ready. What next?"
  echo -e "     ${GREEN}Start with everything disabled — finish now${NC}"
  echo
  echo "После этого наш скрипт сам добавит Research Skills, Tracker и Camofox anti-detection Browser."
  echo
  read -r -p "Нажмите Enter, чтобы открыть официальный installer Hermes..." _
}

install_hermes(){
  ensure_runtime_deps
  prepare_managed_node
  if find_hermes; then
    info "Hermes уже установлен: $(hermes --version 2>/dev/null || echo installed)"
    hermes update >/dev/null 2>&1 || true
  else
    FRESH_INSTALL=1
    show_first_install_instructions
    info "Устанавливаю официальный Hermes Agent..."
    curl -fsSL -H 'Cache-Control: no-cache' "https://hermes-agent.nousresearch.com/install.sh?ts=$(date +%s%N)" | bash
    runtime_path
  fi
  find_hermes || { err "Hermes не найден после официальной установки."; return 1; }
  hermes --version >/dev/null 2>&1 || { err "Команда hermes установлена, но не запускается."; return 1; }
  ok "Hermes установлен: $(hermes --version 2>/dev/null || echo ready)"
}

backup_if_custom(){
  local target="$1"
  [ -f "$target" ] || return 0
  grep -q "$MARKER" "$target" 2>/dev/null && return 0
  mkdir -p "$BACKUP_DIR"
  cp -a "$target" "$BACKUP_DIR/$(basename "$(dirname "$target")")-$(basename "$target").$(date +%Y%m%d-%H%M%S).bak"
}

download_asset(){ local src="$1" dst="$2"; backup_if_custom "$dst"; curl -fsSL -H 'Cache-Control: no-cache, no-store' "$(cache_url "$src")" -o "$dst"; }

install_active_soul(){
  local tmp; tmp="$(mktemp)"
  curl -fsSL -H 'Cache-Control: no-cache, no-store' "$(cache_url "$BASE_URL/SOUL.md")" -o "$tmp"
  if [ "$FRESH_INSTALL" = "1" ]; then
    [ -f "$HERMES_HOME/SOUL.md" ] && { mkdir -p "$BACKUP_DIR"; cp -a "$HERMES_HOME/SOUL.md" "$BACKUP_DIR/SOUL.hermes-default.$(date +%Y%m%d-%H%M%S).bak"; }
    cp "$tmp" "$HERMES_HOME/SOUL.md"; ok "Research SOUL.md активирован"
  elif [ ! -f "$HERMES_HOME/SOUL.md" ] || grep -q "$MARKER" "$HERMES_HOME/SOUL.md" 2>/dev/null; then
    cp "$tmp" "$HERMES_HOME/SOUL.md"; ok "Research SOUL.md установлен/обновлён"
  else
    cp "$tmp" "$HERMES_HOME/SOUL.gentleman-example.md"; warn "Ваш SOUL.md не тронут; новый пример сохранён рядом."
  fi
  rm -f "$tmp"
}

research_layer(){
  mkdir -p "$SKILLS_DIR/signal-radar" "$SKILLS_DIR/evidence-dive" "$SKILLS_DIR/watchlist-monitor" "$RESEARCH_DIR" "$OUTPUT_DIR"
  info "Скачиваю Research Skills и Tracker..."
  download_asset "$BASE_URL/SignalRadar.md" "$SKILLS_DIR/signal-radar/SKILL.md"
  download_asset "$BASE_URL/EvidenceDive.md" "$SKILLS_DIR/evidence-dive/SKILL.md"
  download_asset "$BASE_URL/WatchlistMonitor.md" "$SKILLS_DIR/watchlist-monitor/SKILL.md"
  download_asset "$BASE_URL/tracker.py" "$RESEARCH_DIR/tracker.py"
  chmod +x "$RESEARCH_DIR/tracker.py"
  install_active_soul
  python3 "$RESEARCH_DIR/tracker.py" stats >/dev/null
  ok "Signal Radar / Evidence Dive / Watchlist Monitor / Tracker готовы"
}

sandbox(){
  info "Донастраиваю Docker Sandbox..."
  hermes config set terminal.backend docker
  hermes config set terminal.container_persistent false
  hermes config set terminal.docker_mount_cwd_to_workspace false
  local vols
  vols="$(jq -cn --arg a "$OUTPUT_DIR:/output" --arg b "$RESEARCH_DIR:/research-data" '[$a,$b]')"
  hermes config set terminal.docker_volumes "$vols"
  ok "Docker Sandbox и persistent research-data настроены"
}

browser_camofox_setup(){
  find_hermes || { err "Сначала установите Hermes."; return 1; }
  local tmp; tmp="$(mktemp)"
  info "Устанавливаю Camofox anti-detection Browser..."
  curl -fsSL -H 'Cache-Control: no-cache, no-store' "$(cache_url "$BASE_URL/CamofoxSetup.sh")" -o "$tmp"
  chmod +x "$tmp"
  bash "$tmp"
  rm -f "$tmp"
}

next_steps(){
cat <<EOF2

${CYAN}Первичная установка закончена.${NC}

1. Проверить AI:
   hermes chat -q "Reply only with: AGENT WORKS"

2. Настроить Telegram через пункт 4.

3. Включить Gateway 24/7 через пункт 5.

4. Настроить Tools через пункт 6.
   Для Telegram включите Web Search, Browser Automation, Terminal, File,
   Code Execution, Memory, Session Search, Skills и Cron Jobs.

5. Если нужен X Search — пункт 7 и xAI OAuth.

6. Browser уже ставится как Camofox anti-detection backend.
   Проверка:
   hermes chat -q "Use Browser Automation, not web search. Open https://www.coingecko.com and tell me whether the real homepage loaded or a verification page appeared."

7. GitHub CLI уже установлен базовым скриптом. Для авторизации:
   gh auth login

8. Проверить Signal Radar вручную.
9. Проверить Evidence Dive вручную.
10. Только потом включить Cron.

Research DB: $RESEARCH_DIR
Telegram: https://t.me/GentleChron
EOF2
}

full_install(){
  logo
  install_hermes
  research_layer
  sandbox
  browser_camofox_setup
  hermes egress install >/dev/null 2>&1 || warn "Egress binary пока не установился; это опционально."
  hermes config check || true
  echo -e "\n${GREEN}================ HERMES RESEARCH AGENT УСТАНОВЛЕН ================${NC}"
  next_steps
}

model(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes model; }
telegram(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes gateway setup; }

tools(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  hermes tools
  echo
  info "Tools сохранены. Возвращаю Browser на Camofox anti-detection backend..."
  browser_camofox_setup
}

gateway(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  if systemctl list-unit-files 2>/dev/null | grep -q '^hermes-gateway\.service'; then
    hermes gateway start --system || true; hermes gateway status --system || true
  else
    hermes gateway install; $SUDO loginctl enable-linger "$USER"; hermes gateway start; hermes gateway status || true
  fi
}

xai_auth(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  echo "Откроется device OAuth для X/xAI. Ссылку открывайте на обычном компьютере."
  hermes auth add xai-oauth --no-browser
}

radar_cron(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  local schedule topics
  read -r -p "Интервал [every 6h]: " schedule; schedule="${schedule:-every 6h}"
  read -r -p "Какие темы мониторить? " topics; [ -n "$topics" ] || topics="saved interests and current priority topics"
  hermes cron create "$schedule" "Run Signal Radar for: $topics. Find genuinely NEW or meaningfully UPDATED developments, verify important claims, check the tracker and avoid repeats. Return [SILENT] only if nothing useful is new." --skill signal-radar --deliver telegram --continuity --name "Gentleman Signal Radar"
  hermes cron list
}

watch_cron(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  local schedule
  read -r -p "Интервал [every 12h]: " schedule; schedule="${schedule:-every 12h}"
  hermes cron create "$schedule" "Review the persistent watchlist and report only meaningful changes since the previous known state. Do not repeat background information. Update the tracker. Return [SILENT] if nothing materially changed." --skill watchlist-monitor --deliver telegram --continuity --name "Gentleman Watchlist Monitor"
  hermes cron list
}

tracker(){
  [ -f "$RESEARCH_DIR/tracker.py" ] || { warn "Tracker ещё не установлен."; return; }
  python3 "$RESEARCH_DIR/tracker.py" stats; echo; python3 "$RESEARCH_DIR/tracker.py" recent 20 || true
}

diag(){
  logo
  command -v docker >/dev/null && ok "$(docker --version)" || err "Docker отсутствует"
  command -v gh >/dev/null && ok "GitHub CLI: $(gh --version | head -n1)" || err "GitHub CLI отсутствует"
  if find_hermes; then
    ok "Hermes: $(hermes --version 2>/dev/null || echo installed)"
    if docker ps --format '{{.Names}}' | grep -qx 'camofox-browser' && curl -fsS http://127.0.0.1:9377/health >/dev/null 2>&1; then
      ok "Camofox anti-detection Browser работает"
    else
      err "Camofox Browser не работает"
    fi
    local provider
    provider="$(hermes config get browser.cloud_provider 2>/dev/null || true)"
    [ "$provider" = "camofox" ] && ok "Hermes browser.cloud_provider=camofox" || warn "browser.cloud_provider=$provider"
    hermes gateway status || true
    hermes cron status || true
    hermes egress status || true
  else
    err "Hermes не найден"
  fi
  tracker
}

menu(){
  ui_deps; self_update "$@"
  while true; do
    logo
    local c
    c=$(whiptail --title "Hermes Research Agent by The Gentleman" --menu "Выберите действие:" 26 92 16 \
      "1"  "Первичная установка / восстановление" \
      "2"  "Обновить Research Skills и Tracker" \
      "3"  "Сменить / переподключить AI-модель" \
      "4"  "Настроить Telegram Gateway" \
      "5"  "Включить Gateway 24/7" \
      "6"  "Настроить Tools (Web / Browser / X и др.)" \
      "7"  "Подключить X Search через xAI OAuth" \
      "8"  "Установить / починить Camofox Browser" \
      "9"  "Создать автоматический Signal Radar Cron" \
      "10" "Создать Watchlist Monitor Cron" \
      "11" "Показать Research Tracker" \
      "12" "Диагностика" \
      "13" "Показать следующие шаги" \
      "14" "Выход" 3>&1 1>&2 2>&3) || exit 0
    case "$c" in
      1) full_install;; 2) research_layer;; 3) model;; 4) telegram;; 5) gateway;; 6) tools;; 7) xai_auth;; 8) browser_camofox_setup;; 9) radar_cron;; 10) watch_cron;; 11) tracker;; 12) diag;; 13) next_steps;; 14) exit 0;;
    esac
    echo; read -r -p "Нажмите Enter, чтобы вернуться в меню..." _
  done
}

ui_deps
self_update "$@"
case "${1:-}" in
  --install|install) full_install;;
  --update|update) research_layer;;
  --browser|browser) browser_camofox_setup;;
  --xai|xai) xai_auth;;
  --diagnostics|diagnostics|diag) diag;;
  --next|next) next_steps;;
  "") menu;;
  *) echo "Usage: $0 [--install|--update|--browser|--xai|--diagnostics|--next]"; exit 1;;
esac
