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
        conn.execute(
            "INSERT INTO topics(topic_key,title,primary_url,state,first_seen,last_seen,times_seen) VALUES(?,?,?,?,?,?,1)",
            (key, title, url, state, ts, ts),
        )
    else:
        conn.execute(
            "UPDATE topics SET title=?, primary_url=?, state=?, last_seen=?, times_seen=times_seen+1 WHERE topic_key=?",
            (title, url, state, ts, key),
        )
    conn.commit()
    print("RECORDED")

elif cmd == "sent":
    if len(sys.argv) != 3:
        usage()
    key = sys.argv[2].strip().lower()
    cur = conn.execute("UPDATE topics SET last_sent=?, last_seen=? WHERE topic_key=?", (now(), now(), key))
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
    for row in conn.execute("SELECT * FROM topics WHERE status='watch' ORDER BY last_seen DESC LIMIT ?", (limit,)):
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
