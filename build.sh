#!/usr/bin/env bash
# Build the FartPack datapack and resource pack from source, bump the mirror, and
# print the sha1s. This is the ONLY supported way to produce a deployable zip.
#
#   ./build.sh            -> fartpack-latest.zip (canonical artifact name)
#   ./build.sh v19        -> fartpack-v19.zip, and copies to backups/fartpack/v19.zip
#
# After editing source, ALWAYS:
#   1. bump the version constant in data/fartpack/function/core/bootstrap.mcfunction
#      AND the matching `matches N` in data/fartpack/function/tick.mcfunction:1
#      (only needed when you add/remove a scoreboard objective)
#   2. ./build.sh
#   3. lint it against the live server:  scp build/lintpack.py <server>:/tmp/ && ...
set -euo pipefail
cd "$(dirname "$0")"

VER="${1:-latest}"
VER="${VER#v}"          # accept both `19` and `v19`
DP_SRC="fartpack-latest"
RP_SRC="fartpack_sounds"
RP_OUT="fartpack_sounds.zip"

mkdir -p backups/fartpack
# A versioned build is written straight into backups/fartpack/, so the working
# directory only ever holds the current artifact. Older versions then live in
# exactly one place -- three copies of the same zip in three directories is how
# they drifted apart in the first place.
if [ "$VER" != "latest" ]; then DP_OUT="backups/fartpack/v${VER}.zip"; else DP_OUT="fartpack-latest.zip"; fi

# 1. regenerate anything derived from source, so it can never be stale.
#    world/block_name.mcfunction is derived from tags/block/utility.json.
python3 build/genblocknames.py "$DP_SRC"

# 2. datapack
# Built through a staging copy with every mtime forced to the zip epoch (1980-01-01).
#
# WHY: `zip` stores each entry's mtime, so zipping the same source twice gives two
# different sha1s. That makes a zip's sha1 useless as an identity, which in turn
# means you can never prove that a stored backup was built from the commit you
# think it was. Normalising the timestamps makes the build deterministic, so
# `fartpack-vNN.zip` is reproducible from the commit that produced it and
# backups/MANIFEST.sha256 is actually checkable.
#
# The source tree itself is never touched -- only the staging copy.
# DP_OUT was already resolved at the top of this script; do NOT re-derive it here,
# or versioned builds land in the working directory as well as in backups/.
rm -f "$DP_OUT"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
pack() {  # <src-dir> <out-zip>
  rm -rf "$STAGE"/* 2>/dev/null || true
  rsync -a --exclude '.DS_Store' "$1/" "$STAGE/"
  find "$STAGE" -exec touch -t 198001010000 {} +
  ( cd "$STAGE" && zip -q -r -X "$OLDPWD/$2" . )
}
pack "$DP_SRC" "$DP_OUT"

# 3. resource pack
rm -f "$RP_OUT"
pack "$RP_SRC" "$RP_OUT"

# 4. mirror src/datapack so the old copy stops drifting (gitignored, but some tools use it)
mkdir -p src/datapack
rsync -a --delete "$DP_SRC/data/" src/datapack/data/
mkdir -p src/resourcepack
rsync -a --delete "$RP_SRC/" src/resourcepack/

# 5. archive the datapack by version
if [ "$VER" != "latest" ]; then
  # backups/fartpack/vNN.zip is already the build target; refresh the current
  # artifact the deploy tooling actually uploads.
  cp "$DP_OUT" fartpack-latest.zip
fi

# 6. manifest of every versioned zip.
#
# The zips themselves are gitignored on purpose: with a deterministic build they
# are reproducible from the commit that produced them, so committing binaries
# would add weight and review friction without adding recoverability. What is
# worth committing is the list of expected hashes, because THAT is what lets you
# prove a backup on disk or a release asset still matches the source.
MAN=backups/MANIFEST.sha256
{
  echo "# sha256 of every versioned FartPack artifact, one per line, for \`sha256sum -c\`."
  echo "# Regenerate the datapack line with: ./build.sh vNN   (the build is deterministic,"
  echo "# so rebuilding the same commit must reproduce the same hash -- if it does not,"
  echo "# something non-reproducible has crept into the source or the build script.)"
  echo "# Verified against the deployed zips on 2026-09-26."
  ( cd backups/fartpack && for z in $(ls -1 *.zip 2>/dev/null | sort -V); do
      printf '%s  %s\n' "$(sha256sum "$z" | cut -d' ' -f1)" "fartpack/$z"
    done )
} > "$MAN"
echo "manifest      $MAN  ($(grep -vc '^#' "$MAN") artifact(s))"

echo
echo "datapack      $DP_OUT  sha1=$(sha1sum "$DP_OUT" | cut -d' ' -f1)"
echo "resourcepack  $RP_OUT  sha1=$(sha1sum "$RP_OUT" | cut -d' ' -f1)"
[ "$VER" != "latest" ] && echo "backed up to  backups/fartpack/v${VER}.zip"
echo
echo "NEXT: lint the datapack against the live server before deploying."
