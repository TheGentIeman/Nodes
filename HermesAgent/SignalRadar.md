---
name: signal-radar
description: Broadly scans fresh sources for useful, non-obvious developments in the user's chosen topics and filters out repeats using a persistent tracker.
version: 1.0.1
metadata:
  hermes:
    tags: [research, discovery, monitoring, web, x]
    category: research
---

# managed-by: TheGentleman/HermesAgent

# Signal Radar

Use this skill for broad discovery when no single target has already been selected.

## Goal

Find genuinely new or meaningfully updated developments in the user's chosen areas. Do not optimize for quantity.

## Freshness

Prioritize the last 6 hours, then 24 hours. Use older material only when a story is still developing or it provides necessary context.

Never confuse "new to you" with "new". Verify the actual event timestamp.

## Method

1. Identify the user's priority topics.
2. Search from several angles instead of one generic query.
3. Include small/high-signal sources as well as large publications/accounts.
4. Gather candidate leads before selecting final results.
5. Reject routine, recycled or obvious items.
6. Verify important candidates with primary or independent sources.
7. Check the persistent tracker before including a lead.
8. If already tracked, include it only when something materially changed.
9. Update the tracker after selection.

## Interesting signal test

A lead is useful when at least one is true:

- something materially changed;
- money, users, activity or attention moved abnormally;
- a product, release, repository, contract or feature appeared before broad attention;
- a company/project changed direction;
- public claims conflict with observable evidence;
- there is an unfinished story with a near-term catalyst;
- the information changes a practical decision for the user.

Small, new or viral alone are not enough.

## Tracker

Use `/research-data/tracker.py`.

Check:
`python3 /research-data/tracker.py check "<topic_key>"`

Record/update:
`python3 /research-data/tracker.py record "<topic_key>" "<title>" "<primary_url>" "<short current state>"`

Mark delivered:
`python3 /research-data/tracker.py sent "<topic_key>"`

Recent history:
`python3 /research-data/tracker.py recent 50`

## Output

For every selected item:

### Topic
**What changed:** concrete new development.
**Why it matters:** practical meaning for the user.
**Evidence:** strongest sources and important numbers.
**Confidence:** confirmed / strong inference / unconfirmed.
**Next:** what should be watched or verified next.

Three strong findings are better than ten weak ones.
Return `[SILENT]` only when there is genuinely nothing useful and new.
