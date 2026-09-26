#!/usr/bin/env bash
# treep.sh - print the repo layout, one path per line, indented, skipping noise.
#
# Read-only. Excludes .git and the generated src/ mirror, both of which are
# documented as non-source. Zips are listed but marked, because they are real
# artifacts that exist on disk even though they are gitignored.
set -uo pipefail
cd "$(dirname "$0")/.."

show() {
  find . -mindepth "$1" -maxdepth "$2" \
    -not -path './.git*' \
    -not -path './src*' \
    -not -name '.DS_Store' \
    -not -path '*__MACOSX*' \
    | sort
}

echo "FartPack/"
echo
echo "--- top level ---"
find . -maxdepth 1 -mindepth 1 -not -name '.git' -not -name 'src' | sort | sed 's|^\./||' | while read -r p; do
  if [ -d "$p" ]; then printf '  %-24s %s\n' "$p/" "$([ -n "$(git ls-files "$p" 2>/dev/null)" ] && echo '' || echo '(gitignored)')"
  else printf '  %-24s %s\n' "$p" "$(git check-ignore -q "$p" 2>/dev/null && echo '(gitignored artifact)' || echo '')"; fi
done

echo
echo "--- build/ (tooling, all tracked) ---"
show 1 1 | grep '^\./build/' | sed 's|^\./||' | while read -r p; do
  printf '  %-28s %s\n' "$(basename "$p")" "$(wc -l < "$p" 2>/dev/null | tr -d ' ') lines"
done

echo
echo "--- fartpack-latest/ (the datapack source) ---"
printf '  data/fartpack/function/  %s functions\n' "$(find fartpack-latest/data/fartpack/function -name '*.mcfunction' | wc -l | tr -d ' ')"
find fartpack-latest/data/fartpack/function -mindepth 1 -maxdepth 1 -type d | sort | while read -r d; do
  printf '    %-22s %3s\n' "$(basename "$d")/" "$(find "$d" -name '*.mcfunction' | wc -l | tr -d ' ')"
done
echo "  other datapack files:"
find fartpack-latest -type f -not -name '*.mcfunction' | sort | sed 's|^fartpack-latest/|    |' | head -40

echo
echo "--- fartpack_sounds/ (the resource pack source) ---"
find fartpack_sounds -type f | sort | sed 's|^fartpack_sounds/|    |'

echo
echo "--- backups/ (archives on disk; MANIFEST is tracked, zips are not) ---"
find backups -type f | sort | sed 's|^backups/|    |'
