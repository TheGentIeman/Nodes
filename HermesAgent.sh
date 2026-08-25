#!/bin/bash
set -Eeuo pipefail

VERSION="1.0.2"
BASE_URL="https://raw.githubusercontent.com/TheGentIeman/Nodes/refs/heads/main/HermesAgent"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DIR="$HERMES_HOME/skills"
RESEARCH_DIR="$HERMES_HOME/research-data"
OUTPUT_DIR="$HERMES_HOME/cache/documents"
MARKER="managed-by: TheGentleman/HermesAgent"

GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; RED="\e[31m"; NC="\e[0m"
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
err(){ echo -e "${RED}[x]${NC} $*" >&2; }
info(){ echo -e "${CYAN}[*]${NC} $*"; }
trap 'err "Ошибка на строке $LINENO. Скрипт остановлен."' ERR

[ "$(uname -s)" = Linux ] && command -v apt-get >/dev/null 2>&1 || { err "Нужен Ubuntu/Debian Linux VPS."; exit 1; }
if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null; then SUDO="sudo"; else err "Запустите от root."; exit 1; fi

ui_deps(){
  local missing=()
  for x in figlet whiptail curl wget; do command -v "$x" >/dev/null 2>&1 || missing+=("$x"); done
  if [ "${#missing[@]}" -gt 0 ]; then $SUDO apt-get update -y >/dev/null; $SUDO apt-get install -y "${missing[@]}" >/dev/null; fi
}

logo(){
  clear 2>/dev/null || true
  echo -e "\n${CYAN}$(figlet -w 150 -f standard "Soft by The Gentleman")${NC}"
  echo "================================================================================"
  echo "          Добро пожаловать в мастер установки Hermes Research Agent"
  echo "================================================================================"
  echo -e "${YELLOW}Telegram: https://t.me/GentleChron${NC}\n"
}

base_packages(){
  info "Устанавливаю зависимости..."
  $SUDO apt-get update -y
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y ca-certificates curl wget git jq sqlite3 python3 docker.io figlet whiptail tar xz-utils gzip unzip
  $SUDO systemctl enable --now docker
  ok "Зависимости готовы, включая xz-utils для Node.js"
}

find_hermes(){ export PATH="$HOME/.local/bin:/usr/local/bin:/usr/local/lib/hermes-agent/bin:$PATH"; command -v hermes >/dev/null 2>&1; }

install_hermes(){
  if find_hermes; then
    info "Hermes уже установлен: $(hermes --version 2>/dev/null || echo installed)"
    hermes update >/dev/null 2>&1 || true
  else
    info "Устанавливаю официальный Hermes Agent..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
    export PATH="$HOME/.local/bin:/usr/local/bin:/usr/local/lib/hermes-agent/bin:$PATH"
  fi
  find_hermes || { err "Hermes не найден после установки."; exit 1; }
  ok "Hermes: $(hermes --version 2>/dev/null || echo ready)"
}

research_layer(){
  mkdir -p "$SKILLS_DIR/signal-radar" "$SKILLS_DIR/evidence-dive" "$SKILLS_DIR/watchlist-monitor" "$RESEARCH_DIR" "$OUTPUT_DIR"
  info "Скачиваю Skills и Tracker..."
  curl -fsSL "$BASE_URL/SignalRadar.md" -o "$SKILLS_DIR/signal-radar/SKILL.md"
  curl -fsSL "$BASE_URL/EvidenceDive.md" -o "$SKILLS_DIR/evidence-dive/SKILL.md"
  curl -fsSL "$BASE_URL/WatchlistMonitor.md" -o "$SKILLS_DIR/watchlist-monitor/SKILL.md"
  curl -fsSL "$BASE_URL/tracker.py" -o "$RESEARCH_DIR/tracker.py"
  chmod +x "$RESEARCH_DIR/tracker.py"

  local tmp; tmp="$(mktemp)"; curl -fsSL "$BASE_URL/SOUL.md" -o "$tmp"
  if [ ! -f "$HERMES_HOME/SOUL.md" ] || grep -q "$MARKER" "$HERMES_HOME/SOUL.md" 2>/dev/null; then
    cp "$tmp" "$HERMES_HOME/SOUL.md"
  else
    cp "$tmp" "$HERMES_HOME/SOUL.gentleman-example.md"
    warn "Ваш SOUL.md не тронут; пример сохранён рядом."
  fi
  rm -f "$tmp"
  python3 "$RESEARCH_DIR/tracker.py" stats >/dev/null
  ok "Signal Radar / Evidence Dive / Watchlist Monitor / Tracker готовы"
}

