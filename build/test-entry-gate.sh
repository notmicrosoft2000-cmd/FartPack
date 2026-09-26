#!/usr/bin/env bash
# test-entry-gate.sh - prove check-entry.py actually refuses a credential.
#
# A gate that has never been tested against a real leak is a gate that has never
# been tested. This builds three entries on the box:
#   A  a normal entry                     -> must PASS
#   B  a synthetic credential assignment  -> must FAIL
#   C  the ACTUAL sudo password           -> must FAIL
# C is assembled on the server from SERVER-NOTES.txt so the value is never typed,
# printed, or sent over the wire. It is deleted immediately after.
set -uo pipefail
H="$HOME/homelab"
W="$H/wiki"
CK="$(dirname "$0")/check-entry.py"
T=/tmp/entrytest
rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }
say() { printf '  %s\n' "$*"; }
hdr() { printf '\n=== %s ===\n' "$*"; }

mkdir -p "$T"

hdr "A. a normal entry must PASS"
cat > "$T/good.md" <<'EOF'
## 2026-09-26 23:0x +0630 — Testing the entry gate

Redacted the sudo password line. The credential itself lives in
`~/homelab/SERVER-NOTES.txt` and is deliberately not reproduced here.

* the rcon password is set in server.properties, mode 644
* `management-server-secret` is present but the management server is off
EOF
if python3 "$CK" "$T/good.md" >/tmp/gt.out 2>&1; then ok "A passed, as it should"
else bad "A FAILED but should have passed - the gate is too strict"; sed 's/^/    /' /tmp/gt.out; fi

hdr "B. a synthetic credential assignment must FAIL"
cat > "$T/bad.md" <<'EOF'
## 2026-09-26 23:0x +0630 — oops

  sudo/ssh pw = hunter22
  rcon.password: correcthorsebattery
EOF
if python3 "$CK" "$T/bad.md" >/tmp/bt.out 2>&1; then
  bad "B PASSED but contains two obvious credentials - the gate is broken"
  sed 's/^/    /' /tmp/bt.out
else
  ok "B refused, as it should"
  sed 's/^/    /' /tmp/bt.out
fi

hdr "C. the ACTUAL sudo password must FAIL (value never leaves the box)"
PW=$(grep -m1 -iE '^[[:space:]]*sudo' "$H/SERVER-NOTES.txt" | sed -E 's/^[^:]*[:=][[:space:]]*//' | tr -d ' \r\n')
if [ ${#PW} -lt 3 ]; then bad "could not read the password - the test is void"; exit 3; fi
ok "password read from disk, ${#PW} chars (value withheld)"
{
  echo "## 2026-09-26 23:0x +0630 — the leak, for the test"
  echo
  echo "  sudo/ssh pw = $PW"
} > "$T/real.md"
if grep -qF "$PW" "$T/real.md"; then ok "test file really does contain the value (so a pass would be a false pass)"
else bad "the test file does not contain the value - the test proves nothing"; fi
if python3 "$CK" "$T/real.md" >/tmp/rt.out 2>&1; then
  bad "C PASSED with the real password in it - THE GATE IS BROKEN"
  sed 's/^/    /' /tmp/rt.out
else
  ok "C refused, as it should"
  sed 's/^/    /' /tmp/rt.out
fi
# Prove the output did not echo the value back.
if grep -qF "$PW" /tmp/rt.out; then bad "the gate PRINTED the password in its error output"; else ok "the gate did not echo the value in its message"; fi

hdr "D. and it must not fire on the 4-character value used innocently"
{
  echo "## 2026-09-26 23:0x +0630 — dates are not secrets"
  echo
  echo "Worked through 2026-09-26 and 2026-09-25. Backups: world-2026.tar.gz,"
  echo "fartpack-v11-20260925.zip. Port 25565. 20 of 30 checks passed."
} > "$T/dates.md"
if python3 "$CK" "$T/dates.md" >/tmp/dt.out 2>&1; then
  ok "D passed - a short value in ordinary prose is not a leak"
else
  bad "D failed - the gate cannot tell a date from a password, so it is useless"
  sed 's/^/    /' /tmp/dt.out
fi

hdr "E. every expected secret must actually be loaded (the silent-skip guard)"
# A gate that quietly fails to load a secret still reports success. Assert on the
# LOADED SET, not on the verdict. This test exists because the first version of
# check-entry.py looked for a key called `password=` and never found
# `rcon.password`, so that secret was never cross-checked - and the tool said
# nothing about it. Trap 20(a), in brand new code.
LOADED=$(python3 "$CK" "$H/wiki/registry/README.md" 2>&1 | grep -oE 'known live values read from disk: .*' || true)
say "  ${LOADED:-<none>}"
MISSING=""
for want in rcon.password management-server-secret discord-webhook sudo-password; do
  case "$LOADED" in
    *"$want"*) : ;;
    *) MISSING="$MISSING $want" ;;
  esac
done
if [ -z "$MISSING" ]; then
  ok "all four live secrets are loaded - nothing is being silently skipped"
else
  bad "not loaded, so not cross-checked:$MISSING"
fi
WARNS=$(python3 "$CK" "$H/wiki/registry/README.md" 2>&1 | grep -c 'WARN' || true)
if [ "${WARNS:-0}" -eq 0 ]; then ok "no WARN lines - every source was read and every key was found"
else bad "$WARNS WARN line(s): a secret source could not be read"; fi

