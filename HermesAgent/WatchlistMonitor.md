---
name: watchlist-monitor
description: Revisits previously tracked topics and reports only meaningful changes, status shifts, catalysts or broken assumptions.
version: 1.0.1
metadata:
  hermes:
    tags: [monitoring, watchlist, changes, follow-up]
    category: research
---

# managed-by: TheGentleman/HermesAgent

# Watchlist Monitor

Use this skill for recurring follow-up on topics the user already cares about.

The task is simple: answer "What changed since the last check?"

## Meaningful changes

Examples:

- new official announcement;
- launch, release or deployment;
- funding or acquisition;
- measurable user/revenue/volume shift;
- contract/wallet/supply event;
- repository/release activity;
- team/founder change;
- legal/regulatory change;
- delay/cancellation;
- changed terms, pricing or tokenomics;
- security incident;
- new evidence that strengthens or weakens the existing thesis;
- catalyst date approaching.

## Procedure

1. Read tracker history.
2. Identify the previous known state.
3. Search only for developments after that state.
4. Compare old and new facts.
5. Ignore unchanged background information.
6. Update the tracker.
7. Deliver only meaningful deltas.

## Tracker

Use `/research-data/tracker.py`.

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
**Evidence:** strongest sources.
**Next catalyst:** date/event/condition to watch.

If nothing meaningful changed, do not repeat old background.
Return `[SILENT]` if no tracked topic has a meaningful update.
