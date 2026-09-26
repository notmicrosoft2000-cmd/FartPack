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
DP_SRC="fartpack-latest"
RP_SRC="fartpack_sounds"
DP_OUT="fartpack-latest.zip"
RP_OUT="fartpack_sounds.zip"

# 1. datapack
if [ "$VER" != "latest" ]; then DP_OUT="fartpack-v${VER}.zip"; fi
rm -f "$DP_OUT"
( cd "$DP_SRC" && zip -r -X "../$DP_OUT" . -x '*.DS_Store' >/dev/null )

# 2. resource pack
rm -f "$RP_OUT"
( cd "$RP_SRC" && zip -r -X "../$RP_OUT" . -x '*.DS_Store' >/dev/null )

# 3. mirror src/datapack so the old copy stops drifting (gitignored, but some tools use it)
mkdir -p src/datapack
rsync -a --delete "$DP_SRC/data/" src/datapack/data/
mkdir -p src/resourcepack
rsync -a --delete "$RP_SRC/" src/resourcepack/

# 4. archive the datapack by version
if [ "$VER" != "latest" ]; then
  mkdir -p backups/fartpack
  cp "$DP_OUT" "backups/fartpack/v${VER}.zip"
  cp "$DP_OUT" "$DP_SRC/../fartpack-latest.zip"
fi

echo
echo "datapack      $DP_OUT  sha1=$(sha1sum "$DP_OUT" | cut -d' ' -f1)"
echo "resourcepack  $RP_OUT  sha1=$(sha1sum "$RP_OUT" | cut -d' ' -f1)"
[ "$VER" != "latest" ] && echo "backed up to  backups/fartpack/v${VER}.zip"
echo
echo "NEXT: lint the datapack against the live server before deploying."
