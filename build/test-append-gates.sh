#!/usr/bin/env bash
# test-append-gates.sh - prove journal-append.sh refuses the things it must,
# AGAINST A SCRATCH TREE.
#
#   TEST 2  re-appending an entry already in the journal  -> must REFUSE
#   TEST 3  appending an entry containing a live credential -> must REFUSE
#   TEST 4  an entry heading dated in the FUTURE            -> must REFUSE
#   TEST 5  a correctly dated heading, and "(time not recorded)" -> must ACCEPT
#
# Every refusal must leave the journal byte-identical. A refusal that still writes
# is worse than no refusal, so md5sums are compared, not just line counts.
#
# WHY THIS FILE WAS REWRITTEN
#   The previous version of this suite pointed at the real journals:
#       J="$W/journals/AI-1/JOURNAL.md"
#       S="$W/journals/SHARED-STATE-LOG.md"
#   and built its duplicate-sentinel fixture out of whatever was sitting in
#   /tmp/append-ai.md - a leftover from a manual append hours earlier.
#
#   So it appended a real entry into the real journal, noticed its own side
#   effect, and reported FAIL:
#       FAIL  the journals CHANGED despite the refusal: 1937->2000, 1195->1227
#   The next run found the entry already present, the sentinel refused correctly,
#   and the suite went green - with a 63-line duplicate sitting in the journal,
#   which then had to be excised by hand.
#
#   Two lessons, both now structural rather than advisory:
#     1. A test that writes to production will eventually be run by someone who
#        is not reading, and the response to "the test changed the journal" will
#        be to re-run it until it passes. So: scratch tree, always.
#     2. A test whose input is "whatever the last run left behind" is not
#        reproducible. So: the fixture is built here, named, and stated.
#
# WHAT IS STILL REAL
#   journal-append.sh, check-entry.py and ailock.sh are the live files. Only where
#   they read and write changes. check-entry.py in particular MUST stay real,
#   because reading the live credentials is the entire point of gate 2 - and it
#   prints CANNOT VOUCH when run against synthetic input, which is exactly the
#   honest answer and exactly what we want to see.
# Do not leave a compiled copy of check-entry.py in wiki/bin/. This suite
# imports it as a module, and CPython writes a __pycache__ beside anything it
# imports. That directory is not swept on a schedule - the side effect is
# what should stop, so the side effect is what is stopped here.
export PYTHONDONTWRITEBYTECODE=1
set -uo pipefail
H="$HOME/homelab"
W="$H/wiki"
REAL_J="$W/journals/AI-1/JOURNAL.md"
REAL_S="$W/journals/SHARED-STATE-LOG.md"
JA="$W/bin/journal-append.sh"
CK="$W/bin/check-entry.py"
LOCK="$W/bin/ailock.sh"
rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }
note(){ printf '  ..    %s\n' "$*"; }
say() { printf '  %s\n' "$*"; }
hdr() { printf '\n=== %s ===\n' "$*"; }

hdr "0. the tools must EXIST, or every test below is theatre"
for t in "$JA" "$CK" "$LOCK"; do
  if [ -f "$t" ]; then ok "present: ${t#"$H/"}"
  else bad "MISSING: ${t#"$H/"} - refusing to run"; exit 3; fi
done
if bash -n "$JA" 2>/dev/null; then ok "journal-append.sh parses"; else bad "journal-append.sh has a syntax error"; exit 3; fi
if python3 -c "import ast;ast.parse(open('$CK').read())" 2>/dev/null; then ok "check-entry.py is valid python"; else bad "check-entry.py is not valid python"; exit 3; fi
# 127 is "command not found" and looks exactly like a successful refusal. Every
# test below checks for it explicitly. This is why the existence check is first.
note_127() { [ "$1" -eq 127 ] && bad "exit 127 - the tool did not run at all, this is not a refusal"; }

# ---------------------------------------------------------------- the scratch tree
T=$(mktemp -d)
SCRATCH="$T/homelab"
SJ="$SCRATCH/wiki/journals/AI-1/JOURNAL.md"
SS="$SCRATCH/wiki/journals/SHARED-STATE-LOG.md"
F_AI="$T/fixture-ai.md"
F_SV="$T/fixture-server.md"
mkdir -p "$(dirname "$SJ")" "$(dirname "$SS")"

