#!/usr/bin/env bash
# check-duplicate-headings.sh - find repeated `## ` headings in a journal, and
# tell a DELIBERATE retention apart from a fresh mistake.
#
# WHY THIS EXISTS
#   A plain `grep '^## ' | sort | uniq -d` reports every repeated heading as a
#   defect. In AI-1's journal it found one, and it was a defect I had already
#   found, understood, and deliberately left in place on 2026-09-26. So the check
#   reported a decision as an error, on every run, forever.
#
#   That matters more than it sounds. A check that always reports the same known
#   thing is a check nobody reads — and the 63-line duplicate that
#   `test-append-gates.sh` had been appending to the journal for hours went
#   unnoticed for exactly that reason: the one real signal in that suite's
#   output was buried under a red line everyone had learned to skip.
#
#   So this distinguishes two cases that look identical in the bytes:
#     EXPECTED     the heading text appears VERBATIM in journals/KNOWN-DUPLICATES.md
#     UNDOCUMENTED it does not — a real duplicate, and a failure
#
#   Verbatim, and matching on the heading TEXT rather than a line number,
#   because line numbers move on every append and a suppression keyed to one
#   silently stops matching — at which point it is not a check at all.
#
# USAGE
#   check-duplicate-headings.sh [journal] [declaration]
#   defaults: journals/AI-1/JOURNAL.md and journals/KNOWN-DUPLICATES.md
#   exit 0 = no undocumented duplicate. exit 1 = one or more.
set -uo pipefail
W="$HOME/homelab/wiki"
J="${1:-$W/journals/AI-1/JOURNAL.md}"
DECL="${2:-$W/journals/KNOWN-DUPLICATES.md}"
rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }
note(){ printf '  ..    %s\n' "$*"; }

echo "=== the inputs must EXIST, or this reports on nothing ==="
[ -f "$J" ]    || { bad "no journal at ${J/#$HOME/~} - refusing to report a clean result"; exit 3; }
# ${J/#$HOMELAB/...} was wrong: HOMELAB is not set in this script, so the
# expansion replaced an empty pattern and printed a leading ellipsis in front of
# an absolute path. A cosmetic bug in the one line that tells the reader WHICH
# file was examined - the line that makes the whole report checkable.
ok "journal:    ${J/#$HOME/~} ($(grep -c '^' "$J") lines)"
if [ -f "$DECL" ]; then ok "declaration: ${DECL/#$HOME/~} ($(grep -c '^' "$DECL") lines)"
else
  note "no declaration file at ${DECL/#$HOME/~}"
  note "with none, every duplicate is UNDOCUMENTED - which is the safe direction"
fi

total=$(grep -c '^## ' "$J" 2>/dev/null || echo 0)
note "$total headings in the file"

exp=0; und=0
while IFS= read -r d; do
  [ -z "$d" ] && continue
  if [ -f "$DECL" ] && grep -qF -- "$d" "$DECL" 2>/dev/null; then
    ok "EXPECTED (declared verbatim): $(printf '%s' "$d" | cut -c1-84)"
    note "  at lines: $(grep -nF -- "$d" "$J" | cut -d: -f1 | tr '\n' ' ')"
    exp=$((exp+1))
  else
    bad "UNDOCUMENTED duplicate: $(printf '%s' "$d" | cut -c1-84)"
    note "  at lines: $(grep -nF -- "$d" "$J" | cut -d: -f1 | tr '\n' ' ')"
    note "  this one is NOT in KNOWN-DUPLICATES.md, so nobody ever decided to keep it."
    note "  Investigate before deleting: it may be two different entries sharing a"
    note "  heading, in which case the HEADING is what needs fixing, not a copy."
    und=$((und+1))
  fi
done < <(grep '^## ' "$J" 2>/dev/null | sort | uniq -d)

echo
if [ "$und" -eq 0 ] && [ "$exp" -eq 0 ]; then
  ok "no duplicate headings at all"
elif [ "$und" -eq 0 ]; then
  ok "all $exp duplicate(s) are declared retentions - no undocumented duplicate"
else
  bad "$und undocumented duplicate(s), $exp declared"
fi
note "judgement call: a duplicate is not automatically a mistake. Deleting a copy"
note "of append-only history to tidy a scan is a silent edit, and that is worse"
note "than the noise it removes."

printf '\n'
if [ "$rc" -eq 0 ]; then echo "=== ALL OK ==="; else echo "=== UNDOCUMENTED DUPLICATES ==="; fi
exit $rc
