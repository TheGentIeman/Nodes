#!/bin/bash
set -Eeuo pipefail

VERSION="1.0.5"
SELF_URL="https://raw.githubusercontent.com/TheGentIeman/Nodes/main/HermesAgent.sh"
BASE_URL="https://raw.githubusercontent.com/TheGentIeman/Nodes/main/HermesAgent"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DIR="$HERMES_HOME/skills"
RESEARCH_DIR="$HERMES_HOME/research-data"
OUTPUT_DIR="$HERMES_HOME/cache/documents"
BACKUP_DIR="$HERMES_HOME/gentleman-backups"
MARKER="managed-by: TheGentleman/HermesAgent"

GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; RED="\e[31m"; NC="\e[0m"
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
err(){ echo -e "${RED}[x]${NC} $*" >&2; }
info(){ echo -e "${CYAN}[*]${NC} $*"; }
trap 'err "Ошибка на строке $LINENO. Скрипт остановлен."' ERR

[ "$(uname -s)" = Linux ] && command -v apt-get >/dev/null 2>&1 || { err "Нужен Ubuntu/Debian Linux VPS."; exit 1; }
if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else err "Запустите от root."; exit 1; fi

cache_url(){ printf '%s?ts=%s' "$1" "$(date +%s%N)"; }

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
      cp "$tmp" "$0"
      chmod +x "$0"
      rm -f "$tmp"
      exec "$0" "$@"
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
    ca-certificates curl wget git jq sqlite3 python3 docker.io figlet whiptail \
    tar xz-utils gzip unzip libatomic1

  $SUDO systemctl enable --now docker
  $SUDO ldconfig

  command -v xz >/dev/null 2>&1 || { err "xz-utils не установился."; return 1; }
  command -v tar >/dev/null 2>&1 || { err "tar не установился."; return 1; }
  dpkg-query -W -f='${Status}' libatomic1 2>/dev/null | grep -q 'install ok installed' || {
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install --reinstall -y libatomic1
    $SUDO ldconfig
  }
  ldconfig -p 2>/dev/null | grep -q 'libatomic\.so\.1' || { err "libatomic.so.1 не найден."; return 1; }

  ok "Docker установлен и запущен"
  ok "xz-utils готов"
  ok "libatomic.so.1 найден"
}

find_hermes(){
  export PATH="$HOME/.local/bin:/usr/local/bin:/usr/local/lib/hermes-agent/bin:$PATH"
  command -v hermes >/dev/null 2>&1
}

prepare_managed_node(){
  local node="$HOME/.hermes/node/bin/node"
  if [ -x "$node" ]; then
    if "$node" --version >/dev/null 2>&1; then
      ok "Hermes-managed Node исправен: $($node --version)"
      return 0
    fi
    warn "Нашёл битую/недоустановленную Hermes Node.js. Очищаю."
    rm -rf "$HOME/.hermes/node"
  fi
}

