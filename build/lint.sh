#!/usr/bin/env bash
# lint.sh - unpack the source under test and parse-lint it against the live server.
# Run on the server. Refuses to proceed if anyone is online, because lintpack.py
# EXECUTES every line it checks (it is a real parse test, not a static one) and
# the pack's own lines include setblock/give/kill/tag.
set -euo pipefail

# The zip that deploy.sh installs. Lint THIS, not a source tree.
#
# It used to untar /tmp/v25src.tar.gz, a leftover from an earlier attempt, and
# deploy.sh installed /tmp/fartpack-latest.zip. Nothing tied the two together, so
# on v26 the lint faithfully reported `PARSE FAILURES: 0` - of v25 - while the
# v26 zip it went on to install had two files that would not load at all
# (#30). The lint was not broken; it was checking a different artifact, and its
# output was trusted because it said the right words.
#
# A pre-deploy gate that can validate the wrong build is worse than no gate,
# because it manufactures false confidence. So the source is now derived from
# the exact file that gets installed, and the hash is printed here and compared
# against deploy.sh's "installed:" line.
ZIP=/tmp/fartpack-latest.zip
SRC=/tmp/lintsrc

[ -f "$ZIP" ] || { echo "FATAL: $ZIP not found - nothing to lint"; exit 1; }
LINTED=$(sha1sum "$ZIP" | cut -d' ' -f1)
echo "linting sha1: $LINTED"
echo "  (deploy.sh installs this same file; its 'installed:' hash must match)"

rm -rf "$SRC"
mkdir -p "$SRC"
# python3 zipfile, not unzip: the server has neither zip nor unzip installed
# (checked), and a lint that dies on a missing tool would be another gate that
# silently stops gating.
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$ZIP" "$SRC"
[ -d "$SRC/data" ] || { echo "FATAL: $ZIP did not unpack to a data/ dir"; exit 1; }
echo "unpacked to $SRC"

# Record what was linted. deploy.sh refuses to install if the zip's hash has
# moved since this file was written, which closes the window where a rebuild
# lands between the gate passing and the copy happening.
printf '%s  %s\n' "$LINTED" "$ZIP" > /tmp/linted.sha1

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
# Explicit rather than relying on `set -e` so the reason is legible in the log.
# lintpack.py exits 1 when PARSE FAILURES > 0, and that status has to reach
# deployauto.sh, which branches on it and refuses to deploy.
set +e
python3 /tmp/lintpack.py "$SRC"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo
  echo "FATAL: parse lint failed (exit $rc). The functions listed above do not"
  echo "       parse against this server version. Do NOT deploy - a function"
  echo "       that will not load makes its feature silently do nothing."
  exit "$rc"
fi
echo "lint OK"
