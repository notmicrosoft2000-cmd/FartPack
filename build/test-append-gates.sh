#!/usr/bin/env bash
# test-append-gates.sh - prove journal-append.sh refuses the two things it must.
#
#   TEST 2  re-appending an entry that is already in the journal  -> must REFUSE
#   TEST 3  appending an entry containing a live credential       -> must REFUSE
#
# Both must leave the journals byte-identical. A refusal that still writes is
# worse than no refusal, so md5sums are compared, not just line counts.
#
# LESSON BUILT INTO THIS FILE, after it passed for the wrong reason once:
#   1. Assert the script EXISTS before testing its behaviour. A missing file
#      exits 127, which looks exactly like a successful refusal.
#   2. Find the password with ASSIGNMENT CONTEXT (check-entry.py), never with a
#      raw `grep -F`. The value is 4 characters; a raw search "finds" it in every
#      date in the file and the test becomes a rubber stamp.
set -uo pipefail
H="$HOME/homelab"
W="$H/wiki"
J="$W/journals/AI-1/JOURNAL.md"
S="$W/journals/SHARED-STATE-LOG.md"
JA="$W/bin/journal-append.sh"
CK="$W/bin/check-entry.py"
rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }
say() { printf '  %s\n' "$*"; }
hdr() { printf '\n=== %s ===\n' "$*"; }

hdr "0. the tools must EXIST, or every test below is theatre"
for t in "$JA" "$CK" "$W/bin/ailock.sh"; do
  if [ -f "$t" ]; then ok "present: ${t#"$H/"}"
  else bad "MISSING: ${t#"$H/"} - refusing to run the tests"; exit 3; fi
  if [ -x "$t" ]; then ok "executable: $(basename "$t")"; else bad "$(basename "$t") is not executable"; fi
done
if bash -n "$JA" 2>/dev/null; then ok "journal-append.sh parses"; else bad "journal-append.sh has a syntax error"; fi
# NOT `bash -n` on the .py - that reports a syntax error for every Python file.
if python3 -c "import ast,sys; ast.parse(open('$CK').read())" 2>/dev/null; then ok "check-entry.py is valid python"; else bad "check-entry.py is not valid python"; fi

hdr "baseline"
JB=$(wc -l < "$J"); SB=$(wc -l < "$S")
JB_SUM=$(md5sum < "$J"); SB_SUM=$(md5sum < "$S")
ok "AI-1 journal $JB lines, shared log $SB lines"
[ -s /tmp/append-ai.md ] && ok "/tmp/append-ai.md present" || bad "/tmp/append-ai.md missing - TEST 2 cannot run"
[ -s /tmp/append-server.md ] && ok "/tmp/append-server.md present" || bad "/tmp/append-server.md missing"
# The baseline entry files must themselves be clean, or TEST 2 proves the wrong thing.
if python3 "$CK" /tmp/append-ai.md /tmp/append-server.md >/dev/null 2>&1; then
  ok "the entry files about to be re-appended are clean"
else
  bad "the entry files already contain a credential - fix them before testing"
fi

hdr "TEST 2: re-appending an entry that is already there must be REFUSED"
OUT=$(AI_ID=AI-1 bash "$JA" 2>&1); RRC=$?
printf '%s\n' "$OUT" | grep -iE 'already|gate 3|FATAL' | sed 's/^/    /'
if printf '%s' "$OUT" | grep -q 'already in the journal'; then
  ok "refused, and it said why"
else
  bad "did not refuse a duplicate entry"
  printf '%s\n' "$OUT" | tail -10 | sed 's/^/    /'
fi
# 127 = command not found. That is NOT a refusal, it is a broken test.
if [ "$RRC" -eq 127 ]; then bad "exit 127 - the script did not run at all"; fi
if [ "$RRC" -ne 0 ] && [ "$RRC" -ne 127 ]; then ok "exits non-zero for the right reason (rc=$RRC)"; else bad "exit code $RRC"; fi
JA2=$(wc -l < "$J"); SA2=$(wc -l < "$S")
if [ "$JA2" -eq "$JB" ] && [ "$SA2" -eq "$SB" ]; then ok "journals unchanged: $JA2 and $SA2 lines"
else bad "the journals CHANGED despite the refusal: $JB->$JA2, $SB->$SA2"; fi
if [ "$(md5sum < "$J")" = "$JB_SUM" ] && [ "$(md5sum < "$S")" = "$SB_SUM" ]; then
  ok "and byte-identical, not merely the same line count"
else
  bad "content changed even though the line count did not"
fi

