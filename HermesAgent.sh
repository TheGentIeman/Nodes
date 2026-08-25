#!/bin/bash
set -Eeuo pipefail

# ============================================================
# Hermes Research Agent installer by The Gentleman
# Telegram: https://t.me/GentleChron
# ============================================================

VERSION="1.0.1"
BASE_URL="https://raw.githubusercontent.com/TheGentIeman/Nodes/refs/heads/main/HermesAgent"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DIR="$HERMES_HOME/skills"
RESEARCH_DIR="$HERMES_HOME/research-data"
OUTPUT_DIR="$HERMES_HOME/cache/documents"
BACKUP_DIR="$HERMES_HOME/gentleman-backups"
MARKER="managed-by: TheGentleman/HermesAgent"

GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
NC="\e[0m"

ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }
info() { echo -e "${CYAN}[*]${NC} $*"; }
trap 'err "Ошибка на строке $LINENO. Скрипт остановлен."' ERR

if [ "$(uname -s)" != "Linux" ] || ! command -v apt-get >/dev/null 2>&1; then
  err "Скрипт рассчитан на Ubuntu/Debian Linux VPS."
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  err "Запустите скрипт от root или установите sudo."
  exit 1
fi

install_ui_deps() {
  local need=()
  for util in figlet whiptail curl wget; do
    command -v "$util" >/dev/null 2>&1 || need+=("$util")
  done
  if [ "${#need[@]}" -gt 0 ]; then
    $SUDO apt-get update -y >/dev/null
    $SUDO apt-get install -y "${need[@]}" >/dev/null
  fi
}

show_logo() {
  clear 2>/dev/null || true
  echo -e "\n"
  echo -e "${CYAN}$(figlet -w 150 -f standard "Soft by The Gentleman")${NC}"
  echo "================================================================================"
  echo "          Добро пожаловать в мастер установки Hermes Research Agent"
  echo "================================================================================"
  echo -e "${YELLOW}Telegram: https://t.me/GentleChron${NC}"
  echo
}

animate() {
  for i in 1 2 3; do
    printf "\r${GREEN}Загрузка${NC}%s" "$(printf '.%.0s' $(seq 1 "$i"))"
    sleep 0.35
  done
  echo
}

install_base_packages() {
  info "Обновляю пакеты и ставлю зависимости..."
  $SUDO apt-get update -y
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y \
    ca-certificates curl wget git jq sqlite3 python3 docker.io figlet whiptail \
    tar xz-utils gzip unzip

  $SUDO systemctl enable --now docker

  if [ "$(id -u)" -ne 0 ] && ! id -nG "$USER" | grep -qw docker; then
    $SUDO usermod -aG docker "$USER"
    warn "Пользователь $USER добавлен в группу docker. Если Docker даст Permission denied, перелогиньтесь в SSH."
  fi

  ok "Базовые зависимости готовы"
  ok "tar/xz-utils установлены для распаковки Node.js"
}

find_hermes() {
  export PATH="$HOME/.local/bin:/usr/local/bin:/usr/local/lib/hermes-agent/bin:$PATH"
  command -v hermes >/dev/null 2>&1
}

install_hermes() {
  if find_hermes; then
    info "Hermes уже установлен: $(hermes --version 2>/dev/null || echo installed)"
    hermes update >/dev/null 2>&1 || warn "Автообновление Hermes не завершилось. Оставляю текущую версию."
  else
    info "Устанавливаю официальный Hermes Agent..."
    if ! curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash; then
      echo
      err "Официальный installer Hermes завершился с ошибкой."
      warn "Если ошибка была на 'Extracting node-...tar.xz', xz-utils уже установлен этим скриптом."
      warn "Просто запустите HermesAgent.sh ещё раз — повторная установка безопасна."
      return 1
    fi
    export PATH="$HOME/.local/bin:/usr/local/bin:/usr/local/lib/hermes-agent/bin:$PATH"
  fi

  if ! find_hermes; then
    err "Hermes не найден после установки."
    echo 'Попробуйте: source ~/.bashrc'
    exit 1
  fi

  ok "Hermes установлен: $(hermes --version 2>/dev/null || echo ready)"
}

make_dirs() {
  mkdir -p \
    "$SKILLS_DIR/signal-radar" \
    "$SKILLS_DIR/evidence-dive" \
    "$SKILLS_DIR/watchlist-monitor" \
    "$RESEARCH_DIR" \
    "$OUTPUT_DIR" \
    "$BACKUP_DIR"
}