install_hermes(){
  ensure_runtime_deps
  prepare_managed_node

  if find_hermes; then
    info "Hermes уже установлен: $(hermes --version 2>/dev/null || echo installed)"
    hermes update >/dev/null 2>&1 || true
  else
    info "Устанавливаю официальный Hermes Agent..."
    curl -fsSL -H 'Cache-Control: no-cache' "https://hermes-agent.nousresearch.com/install.sh?ts=$(date +%s%N)" | bash
    export PATH="$HOME/.local/bin:/usr/local/bin:/usr/local/lib/hermes-agent/bin:$PATH"
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

download_asset(){
  local src="$1" dst="$2"
  backup_if_custom "$dst"
  curl -fsSL -H 'Cache-Control: no-cache, no-store' "$(cache_url "$src")" -o "$dst"
}

research_layer(){
  mkdir -p "$SKILLS_DIR/signal-radar" "$SKILLS_DIR/evidence-dive" "$SKILLS_DIR/watchlist-monitor" "$RESEARCH_DIR" "$OUTPUT_DIR"
  info "Скачиваю Research Skills и Tracker..."
  download_asset "$BASE_URL/SignalRadar.md" "$SKILLS_DIR/signal-radar/SKILL.md"
  download_asset "$BASE_URL/EvidenceDive.md" "$SKILLS_DIR/evidence-dive/SKILL.md"
  download_asset "$BASE_URL/WatchlistMonitor.md" "$SKILLS_DIR/watchlist-monitor/SKILL.md"
  download_asset "$BASE_URL/tracker.py" "$RESEARCH_DIR/tracker.py"
  chmod +x "$RESEARCH_DIR/tracker.py"

  local soul_tmp
  soul_tmp="$(mktemp)"
  curl -fsSL -H 'Cache-Control: no-cache, no-store' "$(cache_url "$BASE_URL/SOUL.md")" -o "$soul_tmp"
  if [ ! -f "$HERMES_HOME/SOUL.md" ] || grep -q "$MARKER" "$HERMES_HOME/SOUL.md" 2>/dev/null; then
    cp "$soul_tmp" "$HERMES_HOME/SOUL.md"
  else
    cp "$soul_tmp" "$HERMES_HOME/SOUL.gentleman-example.md"
    warn "Ваш кастомный SOUL.md не тронут; пример сохранён рядом."
  fi
  rm -f "$soul_tmp"

  python3 "$RESEARCH_DIR/tracker.py" stats >/dev/null
  ok "Signal Radar / Evidence Dive / Watchlist Monitor / Tracker готовы"
}

sandbox(){
  info "Настраиваю Docker Sandbox..."
  hermes config set terminal.backend docker
  hermes config set terminal.container_persistent false
  hermes config set terminal.docker_mount_cwd_to_workspace false
  local vols
  vols="$(jq -cn --arg a "$OUTPUT_DIR:/output" --arg b "$RESEARCH_DIR:/research-data" '[$a,$b]')"
  hermes config set terminal.docker_volumes "$vols"
  ok "Docker Sandbox и persistent research-data настроены"
}

next_steps(){
cat <<EOF2

1. Подключить модель через пункт 3 этого меню.
   - Есть ChatGPT Plus/Pro/Codex -> OpenAI ▶
   - Хотите самый простой all-in-one -> Nous Portal
   - Есть API-ключ агрегатора -> OpenRouter
   - Хотите Grok/X Search через xAI -> xAI Grok ▶

2. Проверить чат:
   hermes chat -q "Reply only with: AGENT WORKS"

3. Telegram:
   hermes gateway setup

4. Gateway 24/7:
   hermes gateway install && sudo loginctl enable-linger "$USER" && hermes gateway start

5. Tools:
   hermes tools

6. Signal Radar:
   hermes chat -s signal-radar -q "Find the strongest fresh developments in my priority topics from the last 24 hours. Verify important claims and avoid generic news."

7. Deep Research:
   hermes chat -s evidence-dive -q "Investigate TARGET deeply. Build a timeline, verify claims, find contradictions and separate confirmed facts from inference."

Research DB: $RESEARCH_DIR
Telegram: https://t.me/GentleChron
EOF2
}

full_install(){
  logo
  install_hermes
  research_layer
  sandbox
  hermes egress install >/dev/null 2>&1 || warn "Egress пока не установлен; это опционально."
  hermes config check || true
  hermes doctor || true
  echo -e "\n${GREEN}================ HERMES RESEARCH AGENT УСТАНОВЛЕН ================${NC}"
  next_steps
}

model(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  logo
  local choice
  choice=$(whiptail --title "Выбор AI-провайдера" --menu \
    "Сначала выберите подходящий вариант. Скрипт не просит и не сохраняет ваши ключи — авторизация проходит через официальный Hermes." \
    22 100 8 \
      "1" "ChatGPT Plus/Pro/Codex — рекомендуемый вариант: OpenAI ▶" \
      "2" "Самый простой all-in-one — Nous Portal" \
      "3" "OpenRouter API — если уже есть API key / баланс" \
      "4" "xAI / Grok — direct API или SuperGrok / Premium+ OAuth" \
      "5" "Другой провайдер — открыть полный список Hermes" \
      "6" "Назад" \
    3>&1 1>&2 2>&3) || return 0

  case "$choice" in
    1)
      clear
      echo -e "${CYAN}Сейчас откроется официальный список Hermes.${NC}"
      echo -e "${GREEN}Выберите строку:${NC} OpenAI ▶ (ChatGPT/Codex subscription or direct OpenAI API)"
      echo "Дальше Hermes предложит OAuth подписки или API-вариант."
      echo
      read -r -p "Нажмите Enter, чтобы открыть список..." _
      hermes model
      ;;
    2)
      clear
      echo -e "${CYAN}Запускаю официальный Nous Portal OAuth.${NC}"
      echo "Это самый простой вариант, если не хотите отдельно разбираться с API-провайдерами."
      echo
      hermes setup --portal
      ;;
    3)
      clear
      echo -e "${CYAN}Сейчас откроется официальный список Hermes.${NC}"
      echo -e "${GREEN}Выберите строку:${NC} OpenRouter (Pay-per-use API aggregator)"
      echo
      read -r -p "Нажмите Enter, чтобы открыть список..." _
      hermes model
      ;;
    4)
      clear
      echo -e "${CYAN}Сейчас откроется официальный список Hermes.${NC}"
      echo -e "${GREEN}Выберите строку:${NC} xAI Grok ▶ (Direct API or SuperGrok / Premium+ OAuth)"
      echo
      read -r -p "Нажмите Enter, чтобы открыть список..." _
      hermes model
      ;;
    5) hermes model;;
    6) return 0;;
  esac
}