cleanup() {
  if [ -e "$SCRATCH/wiki/journals/ai.lock" ]; then
    AI_ID=AI-1 WIKI="$SCRATCH/wiki" "$LOCK" drop "$SCRATCH/wiki/journals" "test cleanup" >/dev/null 2>&1 || true
  fi
  rm -rf "$T"
}
trap cleanup EXIT INT TERM

hdr "1. the scratch tree, and the guard that makes production unreachable"
# The fixture entry, written ONCE and named. Every duplicate test uses this.
printf '## 2026-09-26 23:22 +0630 — TEST 2 fixture entry, already present in the journal\n\nThis body exists only in a scratch tree. It is not a real journal entry and it\nis never appended to a real journal.\n' > "$T/seed-entry.md"
{
  cat "$T/seed-entry.md"
  printf '\n## 2026-09-26 23:40 +0630 — a second pre-existing entry\n\nAlso fixture text.\n'
} > "$SJ"
printf '# SHARED-STATE-LOG (scratch)\n\n## 2026-09-26 23:41 +0630 — scratch shared entry\n\nFixture.\n' > "$SS"
ok "scratch journal seeded: $(grep -c '^' "$SJ") lines, 2 entries"
ok "scratch shared log seeded: $(grep -c '^' "$SS") lines"

# THE GUARD. If the resolution logic in journal-append.sh ever changes such that
# the scratch path stops being honoured, every test below would silently start
# writing to the real journal again - which is precisely the bug that caused the
# duplicate. So assert the redirection works BEFORE trusting any result.
hdr "2. prove the redirection actually works, before trusting any test result"
cp "$F_AI" /dev/null 2>/dev/null || true
printf '## %s +0630 — redirection canary, correctly dated\n\nCanary body.\n' "$(date '+%Y-%m-%d %H:%M')" > "$F_AI"
printf '## %s +0630 — redirection canary, shared\n\nCanary.\n' "$(date '+%Y-%m-%d %H:%M')" > "$F_SV"
REAL_BEFORE_J=$(md5sum < "$REAL_J"); REAL_BEFORE_S=$(md5sum < "$REAL_S")
out=$(HOMELAB="$SCRATCH" WIKI="$SCRATCH/wiki" AILOCK="$LOCK" \
      SRC_AI="$F_AI" SRC_SV="$F_SV" AI_ID=AI-1 bash "$JA" --verify 2>&1); r=$?
note_127 "$r"
if [ "$r" -eq 0 ]; then
  ok "journal-append.sh ran against the scratch tree and accepted the canary"
else
  bad "the canary was refused - the redirection is not working, so NO test below is trustworthy"
  printf '%s\n' "$out" | tail -8 | sed 's/^/    /'
fi
if [ "$(md5sum < "$REAL_J")" = "$REAL_BEFORE_J" ] && [ "$(md5sum < "$REAL_S")" = "$REAL_BEFORE_S" ]; then
  ok "and the REAL journals were not touched by the canary"
else
  bad "THE REAL JOURNALS CHANGED - the redirection is not working. Stopping."
  exit 4
fi
# --verify must not write even to the scratch.
if grep -q 'redirection canary' "$SJ"; then
  bad "--verify WROTE to the scratch journal - it is not verify-only"
else
  ok "--verify wrote nothing to the scratch journal either"
fi
# Reset the scratch to its seeded state for the real tests.
cp "$T/seed-entry.md" "$SJ.tmp"
{ cat "$T/seed-entry.md"; printf '\n## 2026-09-26 23:40 +0630 — a second pre-existing entry\n\nAlso fixture text.\n'; } > "$SJ"
rm -f "$SJ.tmp"
printf '# SHARED-STATE-LOG (scratch)\n\n## 2026-09-26 23:41 +0630 — scratch shared entry\n\nFixture.\n' > "$SS"

