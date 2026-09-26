#!/usr/bin/env bash
# check-moved-paths.sh - after moving or deleting a path, prove you covered every
# reference that actually exists, rather than every reference you remember.
#
# WHY THIS EXISTS
#   On 2026-09-26 I moved ~/homelab/server-info/ into ~/homelab/wiki/ and left
#   pointer stubs "so existing references still resolve". I left two stubs. The
#   published handoff doc named five paths under the old directory. Three of them
#   resolved to NOTHING, including the one that answers "is another AI already on
#   this box" - the single most important file to read before making a change.
#
#   The rule I had written down that same evening was "a stub is only worth the
#   effort if it is reachable by the name people actually wrote down". I broke it
#   by never producing the list of names. The names live in files I was no longer
#   looking at: a commit I had already pushed, a doc already in someone's context.
#
# WHAT IT DOES
#   Searches a set of roots for a literal string, extracts every distinct absolute
#   path that contains it, and reports which resolve. You get the list of names
#   the world actually uses, derived rather than remembered.
#
# USAGE
#   check-moved-paths.sh <literal> <root> [root ...]
#   check-moved-paths.sh homelab/server-info/ .
#
#   Optional env:
#     STRIP_PREFIX  if a matched path does not exist, retry with this stripped
#                   from its front (e.g. STRIP_PREFIX=file/ for Minecraft
#                   datapack references)
#     ALLOW_MISSING colon-separated exact paths that are allowed to be absent
#
# Exit 0 = every referenced path resolves. Exit 1 = at least one does not.
# Never prints file contents; only paths and counts.

set -uo pipefail

if [ "$#" -lt 2 ]; then
  printf 'usage: %s <literal> <root> [root ...]\n' "$(basename "$0")" >&2
  printf '  env: STRIP_PREFIX=<prefix>  ALLOW_MISSING=<path>:<path>\n' >&2
  exit 64
fi

LITERAL="$1"; shift
ROOTS=("$@")
ALLOW="${ALLOW_MISSING:-}"
STRIP="${STRIP_PREFIX:-}"

rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }

printf '=== references to %s under: %s\n' "$LITERAL" "${ROOTS[*]}"

# Collect matches as "file:line:content", then pull the absolute path out of the
# content. Sorting -u gives the distinct set of names. Do NOT assert on a live
# pipe: capture first, then reason about the text (wiki page 05, trap 20b).
HITS=$(grep -rn --binary-files=without-match -F "$LITERAL" "${ROOTS[@]}" 2>/dev/null)
NC=$(printf '%s' "$HITS" | grep -c . )
ok "$NC line(s) mention it in ${#ROOTS[@]} root(s)"

# Also search git history, because the moment you edit the file that held the
# references, the working tree stops being evidence of what it used to say. The
# names you need to cover are in the commit you already pushed. Set NO_GIT=1 to
# skip (e.g. when scanning a non-repo directory).
GHITS=""
if [ "${NO_GIT:-0}" != "1" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  GHITS=$(git grep -n -F "$LITERAL" $(git rev-list --all 2>/dev/null | head -40) -- 2>/dev/null)
  GN=$(printf '%s' "$GHITS" | grep -c . )
  if [ "${GN:-0}" -gt 0 ]; then
    ok "$GN more reference(s) in git history (up to 40 commits back)"
  else
    ok "no additional references in git history"
  fi
fi

# Every whitespace-delimited token on a matching line that looks like a path
# containing the literal. The "prefix/literal/rest" shape is included, so a
# reference written as `~/homelab/server-info/00-README.md` yields the whole path
# and not just the tail.
#
# Escape only what ERE treats specially. Forward slash is NOT one of them:
# escaping it produces "stray \ before /" warnings from grep, which is noise that
# trains you to ignore the tool's output.
ESC=$(printf '%s' "$LITERAL" | sed 's/[][\\^$.*+?(){}|]/\\&/g')
PATHS=$(printf '%s\n%s' "$HITS" "$GHITS" \
  | cut -d: -f3- \
  | grep -oE "[A-Za-z0-9_./~<>-]*${ESC}[A-Za-z0-9_./<>-]*" \
  | sed 's/[`"'"'"',;)]*$//' \
  | sort -u)

NP=$(printf '%s' "$PATHS" | grep -c . )
if [ "$NP" -eq 0 ]; then
  printf '\n'
  bad "found $NC mentioning line(s) but extracted 0 paths - the extraction is broken, not the tree"
  printf '       a checker that extracts nothing has proved nothing\n'
  exit 1
fi
ok "$NP distinct path(s) referenced"

printf '\n=== do they resolve? ===\n'
RESOLVED=0; MISSING=0
while read -r p; do
  [ -z "$p" ] && continue
  cand="$p"
  case "$cand" in '~/'*) cand="$HOME/${cand#\~/}" ;; esac
  if [ ! -e "$cand" ] && [ -n "$STRIP" ]; then
    case "$cand" in "$STRIP"*) cand="${cand#$STRIP}" ;; esac
  fi
  if [ -e "$cand" ]; then
    printf '  ok    %s\n' "$p"
    RESOLVED=$((RESOLVED+1))
  elif printf '%s' ":$ALLOW:" | grep -qF ":$p:"; then
    printf '  ok    %s  (allowed to be absent)\n' "$p"
    RESOLVED=$((RESOLVED+1))
  else
    printf '  FAIL  %s\n' "$p"
    if [ -n "$STRIP" ]; then
      printf '          also tried with STRIP_PREFIX=%s stripped\n' "$STRIP"
    fi
    MISSING=$((MISSING+1))
  fi
done <<EOF
$PATHS
EOF

printf '\n=== summary ===\n'
printf '  %d referenced, %d resolve, %d do not\n' "$NP" "$RESOLVED" "$MISSING"
if [ "$MISSING" -gt 0 ]; then
  printf '\n'
  bad "$MISSING referenced path(s) do not exist."
  printf '       Each one is a reference someone wrote down. Leave a stub that says\n'
  printf '       where it went, or the reference silently becomes a dead end.\n'
fi
printf '\n'
if [ "$rc" -eq 0 ]; then echo "=== ALL OK ==="; else echo "=== STILL FAILING ==="; fi
exit $rc