hdr "TEST 3: an entry containing the REAL sudo password must be REFUSED"
cp /tmp/append-ai.md /tmp/ta.keep
cp /tmp/append-server.md /tmp/ts.keep
PW=$(grep -m1 -iE '^[[:space:]]*sudo' "$H/SERVER-NOTES.txt" | sed -E 's/^[^:]*[:=][[:space:]]*//' | tr -d ' \r\n')
if [ ${#PW} -lt 3 ]; then bad "could not read the password - the test is void"; exit 3; fi
ok "password read from disk, ${#PW} chars (value withheld)"
{
  echo "## 2026-09-26 23:3x +0630 — TEST ENTRY, must never be appended"
  echo
  echo "  sudo/ssh pw = $PW"
} > /tmp/append-ai.md
# Confirm the leak with the ASSIGNMENT-CONTEXT checker, not a substring search.
if python3 "$CK" /tmp/append-ai.md >/dev/null 2>&1; then
  bad "the checker did NOT flag the test entry - it would not catch a real leak either"
else
  ok "the checker flags the test entry (assignment context, not substring)"
fi
# And prove the raw search would have been useless here.
NAIVE=$(grep -cF "$PW" /tmp/append-ai.md || true)
ok "a raw grep -F would have reported $NAIVE matching line(s) here - which is why it is not used"

OUT=$(AI_ID=AI-1 bash "$JA" 2>&1); RRC=$?
printf '%s\n' "$OUT" | grep -iE 'credential|gate 2|FATAL|refusing' | sed 's/^/    /'
if printf '%s' "$OUT" | grep -qi 'refusing to append'; then
  ok "refused at gate 2, before any lock was taken"
else
  bad "did not refuse an entry containing a credential"
  printf '%s\n' "$OUT" | tail -10 | sed 's/^/    /'
fi
if [ "$RRC" -eq 127 ]; then bad "exit 127 - the script did not run at all"; fi
if [ "$RRC" -ne 0 ] && [ "$RRC" -ne 127 ]; then ok "exits non-zero (rc=$RRC)"; else bad "exit code $RRC"; fi
# Did the refusal echo the password back?
#
# This check committed trap 21 twice before it was right. `grep -qF "$PW"` is a
# RAW substring search, and the value is a 4-character year, so it matched the
# timestamps in the refusal's own output and reported a leak that was not there.
# The correct assertion is the same assignment-context check, applied to the
# captured output. If the tool really had echoed the value, the output would
# contain `sudo/ssh pw = <value>` and this would catch it.
printf '%s\n' "$OUT" > /tmp/refusal.txt
if python3 "$CK" /tmp/refusal.txt >/dev/null 2>&1; then
  ok "the refusal does not contain a credential (checked in assignment context)"
else
  bad "the refusal output contains a credential - it echoed the value"
  # Show the evidence. A check that reports a problem without showing the line it
  # is complaining about makes the next person guess, which is exactly what
  # happened here three times.
  python3 - /tmp/refusal.txt <<'PY' | sed 's/^/    /'
import pathlib, re, sys
sys.path.insert(0, str(pathlib.Path.home() / "homelab/wiki/bin"))
import importlib.util
spec = importlib.util.spec_from_file_location(
    "ce", pathlib.Path.home() / "homelab/wiki/bin/check-entry.py")
ce = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ce)
p = pathlib.Path(sys.argv[1])
for i, line in enumerate(p.read_text(errors="replace").splitlines(), 1):
    if ce.MARKER in line:
        continue
    for m in ce.ASSIGN.finditer(line):
        if ce.is_placeholder(m.group(2), line):
            continue
        print("line %d: %r" % (i, line))
        print("  label=%r  value=%r  span=%r" % (m.group(1), m.group(2), m.span()))
PY
fi
if grep -qE "pw[[:space:]]*=[[:space:]]*$(printf '%s' "$PW" | sed 's/[][\.*^$/]/\\&/g')\b" /tmp/refusal.txt; then
  bad "the raw text 'pw = <value>' appears in the refusal output"
else
  ok "and no literal 'pw = <value>' appears in it either"
fi
rm -f /tmp/refusal.txt
JA3=$(wc -l < "$J"); SA3=$(wc -l < "$S")
if [ "$JA3" -eq "$JB" ] && [ "$SA3" -eq "$SB" ]; then ok "journals still unchanged: $JA3 and $SA3 lines"
else bad "the journals CHANGED: $JB->$JA3, $SB->$SA3"; fi
if [ -f "$W/journals/ai.lock" ]; then bad "a lock was left behind by the refused run"; else ok "no lock left behind"; fi

hdr "restore the real entry files"
cp /tmp/ta.keep /tmp/append-ai.md
cp /tmp/ts.keep /tmp/append-server.md
rm -f /tmp/ta.keep /tmp/ts.keep
if python3 "$CK" /tmp/append-ai.md /tmp/append-server.md >/dev/null 2>&1; then
  ok "restored, and verified clean with the same checker"
else
  bad "the restored entry is NOT clean"
fi

hdr "final state"
ok "AI-1 journal $JA3 lines, shared log $SA3 lines"
L=$(find "$H" -name ai.lock 2>/dev/null | wc -l)
if [ "$L" -eq 0 ]; then ok "no ai.lock anywhere under $H"; else bad "$L lock(s) left"; fi

printf '\n'
if [ "$rc" -eq 0 ]; then echo "=== ALL OK ==="; else echo "=== STILL FAILING ==="; fi
exit $rc