backup_if_custom() {
  local target="$1"
  if [ -f "$target" ] && ! grep -q "$MARKER" "$target" 2>/dev/null; then
    local stamp parent
    stamp="$(date +%Y%m%d-%H%M%S)"
    parent="$(basename "$(dirname "$target")")"
    cp -a "$target" "$BACKUP_DIR/${parent}-$(basename "$target").${stamp}.bak"
    warn "Существующий файл сохранён в backup: $target"
  fi
}

download_managed() {
  local url="$1"
  local target="$2"
  backup_if_custom "$target"
  curl -fsSL "$url" -o "$target"
}

install_research_layer() {
  make_dirs
  info "Скачиваю Research Skills и Tracker..."

  download_managed "$BASE_URL/SignalRadar.md" "$SKILLS_DIR/signal-radar/SKILL.md"
  download_managed "$BASE_URL/EvidenceDive.md" "$SKILLS_DIR/evidence-dive/SKILL.md"
  download_managed "$BASE_URL/WatchlistMonitor.md" "$SKILLS_DIR/watchlist-monitor/SKILL.md"
  download_managed "$BASE_URL/tracker.py" "$RESEARCH_DIR/tracker.py"
  chmod +x "$RESEARCH_DIR/tracker.py"

  local soul_tmp
  soul_tmp="$(mktemp)"
  curl -fsSL "$BASE_URL/SOUL.md" -o "$soul_tmp"

  if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
    cp "$soul_tmp" "$HERMES_HOME/SOUL.md"
    ok "Создан пример SOUL.md"
  elif grep -q "$MARKER" "$HERMES_HOME/SOUL.md" 2>/dev/null; then
    cp "$soul_tmp" "$HERMES_HOME/SOUL.md"
    ok "Обновлён управляемый SOUL.md"
  else
    cp "$soul_tmp" "$HERMES_HOME/SOUL.gentleman-example.md"
    warn "Ваш кастомный SOUL.md не тронут. Новый пример сохранён рядом."
  fi
  rm -f "$soul_tmp"

  python3 "$RESEARCH_DIR/tracker.py" stats >/dev/null

  ok "Signal Radar установлен"
  ok "Evidence Dive установлен"
  ok "Watchlist Monitor установлен"
  ok "Persistent Tracker работает"
}

configure_docker() {
  info "Настраиваю Docker Sandbox..."
  hermes config set terminal.backend docker
  hermes config set terminal.container_persistent false
  hermes config set terminal.docker_mount_cwd_to_workspace false

  local volumes_json
  volumes_json="$(jq -cn --arg out "$OUTPUT_DIR:/output" --arg research "$RESEARCH_DIR:/research-data" '[$out,$research]')"
  hermes config set terminal.docker_volumes "$volumes_json"

  ok "Hermes Terminal переключён на Docker"
  ok "Research DB доступна внутри sandbox как /research-data"
  ok "Файлы доступны внутри sandbox как /output"
}

install_egress() {
  info "Ставлю Hermes Egress binary..."
  if hermes egress install >/dev/null 2>&1; then
    ok "Egress установлен"
  else
    warn "Egress не установился автоматически. Это опционально."
  fi
}

next_steps() {
  cat <<EOF
${CYAN}Что сделать дальше:${NC}

1. Подключить модель:
   hermes model

2. Проверить чат:
   hermes chat -q "Reply only with: AGENT WORKS"

3. Подключить Telegram:
   hermes gateway setup

4. После успешной проверки Telegram:
   hermes gateway install
   sudo loginctl enable-linger "$USER"
   hermes gateway start

5. Настроить Tools:
   hermes tools

6. Проверить Signal Radar вручную:
   hermes chat -s signal-radar -q "Find the strongest fresh developments in my priority topics from the last 24 hours. Verify important claims and avoid generic news."

7. Глубокий ресёрч одной темы:
   hermes chat -s evidence-dive -q "Investigate TARGET deeply. Build a timeline, verify claims, find contradictions and separate confirmed facts from inference."

8. Когда ручной результат устраивает, создайте Cron через это меню.

Research DB: $RESEARCH_DIR
Telegram: https://t.me/GentleChron
EOF
}

full_install() {
  show_logo
  animate
  install_base_packages
  install_hermes
  install_research_layer
  configure_docker
  install_egress

  echo
  info "Запускаю мягкую диагностику. Ошибки провайдера до подключения модели нормальны."
  hermes config check || true
  hermes doctor || true

  echo
  echo -e "${GREEN}================================================================================${NC}"
  echo -e "${GREEN}                    HERMES RESEARCH AGENT УСТАНОВЛЕН${NC}"
  echo -e "${GREEN}================================================================================${NC}"
  next_steps
}

