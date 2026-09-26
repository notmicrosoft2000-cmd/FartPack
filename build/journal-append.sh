#!/usr/bin/env bash
# Append journal entries by COPYING FILES, never by heredoc, and never by
# passing text through a shell.
#
# The first attempt at this used `cat >> file <<EOF` with escaped backticks and it
# appended nothing at all, silently, under `set -e`. Markdown is full of backticks,
# `$(...)`, `$VAR` and `!`, so the only reliable way to move prose into a file on
# this box is: write it locally, scp it, `cat >>`. No shell ever sees the text.
#
# The headers are read OUT OF THE ENTRY FILES, not passed as arguments. An earlier
# version took them as argv, and over ssh the remote fish shell truncated
# "2026-09-26 22:8x +0630" to "2026-09-26 22" -- because fish uses `:` as a command
# separator. The duplicate-entry gate then matched that prefix against six real
# dates in the journal and refused a legitimate append. Passing prose as an
# argument is asking the shell to respect prose, and it will not.
#
# LAYOUT (changed 2026-09-26). The journals moved when the server wiki was rebuilt:
#   ~/homelab/wiki/journals/AI-N/JOURNAL.md      per-AI narrative  (was ~/homelab/AI-N-JOURNAL.md)
#   ~/homelab/wiki/journals/SHARED-STATE-LOG.md  state deltas       (was ~/homelab/server-info/JOURNAL.md)
# ~/homelab/AI-JOURNAL.md and ~/homelab/AI-1-JOURNAL.md are POINTER STUBS. Writing to
# them would silently do nothing useful, so this script refuses.
#
# FOUR GATES, each added because it caught something real:
#   1. ai.lock     - two AIs appending to one journal interleave badly, and an
#                    append is multi-step (backup, write, verify). Take the lock
#                    on the journals folder; release it on every exit path.
#   2. check-entry - REFUSES to append text containing a live credential. This
#                    exact script is how the sudo password got into the journal;
#                    four sites across three files had to be scrubbed afterwards.
#   3. sentinel    - refuses to append an entry whose heading is already present.
#                    Re-running after a fix used to duplicate the entry, and a
#                    journal cannot tell a re-run from a second real event.
#   4. growth      - asserts the files actually GREW, not that a command exited 0.
set -euo pipefail

H="$HOME/homelab"
W="$H/wiki"
SHARED="wiki/journals/SHARED-STATE-LOG.md"
AILOCK="$W/bin/ailock.sh"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_ENTRY="$SELF_DIR/check-entry.py"
SRC_AI="/tmp/append-ai.md"
SRC_SV="/tmp/append-server.md"
LOCKDIR="$W/journals"
LOCK_HELD=0

usage() {
  cat >&2 <<'USAGE'
usage: journal-append.sh [journal] [--verify]

  journal  your journal, relative to ~/homelab
           (default wiki/journals/AI-1/JOURNAL.md)
  --verify run only the checks, append nothing

The entry TEXT is not an argument and is not typed. Write it locally, scp it to
/tmp/append-ai.md and /tmp/append-server.md, and this copies them in. The entry
heading is read from the first `## ` line of each file.
USAGE
  exit 2
}

JOURNAL="wiki/journals/AI-1/JOURNAL.md"
for a in "$@"; do
  case "$a" in
    --verify) VERIFY_ONLY=1 ;;
    --help|-h) usage ;;
    -*) echo "FATAL: unknown option $a" >&2; usage ;;
    *) JOURNAL="$a" ;;
  esac
done
[ "${VERIFY_ONLY:-0}" = "1" ] || VERIFY_ONLY=0

# The old basename calling convention. Getting it silently wrong is worse than a
# bit of argument juggling, so translate it and say so.
case "$JOURNAL" in
  AI-1-JOURNAL.md)
    echo "note: $JOURNAL is the old path; using wiki/journals/AI-1/JOURNAL.md"
    JOURNAL="wiki/journals/AI-1/JOURNAL.md"
    ;;
  AI-JOURNAL.md)
    echo "FATAL: AI-JOURNAL.md is a pointer stub, not a journal."
    echo "       Use your own: wiki/journals/AI-N/JOURNAL.md. See wiki/03-AI-REGISTRATION.md."
    exit 1
    ;;
esac
case "$JOURNAL" in
  *server-info*|*.bak*|*/archive/*|*/journals/SHARED-STATE-LOG.md)
    echo "FATAL: refusing to use $JOURNAL - that is the shared log, history, or a stub."
    exit 1
    ;;
esac

JFILE="$H/$JOURNAL"
SFILE="$H/$SHARED"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; RC=1; }
hdr()  { printf '\n=== %s ===\n' "$*"; }
RC=0

release() {
  if [ "$LOCK_HELD" = "1" ]; then
    AI_ID="${AI_ID:-AI-1}" "$AILOCK" drop "$LOCKDIR" "journal-append done" >/dev/null 2>&1 || true
    printf '\n  (ai.lock released on %s)\n' "$LOCKDIR"
  fi
}
trap release EXIT INT TERM

