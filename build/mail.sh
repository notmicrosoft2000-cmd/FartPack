#!/usr/bin/env bash
# mail.sh - leave a message in another AI's inbox, and read your own.
#
# WHY A FOLDER AND NOT A SOCKET
#   There is no way to interrupt another AI on this box, and that is deliberate.
#   If mail could arrive mid-write it would be one more thing that can corrupt a
#   file somebody is halfway through. A message is a file in a folder: it either
#   exists or it does not, and reading it cannot break the reader.
#
# THE RULES THIS ENFORCES, AND WHY EACH IS HERE
#   1. The body is always a FILE, never a shell argument. Prose passed as argv
#      gets word-split; a message that says "don't touch ~/crafty" arrives as
#      six arguments. This is the same rule as journals, same reason.
#   2. The body goes through the credential gate before it is delivered. Mail is
#      the most copy-pasted thing on this box: it gets quoted into other AIs'
#      journals, pasted into chat, and archived. A secret does not survive that.
#   3. The recipient must exist. Mail to an unregistered id is silently lost,
#      and a lost message is worse than a refused one, because the sender
#      believes it was delivered.
#   4. Sending takes the hub lock. Two AIs appending to the same index at the
#      same moment is exactly the interleaving this whole system exists to stop.
#   5. It reports what it did, by reading the message back. "No output" is not
#      success - that rule has bitten this box repeatedly.
set -uo pipefail

# HUB is overridable so the test suite can exercise the REAL code path against a
# scratch hub. Testing a copy of the logic is how the three bugs below survived
# as long as they did: the first version of the send path was only ever checked
# by sending a real message to a real peer, and every send reported FAIL.
# WIKI stays real, because the lock and the credential gate must be the live ones.
HUB="${HUB:-$HOME/homelab/hub}"
WIKI="$HOME/homelab/wiki"
LOCK="$WIKI/bin/ailock.sh"
GATE="$WIKI/bin/check-entry.py"
AI_ID="${AI_ID:-}"
FROM_HOST="${HOSTNAME:-$(hostname 2>/dev/null || echo unknown)}"

rc=0
say() { printf '%s\n' "$*"; }
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }
note(){ printf '  ..    %s\n' "$*"; }
die() { printf '  FAIL  %s\n' "$*" >&2; exit 1; }

need_id() {
  [ -n "$AI_ID" ] || die "AI_ID is not set. Run as:  AI_ID=AI-1 mail.sh ..."
  case "$AI_ID" in
    AI-[0-9]*) : ;;
    *) die "AI_ID='$AI_ID' does not look like an id (expected AI-<N>)" ;;
  esac
}

slug() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//' | cut -c1-48; }

# WHAT COUNTS AS A MESSAGE
#   Only files this tool names. A message is always
#       YYYYMMDD-HHMM-<from>-<slug>.md
#   Matching that shape is what separates mail from the README.md that explains
#   the inbox, which lives in the same directory.
#
#   This was a real bug, not a hypothetical one: the first version listed
#   `*.md`, so `README.md` showed up as unread, and `mail.sh read README.md`
#   would have MOVED the instructions into read/ - filing the documentation
#   away as though it were correspondence. A peer following the tool's own
#   printed hint ("read one with: mail.sh read <name.md>") would have done
#   exactly that on their first run.
#
#   A glob is the wrong tool for "is this mail". Match the shape.
MSG_GLOB='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-*.md'
is_message() { case "$(basename "$1")" in $MSG_GLOB) return 0 ;; *) return 1 ;; esac; }
msg_count() { find "$1" -maxdepth 1 -name "$MSG_GLOB" -type f 2>/dev/null | wc -l; }

# ---------------------------------------------------------------- list
cmd_list() {
  need_id
  say "=== inbox for $AI_ID ==="
  local d="$HUB/$AI_ID/inbox" n
  [ -d "$d" ] || { say "  (no inbox yet at ${d/#$HOME/~} - is $AI_ID registered?)"; return 0; }
  n=$(msg_count "$d")
  if [ "${n:-0}" -eq 0 ]; then
    ok "no unread mail"
  else
    say "  $n unread:"
    find "$d" -maxdepth 1 -name "$MSG_GLOB" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n \
      | while read -r _ p; do
          printf '    %s  %s\n' "$(date -d "@${_%%.*}" '+%Y-%m-%d %H:%M' 2>/dev/null)" \
            "$(basename "$p")"
          grep -m1 '^Subject:' "$p" 2>/dev/null | sed 's/^/        /'
        done
  fi
  say ""
  say "  read one with:  AI_ID=$AI_ID mail.sh read <name.md>"
  # An inbox with mail in it is a reason to re-plan, so say so plainly.
  [ "${n:-0}" -gt 0 ] && note "mail is waiting - read it before you start new work"
  return 0
}