update_research_layer() {
  if ! find_hermes; then
    err "Hermes не найден. Сначала выполните первичную установку."
    exit 1
  fi
  install_research_layer
  ok "Research-слой обновлён до версии $VERSION"
}

setup_model() { find_hermes || { err "Hermes не установлен."; exit 1; }; hermes model; }
setup_telegram() { find_hermes || { err "Hermes не установлен."; exit 1; }; hermes gateway setup; }
setup_tools() { find_hermes || { err "Hermes не установлен."; exit 1; }; hermes tools; }

enable_gateway() {
  find_hermes || { err "Hermes не установлен."; exit 1; }
  hermes gateway install
  $SUDO loginctl enable-linger "$USER"
  hermes gateway start
  hermes gateway status || true
}

create_radar_cron() {
  find_hermes || { err "Hermes не установлен."; exit 1; }
  show_logo
  read -r -p "Интервал [every 6h]: " SCHEDULE
  SCHEDULE="${SCHEDULE:-every 6h}"
  read -r -p "Какие темы мониторить? " TOPICS
  TOPICS="${TOPICS:-the user's saved interests and current priority topics}"

  hermes cron create "$SCHEDULE" \
    "Run Signal Radar for: $TOPICS. Search broadly for genuinely NEW or meaningfully UPDATED developments. Verify important claims, check the persistent tracker and avoid repeats. Return [SILENT] only if there is genuinely nothing useful." \
    --skill signal-radar \
    --deliver telegram \
    --continuity \
    --name "Gentleman Signal Radar"
  hermes cron list
}

create_watchlist_cron() {
  find_hermes || { err "Hermes не установлен."; exit 1; }
  show_logo
  read -r -p "Интервал [every 12h]: " SCHEDULE
  SCHEDULE="${SCHEDULE:-every 12h}"

  hermes cron create "$SCHEDULE" \
    "Review the persistent watchlist and report only meaningful changes since the previous known state. Do not repeat background information. Update the tracker. Return [SILENT] if nothing materially changed." \
    --skill watchlist-monitor \
    --deliver telegram \
    --continuity \
    --name "Gentleman Watchlist Monitor"
  hermes cron list
}

show_tracker() {
  [ -f "$RESEARCH_DIR/tracker.py" ] || { warn "Tracker пока не установлен."; return; }
  python3 "$RESEARCH_DIR/tracker.py" stats
  echo
  python3 "$RESEARCH_DIR/tracker.py" recent 20 || true
}

diagnostics() {
  show_logo
  find_hermes && ok "Hermes: $(hermes --version 2>/dev/null || echo installed)" || err "Hermes не найден"
  command -v docker >/dev/null 2>&1 && ok "Docker: $(docker --version 2>/dev/null || true)" || err "Docker не найден"
  command -v xz >/dev/null 2>&1 && ok "xz-utils установлен" || err "xz-utils отсутствует"
  command -v tar >/dev/null 2>&1 && ok "tar установлен" || err "tar отсутствует"

  if find_hermes; then
    echo
    hermes config get terminal.backend 2>/dev/null || true
    hermes skills list 2>/dev/null || true
    hermes gateway status || true
    hermes cron status || true
    hermes egress status || true
  fi
  show_tracker
}

menu() {
  install_ui_deps
  show_logo
  animate

  while true; do
    CHOICE=$(whiptail --title "Hermes Research Agent by The Gentleman" \
      --menu "Выберите нужное действие:" 24 84 14 \
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
        "12" "Выход" \
      3>&1 1>&2 2>&3) || exit 0

    case "$CHOICE" in
      1) full_install ;;
      2) update_research_layer ;;
      3) setup_model ;;
      4) setup_telegram ;;
      5) enable_gateway ;;
      6) setup_tools ;;
      7) create_radar_cron ;;
      8) create_watchlist_cron ;;
      9) show_tracker ;;
      10) diagnostics ;;
      11) next_steps ;;
      12) exit 0 ;;
    esac

    echo
    read -r -p "Нажмите Enter, чтобы вернуться в меню..." _
    show_logo
  done
}

case "${1:-}" in
  --install|install) install_ui_deps; full_install ;;
  --update|update) install_ui_deps; update_research_layer ;;
  --diagnostics|diagnostics|diag) install_ui_deps; diagnostics ;;
  --next|next) install_ui_deps; next_steps ;;
  "") menu ;;
  *) echo "Usage: $0 [--install|--update|--diagnostics|--next]"; exit 1 ;;
esac
