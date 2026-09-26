#!/usr/bin/env bash
# lint.sh - unpack the source under test and parse-lint it against the live server.
# Run on the server. Refuses to proceed if anyone is online, because lintpack.py
# EXECUTES every line it checks (it is a real parse test, not a static one) and
# the pack's own lines include setblock/give/kill/tag.
set -euo pipefail

SRC=/tmp/fartpack-latest

tar xzf /tmp/v25src.tar.gz -C /tmp
[ -d "$SRC" ] || { echo "FATAL: $SRC did not unpack"; exit 1; }

# --- player gate -------------------------------------------------------------
# MUST be an array. `R=$(python3 /tmp/rcon.py)` makes R the single string
# "python3 /tmp/rcon.py", and "${R[@]}" then passes that as ONE argv entry, so
# every call fails silently and the player count reads as empty. This exact
# mistake is documented in build/README.md; do not reintroduce it.
R=(python3 /tmp/rcon.py)
n=$("${R[@]}" 'list' 2>/dev/null | tail -1)
# "There are 0 of a max of 20 players online:"  ->  the number after "are "
count=$(printf '%s' "$n" | sed -n 's/.*There are \([0-9][0-9]*\) of.*/\1/p')
if [ -z "$count" ]; then
  echo "FATAL: could not read the player count from: $n"
  echo "       Aborting rather than assuming the server is empty."
  exit 1
fi
echo "players online: $count"
if [ "$count" != "0" ]; then
  echo "FATAL: $count player(s) online. Lint executes commands; run this on an empty server."
  exit 1
fi

# --- block tag check ---------------------------------------------------------
# One unrecognised id silently kills an entire tags/block/*.json with nothing in
# the log, so this is checked separately from the function parse. checkblocks.py
# wants a plain text file of ids, not a directory, so flatten the tag JSONs first.
echo
echo "=== block tag validity ==="
python3 - "$SRC" > /tmp/tagids.txt <<'PY'
import glob, json, os, sys
src = sys.argv[1]
ids = []
for p in sorted(glob.glob(os.path.join(src, "data", "**", "tags", "block", "*.json"), recursive=True)):
    for v in json.load(open(p)).get("values", []):
        ids.append(v if isinstance(v, str) else v.get("id", ""))
for i in ids:
    print(i)
PY
n_ids=$(grep -c . /tmp/tagids.txt || true)
echo "flattened $n_ids block ids from tags/block/*.json"
python3 /tmp/checkblocks.py /tmp/tagids.txt > /tmp/tagcheck.out 2>&1 || true
grep -E '^(BAD|checked)' /tmp/tagcheck.out || { echo "could not read checkblocks output:"; cat /tmp/tagcheck.out; exit 1; }
if grep -q '^BAD' /tmp/tagcheck.out; then
  echo "FATAL: an invalid block id would silently kill the whole tag"
  grep '^BAD' /tmp/tagcheck.out
  exit 1
fi

# --- function parse lint -----------------------------------------------------
echo
echo "=== function parse lint ==="
python3 /tmp/lintpack.py "$SRC"