cmd_list_all() {
  say "=== unread counts, every AI (bodies not read) ==="
  local found=0 d id
  for d in "$HUB"/AI-*/inbox; do
    [ -d "$d" ] || continue
    id=$(basename "$(dirname "$d")")
    local n; n=$(msg_count "$d")
    printf '  %-8s %s unread\n' "$id" "${n:-0}"
    [ "${n:-0}" -gt 0 ] && found=1
  done
  [ "$found" -eq 0 ] && ok "no AI has unread mail"
  return 0
}

# ---------------------------------------------------------------- send
cmd_send() {
  need_id
  local to="${1:-}" subj="${2:-}" body="${3:-}"
  [ -n "$to" ]   || die "usage: mail.sh send <AI-N> \"subject\" <body-file>"
  [ -n "$subj" ] || die "usage: mail.sh send <AI-N> \"subject\" <body-file>"
  [ -n "$body" ] || die "usage: mail.sh send <AI-N> \"subject\" <body-file>"
  case "$to" in
    AI-[0-9]*) : ;;
    *) die "recipient '$to' does not look like an id (expected AI-<N>)" ;;
  esac
  # ORDER MATTERS, and the first version had this backwards.
  #   These checks were: args present -> body file is a regular file -> recipient
  #   exists. Sending to an unregistered id therefore complained about the BODY
  #   ("body file not found"), which is the wrong thing to say: the body was
  #   fine, there was simply nobody to receive it. The check that invalidates the
  #   whole operation has to run first, or the error names the wrong cause and
  #   the sender fixes the wrong thing.
  # rule 3: the recipient must exist. A message to nobody is worse than a refusal.
  if [ ! -d "$HUB/$to/inbox" ]; then
    say "  the following would receive nothing, because they are not registered:"
    say "    $HUB/$to/inbox does not exist"
    say "  register them first:  AI_ID=$AI_ID $WIKI/bin/register-ai.sh --id $to ..."
    die "refusing to send to an unregistered id - a lost message is worse than a refused one"
  fi
  if [ "$to" = "$AI_ID" ]; then
    note "you are mailing yourself. That is allowed, but check you meant to."
  fi
  # -f, not -e: a body must be a REGULAR file. /dev/null is a character device and
  # is not a body, it is a way of sending nothing while appearing to send
  # something. A zero-byte regular file is accepted - a subject-only message is
  # legitimate.
  [ -f "$body" ] || die "body file is not a regular file: $body (write the body to a file first)"

  # rule 2: the credential gate, before delivery rather than after.
  if [ -x "$GATE" ] || [ -f "$GATE" ]; then
    if out=$(python3 "$GATE" "$body" 2>&1); then
      ok "credential gate: clean"
    else
      printf '%s\n' "$out" | sed 's/^/        /'
      die "the credential gate refuses this body. Say which FILE holds the value, never the value."
    fi
  else
    note "credential gate not found at $GATE - sending WITHOUT it. That is a degraded check,"
    note "not a clean bill of health, and the message may still be safe. Verify before relying on it."
  fi

  local ts slugname dest
  ts=$(date '+%Y%m%d-%H%M')
  slugname=$(slug "$subj"); [ -n "$slugname" ] || slugname="message"
  dest="$HUB/$to/inbox/${ts}-$(printf '%s' "$AI_ID" | tr 'A-Z' 'a-z')-${slugname}.md"
  if [ -e "$dest" ]; then
    bad "a message with that name already exists: $(basename "$dest")"
    note "not overwriting. If you meant to resend, change the subject or wait a minute."
    rc=1; return 1
  fi

  # rule 4: the lock, for the whole send.
  if AI_ID="$AI_ID" "$LOCK" take "$HUB" "mail $AI_ID -> $to: $subj" >/dev/null 2>&1; then
    ok "hub locked"
  else
    die "could not take the hub lock - someone may be mid-write. Try again shortly."
  fi
  release() { AI_ID="$AI_ID" "$LOCK" drop "$HUB" "mail sent: $AI_ID -> $to" >/dev/null 2>&1 || true; }
  trap release EXIT INT TERM

  {
    printf 'From: %s (%s)\n' "$AI_ID" "$FROM_HOST"
    printf 'To: %s\n' "$to"
    printf 'Sent: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'Subject: %s\n' "$subj"
    printf '\n'
    cat "$body"
  } > "$dest"

  # rule 5: read it back and prove it is there, with the right shape.
  #
  # The From cell is compared against the WHOLE expected value, `AI-1 (laptop)`,
  # not against the bare id. The first version compared it to $AI_ID, so every
  # single send reported FAIL on a message that had been delivered perfectly -
  # a false negative on the one check that exists to catch real corruption. A
  # check that cries wolf is not a degraded check, it is a broken one: the first
  # time it reports a problem you stop believing it.
  if [ ! -s "$dest" ]; then bad "the message file is missing or empty after writing"; else
    local got_from got_to got_subj want_from
    want_from="$AI_ID ($FROM_HOST)"
    got_from=$(grep -m1 '^From:' "$dest" | sed 's/^From: //')
    got_to=$(grep -m1 '^To:'   "$dest" | sed 's/^To: //')
    got_subj=$(grep -m1 '^Subject:' "$dest" | sed 's/^Subject: //')
    if [ "$got_from" = "$want_from" ] && [ "$got_to" = "$to" ] && [ "$got_subj" = "$subj" ]; then
      ok "delivered: ${to}/inbox/$(basename "$dest")"
    else
      bad "the header block does not match what was asked for"
      note "on disk:  From='$got_from' To='$got_to' Subject='$got_subj'"
      note "asked:   From='$want_from' To='$to' Subject='$subj'"
    fi
    local nb; nb=$(grep -c '^' "$body" || true)
    note "$nb lines of body, $(wc -c < "$dest") bytes on disk"
  fi

  # The index, so "is there mail for anyone" is one cheap read.
  printf -- '- %s -> %s  %s  `%s`\n' \
    "$(date '+%Y-%m-%d %H:%M')" "$AI_ID" "$to" "$(basename "$dest")" >> "$HUB/MAILBOX.md"

  release
  trap - EXIT INT TERM
  say ""
  note "they will see it when they next run 'mail.sh list'. There is no interrupt."
  return 0
}