run_append() { # args... -> sets $out and $r
  out=$(HOMELAB="$SCRATCH" WIKI="$SCRATCH/wiki" AILOCK="$LOCK" \
        SRC_AI="$F_AI" SRC_SV="$F_SV" AI_ID=AI-1 bash "$JA" "$@" 2>&1)
  r=$?
}
scratch_unchanged() { # label
  if [ "$(md5sum < "$SJ")" = "$J_MD5" ] && [ "$(md5sum < "$SS")" = "$S_MD5" ]; then
    ok "$1"
  else
    bad "$1 - FAILED: the scratch journal changed anyway"
    diff <(printf '%s' "$J_SEED") "$SJ" | head -8 | sed 's/^/        /'
  fi
}
J_SEED=$(cat "$SJ"); J_MD5=$(md5sum < "$SJ")
S_SEED=$(cat "$SS"); S_MD5=$(md5sum < "$SS")

hdr "TEST 2: re-appending an entry that is already there must be REFUSED"
cat "$T/seed-entry.md" > "$F_AI"
printf '## 2026-09-26 23:41 +0630 — scratch shared entry, already present\n\nFixture.\n' > "$F_SV"
run_append; note_127 "$r"
printf '%s\n' "$out" | grep -iE 'already|gate 3|FATAL' | head -3 | sed 's/^/    /'
if printf '%s' "$out" | grep -q 'already in the journal'; then
  ok "refused, and it said why"
else
  bad "did not refuse a duplicate entry"
  printf '%s\n' "$out" | tail -8 | sed 's/^/    /'
fi
[ "$r" -ne 0 ] && [ "$r" -ne 127 ] && ok "exits non-zero for the right reason (rc=$r)" || bad "exit code $r"
scratch_unchanged "journals unchanged: $(grep -c '^' "$SJ") and $(grep -c '^' "$SS") lines"
# THE POINT OF THE WHOLE EXERCISE: production must be untouched.
if [ "$(md5sum < "$REAL_J")" = "$REAL_BEFORE_J" ]; then ok "the REAL journal is still byte-identical"
else bad "THE REAL JOURNAL CHANGED"; exit 4; fi