# The heading of an entry, taken from the file itself. This is why the header is
# not an argument: a header and its entry can no longer drift apart, and no shell
# gets a chance to truncate the text.
heading_of() { grep -m1 '^## ' "$1" || true; }

# The two (heading, file) pairs, as parallel arrays.
#
# NOT a colon-joined "pair" string. An earlier version did
# `for pair in "$HEADER_AI:$JFILE"; h="${pair%%:*}"` and every heading in these
# journals contains colons - "## 2026-09-26 22:8x +0630" - so `%%:*` stripped at
# the first colon and the sentinel became "## 2026-09-26 22", which then matched
# six real dates and refused a legitimate append. Two failures in a row from the
# same root cause: treating a delimiter as unambiguous when the payload is prose.
# Prose contains every character you might pick. Use two variables.
HEADINGS=()
FILES=()

# ---------------------------------------------------------------- preconditions
hdr "preconditions"
[ -d "$W" ] || { echo "FATAL: no wiki at $W - has the layout changed again?"; exit 1; }
[ -f "$JFILE" ] || { echo "FATAL: your journal $JFILE does not exist."; echo "       Register first: $W/bin/register-ai.sh"; exit 1; }
[ -f "$SFILE" ] || { echo "FATAL: shared log $SFILE does not exist."; exit 1; }
say "your journal:   $JOURNAL"
say "shared log:     $SHARED"
for t in "$AILOCK" "$CHECK_ENTRY"; do
  [ -f "$t" ] || { echo "FATAL: $t is missing"; exit 1; }
done
[ -x "$AILOCK" ] || { echo "FATAL: $AILOCK is not executable - a non-executable tool is a broken tool"; exit 1; }
ok "tools present and executable"

# ------------------------------------------------------------------ entry text
# In verify mode we still want the heading and credential checks, so read the
# entry files if they are there. The only difference is that nothing is written.
if [ ! -s "$SRC_AI" ] || [ ! -s "$SRC_SV" ]; then
  if [ "$VERIFY_ONLY" = "1" ]; then
    say "verify-only, and no entry files in /tmp - checking the journals as they stand"
    HEADER_AI=""
    HEADER_SV=""
    SKIP_HEADING_CHECK=1
  else
    echo "FATAL: $SRC_AI and $SRC_SV must both exist. Write the text locally and scp it." >&2
    echo "       Never pass journal prose as a shell argument - see this script's header." >&2
    exit 1
  fi
else
  HEADER_AI="$(heading_of "$SRC_AI")"
  HEADER_SV="$(heading_of "$SRC_SV")"
  [ -n "$HEADER_AI" ] || { echo "FATAL: $SRC_AI has no '## ' heading - the entry needs one so the journal stays navigable"; exit 1; }
  [ -n "$HEADER_SV" ] || { echo "FATAL: $SRC_SV has no '## ' heading"; exit 1; }
  SKIP_HEADING_CHECK=0
  say "entry headings read from the files:"
  say "  AI:     ${HEADER_AI:0:70}"
  say "  shared: ${HEADER_SV:0:70}"
  # Populated here, not inside the append branch, so --verify can check them too.
  # An earlier version built these only when appending, so verify mode printed
  # "the headings are present exactly once" and then checked nothing at all - a
  # check that announces itself and inspects an empty list.
  HEADINGS=("$HEADER_AI" "$HEADER_SV")
  FILES=("$JFILE" "$SFILE")
  SRCS=("$SRC_AI" "$SRC_SV")
fi

if [ "$VERIFY_ONLY" = "0" ]; then
  hdr "gate 2: will this entry leak a credential?"
  # The gate that matters most. The sudo password reached the journal through this
  # very script, and cleaning it out afterwards cost four sites across three files,
  # because the redaction tool and its own checker disagreed about which files
  # existed. Refusing at append time is a one-line fix instead.
  python3 "$CHECK_ENTRY" "$SRC_AI" "$SRC_SV" || {
    echo
    echo "FATAL: refusing to append. Nothing was written."
    exit 1
  }

  hdr "gate 3: is this entry already in the journals?"
  DUP=0
  i=0
  while [ "$i" -lt "${#HEADINGS[@]}" ]; do
    h="${HEADINGS[$i]}"; f="${FILES[$i]}"
    n=$(grep -cF "$h" "$f" || true)
    if [ "${n:-0}" -gt 0 ]; then
      bad "heading already present in $(basename "$f") ($n occurrence(s))"
      say "        $h"
      DUP=$((DUP+1))
    fi
    i=$((i+1))
  done
  if [ "$DUP" -gt 0 ]; then
    echo
    echo "FATAL: this entry is already in the journal. Nothing was written."
    echo "       If you really meant a second, distinct event, change the heading."
    exit 1
  fi
  ok "neither heading is present yet"

  hdr "gate 1: take the lock on $LOCKDIR"
  if AI_ID="${AI_ID:-AI-1}" "$AILOCK" take "$LOCKDIR" "appending a journal entry"; then
    LOCK_HELD=1
    ok "ai.lock held"
  else
    echo "FATAL: another AI holds $LOCKDIR. Wait for it to be released. Nothing was written."
    exit 3
  fi
fi