sandbox(){
  info "Настраиваю Docker Sandbox..."
  hermes config set terminal.backend docker
  hermes config set terminal.container_persistent false
  hermes config set terminal.docker_mount_cwd_to_workspace false
  local vols; vols="$(jq -cn --arg a "$OUTPUT_DIR:/output" --arg b "$RESEARCH_DIR:/research-data" '[$a,$b]')"
  hermes config set terminal.docker_volumes "$vols"
  ok "Docker Sandbox и persistent research-data настроены"
}

full_install(){
  logo; base_packages; install_hermes; research_layer; sandbox
  hermes egress install >/dev/null 2>&1 || true
  hermes config check || true
  hermes doctor || true
  echo -e "\n${GREEN}================ HERMES RESEARCH AGENT УСТАНОВЛЕН ================${NC}"
  next_steps
}

next_steps(){
cat <<EOF

1. Модель:      hermes model
2. Тест:        hermes chat -q "Reply only with: AGENT WORKS"
3. Telegram:    hermes gateway setup
4. Gateway 24/7: hermes gateway install && sudo loginctl enable-linger "$USER" && hermes gateway start
5. Tools:       hermes tools
6. Signal Radar: hermes chat -s signal-radar -q "Find the strongest fresh developments in my priority topics from the last 24 hours. Verify important claims and avoid generic news."
7. Deep Research: hermes chat -s evidence-dive -q "Investigate TARGET deeply. Build a timeline, verify claims, find contradictions and separate confirmed facts from inference."

Research DB: $RESEARCH_DIR
Telegram: https://t.me/GentleChron
EOF
}

model(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes model; }
telegram(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes gateway setup; }
tools(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes tools; }
gateway(){ find_hermes || { err "Сначала установите Hermes."; return; }; hermes gateway install; $SUDO loginctl enable-linger "$USER"; hermes gateway start; hermes gateway status || true; }

radar_cron(){
  find_hermes || { err "Сначала установите Hermes."; return; }
  local schedule topics
  read -r -p "Интервал [every 6h]: " schedule; schedule="${schedule:-every 6h}"
  read -r -p "Какие темы мониторить? " topics
  if [ -z "$topics" ]; then topics="saved interests and current priority topics"; fi
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
  if [ ! -f "$RESEARCH_DIR/tracker.py" ]; then warn "Tracker ещё не установлен."; return; fi
  python3 "$RESEARCH_DIR/tracker.py" stats; echo; python3 "$RESEARCH_DIR/tracker.py" recent 20 || true
}

diag(){
  logo
  command -v xz >/dev/null && ok "xz-utils есть" || err "xz-utils отсутствует"
  command -v tar >/dev/null && ok "tar есть" || err "tar отсутствует"
  command -v docker >/dev/null && ok "$(docker --version)" || err "Docker отсутствует"
  if find_hermes; then
    ok "Hermes: $(hermes --version 2>/dev/null || echo installed)"
    hermes gateway status || true
    hermes cron status || true
    hermes egress status || true
  else err "Hermes не найден"; fi
  tracker
}

menu(){
  ui_deps
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

case "${1:-}" in
  --install|install) ui_deps; full_install;;
  --update|update) ui_deps; research_layer;;
  --diagnostics|diagnostics|diag) ui_deps; diag;;
  --next|next) ui_deps; next_steps;;
  "") menu;;
  *) echo "Usage: $0 [--install|--update|--diagnostics|--next]"; exit 1;;
esac
