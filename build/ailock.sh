#!/usr/bin/env bash
# ailock.sh - the ai.lock protocol as a tool.
#
# WHY THIS EXISTS: a lock file cannot stop a write. It works only because every
# AI reads before it writes. This script's job is to make "I didn't notice"
# impossible -- `take` HARD-FAILS when a live lock is already present, and names
# the holder. See wiki/02-FILE-OWNERSHIP-AND-LOCKS.md.
#
# A file cannot stop a write. This works only because AIs read before they write.
# Do not treat acquiring a lock as permission to take over someone else's area --
# a lock coordinates AI-to-AI. It never replaces asking the human.
#
#   ailock.sh take  <dir> [reason]   acquire; refuse if a live lock is present
#   ailock.sh hold  <dir>            refresh the timestamp (for long jobs)
#   ailock.sh show                  every lock on the box, with age and staleness
#   ailock.sh check <dir>           exit 1 if locked. For use in scripts/CI.
#   ailock.sh guard <dir> <cmd...>  take, run cmd, drop. Always drops, even on fail.
#   ailock.sh drop  <dir> [note]    release a lock YOU hold
#   ailock.sh steal <dir> <reason>  take over a STALE lock. Logged. Must justify.
#
# Env: AI_ID (default: auto-detect from $AI_REGISTRY_FILE, else "unknown")
#      AI_STALE_MINUTES (default 30)
set -uo pipefail

# WIKI is overridable so a test can take a REAL lock on a scratch path without
# appending a hundred audit records to the real SHARED-STATE-LOG.md. A log full
# of test noise is a log people stop reading, and this log is the evidence that
# the lock protocol was actually followed.
WIKI="${WIKI:-$HOME/homelab/wiki}"
STATE_LOG="$WIKI/journals/SHARED-STATE-LOG.md"
LOCKNAME="ai.lock"
STALE_MIN="${AI_STALE_MINUTES:-30}"
AI_ID="${AI_ID:-unknown}"

now()  { date '+%Y-%m-%d %H:%M:%S %z'; }
log()  { printf '%s\n' "$*"; }
die()  { printf 'ailock: %s\n' "$*" >&2; exit 1; }

# What the last cmd_take actually did. A caller that assumes "take returned 0, so
# a lock now exists" is wrong whenever this says 'covered' - which is how guard
# used to end up trying to drop a lock it never took.
TAKE_RESULT=""

# Normalise a path to an absolute, symlink-free form so that ancestor checks are
# reliable. `realpath -m` resolves a path that does not exist yet, which matters:
# you often want to lock a directory you are about to create.
abspath() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then realpath -m -- "$p"; else
    case "$p" in /*) printf '%s\n' "$p" ;; *) printf '%s/%s\n' "$PWD" "$p" ;; esac
  fi
}

# Read a key out of a lock file. Keys are "key: value" with two-space indent.
lockval() { grep -m1 "^$2:" "$1" 2>/dev/null | sed -E "s/^$2:[[:space:]]*//"; }

lock_age_min() {
  local f="$1" m
  m=$(stat -c %Y -- "$f" 2>/dev/null) || { echo 999999; return; }
  echo $(( ( $(date +%s) - m ) / 60 ))
}

# Is a pid alive? Only meaningful on this host, so an empty host field or a
# different host is reported as "unknown", never as "dead".
pid_alive() {
  local pid="$1" host="$2" me
  me=$(hostname 2>/dev/null || echo unknown)
  [ -n "$pid" ] || { echo unknown; return; }
  [ "$host" = "$me" ] || { echo unknown; return; }
  case "$pid" in (*[!0-9]*|'') echo unknown; return ;; esac
  if kill -0 "$pid" 2>/dev/null; then echo alive; else echo dead; fi
}

