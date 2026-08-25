#!/bin/bash
set -Eeuo pipefail

# ============================================================
# Hermes Research Agent installer by The Gentleman
# Telegram: https://t.me/GentleChron
# ============================================================

VERSION="1.0.0"
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
PURPLE="\e[35m"
NC="\e[0m"

ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }
info() { echo -e "${CYAN}[*]${NC} $*"; }

trap 'err "Ошибка на строке $LINENO. Скрипт остановлен."' ERR

if [ "$(uname -s)" != "Linux" ]; then
  err "Скрипт рассчитан на Linux VPS."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  err "Автоматическая установка рассчитана на Ubuntu/Debian."
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    err "Запустите скрипт от root или установите sudo."
    exit 1
  fi
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
    ca-certificates curl wget git jq sqlite3 python3 docker.io figlet whiptail

  $SUDO systemctl enable --now docker

  if [ "$(id -u)" -ne 0 ] && ! id -nG "$USER" | grep -qw docker; then
    $SUDO usermod -aG docker "$USER"
    warn "Пользователь $USER добавлен в группу docker. Если будет Permission denied, перелогиньтесь в SSH."
  fi

  ok "Базовые зависимости готовы"
}

find_hermes() {
  export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
  command -v hermes >/dev/null 2>&1
}

install_hermes() {
  if find_hermes; then
    info "Hermes уже установлен: $(hermes --version 2>/dev/null || echo installed)"
    info "Пробую обновить Hermes..."
    hermes update >/dev/null 2>&1 || warn "Автообновление не завершилось. Оставляю текущую версию."
  else
    info "Устанавливаю официальный Hermes Agent..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
    export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
  fi

  if ! find_hermes; then
    err "Hermes не найден после установки."
    echo 'Попробуйте выполнить: source ~/.bashrc'
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

write_soul() {
  local target="$HERMES_HOME/SOUL.md"
  local example="$HERMES_HOME/SOUL.gentleman-example.md"
  local tmp
  tmp="$(mktemp)"

  cat > "$tmp" <<'EOF_SOUL'
# managed-by: TheGentleman/HermesAgent

# Role

You are an autonomous research assistant.

Your goal is not to produce the largest possible amount of information.
Your goal is to notice useful changes early, verify them, keep track of what has already been seen, and explain the important part clearly.

# How to think

Use different sources for different jobs:

- X and social sources for early signals, discussion and unusual activity.
- Web search for discovery and independent confirmation.
- Official websites, docs and announcements for factual claims.
- GitHub for development activity and technical evidence.
- Browser automation for dynamic pages or interfaces normal extraction cannot read.
- Onchain/data tools when the topic depends on contracts, wallets, money flows or measurable activity.

# Core rules

- Never invent facts, links, dates, wallets, people or numbers.
- Prefer primary sources.
- A single post is a lead, not proof.
- Separate confirmed facts from interpretation.
- Do not confuse "new to you" with "new".
- Always check the real publication/event timestamp.
- Avoid repeating the same story unless something materially changed.
- Do not fill reports with weak items just to make them longer.
- If evidence is weak, say so.
- If two sources conflict, show the conflict instead of silently choosing one.
- Focus on what changed, why it matters, and what should happen next.

# Personalization

The user may define areas of interest, companies, projects, technologies, markets, people, products or topics.

Treat those interests as a priority filter, not as a reason to lower evidence standards.

When the user's interests are unknown, ask them to define 3-10 topics they genuinely want monitored.

# Output

For research findings, prefer:

1. What changed?
2. Why does it matter?
3. What proves it?
4. What is uncertain?
5. What should be watched next?
EOF_SOUL

  if [ ! -f "$target" ]; then
    cp "$tmp" "$target"
    ok "Создан пример SOUL.md"
  elif grep -q "$MARKER" "$target" 2>/dev/null; then
    cp "$tmp" "$target"
    ok "Обновлён управляемый SOUL.md"
  else
    cp "$tmp" "$example"
    warn "Ваш SOUL.md не тронут. Новый пример сохранён как SOUL.gentleman-example.md"
  fi

  rm -f "$tmp"
}

write_signal_radar() {
  local target="$SKILLS_DIR/signal-radar/SKILL.md"
  backup_if_custom "$target"

  cat > "$target" <<'EOF_RADAR'
---
name: signal-radar
description: Broadly scans fresh sources for useful, non-obvious developments in the user's chosen topics and filters out repeats using a persistent tracker.
version: 1.0.0
metadata:
  hermes:
    tags: [research, discovery, monitoring, web, x]
    category: research
---

# managed-by: TheGentleman/HermesAgent

# Signal Radar

## Purpose

Use this skill when the user wants to discover what is new, unusual, under-discussed or worth investigating across one or more topics.

This is a discovery workflow, not a deep investigation of one known target.

## Good use cases

- crypto / markets;
- AI and technology;
- companies and products;
- startups and funding;
- security incidents;
- open-source projects;
- new tools;
- regulation;
- scientific or technical niches;
- competitors;
- any user-defined watch area.

## Freshness order

Default:

1. Last 6 hours: highest priority.
2. Last 24 hours: normal discovery window.
3. Last 72 hours: only if the story is still developing or a new delta appeared.

Always identify when the actual event happened. Do not repackage old information as fresh.

## Discovery loop

1. Identify the user's priority topics.
2. Search broadly before selecting winners.
3. Use multiple query angles, not one generic search.
4. Search small/high-signal sources as well as large accounts/publications.
5. Collect candidate leads.
6. Reject obvious/noisy/recycled items.
7. Verify strong candidates with primary or independent sources.
8. Check the persistent tracker before sending.
9. If the topic was already seen, look specifically for a meaningful change.
10. Record the final findings in the tracker.

## Interesting-signal test

A lead becomes interesting when at least one of these is true:

- something materially changed;
- money, users, activity or attention moved abnormally;
- a product/release/contract/repository appeared before broad attention;
- a company/project changed direction;
- credible people started paying attention unusually early;
- public claims conflict with observable evidence;
- there is an unfinished story with a near-term catalyst;
- the information changes a practical decision for the user.

"Small", "new" or "viral" alone are not enough.

## Source discipline

Use the earliest signal for discovery, then verify with the strongest source available.

When possible:

- claim → official source;
- development → repository/release;
- market/data claim → measurable data;
- social claim → original post;
- financial claim → filing, dashboard, onchain or first-party disclosure.

## Persistent tracker

Tracker:

`/research-data/tracker.py`

Check:

`python3 /research-data/tracker.py check "<topic_key>"`

Record/update:

`python3 /research-data/tracker.py record "<topic_key>" "<title>" "<primary_url>" "<short current state>"`

Mark delivered:

`python3 /research-data/tracker.py sent "<topic_key>"`

Recent history:

`python3 /research-data/tracker.py recent 50`

Use stable lowercase keys.

## What to reject

Unless a special angle exists, reject:

- generic summaries;
- routine listings/releases;
- normal price movement;
- repost chains with no primary source;
- old stories resurfacing without a real update;
- technical trivia with no practical meaning;
- weak speculation presented as a lead;
- ten near-identical items from the same narrative.

## Output

Return strongest items first.

For every item:

### Topic

**What changed:** concrete new development.

**Why it matters:** practical meaning for the user.

**Evidence:** primary/independent sources and important numbers.

**Confidence:** confirmed / strong inference / unconfirmed.

**Next:** what to watch, verify or do next.

Do not target a fixed number. Three strong findings are better than ten weak ones.

Return `[SILENT]` only when there is genuinely nothing useful and new.
EOF_RADAR
}

write_evidence_dive() {
  local target="$SKILLS_DIR/evidence-dive/SKILL.md"
  backup_if_custom "$target"

  cat > "$target" <<'EOF_DIVE'
---
name: evidence-dive
description: Performs a deep, evidence-led investigation of one selected topic, project, company, event, product, person, claim or thesis.
version: 1.0.0
metadata:
  hermes:
    tags: [research, investigation, verification, deep-research]
    category: research
---

# managed-by: TheGentleman/HermesAgent

# Evidence Dive

## Activation

Use when ONE target or question has already been selected.

Examples:

- "Research this company."
- "Why did this token move?"
- "Is this product actually growing?"
- "What happened in this incident?"
- "Check whether this claim is true."
- "Compare what the founder says with the data."
- "Investigate this new AI project."

Do not use this skill for broad discovery.

## Goal

Build the strongest possible evidence chain, not the longest possible report.

## Method

### 1. Define the exact question

Before searching, restate internally:

- What are we trying to prove/disprove/understand?
- Which facts would materially change the conclusion?
- What time window matters?

### 2. Build a timeline

Collect dates for:

- first signal;
- announcement;
- product/repository/contract changes;
- funding or money movement;
- major public reactions;
- latest confirmed state.

Timeline conflicts are often more useful than generic summaries.

### 3. Map the actors

When relevant:

- founders/team;
- investors;
- partners;
- customers/users;
- wallets/contracts;
- developers/repos;
- competitors;
- regulators;
- notable supporters/critics.

Only state relationships that can be supported.

### 4. Follow the money/data

When relevant inspect:

- funding;
- revenue/fees;
- treasury;
- incentives;
- token supply/unlocks;
- wallets/transfers;
- market liquidity;
- users/volume/traffic;
- pricing;
- grants;
- expenditures.

Do not use a vanity metric when a better metric exists.

### 5. Inspect technical evidence

For technical projects:

- repository history;
- commits;
- releases;
- deployments;
- frontend/API changes;
- docs;
- contracts;
- package/release metadata.

A code breadcrumb is evidence of work, not automatic proof of an announced future event.

### 6. Search for contradictions

Look specifically for:

- claims vs data;
- old statements vs new behavior;
- announced dates vs actual deployments;
- reported metrics vs observable metrics;
- "decentralized" claims vs control structure;
- "organic" growth vs incentives;
- funding/valuation headlines vs actual token/equity terms.

### 7. Search against your own thesis

Once a likely explanation forms, actively search for evidence that would invalidate it.

Do not only collect supporting evidence.

## Evidence labels

### CONFIRMED
Directly supported by primary or highly reliable evidence.

### STRONG INFERENCE
Multiple facts support the interpretation, but there is no direct confirmation.

### UNCONFIRMED
Potentially relevant claim that could not be independently verified.

### CONTRADICTED
Available evidence directly conflicts with the claim.

## Final report

Use sections that fit the case, not a rigid template.

Always include:

1. Main conclusion.
2. Timeline.
3. Strongest evidence.
4. Important numbers/data.
5. Contradictions or alternative explanations.
6. What remains unknown.
7. What would change the conclusion.
8. Primary sources.

If the user asks for maximum depth, do not compress meaningful evidence.
EOF_DIVE
}

write_watchlist_monitor() {
  local target="$SKILLS_DIR/watchlist-monitor/SKILL.md"
  backup_if_custom "$target"

  cat > "$target" <<'EOF_WATCH'
---
name: watchlist-monitor
description: Revisits previously tracked topics and reports only meaningful changes, status shifts, catalysts or broken assumptions.
version: 1.0.0
metadata:
  hermes:
    tags: [monitoring, watchlist, changes, follow-up]
    category: research
---

# managed-by: TheGentleman/HermesAgent

# Watchlist Monitor

## Purpose

Use this skill for recurring follow-up.

The job is not to discover random new topics. The job is to revisit things the user already cares about and answer:

"What changed since the last check?"

## Inputs

A watchlist may contain:

- projects;
- companies;
- products;
- tokens;
- protocols;
- people;
- repositories;
- regulations;
- court cases;
- research topics;
- competitors;
- incidents.

Use the persistent tracker and previous run context whenever available.

## Change categories

A meaningful change includes:

- new official announcement;
- launch/release/deployment;
- funding or acquisition;
- measurable user/revenue/volume shift;
- contract/wallet/supply event;
- repository/release activity;
- team/founder departure or addition;
- legal/regulatory change;
- delay/cancellation;
- changed terms/pricing/tokenomics;
- security incident;
- new evidence that strengthens or weakens the existing thesis;
- catalyst date approaching.

## Procedure

1. Read recent tracker history.
2. Identify the previous known state.
3. Search only for developments after that state.
4. Compare old and new facts.
5. Ignore unchanged background information.
6. Update the tracker with the new state.
7. Deliver only meaningful deltas.

## Persistent tracker

`/research-data/tracker.py`

Useful commands:

`python3 /research-data/tracker.py recent 100`

`python3 /research-data/tracker.py check "<topic_key>"`

`python3 /research-data/tracker.py record "<topic_key>" "<title>" "<primary_url>" "<new current state>"`

`python3 /research-data/tracker.py sent "<topic_key>"`

## Output

### Topic

**Previous state:** one sentence.

**New:** what materially changed.

**Impact:** why the change matters.

**Evidence:** sources.

**Next catalyst:** date/event/condition to watch.

If nothing meaningful changed, do not repeat the old background.

Return `[SILENT]` if no tracked topic has a meaningful update.
EOF_WATCH
}

write_tracker() {
  local target="$RESEARCH_DIR/tracker.py"
  backup_if_custom "$target"

  cat > "$target" <<'EOF_TRACKER'
#!/usr/bin/env python3
# managed-by: TheGentleman/HermesAgent

import json
import os
import sqlite3
import sys
import time
from pathlib import Path

def db_path():
    override = os.getenv("RESEARCH_TRACKER_DB")
    if override:
        return override
    if Path("/research-data").exists():
        return "/research-data/research.db"
    return str(Path.home() / ".hermes" / "research-data" / "research.db")

DB = db_path()
Path(DB).parent.mkdir(parents=True, exist_ok=True)

conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row

conn.execute("""
CREATE TABLE IF NOT EXISTS topics (
    topic_key TEXT PRIMARY KEY,
    title TEXT NOT NULL DEFAULT '',
    primary_url TEXT NOT NULL DEFAULT '',
    state TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'watch',
    first_seen INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    last_sent INTEGER,
    times_seen INTEGER NOT NULL DEFAULT 1
)
""")
conn.commit()

def now():
    return int(time.time())

def usage():
    print("""Commands:
  tracker.py check <topic_key>
  tracker.py record <topic_key> <title> <primary_url> [state]
  tracker.py sent <topic_key>
  tracker.py recent [limit]
  tracker.py watch [limit]
  tracker.py status <topic_key> <watch|paused|closed>
  tracker.py stats
""")
    raise SystemExit(1)

def print_row(row):
    print(json.dumps(dict(row), ensure_ascii=False, indent=2))

if len(sys.argv) < 2:
    usage()

cmd = sys.argv[1]

if cmd == "check":
    if len(sys.argv) != 3:
        usage()
    key = sys.argv[2].strip().lower()
    row = conn.execute("SELECT * FROM topics WHERE topic_key=?", (key,)).fetchone()
    print("NEW" if row is None else json.dumps(dict(row), ensure_ascii=False, indent=2))

elif cmd == "record":
    if len(sys.argv) < 5:
        usage()
    key = sys.argv[2].strip().lower()
    title = sys.argv[3].strip()
    url = sys.argv[4].strip()
    state = sys.argv[5].strip() if len(sys.argv) > 5 else ""
    ts = now()

    row = conn.execute("SELECT topic_key FROM topics WHERE topic_key=?", (key,)).fetchone()
    if row is None:
        conn.execute("""
          INSERT INTO topics(topic_key,title,primary_url,state,first_seen,last_seen,times_seen)
          VALUES(?,?,?,?,?,?,1)
        """, (key, title, url, state, ts, ts))
    else:
        conn.execute("""
          UPDATE topics
          SET title=?, primary_url=?, state=?, last_seen=?, times_seen=times_seen+1
          WHERE topic_key=?
        """, (title, url, state, ts, key))
    conn.commit()
    print("RECORDED")

elif cmd == "sent":
    if len(sys.argv) != 3:
        usage()
    key = sys.argv[2].strip().lower()
    cur = conn.execute(
        "UPDATE topics SET last_sent=?, last_seen=? WHERE topic_key=?",
        (now(), now(), key)
    )
    conn.commit()
    if cur.rowcount == 0:
        print("NOT_FOUND")
        raise SystemExit(2)
    print("MARKED_SENT")

elif cmd == "recent":
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    limit = max(1, min(limit, 500))
    for row in conn.execute("SELECT * FROM topics ORDER BY last_seen DESC LIMIT ?", (limit,)):
        print(json.dumps(dict(row), ensure_ascii=False))

elif cmd == "watch":
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 100
    limit = max(1, min(limit, 500))
    for row in conn.execute(
        "SELECT * FROM topics WHERE status='watch' ORDER BY last_seen DESC LIMIT ?",
        (limit,)
    ):
        print(json.dumps(dict(row), ensure_ascii=False))

elif cmd == "status":
    if len(sys.argv) != 4 or sys.argv[3] not in {"watch", "paused", "closed"}:
        usage()
    key = sys.argv[2].strip().lower()
    cur = conn.execute("UPDATE topics SET status=? WHERE topic_key=?", (sys.argv[3], key))
    conn.commit()
    print("UPDATED" if cur.rowcount else "NOT_FOUND")

elif cmd == "stats":
    total = conn.execute("SELECT COUNT(*) FROM topics").fetchone()[0]
    watch = conn.execute("SELECT COUNT(*) FROM topics WHERE status='watch'").fetchone()[0]
    sent = conn.execute("SELECT COUNT(*) FROM topics WHERE last_sent IS NOT NULL").fetchone()[0]
    day = conn.execute("SELECT COUNT(*) FROM topics WHERE last_seen>=?", (now()-86400,)).fetchone()[0]
    print(json.dumps({
        "db": DB,
        "total_topics": total,
        "watching": watch,
        "sent": sent,
        "seen_last_24h": day,
    }, ensure_ascii=False, indent=2))

else:
    usage()
EOF_TRACKER

  chmod +x "$target"
}

configure_docker() {
  info "Настраиваю Docker Sandbox для Hermes..."

  hermes config set terminal.backend docker
  hermes config set terminal.container_persistent false
  hermes config set terminal.docker_mount_cwd_to_workspace false

  local volumes_json
  volumes_json="$(jq -cn \
    --arg out "$OUTPUT_DIR:/output" \
    --arg research "$RESEARCH_DIR:/research-data" \
    '[$out,$research]')"

  hermes config set terminal.docker_volumes "$volumes_json"

  ok "Hermes Terminal переключён на Docker"
  ok "Research DB проброшена в /research-data"
  ok "Папка для файлов проброшена в /output"
}

install_research_layer() {
  make_dirs
  write_soul
  write_signal_radar
  write_evidence_dive
  write_watchlist_monitor
  write_tracker

  if python3 "$RESEARCH_DIR/tracker.py" stats >/dev/null; then
    ok "Persistent Tracker работает"
  else
    err "Tracker не прошёл проверку"
    return 1
  fi

  ok "Установлены Skills: signal-radar, evidence-dive, watchlist-monitor"
}

install_egress() {
  info "Ставлю Hermes Egress (настройка ключей будет позже вручную)..."
  if hermes egress install >/dev/null 2>&1; then
    ok "Egress binary установлен"
  else
    warn "Egress не установился автоматически. Это опционально."
    warn "Позже можно выполнить: hermes egress install"
  fi
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
  echo
  ok "Hermes"
  ok "Docker Sandbox"
  ok "Persistent Tracker"
  ok "Signal Radar"
  ok "Evidence Dive"
  ok "Watchlist Monitor"
  ok "SOUL example"
  echo
  next_steps
}

update_research_layer() {
  if ! find_hermes; then
    err "Hermes не найден. Сначала выполните первичную установку."
    exit 1
  fi

  make_dirs
  install_research_layer
  ok "Research-слой обновлён до версии $VERSION"
}

setup_model() {
  if ! find_hermes; then
    err "Hermes не установлен."
    exit 1
  fi
  show_logo
  echo -e "${CYAN}Откроется официальный мастер выбора модели Hermes.${NC}"
  echo
  hermes model
}

setup_telegram() {
  if ! find_hermes; then
    err "Hermes не установлен."
    exit 1
  fi
  show_logo
  echo -e "${CYAN}Откроется официальный мастер Gateway. Выберите Telegram и следуйте шагам.${NC}"
  echo -e "${YELLOW}Bot Token никому не отправляйте и не публикуйте.${NC}"
  echo
  hermes gateway setup
}

enable_gateway() {
  if ! find_hermes; then
    err "Hermes не установлен."
    exit 1
  fi

  hermes gateway install
  $SUDO loginctl enable-linger "$USER"
  hermes gateway start
  hermes gateway status || true
}

setup_tools() {
  if ! find_hermes; then
    err "Hermes не установлен."
    exit 1
  fi
  hermes tools
}

create_radar_cron() {
  if ! find_hermes; then
    err "Hermes не установлен."
    exit 1
  fi

  show_logo
  echo "Автоматический Signal Radar будет периодически искать новые темы и отправлять результат в Telegram."
  echo "Перед этим желательно вручную проверить, что модель, Telegram и нужные Tools уже работают."
  echo
  read -r -p "Интервал [по умолчанию every 6h]: " SCHEDULE
  SCHEDULE="${SCHEDULE:-every 6h}"

  read -r -p "Какие темы мониторить? Например: crypto, AI agents, new tools: " TOPICS
  if [ -z "$TOPICS" ]; then
    TOPICS="the user's saved interests and current priority topics"
  fi

  hermes cron create "$SCHEDULE" \
    "Run Signal Radar for: $TOPICS. Search broadly for genuinely NEW or meaningfully UPDATED developments. Use primary sources, verify important claims, check the persistent tracker, and avoid repeating old information. Return [SILENT] only if there is genuinely nothing useful." \
    --skill signal-radar \
    --deliver telegram \
    --continuity \
    --name "Gentleman Signal Radar"

  echo
  hermes cron list
}

create_watchlist_cron() {
  if ! find_hermes; then
    err "Hermes не установлен."
    exit 1
  fi

  show_logo
  echo "Watchlist Monitor проверяет только уже сохранённые темы и сообщает, что изменилось."
  echo
  read -r -p "Интервал [по умолчанию every 12h]: " SCHEDULE
  SCHEDULE="${SCHEDULE:-every 12h}"

  hermes cron create "$SCHEDULE" \
    "Review the persistent watchlist and report only meaningful changes since the previous known state. Do not repeat background information. Update the tracker. Return [SILENT] if nothing materially changed." \
    --skill watchlist-monitor \
    --deliver telegram \
    --continuity \
    --name "Gentleman Watchlist Monitor"

  echo
  hermes cron list
}

show_tracker() {
  if [ -f "$RESEARCH_DIR/tracker.py" ]; then
    echo
    python3 "$RESEARCH_DIR/tracker.py" stats
    echo
    echo "Последние записи:"
    python3 "$RESEARCH_DIR/tracker.py" recent 20 || true
  else
    warn "Tracker пока не установлен."
  fi
}

diagnostics() {
  show_logo
  echo -e "${CYAN}Диагностика Hermes Research Agent${NC}"
  echo

  if find_hermes; then
    ok "Hermes: $(hermes --version 2>/dev/null || echo installed)"
  else
    err "Hermes не найден"
  fi

  if command -v docker >/dev/null 2>&1; then
    ok "Docker CLI: $(docker --version 2>/dev/null || true)"
    if $SUDO docker info >/dev/null 2>&1; then
      ok "Docker daemon доступен"
    else
      warn "Docker daemon недоступен"
    fi
  else
    err "Docker не установлен"
  fi

  if find_hermes; then
    echo
    echo "Terminal backend:"
    hermes config get terminal.backend 2>/dev/null || true

    echo
    echo "Docker volumes:"
    hermes config get terminal.docker_volumes --json 2>/dev/null || true

    echo
    echo "Skills:"
    hermes skills list 2>/dev/null || true

    echo
    echo "Gateway:"
    hermes gateway status || true

    echo
    echo "Cron:"
    hermes cron status || true

    echo
    echo "Egress:"
    hermes egress status || true
  fi

  show_tracker
}

next_steps() {
  cat <<EOF_NEXT
${CYAN}Что сделать дальше:${NC}

1. Подключить модель:
   hermes model

2. Проверить обычный чат:
   hermes chat -q "Reply only with: AGENT WORKS"

3. Подключить Telegram:
   hermes gateway setup

4. После успешной проверки Telegram:
   hermes gateway install
   sudo loginctl enable-linger "$USER"
   hermes gateway start

5. Настроить инструменты:
   hermes tools

6. Проверить Signal Radar вручную:
   hermes chat -s signal-radar -q "Find the strongest fresh developments in my priority topics from the last 24 hours. Verify important claims and avoid generic news."

7. Глубокий ресёрч одной темы:
   hermes chat -s evidence-dive -q "Investigate TARGET deeply. Build a timeline, verify the strongest claims, find contradictions and separate confirmed facts from inference."

8. Когда результат вас устраивает, включить автоматический Cron через меню этого скрипта.

${YELLOW}Важно:${NC}
- API Keys и Telegram Token этот скрипт не собирает и не хранит.
- Ваш кастомный SOUL.md не перезаписывается.
- База ресёрча хранится в:
  $RESEARCH_DIR

${CYAN}Telegram: https://t.me/GentleChron${NC}
EOF_NEXT
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
  --install|install)
    install_ui_deps
    full_install
    ;;
  --update|update)
    install_ui_deps
    update_research_layer
    ;;
  --diagnostics|diagnostics|diag)
    install_ui_deps
    diagnostics
    ;;
  --next|next)
    install_ui_deps
    next_steps
    ;;
  "")
    menu
    ;;
  *)
    echo "Usage: $0 [--install|--update|--diagnostics|--next]"
    exit 1
    ;;
esac