hdr "TEST 3: an entry containing the REAL sudo password must be REFUSED"
# The password is read from disk with ASSIGNMENT CONTEXT and never printed. A
# raw `grep -F` for a 4-character value "finds" it in every date in the file,
# which is how this check became a rubber stamp once already.
PW=$(grep -m1 -iE '^[[:space:]]*sudo' "$H/SERVER-NOTES.txt" | sed -E 's/^[^:]*[:=][[:space:]]*//' | tr -d ' \r\n')
if [ ${#PW} -lt 3 ]; then bad "could not read the password - the test is void"; exit 3; fi
ok "password read from disk, ${#PW} chars (value withheld)"
printf '## 2026-09-26 23:3x +0630 — TEST ENTRY, must never be appended\n\n  sudo/ssh pw = %s\n' "$PW" > "$F_AI"
printf '## 2026-09-26 23:42 +0630 — scratch shared, clean\n\nFixture.\n' > "$F_SV"
if python3 "$CK" "$F_AI" >/dev/null 2>&1; then
  bad "the checker did NOT flag the test entry - it would not catch a real leak either"
else
  ok "the checker flags the test entry (assignment context, not substring)"
fi
NAIVE=$(grep -cF "$PW" "$F_AI" || true)
ok "a raw grep -F would have reported $NAIVE matching line(s) here - which is why it is not used"
run_append; note_127 "$r"
printf '%s\n' "$out" | grep -iE 'credential|gate 2|FATAL|refusing' | head -3 | sed 's/^/    /'
if printf '%s' "$out" | grep -qi 'refusing to append'; then
  ok "refused at gate 2, before any lock was taken"
else
  bad "did not refuse an entry containing a credential"
  printf '%s\n' "$out" | tail -8 | sed 's/^/    /'
fi
[ "$r" -ne 0 ] && [ "$r" -ne 127 ] && ok "exits non-zero (rc=$r)" || bad "exit code $r"
# Did the refusal echo the password back? Checked in ASSIGNMENT CONTEXT against
# the captured output, never by raw substring - see the note above.
printf '%s\n' "$out" > "$T/refusal.txt"
if python3 "$CK" "$T/refusal.txt" >/dev/null 2>&1; then
  ok "the refusal does not contain a credential (checked in assignment context)"
else
  bad "the refusal output contains a credential - it echoed the value"
  # Show the offending line. A check that reports a problem without showing the
  # evidence makes the next person guess.
  python3 - "$T/refusal.txt" "$CK" <<'PY' | sed 's/^/    /'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location("ce", sys.argv[2])
ce = importlib.util.module_from_spec(spec); spec.loader.exec_module(ce)
for i, line in enumerate(pathlib.Path(sys.argv[1]).read_text(errors="replace").splitlines(), 1):
    if ce.MARKER in line:
        continue
    for m in ce.ASSIGN.finditer(line):
        if not ce.is_placeholder(m.group(2), line):
            print("line %d: %r" % (i, line))
            print("  label=%r value-len=%d" % (m.group(1), len(m.group(2))))
PY
fi
scratch_unchanged "scratch journals still unchanged"
if [ -f "$SCRATCH/wiki/journals/ai.lock" ]; then bad "a lock was left behind by the refused run"; else ok "no lock left behind"; fi
if [ "$(md5sum < "$REAL_J")" = "$REAL_BEFORE_J" ]; then ok "the REAL journal is still byte-identical"
else bad "THE REAL JOURNAL CHANGED"; exit 4; fi

hdr "TEST 4: an entry heading dated in the FUTURE must be REFUSED"
# Why this gate exists: on 2026-09-26 I stamped three entries 00:0x, 00:4x and
# 00:5x +0630 when the clock said 23:25. They sat up to 40 minutes ahead of "now"
# and nothing caught it, because every other gate looks at content and none of
# them looked at the date. A plausible time written from memory is the same
# failure as a check that examines the wrong thing.
FUT_Y=$(date -d '+2 days' '+%Y-%m-%d' 2>/dev/null || date -v+2d '+%Y-%m-%d')
if [ -z "$FUT_Y" ]; then
  bad "cannot compute a future date on this box - TEST 4 cannot run"
else
  printf '## %s 09:99 +0630 — TEST 4 synthetic entry, dated in the future on purpose\n\nsynthetic body, no secrets.\n' "$FUT_Y" > "$F_AI"
  printf '## %s 09:99 +0630 — TEST 4 synthetic shared entry, future-dated\n\nsynthetic body.\n' "$FUT_Y" > "$F_SV"
  run_append; note_127 "$r"
  printf '%s\n' "$out" > "$T/refusal4.txt"
  [ "$r" -ne 0 ] && ok "refused, rc=$r" || bad "ACCEPTED a future-dated heading - the gate is not working"
  if grep -q 'dated in the future' "$T/refusal4.txt"; then
    ok "the refusal says why (it names the future date)"
    # Quote the tool's own message as evidence, but label it. Quoting it raw put a
    # line beginning "FAIL" into my output, and a reader scanning for failures
    # cannot tell that word belongs to journal-append.sh, not to this suite. The
    # suite's verdict is the ok/bad line above; this is the quoted reason.
    grep -m1 'AFTER today' "$T/refusal4.txt" | sed 's/^/        journal-append.sh said: /' | cut -c1-118
  else
    bad "refused but did not explain itself"
  fi
  if grep -q 'ai.lock held' "$T/refusal4.txt"; then
    bad "it took the lock before refusing - a refused run would leave a lock behind"
  else
    ok "refused before taking the lock"
  fi
  scratch_unchanged "the scratch journal is byte-identical"
  if [ "$(md5sum < "$REAL_J")" = "$REAL_BEFORE_J" ]; then ok "the REAL journal is still byte-identical"
  else bad "THE REAL JOURNAL CHANGED"; exit 4; fi
fi

hdr "TEST 5: a correctly dated heading is ACCEPTED, and so is '(time not recorded)'"
# A gate that refuses everything is as useless as one that refuses nothing. Prove
# the accept path still works, in --verify mode so nothing is written anywhere.
TODAY_NOW=$(date '+%Y-%m-%d %H:%M')
printf '## %s +0630 — TEST 5 synthetic entry, correctly dated\n\nsynthetic body, no secrets.\n' "$TODAY_NOW" > "$F_AI"
printf '## %s +0630 — TEST 5 synthetic shared entry, correctly dated\n\nsynthetic body.\n' "$TODAY_NOW" > "$F_SV"
run_append --verify; note_127 "$r"
if [ "$r" -eq 0 ]; then ok "accepted, rc=0"
else bad "REFUSED a valid, correctly dated entry - the gate is too strict"
     printf '%s\n' "$out" | grep -m3 -E 'FAIL|FATAL' | sed 's/^/    /'; fi
if printf '%s' "$out" | grep -q 'dated 20'; then ok "the date gate reported the heading as not-in-the-future"
else bad "the date gate said nothing - it may not have run"; fi
scratch_unchanged "--verify wrote nothing"

printf '## 2026-09-26 23:4x +0630 — TEST 5 entry with no recorded time (time not recorded)\n\nsynthetic body.\n' > "$F_AI"
run_append --verify; note_127 "$r"
[ "$r" -eq 0 ] && ok "accepted '(time not recorded)' - a missing time is honest, so it is allowed" \
               || bad "refused '(time not recorded)' - an honest gap should be allowed"

printf '## no date at all in this heading\n\nsynthetic body.\n' > "$F_AI"
run_append --verify; note_127 "$r"
[ "$r" -ne 0 ] && ok "refused a heading with no date at all - an undated entry cannot be placed" \
               || bad "accepted a heading with no date"

hdr "TEST 6: the whole suite left production untouched"
if [ "$(md5sum < "$REAL_J")" = "$REAL_BEFORE_J" ]; then
  ok "REAL AI-1 journal: byte-identical (md5 ${REAL_BEFORE_J%% *})"
else
  bad "REAL AI-1 JOURNAL CHANGED during this suite"
fi
if [ "$(md5sum < "$REAL_S")" = "$REAL_BEFORE_S" ]; then
  ok "REAL shared log: byte-identical (md5 ${REAL_BEFORE_S%% *})"
else
  bad "REAL SHARED LOG CHANGED during this suite"
fi
# Assert about the places THIS SUITE can write, and nothing else.
#
# The previous version counted every ai.lock under ~/homelab and called any of
# them a leak. It fired on the lock held by whatever script invoked the suite -
# which the protocol tells every AI to hold while it works - so a peer doing
# ordinary work got a red line it could not own and could not fix. A leaked lock
# and someone else's lock must not look the same, or the check teaches the reader
# to ignore it, and the one assertion that could catch a real leak dies with it.
if [ -e "$SCRATCH/wiki/journals/ai.lock" ]; then
  bad "this suite left a lock in its own scratch tree"
else
  ok "no lock in the scratch tree - every take had a matching drop"
fi
if [ -e "$W/journals/ai.lock" ]; then
  bad "THE REAL JOURNALS ARE LOCKED and this suite must never lock them"
else
  ok "no lock on the real journals - the suite never touched production's lock"
fi
# Any other lock on the box is another AI's business. Name it, so the reader can
# see it and dismiss it, rather than being handed a bare count to interpret.
other=$(find "$H" -name ai.lock 2>/dev/null | grep -v "^$W/journals/ai.lock$" || true)
if [ -n "$other" ]; then
  note "held by someone else, correctly outside this suite's scope:"
  printf '%s\n' "$other" | while read -r f; do
    printf '        %s  (%s)\n' "${f/#$H/~}" "$(sed -n 's/^reason: //p' "$f" 2>/dev/null | head -1)"
  done
else
  ok "no other ai.lock on the box"
fi
# The scratch tree is gone, and nothing of it leaked into the wiki.
if [ -d "$T" ]; then note "scratch tree removed on exit"; fi
if [ -e /tmp/append-ai.md ] || [ -e /tmp/append-server.md ]; then
  ok "no fixture left in /tmp - the suite builds its own"
else
  ok "no /tmp fixture at all: this suite never depends on leftover state"
fi

printf '\n'
if [ "$rc" -eq 0 ]; then echo "=== ALL OK ==="; else echo "=== STILL FAILING ==="; fi
exit $rc