# Do I already hold this folder, or an ancestor of it?
held_by_me() {
  local target="$1" d ai host pid
  d=$(abspath "$target")
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    if [ -f "$d/$LOCKNAME" ]; then
      ai=$(lockval "$d/$LOCKNAME" ai)
      host=$(lockval "$d/$LOCKNAME" host)
      pid=$(lockval "$d/$LOCKNAME" pid)
      if [ "$ai" = "$AI_ID" ]; then
        printf '%s\n' "$d"
        return 0
      fi
      # Someone else's lock in an ancestor: that also blocks us.
      printf 'BLOCKED-BY %s (ai=%s host=%s pid=%s)\n' "$d" "$ai" "$host" "$pid"
      return 2
    fi
    d=$(dirname "$d")
  done
  return 1
}

# Any descendant of $1 holding a lock? (depth-limited; a live tree is shallow)
descendant_locks() {
  local root="$1" max=6 d=0 cur f
  cur="$root"
  while [ "$d" -lt "$max" ]; do
    for sub in "$cur"/*/; do
      [ -d "$sub" ] || continue
      if [ -f "$sub/$LOCKNAME" ]; then printf '%s\n' "${sub%/}"; fi
      d=$((d+1))
    done
    break
  done
}

append_state() {
  # Create the log rather than skipping the write if it is missing. A lock event
  # that is recorded nowhere is exactly the invisible-collision case this
  # protocol exists to prevent.
  if [ ! -f "$STATE_LOG" ]; then
    mkdir -p "$(dirname "$STATE_LOG")" 2>/dev/null || return 0
    {
      printf '# SHARED STATE LOG\n\n'
      printf 'What changed on this machine: where, why, how to revert. Shared by every\n'
      printf 'AI because the machine is shared even when the work is not.\n\n'
      printf 'Per-AI narrative lives in journals/AI-<N>/JOURNAL.md.\n\n'
      printf 'Appended to by wiki/bin/ailock.sh for lock events, and by hand for\n'
      printf 'everything else. Never heredoc an append - see 04-AI-RULES.md.\n'
    } > "$STATE_LOG" 2>/dev/null || return 0
  fi
  printf '\n### %s - %s\n\n%s\n' "$(now)" "$1" "$2" >> "$STATE_LOG"
}

cmd_take() {
  local target="${1:-}" reason="${2:-no reason given}"
  [ -n "$target" ] || die "usage: ailock.sh take <dir> [reason]"
  local d; d=$(abspath "$target")
  [ -d "$d" ] || die "not a directory: $d"
  [ -w "$d" ] || die "not writable, cannot place $LOCKNAME: $d"

  if [ -f "$d/$LOCKNAME" ]; then
    local age ai host pid since alive
    age=$(lock_age_min "$d/$LOCKNAME")
    ai=$(lockval "$d/$LOCKNAME" ai)
    host=$(lockval "$d/$LOCKNAME" host)
    pid=$(lockval "$d/$LOCKNAME" pid)
    since=$(lockval "$d/$LOCKNAME" since)
    alive=$(pid_alive "$pid" "$host")

    # MY lock: re-taking it is a no-op, not a conflict. Refusing here would make
    # the tool unusable, because a long job legitimately re-enters this path.
    if [ "$ai" = "$AI_ID" ]; then
      touch "$d/$LOCKNAME" || die "held by $AI_ID but could not refresh $d/$LOCKNAME"
      TAKE_RESULT="mine"
      log "Already held by $AI_ID: $d  (timestamp refreshed, $(now))"
      return 0
    fi

    log "REFUSED: $d is already locked by someone else."
    log "  held by : ${ai:-unknown} (host ${host:-unknown}, pid ${pid:-unknown})"
    log "  since   : ${since:-unknown}  (${age} min ago; stale after ${STALE_MIN} min)"
    log "  process : $alive"
    log ""
    if [ "$age" -ge "$STALE_MIN" ] && [ "$alive" != "alive" ]; then
      log "  Looks STALE. Before taking over:"
      log "    1. check wiki/registry/README.md - is that AI really gone?"
      log "    2. ask the user."
      log "    3. ailock.sh steal $d \"why\"    <- mandatory reason, gets logged"
    elif [ "$alive" = "dead" ]; then
      log "  The holder's process is gone, but the lock is only ${age} min old."
      log "  A dead pid does NOT mean abandoned: the AI may run many short"
      log "  processes, and the work may be mid-flight in a session you cannot see."
      log "  Wait, or ask the user. Do not treat this as an invitation."
    else
      log "  It is LIVE. Wait until it is removed. Do not work here."
      log "  If you are blocked, say so in your journal - silent blocking looks lazy."
    fi
    return 3
  fi

  # A lock somewhere below us also means someone is working in here.
  local below; below=$(descendant_locks "$d")
  if [ -n "$below" ]; then
    log "REFUSED: a lock exists BELOW $d:"
    printf '  %s\n' "$below"
    log "  Lock that folder instead of its parent, or wait."
    return 3
  fi

  local self
  if self=$(held_by_me "$d"); then
    TAKE_RESULT="covered"
    log "Already held by $AI_ID at: $self"
    log "  (a lock on an ancestor covers this folder - no second lock needed)"
    return 0
  else
    local rc=$?
    if [ "$rc" -eq 2 ]; then
      log "REFUSED: $self"
      log "  That is an ancestor folder. Wait for it to be released."
      return 3
    fi
  fi

  {
    printf '# %s - see wiki/02-FILE-OWNERSHIP-AND-LOCKS.md\n' "$LOCKNAME"
    printf '# A file cannot stop a write. This works only because AIs read first.\n'
    printf 'ai:        %s\n' "$AI_ID"
    printf 'host:      %s\n' "$(hostname 2>/dev/null || echo unknown)"
    printf 'pid:       %s\n' "$$"
    printf 'since:     %s\n' "$(now)"
    printf 'reason:    %s\n' "$reason"
    printf 'journal:   %s\n' "$WIKI/journals/$AI_ID/JOURNAL.md"
    printf '#\n'
    printf '# Stale after %s minutes. Do not steal a live lock.\n' "$STALE_MIN"
    printf '# Release: ailock.sh drop %s "done"\n' "$d"
  } > "$d/$LOCKNAME" || die "could not write $d/$LOCKNAME"

  # Verify it actually landed. A lock you think you took and did not is worse
  # than no lock, because it is a false claim of exclusivity.
  if [ ! -s "$d/$LOCKNAME" ]; then
    die "wrote $LOCKNAME but it is not there. Aborting - treat this folder as UNSAFE."
  fi

  log "LOCKED  $d"
  log "  by $AI_ID (pid $$, host $(hostname 2>/dev/null || echo unknown))"
  log "  reason: $reason"
  log "  release: ailock.sh drop $d \"done\""
  TAKE_RESULT="created"
}

cmd_hold() {
  local target="${1:-}"
  [ -n "$target" ] || die "usage: ailock.sh hold <dir>"
  local d; d=$(abspath "$target")
  [ -f "$d/$LOCKNAME" ] || die "no lock in $d (take one first)"
  local ai; ai=$(lockval "$d/$LOCKNAME" ai)
  [ "$ai" = "$AI_ID" ] || die "$d is held by ${ai:-unknown}, not $AI_ID. Not touching it."
  touch "$d/$LOCKNAME" || die "could not refresh $d/$LOCKNAME"
  log "REFRESHED $d (stale clock reset; $(now))"
}

cmd_show() {
  log "=== ai.lock inventory ($(now)) ==="
  log "stale after ${STALE_MIN} min; I am $AI_ID on $(hostname 2>/dev/null || echo unknown)"
  local found=0 f
  while IFS= read -r f; do
    found=1
    local d; d=$(dirname "$f")
    local age ai host pid since alive
    age=$(lock_age_min "$f")
    ai=$(lockval "$f" ai); host=$(lockval "$f" host)
    pid=$(lockval "$f" pid); since=$(lockval "$f" since)
    alive=$(pid_alive "$pid" "$host")
    local state="LIVE"
    if [ "$ai" = "$AI_ID" ]; then state="MINE"; fi
    if [ "$age" -ge "$STALE_MIN" ] && [ "$alive" != "alive" ]; then state="STALE"; fi
    log ""
    log "  $d/$LOCKNAME  [$state]"
    log "    ai     : ${ai:-unknown}"
    log "    host   : ${host:-unknown}   pid: ${pid:-unknown} (process $alive)"
    log "    since  : ${since:-unknown}   age: ${age} min"
    log "    reason : $(lockval "$f" reason)"
  done < <(find "$HOME" -maxdepth 6 -name "$LOCKNAME" 2>/dev/null | sort)
  [ "$found" -eq 1 ] || log ""
  log "  (none found)"
  log ""
  log "Reminder: a lock is a courtesy flag. It does not stop a write, and it is"
  log "not permission to take over an area you do not own."
}

cmd_check() {
  local target="${1:-}"
  [ -n "$target" ] || die "usage: ailock.sh check <dir>"
  local d; d=$(abspath "$target")
  if [ -f "$d/$LOCKNAME" ]; then
    log "LOCKED: $d held by $(lockval "$d/$LOCKNAME" ai) since $(lockval "$d/$LOCKNAME" since)" >&2
    return 1
  fi
  return 0
}

cmd_guard() {
  local target="${1:-}"; shift || true
  [ -n "$target" ] || die "usage: ailock.sh guard <dir> <cmd> [args...]"
  [ "$#" -ge 1 ] || die "guard needs a command to run"
  cmd_take "$target" "guard: $*" || exit $?
  # `take` can succeed WITHOUT creating a lock here, when an ancestor is already
  # locked by us. Running the command is then fine, but there is nothing in THIS
  # directory to release - and a drop that finds nothing used to turn a
  # successful run into a failure.
  if [ "$TAKE_RESULT" = "covered" ]; then
    log "  (ancestor already locked by $AI_ID; nothing to release here)"
    "$@"
    return $?
  fi
  # Always release, even if the command fails or we are killed after this point.
  trap 'cmd_drop "$target" "guard finished (or was interrupted)"' EXIT INT TERM
  "$@"
  local rc=$?
  trap - EXIT INT TERM
  cmd_drop "$target" "guard finished rc=$rc"
  return $rc
}

cmd_drop() {
  local target="${1:-}" note="${2:-done}"
  [ -n "$target" ] || die "usage: ailock.sh drop <dir> [note]"
  local d; d=$(abspath "$target")
  [ -f "$d/$LOCKNAME" ] || die "no lock in $d - nothing to release"
  local ai; ai=$(lockval "$d/$LOCKNAME" ai)
  if [ "$ai" != "$AI_ID" ]; then
    die "$d is held by ${ai:-unknown}, not $AI_ID. Refusing to delete someone else's lock."
  fi
  local since; since=$(lockval "$d/$LOCKNAME" since)
  rm -f "$d/$LOCKNAME" || die "could not remove $d/$LOCKNAME"
  if [ -e "$d/$LOCKNAME" ]; then
    die "lock still present after rm. Treat $d as STILL LOCKED."
  fi
  append_state "lock released" "folder: $d
held by: $AI_ID since $since
released: $note"
  log "UNLOCKED $d  ($note)"
}

cmd_steal() {
  local target="${1:-}" reason="${2:-}"
  [ -n "$reason" ] || die "usage: ailock.sh steal <dir> \"reason\"
A reason is mandatory. An unexplained takeover is indistinguishable from the
collision this protocol exists to prevent."
  local d; d=$(abspath "$target")
  [ -f "$d/$LOCKNAME" ] || die "no lock in $d - just use 'take'"
  local age ai host pid since alive
  age=$(lock_age_min "$d/$LOCKNAME")
  ai=$(lockval "$d/$LOCKNAME" ai); host=$(lockval "$d/$LOCKNAME" host)
  pid=$(lockval "$d/$LOCKNAME" pid); since=$(lockval "$d/$LOCKNAME" since)
  alive=$(pid_alive "$pid" "$host")

  # A lock with no identity in it was not written by this tool. It may be a
  # half-finished write, a stray file, or something a human put there. Treating
  # it as an abandoned lock and taking over would be exactly the unaccountable
  # takeover this protocol exists to prevent.
  if [ -z "$ai" ] || [ "$ai" = "unknown" ]; then
    die "REFUSING to steal $d.
The ai.lock there carries no owner (ai: field is '${ai:-<empty>}'), so I cannot
tell who it belongs to or whether it is really abandoned. That usually means a
half-written lock file, or a marker some other tool put there.
Look at it by hand:  cat '$d/$LOCKNAME'
Then either remove it yourself, or keep the copy at
  $d/$LOCKNAME.reason.$AI_ID.$$  and re-run."
  fi

  if [ "$alive" = "alive" ]; then
    die "REFUSING to steal. ${ai:-unknown}'s process (pid $pid on $host) is ALIVE.
A lock can be old and still valid - long jobs are normal. Wait, or ask the user."
  fi
  if [ "$age" -lt "$STALE_MIN" ]; then
    die "REFUSING to steal. Lock is only ${age} min old (threshold ${STALE_MIN}).
If you are certain the holder is gone, wait for it to go stale, or ask the user
to confirm. A lock under ${STALE_MIN} min old is not abandoned, it is young."
  fi
  append_state "LOCK STOLEN" "folder: $d
originally held by: ${ai:-unknown} (host ${host:-unknown}, pid ${pid:-unknown}, since ${since:-unknown})
age at takeover: ${age} min (threshold ${STALE_MIN})
process state: $alive
taken by: $AI_ID
REASON: $reason"
  printf '%s\n' "$reason" > "$d/$LOCKNAME.reason.$AI_ID.$$"
  rm -f "$d/$LOCKNAME" || die "could not remove the stale lock"
  log "STALE LOCK TAKEN OVER: $d"
  log "  was held by ${ai:-unknown} for ${age} min (process $alive)"
  log "  reason: $reason"
  log "  This is recorded in journals/SHARED-STATE-LOG.md."
  cmd_take "$d" "took over a stale lock: $reason" || exit $?
  # The takeover is only real if a lock now exists. If an ancestor is locked by us
  # the take reports 'covered' and nothing is held HERE - saying "taken over"
  # at that point would be a false claim of exclusivity, which is the one thing
  # this tool must never do.
  if [ ! -f "$d/$LOCKNAME" ]; then
    append_state "LOCK STOLEN BUT NOT RE-ACQUIRED" "folder: $d
originally held by: $ai (host ${host:-unknown}, pid ${pid:-unknown}, since ${since:-unknown})
taken by: $AI_ID
REASON: $reason
OUTCOME: the stale lock was removed, but $d is NOT now locked (an ancestor is
already held by $AI_ID, which covers it). Treat $d as covered, not locked."
    log "  WARNING: stale lock removed, but $d is not directly locked."
    log "           An ancestor is held by $AI_ID, which does cover it."
    log "           Recorded in journals/SHARED-STATE-LOG.md."
    return 0
  fi
  log "  Now held by $AI_ID."
}

case "${1:-}" in
  take)  shift; cmd_take  "$@" ;;
  hold)  shift; cmd_hold  "$@" ;;
  show)  shift; cmd_show  "$@" ;;
  check) shift; cmd_check "$@" ;;
  guard) shift; cmd_guard "$@" ;;
  drop)  shift; cmd_drop  "$@" ;;
  steal) shift; cmd_steal "$@" ;;
  ""|-h|--help|help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command: $1 (try: ailock.sh --help)" ;;
esac
