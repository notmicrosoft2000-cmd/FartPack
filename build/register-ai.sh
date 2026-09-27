#!/usr/bin/env bash
# register-ai.sh - claim an AI id on this box.
#
# An unregistered AI is invisible, and an invisible AI is a collision waiting to
# happen. This allocates the lowest UNUSED id, creates your journal folder and
# registry page, and adds you to the roster. Read wiki/03-AI-REGISTRATION.md.
#
# It does NOT touch the Minecraft server, Crafty, or anything outside ~/homelab/wiki.
#
#   register-ai.sh                  allocate the next id, interactively
#   register-ai.sh --name "..." --works-on "..." --owns "..." --host "..."
#   register-ai.sh --list           show the roster and exit
#   register-ai.sh --id AI-7        claim a specific id (must be unused)
set -uo pipefail

WIKI="$HOME/homelab/wiki"
REG="$WIKI/registry/README.md"
JOURNALS="$WIKI/journals"
LOCK="$WIKI/bin/ailock.sh"

die() { printf 'register-ai: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
ask() { # ask <varname> <prompt> <default>
  local __v="$1" __p="$2" __d="${3:-}"
  if [ -n "${!__v:-}" ]; then return 0; fi
  if [ -n "$__d" ]; then
    printf '%s [%s]: ' "$__p" "$__d"
  else
    printf '%s: ' "$__p"
  fi
  local a; IFS= read -r a || a=""
  [ -n "$a" ] || a="$__d"
  printf -v "$__v" '%s' "$a"
}

WANT_ID=""; NAME=""; WORKS=""; OWNS=""; HOSTNAME_AI=""; MACHINE=""; LISTONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --list)    LISTONLY=1 ;;
    --id)      WANT_ID="${2:-}"; shift ;;
    --name)    NAME="${2:-}"; shift ;;
    --works-on) WORKS="${2:-}"; shift ;;
    --owns)    OWNS="${2:-}"; shift ;;
    --host)    HOSTNAME_AI="${2:-}"; shift ;;
    --from)    MACHINE="${2:-}"; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[ -f "$REG" ] || die "roster not found at $REG - is the wiki installed?"
[ -x "$LOCK" ] || die "$LOCK is missing or not executable"

# ---------- --list ----------
if [ "$LISTONLY" -eq 1 ]; then
  say "=== roster ==="
  sed -n '/^| *ID/,$p' "$REG"
  exit 0
fi