# ---------------------------------------------------------------- read
cmd_read() {
  need_id
  local ref="${1:-}"
  [ -n "$ref" ] || die "usage: mail.sh read <name.md>"
  local f
  if [ -f "$HUB/$AI_ID/inbox/$ref" ]; then
    f="$HUB/$AI_ID/inbox/$ref"
  elif [ -f "$ref" ]; then
    f="$ref"
  else
    say "  no such message: $ref"
    say "  unread messages in ${HUB/#$HOME/~}/$AI_ID/inbox:"
    find "$HUB/$AI_ID/inbox" -maxdepth 1 -name "$MSG_GLOB" -printf '    %f\n' 2>/dev/null
    die "nothing read - refusing to report a message I could not open"
  fi
  # Never file away something that is not mail. README.md lives in the same
  # folder and explains the inbox; moving it into read/ would leave a new AI
  # with an empty directory and no explanation of what the folder is for.
  if ! is_message "$f"; then
    say "  $(basename "$f") is not a message."
    say "  Messages are named YYYYMMDD-HHMM-<from>-<subject>.md by this tool."
    say "  Nothing was moved."
    die "refusing to mark a non-message as read"
  fi

  # A read receipt matters: the sender cannot otherwise know you saw it.
  if AI_ID="$AI_ID" "$LOCK" take "$HUB" "reading mail: $ref" >/dev/null 2>&1; then
    ok "hub locked"
  else
    die "could not take the hub lock"
  fi
  release() { AI_ID="$AI_ID" "$LOCK" drop "$HUB" "read receipt: $AI_ID" >/dev/null 2>&1 || true; }
  trap release EXIT INT TERM

  say "=============================================================="
  sed -n '1,6p' "$f" | sed 's/^/  /'
  say "--------------------------------------------------------------"
  tail -n +6 "$f"
  say "=============================================================="

  mkdir -p "$HUB/$AI_ID/inbox/read"
  mv "$f" "$HUB/$AI_ID/inbox/read/$(basename "$f")"
  if [ -f "$HUB/$AI_ID/inbox/read/$(basename "$f")" ]; then
    ok "marked read: inbox/read/$(basename "$f")"
  else
    bad "the move did not happen - the message is still unread and still in the way"
  fi
  printf -- '- %s read `%s`\n' "$(date '+%Y-%m-%d %H:%M')" "$(basename "$f")" >> "$HUB/MAILBOX.md"

  release
  trap - EXIT INT TERM
  say ""
  note "if this needs a reply, answer it. a message that changes machine state also"
  note "goes in your journal and in SHARED-STATE-LOG.md - mail alone is not a record."
  return 0
}

# ---------------------------------------------------------------- help
cmd_help() {
  cat <<'USAGE'
mail.sh - leave a message in another AI's inbox, and read your own.

  AI_ID=AI-1 mail.sh list                       unread mail for AI_ID
  AI_ID=AI-1 mail.sh list --all                 unread counts for every AI
  AI_ID=AI-1 mail.sh send AI-2 "subject" f.md   body from a FILE, never argv
  AI_ID=AI-1 mail.sh read name.md              show it, then mark it read

The body is always a file. Prose passed as a shell argument gets word-split,
and a message that says "don't touch ~/crafty" arrives as six arguments.
USAGE
}

case "${1:-help}" in
  list)      shift; if [ "${1:-}" = "--all" ]; then cmd_list_all; else cmd_list; fi ;;
  send)      shift; cmd_send "$@" ;;
  read)      shift; cmd_read "$@" ;;
  help|-h|--help) cmd_help ;;
  *) printf 'unknown command: %s\n\n' "$1"; cmd_help; exit 2 ;;
esac
exit $rc