# --------------------------------------------------------------------- append
BEFORES=()
if [ "$VERIFY_ONLY" = "0" ]; then
  BEFORES=("$(wc -l < "$JFILE")" "$(wc -l < "$SFILE")")
  say "before: your journal ${BEFORES[0]} lines, shared log ${BEFORES[1]} lines"
  # Same reason as the headings: no delimiter-joined pairs. Iterate the arrays.
  i=0
  while [ "$i" -lt "${#FILES[@]}" ]; do
    src="${SRCS[$i]}"; dst="${FILES[$i]}"
    cp "$dst" "$dst.bak-journal-$(date +%H%M%S)-$$"
    cat "$src" >> "$dst"
    say "appended $(wc -l < "$src") lines to ${dst#"$H/"}"
    i=$((i+1))
  done
fi

# --------------------------------------------------------------------- verify
hdr "gate 4: did the files actually grow?"
now_ai=$(wc -l < "$JFILE")
now_sv=$(wc -l < "$SFILE")
say "your journal:   $now_ai lines"
say "shared log:     $now_sv lines"
if [ "$VERIFY_ONLY" = "0" ]; then
  if [ "$now_ai" -le "${BEFORES[0]}" ]; then bad "your journal did not grow (${BEFORES[0]} -> $now_ai)"; else ok "your journal grew by $((now_ai - BEFORES[0])) lines"; fi
  if [ "$now_sv" -le "${BEFORES[1]}" ]; then bad "the shared log did not grow (${BEFORES[1]} -> $now_sv)"; else ok "shared log grew by $((now_sv - BEFORES[1])) lines"; fi
fi

hdr "the headings are present exactly once, and markdown survived"
if [ "${SKIP_HEADING_CHECK:-0}" = "1" ]; then
  say "no entry file to check a heading against - skipped, and that is NOT a pass"
  say "the journal is expected to already contain its previous entries"
  # Prove the journals still hold their most recent heading, so this is not vacuous.
  for f in "$JFILE" "$SFILE"; do
    LAST=$(grep -m1 '^## ' "$f" || true)
    if [ -n "$LAST" ]; then ok "$(basename "$f") last heading: ${LAST:0:60}"; else bad "$(basename "$f") has no heading at all"; fi
  done
  HEADINGS=(); FILES=()
fi
i=0
while [ "$i" -lt "${#HEADINGS[@]}" ]; do
  h="${HEADINGS[$i]}"; f="${FILES[$i]}"
  n=$(grep -cF "$h" "$f" || true)
  esc=$(grep -c '\\`' "$f" || true)
  say "$(basename "$f"): $n occurrence(s) of its heading, ${esc:-0} stray escaped backticks, $(wc -l < "$f") lines"
  [ "${n:-0}" -eq 1 ] || bad "heading count is $n, expected exactly 1"
  [ "${esc:-0}" -eq 0 ] || bad "escaped backticks survived - the markdown is broken"
  i=$((i+1))
done

# Re-check the JOURNALS, not just the source files. That is the assertion a copy
# that did not do what it said cannot survive.
# Re-check what actually landed, using the SAME gate, applied to ONLY the region
# this run appended.
#
# An earlier version re-scanned the whole journal and reported three pre-existing
# false positives - the label "pw" matching the tail of "pwr:do_power", "pwr:load"
# and "pwrcheck=1..". A whole-file scan means any historical near-miss permanently
# blocks every future append, and a gate that blocks everything gets disabled
# rather than fixed. Scope the check to what you wrote; keep the whole-file scan
# as a separate, deliberate audit.
hdr "re-check what is now actually in the journals (the region this run added)"
if [ "$VERIFY_ONLY" = "0" ]; then
  TAILD=$(mktemp -d)
  i=0
  while [ "$i" -lt "${#FILES[@]}" ]; do
    tail -n "+$(( ${BEFORES[$i]} + 1 ))" "${FILES[$i]}" > "$TAILD/region-$i.md"
    i=$((i+1))
  done
  if python3 "$CHECK_ENTRY" "$TAILD"/region-*.md; then
    ok "the appended text is clean"
  else
    bad "the appended text contains a credential - investigate immediately"
  fi
  # Prove the extraction was not empty. A gate pointed at a zero-line file passes
  # trivially - trap 20(a) in a new costume.
  for r in "$TAILD"/region-*.md; do
    n=$(wc -l < "$r")
    if [ "$n" -gt 0 ]; then ok "$(basename "$r") is $n lines - the check had something to read"
    else bad "$(basename "$r") is empty - the check proved nothing"; fi
  done
  rm -rf "$TAILD"
else
  say "verify-only: nothing was written, so there is no new region to re-check"
fi

hdr "no leftover locks"
release
LOCK_HELD=0
if find "$H" -name ai.lock 2>/dev/null | grep -q .; then
  bad "an ai.lock was left behind"
  find "$H" -name ai.lock | sed 's/^/    /'
else
  ok "no ai.lock anywhere under $H"
fi

printf '\n'
if [ "$RC" -eq 0 ]; then echo "OK - journals verified"; else echo "FAIL - see above"; fi
exit $RC
