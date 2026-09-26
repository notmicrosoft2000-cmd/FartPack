#!/usr/bin/env bash
# Append journal entries by COPYING FILES, never by heredoc.
#
# The first attempt at this used `cat >> file <<EOF` with escaped backticks and it
# appended nothing at all, silently, under `set -e`. Markdown is full of backticks,
# `$(...)`, `$VAR` and `!`, so the only reliable way to move prose into a file on
# this box is: write it locally, scp it, `cat >>`. No shell ever sees the text.
set -euo pipefail
H="$HOME/homelab"
# Two headers, because the two journals are written independently and do NOT share
# wording. Checking both for one string was wrong and reported a false failure on a
# perfectly good append.
HEADER_AI="${1:?usage: journal-append.sh '<AI-JOURNAL header>' '<server-info header>'}"
HEADER_SV="${2:?usage: journal-append.sh '<AI-JOURNAL header>' '<server-info header>'}"

# --verify re-runs only the checks, so a failed check can be re-examined without
# appending the same entry a second time.
if [ "${3:-}" = "--verify" ]; then
  rc=0
  for pair in "$HEADER_AI:AI-JOURNAL.md" "$HEADER_SV:server-info/JOURNAL.md"; do
    hdr="${pair%%:*}"; f="${pair##*:}"
    n=$(grep -cF "$hdr" "$H/$f" || true)
    esc=$(grep -c '\\`' "$H/$f" || true)
    echo "  $f: $n occurrence(s) of its header, ${esc:-0} stray backslash-backticks, $(wc -l < "$H/$f") lines total"
    [ "${n:-0}" -eq 1 ] || { echo "  FAIL: $f header count is $n, expected 1"; rc=1; }
    [ "${esc:-0}" -eq 0 ] || { echo "  FAIL: $f has escaped backticks"; rc=1; }
  done
  exit $rc
fi

# Record exactly where we started, so the operation is verifiable afterwards.
before_ai=$(wc -l < "$H/AI-JOURNAL.md")
before_sv=$(wc -l < "$H/server-info/JOURNAL.md")

for pair in "/tmp/append-ai.md:AI-JOURNAL.md" "/tmp/append-server.md:server-info/JOURNAL.md"; do
  src="${pair%%:*}"
  dst="$H/${pair##*:}"
  [ -s "$src" ] || { echo "FATAL: $src missing or empty"; exit 1; }
  cp "$dst" "$dst.bak-journal-$(date +%H%M%S)"
  cat "$src" >> "$dst"
  echo "appended $(wc -l < "$src") lines to ${pair##*:}"
done

echo
echo "=== verify the append actually landed ==="
now_ai=$(wc -l < "$H/AI-JOURNAL.md")
now_sv=$(wc -l < "$H/server-info/JOURNAL.md")
echo "  AI-JOURNAL.md      $before_ai -> $now_ai  (delta $((now_ai - before_ai)))"
echo "  server-info/JOURNAL.md $before_sv -> $now_sv  (delta $((now_sv - before_sv)))"
[ "$now_ai" -gt "$before_ai" ] || { echo "  FAIL: AI-JOURNAL did not grow"; exit 1; }
[ "$now_sv" -gt "$before_sv" ] || { echo "  FAIL: server-info JOURNAL did not grow"; exit 1; }

for pair in "$HEADER_AI:AI-JOURNAL.md" "$HEADER_SV:server-info/JOURNAL.md"; do
  hdr="${pair%%:*}"; f="${pair##*:}"
  n=$(grep -cF "$hdr" "$H/$f" || true)
  esc=$(grep -c '\\`' "$H/$f" || true)
  echo "  $f: $n occurrence(s) of its header, ${esc:-0} stray backslash-backticks, $(wc -l < "$H/$f") lines"
  [ "${n:-0}" -eq 1 ] || { echo "  FAIL: $f header count is $n, expected 1"; exit 1; }
  # backticks must have survived as real backticks, not as escaped \` sequences
  [ "${esc:-0}" -eq 0 ] || { echo "  FAIL: $f has escaped backticks"; exit 1; }
done
echo "OK"
done

echo
echo "=== new section headers now present ==="
grep -n '^## ' "$H/AI-JOURNAL.md" | tail -2 | sed 's/^/  AI:    /'
grep -n '^## ' "$H/server-info/JOURNAL.md" | tail -2 | sed 's/^/  SRV:   /'
echo
echo "OK - both journals updated"