# ---------- allocate an id ----------
# An id is taken if ANY of these exist: a roster row, a registry page, or a
# journal folder. Checking only some of them is how two AIs end up sharing a
# number, which is the exact failure this whole system exists to prevent.
id_in_roster() {
  # TRUE only if the roster carries a real registration row for this id.
  #
  # The previous version was:
  #     grep -qE "(^|[^A-Za-z0-9_-])$1([^A-Za-z0-9_-]|$)" "$REG"
  # which is a substring match over the WHOLE file. It called an id taken if the
  # string appeared anywhere - including in this repository's own prose, or in a
  # placeholder row whose only purpose is to say "this number was skipped on
  # purpose, do not read it as lost".
  #
  # AI-2 hit exactly that on 2026-09-27: the roster deliberately carried
  #     | `AI-2` | *unclaimed* | ...
  # so `register-ai.sh --id AI-2` refused with "ALREADY REGISTERED" and the
  # documented claim command could never claim AI-2. It failed safe - it refused
  # to write - but it blocked the documented path for the next AI identically.
  #
  # A registration is a TABLE ROW whose id cell is exactly this id and whose
  # status cell is not a placeholder. Everything else - prose, headings, a
  # skipped-number row - is not a registration.
  awk -v want="$1" '
    /^\|/ {
      n = split($0, c, "|")
      if (n < 3) next
      id = c[2]
      gsub(/[ \t`]/, "", id)
      if (id != want) next
      status = tolower(c[3])
      # A placeholder status is documentation, not a registration.
      if (status ~ /unclaimed|\*free\*|\(none\)|available|^-[[:space:]]*$/) next
      found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$REG" 2>/dev/null
}
pick_id() {
  local n
  for n in $(seq 1 200); do
    local id="AI-$n"
    if [ -e "$WIKI/registry/$id.md" ] || [ -e "$JOURNALS/$id" ] || id_in_roster "$id"; then
      continue
    fi
    printf '%s\n' "$id"; return 0
  done
  die "no free id below AI-200. Extend the range in this script."
}

if [ -n "$WANT_ID" ]; then
  case "$WANT_ID" in
    AI-[0-9]*) : ;;
    *) die "--id must look like AI-7, got: $WANT_ID" ;;
  esac
  ID="$WANT_ID"
else
  ID=$(pick_id)
fi

if [ -e "$WIKI/registry/$ID.md" ] || [ -e "$JOURNALS/$ID" ] || id_in_roster "$ID"; then
  die "$ID is ALREADY REGISTERED (roster row, registry page, or journal folder exists).
Ids are permanent. Never reuse one, even if that AI is finished - pick a new one."
fi

# ---------- questions ----------
say "About to register $ID on $(hostname 2>/dev/null || echo unknown)."
say "Nothing outside ~/homelab/wiki will be touched. The Minecraft server is not involved."
say
ask NAME      "What should we call you (agent/model name)"  "AI"
ask WORKS     "One line: what are you working on"            "not stated"
ask OWNS      "Paths you own, comma separated"               "$WIKI/journals/$ID/"
ask MACHINE   "Which machine is your repo/home on"           "unknown"
ask HOSTNAME_AI "Who do you answer to (the human)"          "the user"

TS_LOCAL=$(date '+%Y-%m-%d %H:%M %z')
TS_UTC=$(date -u '+%Y-%m-%d %H:%M UTC')

# ---------- take the lock on the wiki ----------
say
if ! AI_ID="register-ai($ID)" "$LOCK" take "$WIKI" "registering $ID"; then
  die "could not take the wiki lock - another AI is editing the wiki. Wait, then retry."
fi
# From here on we hold the lock; make sure we always give it back.
cleanup() { AI_ID="register-ai($ID)" "$LOCK" drop "$WIKI" "registered $ID" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

# Re-check under the lock: another AI may have registered while we were asking questions.
if [ -e "$WIKI/registry/$ID.md" ] || [ -e "$JOURNALS/$ID" ] || id_in_roster "$ID"; then
  die "$ID was registered by someone else while you were answering. Nothing written. Pick a new id."
fi

mkdir -p "$JOURNALS/$ID" || die "could not create $JOURNALS/$ID"

# ---------- your journal ----------
cat > "$JOURNALS/$ID/JOURNAL.md" <<EOF
<!--
JOURNAL FOR $ID - yours alone. No other AI writes here.

RULES
  * Append a timestamped entry for every change you make. Local time is UTC+0630;
    also state UTC. The Minecraft log is UTC and mixing them up causes real
    confusion.
  * NEVER append with a heredoc over ssh - these files are full of backticks,
    \$(...), \$VAR and !, and a heredoc mangles them or appends nothing while
    appearing to succeed. Write the entry locally, scp it, cat it on, then
    VERIFY the line count grew.
  * Always say what you could NOT verify. A journal of only successes teaches
    the next reader something false.
  * Server-state changes also go to ../SHARED-STATE-LOG.md.
  * Lock the folder before you write: wiki/bin/ailock.sh take <dir>
-->

# $ID - Journal

**Agent:** $NAME
**Works on:** $WORKS
**Owns:** $OWNS
**Home machine / repo:** $MACHINE
**Answers to:** $HOSTNAME_AI
**Registered:** $TS_LOCAL ($TS_UTC)
**Registry page:** ../../registry/$ID.md

---

## $TS_LOCAL ($TS_UTC) - registered
AI: $ID

### Changed
- Created this journal: wiki/journals/$ID/JOURNAL.md
- Created registry page: wiki/registry/$ID.md
- Added a row to registry/README.md
- Nothing else. No Minecraft server, Crafty, or owner file was touched.

### Verified
- (fill this in on your first real task)

### Could NOT verify
- (say so explicitly - this line is not optional)

### Revert
- Remove wiki/journals/$ID/ and wiki/registry/$ID.md and this row. Do NOT reuse
  the id: numbers are permanent.
EOF

# ---------- your registry page ----------
cat > "$WIKI/registry/$ID.md" <<EOF
# $ID

**Status:** Active
**Registered:** $TS_LOCAL ($TS_UTC)
**Last seen:** $TS_LOCAL ($TS_UTC)
**Agent:** $NAME
**Answers to:** $HOSTNAME_AI

## What I work on
$WORKS

## What I own
$OWNS

## What I need from the human
_(keep this short and current - it is the first thing a human reads when you
are stuck)_

## What I must never do
_(anything you were told not to, in your own words, so the next reader of this
file does not have to go find it in a transcript)_

## Where I am working from
$MACHINE

## In flight right now
_(the most important field on this page. If you stop, this is what the next
person reads. Empty means you are idle.)_

- just registered; nothing started yet

## Done / handed off
_(what you finished, what you left behind, where the evidence is)_
EOF

# ---------- roster row ----------
# Appended inside the existing table. If the table is not where we expect, say so
# loudly rather than silently creating a second table.
roster_ok=1
if grep -q '^| *ID' "$REG"; then
  # Refuse to append a second row for an id that is already in the table. A
  # duplicate id is worse than a missing registration: it looks authoritative
  # while being wrong, and two AIs then share a number.
  dup=$(grep -cE "(^|[^A-Za-z0-9_-])${ID}([^A-Za-z0-9_-]|$)" "$REG")
  if [ "${dup:-0}" -ge 1 ]; then
    die "$ID already appears in the roster ($dup row(s)). Refusing to add a second.
Nothing was written. Check registry/README.md by hand and pick a new id."
  fi
  printf '| `%s` | **%s** | %s | `%s` | %s |\n' \
    "$ID" "$NAME" "$WORKS" "journals/$ID/JOURNAL.md" "$TS_LOCAL" >> "$REG"
  say "roster row appended to registry/README.md"
else
  say "WARNING: could not find the roster table in registry/README.md."
  say "         Add your row by hand, or you will be invisible to the next AI."
  roster_ok=0
fi

# ---------- verify everything landed ----------
rc=0
[ "$roster_ok" -eq 1 ] || rc=1
for f in "$JOURNALS/$ID/JOURNAL.md" "$WIKI/registry/$ID.md"; do
  if [ -s "$f" ]; then
    say "ok   ${f/#$HOME\//} ($(wc -l < "$f") lines)"
  else
    say "FAIL ${f/#$HOME\//} missing or empty"
    rc=1
  fi
done
if grep -q "\`$ID\`" "$REG"; then
  say "ok   row for $ID is in the roster"
else
  say "FAIL row for $ID is NOT in the roster"
  rc=1
fi

cleanup
trap - EXIT INT TERM

say ""
if [ "$rc" -eq 0 ]; then
  say "=== REGISTERED: $ID ==="
  say ""
  say "Next, in order:"
  say "  1. Read wiki/00-README.md, then wiki/04-AI-RULES.md."
  say "  2. Read wiki/05-ENVIRONMENT-TRAPS.md BEFORE your first command."
  say "     Every trap in it fails quietly."
  say "  3. Check wiki/01-FILE-STRUCTURE.md for where things live."
  say "  4. Fill in registry/$ID.md properly - especially 'What I must never do'."
  say "  5. Before you write anything: wiki/bin/ailock.sh take <folder>"
  say "  6. Journal what you do in journals/$ID/JOURNAL.md, and state changes in"
  say "     journals/SHARED-STATE-LOG.md."
  say "  7. When you stop, set your status to Idle or Done and say what you left"
  say "     in flight. A row that says Active with nobody working is the most"
  say "     expensive thing you can leave behind on a shared box."
else
  say "=== REGISTRATION INCOMPLETE - fix the FAILs above ==="
fi
exit $rc