telegram(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes gateway setup; }
tools(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes tools; }
gateway(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes gateway install; $SUDO loginctl enable-linger "$USER"; hermes gateway start; hermes gateway status || true; }

radar_cron(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  local schedule topics
  read -r -p "Интервал [every 6h]: " schedule; schedule="${schedule:-every 6h}"
  read -r -p "Какие темы мониторить? " topics
  [ -n "$topics" ] || topics="saved interests and current priority topics"
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
  python3 "$RESEARCH_DIR/tracker.py" stats
  echo
  python3 "$RESEARCH_DIR/tracker.py" recent 20 || true
}

diag(){
  logo
  dpkg-query -W -f='${Status}' libatomic1 2>/dev/null | grep -q 'install ok installed' && ok "libatomic1 установлен" || err "libatomic1 отсутствует"
  ldconfig -p 2>/dev/null | grep -q 'libatomic\.so\.1' && ok "libatomic.so.1 виден loader" || err "libatomic.so.1 не виден loader"
  command -v xz >/dev/null && ok "xz-utils есть" || err "xz-utils отсутствует"
  command -v docker >/dev/null && ok "$(docker --version)" || err "Docker отсутствует"
  if find_hermes; then
    ok "Hermes: $(hermes --version 2>/dev/null || echo installed)"
    hermes gateway status || true
    hermes cron status || true
    hermes egress status || true
  else
    err "Hermes не найден"
  fi
  tracker
}

menu(){
  ui_deps
  self_update "$@"
  while true; do
    logo
    local c
    c=$(whiptail --title "Hermes Research Agent by The Gentleman" --menu "Выберите действие:" 24 84 14 \
      "1" "Первичная установка / восстановление" \
      "2" "Обновить Research Skills и Tracker" \
      "3" "Подключить / сменить AI-модель" \
      "4" "Настроить Telegram Gateway" \
      "5" "Включить Gateway 24/7" \
      "6" "Настроить Tools (X / Web / Browser и др.)" \
      "7" "Создать автоматический Signal Radar Cron" \
      "8" "Создать Watchlist Monitor Cron" \
      "9" "Показать Research Tracker" \
      "10" "Диагностика" \
      "11" "Показать следующие шаги" \
      "12" "Выход" 3>&1 1>&2 2>&3) || exit 0
    case "$c" in
      1) full_install;; 2) research_layer;; 3) model;; 4) telegram;; 5) gateway;; 6) tools;;
      7) radar_cron;; 8) watch_cron;; 9) tracker;; 10) diag;; 11) next_steps;; 12) exit 0;;
    esac
    echo; read -r -p "Нажмите Enter, чтобы вернуться в меню..." _
  done
}

ui_deps
self_update "$@"
case "${1:-}" in
  --install|install) full_install;;
  --update|update) research_layer;;
  --diagnostics|diagnostics|diag) diag;;
  --next|next) next_steps;;
  "") menu;;
  *) echo "Usage: $0 [--install|--update|--diagnostics|--next]"; exit 1;;
esac
