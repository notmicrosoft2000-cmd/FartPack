#!/usr/bin/env bash
# Append journal entries by COPYING FILES, never by heredoc.
#
# The first attempt at this used `cat >> file <<EOF` with escaped backticks and it
# appended nothing at all, silently, under `set -e`. Markdown is full of backticks,
# `$(...)`, `$VAR` and `!`, so the only reliable way to move prose into a file on
# this box is: write it locally, scp it, `cat >>`. No shell ever sees the text.
set -euo pipefail
H="$HOME/homelab"

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

for f in AI-JOURNAL.md server-info/JOURNAL.md; do
  n=$(grep -c '2026-09-26 14:59 +0630' "$H/$f" || true)
  echo "  $f: $n occurrence(s) of the new section header"
  [ "${n:-0}" -eq 1 ] || { echo "  FAIL: $f header count is $n, expected 1"; exit 1; }
  # backticks must have survived as real backticks, not as escaped \` sequences
  esc=$(grep -c '\\`' "$H/$f" || true)
  echo "  $f: ${esc:-0} stray backslash-backticks"
  [ "${esc:-0}" -eq 0 ] || { echo "  FAIL: $f has escaped backticks"; exit 1; }
done

echo
echo "=== new section headers now present ==="
grep -n '^## ' "$H/AI-JOURNAL.md" | tail -2 | sed 's/^/  AI:    /'
grep -n '^## ' "$H/server-info/JOURNAL.md" | tail -2 | sed 's/^/  SRV:   /'
echo
echo "OK - both journals updated"
