#!/usr/bin/env bash
# final-verify.sh - close out the wiki rebuild.
#
# 1. Append the dedup note, guarded by a sentinel (trap 20e - the fix, applied).
# 2. Install the updated traps page.
# 3. Verify the ENTIRE wiki end to end, not just today's changes.
#
# FILESYSTEM ONLY. No Crafty, no Minecraft, no RCON.
set -uo pipefail

H="$HOME/homelab"
W="$H/wiki"
J="$W/journals/AI-1/JOURNAL.md"
S="$W/journals/SHARED-STATE-LOG.md"
rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }
hdr() { printf '\n=== %s ===\n' "$*"; }

hdr "lock"
if AI_ID=AI-1 "$W/bin/ailock.sh" take "$H" "closing out the wiki rebuild"; then
  ok "ai.lock held"
else
  bad "could not lock $H - stopping."; exit 3
fi
release() { AI_ID=AI-1 "$W/bin/ailock.sh" drop "$H" "done rc=$rc" >/dev/null 2>&1 || true; printf '\n  (ai.lock released)\n'; }
trap release EXIT INT TERM

hdr "append the dedup note - SENTINEL GUARDED, the fix for trap 20e"
SENT='<!-- entry:AI-1:2026-09-26-dedup-nonidempotent -->'
if grep -qF "$SENT" "$J"; then
  ok "already present - not appending twice (this is the guard working)"
else
  BEFORE=$(wc -l < "$J")
  { printf '\n%s\n' "$SENT"; cat /tmp/entry-dedup.md; } >> "$J"
  AFTER=$(wc -l < "$J")
  if [ "$AFTER" -le "$BEFORE" ]; then bad "the note did not land"; else ok "$BEFORE -> $AFTER lines (+$((AFTER-BEFORE)))"; fi
  if grep -qF "$SENT" "$J"; then ok "sentinel is in the file, so a re-run will skip"; else bad "sentinel missing - the guard will not work"; fi
fi

hdr "install the updated traps page"
cp /tmp/wiki/05-ENVIRONMENT-TRAPS.md "$W/05-ENVIRONMENT-TRAPS.md" && ok "05-ENVIRONMENT-TRAPS.md updated"
TRAPS=$(grep -cE '^## [0-9]+\. ' "$W/05-ENVIRONMENT-TRAPS.md")
ok "numbered traps: $TRAPS"
if [ "$TRAPS" -eq 21 ]; then ok "21 traps"; else bad "expected 21 traps, found $TRAPS"; fi
if grep -qF '20(e)' "$W/05-ENVIRONMENT-TRAPS.md" || grep -qF '(e) A script that appends' "$W/05-ENVIRONMENT-TRAPS.md"; then
  ok "trap 20(e) is present"
else
  bad "trap 20(e) did not make it onto the page"
fi
if grep -qF "| $TRAPS traps" "$W/00-README.md"; then ok "index agrees: $TRAPS traps"; else bad "index disagrees with page 05"; fi

hdr "A. the tree is complete"
N=$(ls -1 "$W"/[0-9][0-9]-*.md 2>/dev/null | wc -l)
if [ "$N" -eq 18 ]; then ok "18 numbered pages"; else bad "$N numbered pages, expected 18"; fi
for d in registry journals journals/AI-1 bin archive; do
  if [ -d "$W/$d" ]; then ok "wiki/$d/ exists"; else bad "wiki/$d/ missing"; fi
done
for f in registry/README.md registry/AI-1.md journals/README.md journals/SHARED-STATE-LOG.md journals/AI-1/JOURNAL.md; do
  if [ -s "$W/$f" ]; then ok "wiki/$f non-empty ($(wc -l < "$W/$f") lines)"; else bad "wiki/$f missing or empty"; fi
done

hdr "B. every page is referenced from the index (no orphans)"
ORPH=0
for f in "$W"/[0-9][0-9]-*.md; do
  b=$(basename "$f")
  [ "$b" = "00-README.md" ] && continue
  if ! grep -qF "$b" "$W/00-README.md"; then bad "orphan: $b is not linked from 00-README"; ORPH=$((ORPH+1)); fi
done
[ "$ORPH" -eq 0 ] && ok "no orphans (00-README is the index, so it does not link to itself)"