hdr "F. the checker must not flag its OWN output"
# Prose about credentials keeps tripping a checker for credentials. Two rounds of
# rewording did not fix it, because the problem is structural. The fix is the
# MARKER: this tool's own diagnostics are skipped when re-scanned.
# If it ever echoed a real secret, that echoed line would not carry the marker -
# so this property does not weaken the gate.
cat > "$T/leaky.md" <<'EOF'
## test

  sudo/ssh pw = leakedvalue123
EOF
python3 "$CK" "$T/leaky.md" > "$T/selfout.txt" 2>&1
if python3 "$CK" "$T/selfout.txt" >/dev/null 2>&1; then
  ok "the checker's own report is clean when re-scanned"
else
  bad "the checker flags its own output - reword the report AND check the marker"
  python3 "$CK" "$T/selfout.txt" 2>&1 | grep -E 'possible credential|holds the live' | sed 's/^/    /'
fi
# And the gate must still catch a real value even inside a report-shaped file.
rm -f "$T/selfout.txt"

hdr "G. the regex contract itself (two real bugs lived here)"
python3 - "$CK" <<'PY'
import importlib.util, pathlib, re, sys
spec = importlib.util.spec_from_file_location("ce", sys.argv[1])
ce = importlib.util.module_from_spec(spec); spec.loader.exec_module(ce)
bad = 0
def ok(m):  print("  ok    %s" % m)
def bad_(m): print("  FAIL  %s" % m); globals()['bad'] = globals().get('bad', 0) + 1

# G1: ASSIGN must have exactly two groups, and group 2 must be the VALUE.
if ce.ASSIGN.groups == 2:
    ok("ASSIGN has exactly 2 groups (1=label, 2=value)")
else:
    bad_("ASSIGN has %d groups, expected 2 - a nested capture group in LABEL has "
         "renumbered them and every report is about the wrong thing" % ce.ASSIGN.groups)

m = ce.ASSIGN.search("  sudo/ssh pw = hunter22")
if m and m.group(2) == "hunter22":
    ok("group(2) is the value: %r" % m.group(2))
else:
    bad_("group(2) is %r, expected 'hunter22'" % (m.group(2) if m else None))

m = ce.ASSIGN.search("  rcon.password: correcthorsebattery")
if m and m.group(2) == "correcthorsebattery":
    ok("group(2) is the value for a dotted label too: %r" % m.group(2))
else:
    bad_("group(2) is %r, expected 'correcthorsebattery'" % (m.group(2) if m else None))

# G2: a reported length must be the value's length. This is the assertion that
# would have caught the group-numbering bug on the first run instead of the fifth.
m = ce.ASSIGN.search("  api_key: abcdefghijklmnop")
if m and len(m.group(2).rstrip(ce.TRAILING)) == 16:
    ok("value length is reported as the value's length (16)")
else:
    bad_("value length wrong: %r" % (m.group(2) if m else None))

# G3: the placeholder exemption must apply to the VALUE.
for line, why in [("  sudo/ssh pw = [REDACTED].", "bracketed placeholder with a full stop"),
                  ("  password: <withheld>", "angle-bracket placeholder"),
                  ("  token: ****", "asterisk mask"),
                  ("  secret: not shown", "prose placeholder")]:
    m = ce.ASSIGN.search(line)
    if m and ce.is_placeholder(m.group(2), line):
        ok("exempt: %s" % why)
    else:
        bad_("NOT exempt: %s (value=%r)" % (why, m.group(2) if m else None))

# G4: and a real value must NOT be exempt.
m = ce.ASSIGN.search("  sudo/ssh pw = hunter22")
if m and not ce.is_placeholder(m.group(2), "  sudo/ssh pw = hunter22"):
    ok("a real value is not exempt")
else:
    bad_("a real value was treated as a placeholder")

# G5: the word-boundary fix - 'pwr' must not match the label 'pw'.
if not ce.ASSIGN.search("  pwr:do_power triggered"):
    ok("'pwr:do_power' does not match (word boundaries hold)")
else:
    bad_("'pw' is matching inside 'pwr' again - the datapack's own variable names "
         "would be flagged as credentials")

sys.exit(1 if bad else 0)
PY
if [ $? -eq 0 ]; then ok "the regex contract holds"; else bad "the regex contract is broken"; fi

hdr "cleanup"
rm -f "$T"/real.md "$T"/bad.md "$T"/good.md "$T"/dates.md "$T"/leaky.md "$T"/selfout.txt /tmp/gt.out /tmp/bt.out /tmp/rt.out /tmp/dt.out
if [ -f "$T/real.md" ]; then bad "the test file with the real password still exists"; else ok "test files deleted"; fi
rmdir "$T" 2>/dev/null || true

hdr "final: no password anywhere in the journals"
CHK=$(python3 /tmp/leakcheck.py 2>&1)
T2=$(printf '%s' "$CHK" | grep -oE 'TOTAL [0-9]+' | grep -oE '[0-9]+$')
if [ "$T2" = "0" ]; then ok "journals clean"; else bad "$T2 hit(s) remain"; fi

printf '\n'
if [ "$rc" -eq 0 ]; then echo "=== ALL OK ==="; else echo "=== STILL FAILING ==="; fi
exit $rc