hdr "C. no live page links into server-info/, and the journals still DO"
# Ported from closeout.sh. The first version of this check flagged the two
# journals, which was wrong: journals are append-only records of what was true
# when written, and a check that demands history be rewritten to match the
# present destroys the evidence it exists to protect. Only the live reference
# pages must be clean - and for the journals the assertion is the OPPOSITE.
LIVE=0
for f in "$W"/[0-9][0-9]-*.md "$W"/registry/*.md; do
  if grep -q 'homelab/server-info/' "$f" 2>/dev/null; then
    bad "live page still links into server-info/: $(basename "$f")"
    grep -n 'homelab/server-info/' "$f" | sed 's/^/      /' | cut -c1-140
    LIVE=$((LIVE+1))
  fi
done
if [ "$LIVE" -eq 0 ]; then ok "no live page links into server-info/"
else bad "$LIVE live page(s) still link into server-info/"; fi
J_MENTIONS=$(grep -c 'homelab/server-info/' "$J" 2>/dev/null || true)
S_MENTIONS=$(grep -c 'homelab/server-info/' "$W/journals/SHARED-STATE-LOG.md" 2>/dev/null || true)
ok "journals still mention the old paths on purpose: AI-1 $J_MENTIONS, shared $S_MENTIONS"
if [ "${J_MENTIONS:-0}" -gt 0 ]; then ok "history preserved, not scrubbed"
else bad "the AI-1 journal no longer mentions the old paths - was history rewritten?"; fi

hdr "D. history was preserved, not truncated"
for pair in "journals/AI-1/JOURNAL.md:1200" "journals/SHARED-STATE-LOG.md:560"; do
  f="${pair%%:*}"; min="${pair##*:}"
  n=$(wc -l < "$W/$f")
  if [ "$n" -ge "$min" ]; then ok "$f has $n lines (>= $min)"
  else bad "$f has only $n lines - history was truncated"; fi
done
ARC=$(find "$W/archive" -type f | wc -l)
if [ "$ARC" -ge 20 ]; then ok "archive holds $ARC files (the old wiki + journal backups)"
else bad "archive holds only $ARC files - something was not preserved"; fi

hdr "E. the pointer stubs resolve"
for s in "$H/AI-JOURNAL.md" "$H/AI-1-JOURNAL.md" "$H/server-info/00-README.md"; do
  if [ -f "$s" ]; then ok "$(basename "$s") stub exists"
  else bad "$s is missing - the other AI's old references would break"; fi
done
if [ -d "$H/server-info" ]; then ok "server-info/ still exists as a directory (stub, not deleted)"; else bad "server-info/ was deleted"; fi

hdr "F. the tools work"
for t in ailock.sh register-ai.sh; do
  if [ -x "$W/bin/$t" ]; then ok "bin/$t is executable"; else bad "bin/$t is NOT executable"; fi
  if bash -n "$W/bin/$t" 2>/dev/null; then ok "bin/$t parses"; else bad "bin/$t has a syntax error"; fi
done
if "$W/bin/ailock.sh" show >/dev/null 2>&1; then ok "ailock.sh show runs"; else bad "ailock.sh show failed"; fi
if "$W/bin/register-ai.sh" --list >/dev/null 2>&1; then ok "register-ai.sh --list runs"; else bad "register-ai.sh --list failed"; fi

hdr "G. the roster is sane and AI-2 is still free"
if grep -qE '^\| *`AI-1`' "$W/registry/README.md"; then ok "AI-1 has a roster row"; else bad "AI-1 has no roster row"; fi
if grep -qE '^\| *`AI-2`' "$W/registry/README.md"; then ok "AI-2 is listed as unclaimed"; else bad "AI-2 row missing"; fi
DUP=$(grep -cE '^\| *`AI-1`' "$W/registry/README.md")
if [ "$DUP" -eq 1 ]; then ok "exactly one AI-1 row (no duplicate)"; else bad "$DUP AI-1 rows"; fi
if [ -d "$W/journals/AI-2" ]; then bad "journals/AI-2/ exists - AI-2 is not free"; else ok "no journals/AI-2/ - the id is still free"; fi

hdr "H. no secrets in the wiki"
CHK=$(python3 /tmp/leakcheck.py 2>&1); CRC=$?
if [ "$CRC" -ne 0 ]; then bad "leakcheck could not run"; printf '%s\n' "$CHK" | sed 's/^/    /'
else
  T=$(printf '%s' "$CHK" | grep -oE 'TOTAL [0-9]+' | grep -oE '[0-9]+$')
  if [ "$T" = "0" ]; then ok "no sudo password in assignment context"; else bad "$T hit(s)"; printf '%s\n' "$CHK" | sed 's/^/    /'; fi
fi
# The other two live secrets, by the never-print-the-value method.
SP="$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/server.properties"
if [ -f "$SP" ]; then
  ok "server.properties found"
  for k in rcon.password management-server-secret; do
    if ! grep -qE "^$k=" "$SP"; then bad "key $k absent - cannot vouch"; continue; fi
    v=$(grep -m1 "^$k=" "$SP" | cut -d= -f2-)
    if [ -z "$v" ]; then ok "$k present but empty"; continue; fi
    if grep -rqF -- "$v" "$W" 2>/dev/null; then bad "$k VALUE is in the wiki"; else ok "$k (${#v} chars) not in the wiki"; fi
  done
  HOOK=$(cat "$H/.discord_webhook" 2>/dev/null)
  if [ -n "$HOOK" ] && grep -rqF -- "$HOOK" "$W" 2>/dev/null; then bad "discord webhook VALUE is in the wiki"
  elif [ -n "$HOOK" ]; then ok "discord webhook (${#HOOK} chars) not in the wiki"
  else bad "cannot read the webhook - not a pass"; fi
else
  bad "server.properties not found at $SP - cannot vouch for anything"
fi

hdr "I. the redaction did no collateral damage"
JD=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$J" | wc -l)
AD=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$W/archive/AI-1-JOURNAL.md.bak-journal-221435" | wc -l)
if [ "$JD" -ge "$AD" ]; then ok "journal dates ($JD) >= backup dates ($AD)"; else bad "dates lost"; fi
if [ "$(grep -F '[REDACTED]' "$J" | grep -cE '[0-9]{4}-[0-9]{2}-[0-9]{2}')" -eq 0 ]; then ok "no redaction landed on a date"; else bad "a redaction hit a date line"; fi
# "exactly one" is not an idempotent assertion. The journal now QUOTES the redacted
# line in a later entry explaining the redaction, so the count legitimately grew -
# and an exact-count check then fails on a perfectly correct file. Trap 20(e).
# The authoritative assertion is the assignment-context leak check (TOTAL 0), which
# is run in group H. Here we only assert that the redaction is present at all.
REDN=$(grep -cF 'sudo/ssh pw = [REDACTED]' "$J" || true)
ok "lines matching the redacted password in the journal: ${REDN:-0} (>= 1 expected; the exact count grows as entries quote it)"
if [ "${REDN:-0}" -ge 1 ]; then ok "the redaction is present"
else bad "no redacted password line found in the journal"; fi
for a in AI-1-JOURNAL.md.bak-journal-145959 AI-1-JOURNAL.md.bak-journal-154017 AI-1-JOURNAL.md.bak-journal-221435; do
  n=$(grep -cF 'sudo/ssh pw = [REDACTED]' "$W/archive/$a" 2>/dev/null || echo 0)
  if [ "${n:-0}" -ge 1 ]; then ok "archive/$a is redacted"
  else bad "archive/$a still holds the password in the clear"; fi
done
# And the whole point, restated as a direct check rather than an inferred one.
LK=$(python3 /tmp/leakcheck.py 2>&1 | grep -oE 'TOTAL [0-9]+' | grep -oE '[0-9]+$')
if [ "$LK" = "0" ]; then ok "assignment-context leak check: 0 sites anywhere under the wiki"
else bad "leak check reports $LK site(s)"; fi

hdr "J. no leftover locks"
release
if [ -f "$H/ai.lock" ]; then bad "ai.lock still in $H"; else ok "no lock in $H"; fi
L=$(find "$H" -name ai.lock 2>/dev/null | wc -l)
if [ "$L" -eq 0 ]; then ok "no ai.lock anywhere under $H"; else bad "$L ai.lock(s) left behind"; fi

printf '\n'
if [ "$rc" -eq 0 ]; then echo "=== ALL OK ==="; else echo "=== STILL FAILING ==="; fi
exit $rc
