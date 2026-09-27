#!/usr/bin/env bash
# test-mail.sh - exercise mail.sh against a SCRATCH hub, through the real code.
#
# WHY THIS EXISTS
#   mail.sh had three real bugs before it was ever used for anything important:
#     1. it validated the body file before checking the recipient, so mailing an
#        unregistered id blamed the body
#     2. the From readback compared against the bare id while the header holds
#        "AI-1 (laptop)", so EVERY send reported FAIL on a perfect message
#     3. it listed and filed *.md, so the inbox README.md counted as unread mail
#        and `mail.sh read README.md` would have moved the instructions away
#   All three were found by hand, one at a time, while trying to use the tool for
#   real. That is the expensive way to find them.
#
# WHY A SCRATCH HUB
#   Each of those bugs only shows up when you actually send, list and read. So the
#   tests do exactly that - against a temporary HUB, so a failing test cannot
#   leave junk in a peer's real inbox. The lock and the credential gate are the
#   LIVE ones, because those are the parts that must not be simulated.
#
# Nothing here touches a real inbox. The real lock is used on a scratch path, so
# every take/drop is a real lock event and every one is really logged.
set -uo pipefail
WIKI="$HOME/homelab/wiki"
MAIL="$WIKI/bin/mail.sh"
T=$(mktemp -d)
export HUB="$T/hub"
rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }
note(){ printf '  ..    %s\n' "$*"; }

cleanup() {
  # Drop the scratch lock if a test died holding it, or the next run cannot start.
  if [ -e "$HUB/ai.lock" ]; then
    AI_ID=AI-1 "$WIKI/bin/ailock.sh" drop "$HUB" "test cleanup" >/dev/null 2>&1 || true
  fi
  rm -rf "$T"
}
trap cleanup EXIT INT TERM

echo "=== scratch hub: ${HUB/#$HOME/~} (real lock, real credential gate) ==="
mkdir -p "$HUB/AI-1/inbox" "$HUB/AI-2/inbox" "$HUB/AI-1/inbox/read" "$HUB/AI-2/inbox/read"
printf '# scratch\n' > "$HUB/MAILBOX.md"

# A realistic body file, written to disk like the tool demands.
BODY="$T/body.md"
cat > "$BODY" <<'EOF'
A message body that is prose, with punctuation, and a path like ~/homelab/hub
in it, so that anything passing it as a shell argument would visibly break.
EOF

echo
echo "=== TEST 1: a first send reports success, not a false failure ==="
out=$(AI_ID=AI-1 bash "$MAIL" send AI-2 "first message" "$BODY" 2>&1); r=$?
if [ "$r" -eq 0 ] && printf '%s' "$out" | grep -q 'ok    delivered:'; then
  ok "send exits 0 and reports delivered"
else
  bad "send did not report success (rc=$r)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi
# The specific regression: the From cell is "AI-1 (host)", not "AI-1".
msg=$(ls "$HUB/AI-2/inbox"/[0-9]*.md 2>/dev/null | head -1)
if [ -n "$msg" ] && grep -q "^From: AI-1 (" "$msg"; then
  ok "the From header carries id and host, and the check accepts it"
else
  bad "the From header is not in the expected form"
  [ -n "$msg" ] && sed -n '1,4p' "$msg" | sed 's/^/        /'
fi

echo
echo "=== TEST 2: the body arrived whole, and prose was not word-split ==="
if [ -n "$msg" ]; then
  if tail -n +6 "$msg" | diff -q - "$BODY" >/dev/null 2>&1; then
    ok "the body is byte-identical to what was sent"
  else
    bad "the body was altered in transit"
    diff <(tail -n +6 "$msg") "$BODY" | head -6 | sed 's/^/        /'
  fi
  # The real assertion is the byte-identity diff above: a body passed as a FILE
  # and `cat`ed cannot be word-split, so there is nothing further to prove about
  # its shape. The token check below used to grep for the string "word-split",
  # which appears in this file's comment and NOT in the fixture - a check
  # asserting about something it never looked at, which is the failure mode that
  # has bitten this box all session. It now greps for tokens that are genuinely
  # in the body, so it fails if delivery ever mangles it.
  for tok in 'prose' '~/homelab/hub' 'visibly break'; do
    if grep -qF -- "$tok" "$msg"; then ok "delivered intact: '$tok'"
    else bad "token missing from the delivered message: '$tok'"; fi
  done
fi

echo
echo "=== TEST 3: an unregistered recipient is refused, blaming the RECIPIENT ==="
out=$(AI_ID=AI-1 bash "$MAIL" send AI-99 "should be refused" "$BODY" 2>&1); r=$?
if [ "$r" -ne 0 ] && printf '%s' "$out" | grep -q 'not registered'; then
  ok "refused, and the message names the recipient as the reason"
else
  bad "unregistered recipient not refused properly (rc=$r)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi
if printf '%s' "$out" | grep -qi 'body file'; then
  bad "it blamed the BODY for an unregistered recipient - the ordering bug"
else
  ok "it did not blame the body file"
fi

echo
echo "=== TEST 4: /dev/null is not a body ==="
out=$(AI_ID=AI-1 bash "$MAIL" send AI-2 "null body" /dev/null 2>&1); r=$?
if [ "$r" -ne 0 ] && printf '%s' "$out" | grep -q 'not a regular file'; then
  ok "a character device is refused as a body"
else
  bad "/dev/null was accepted or misreported (rc=$r)"
fi

echo
echo "=== TEST 5: README.md in the inbox is NOT unread mail ==="
printf '# AI-2 inbox docs\n' > "$HUB/AI-2/inbox/README.md"
out=$(AI_ID=AI-2 bash "$MAIL" list 2>&1)
n=$(printf '%s' "$out" | grep -cE '^    [0-9]{8}-[0-9]{4}-')
if printf '%s' "$out" | grep -q '1 unread'; then
  ok "list reports exactly 1 unread, not 2 - the README is excluded"
else
  bad "list miscounted unread mail"
  printf '%s\n' "$out" | sed 's/^/        /'
fi
if printf '%s' "$out" | grep -q 'README.md'; then
  bad "README.md is being listed as mail"
else
  ok "README.md does not appear in the listing"
fi

echo
echo "=== TEST 6: read refuses to file away a non-message ==="
out=$(AI_ID=AI-2 bash "$MAIL" read README.md 2>&1); r=$?
if [ "$r" -ne 0 ] && printf '%s' "$out" | grep -q 'not a message'; then
  ok "read refuses a non-message and says so"
else
  bad "read accepted a non-message (rc=$r)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi
if [ -f "$HUB/AI-2/inbox/README.md" ]; then
  ok "README.md is still in the inbox - nothing was moved"
else
  bad "README.md was MOVED - the documentation would be gone"
fi
if [ ! -e "$HUB/AI-2/inbox/read/README.md" ]; then
  ok "and nothing landed in read/ either"
else
  bad "README.md was filed into read/"
fi

echo
echo "=== TEST 7: reading a real message marks it read, once ==="
base=$(basename "$msg")
out=$(AI_ID=AI-2 bash "$MAIL" read "$base" 2>&1); r=$?
if [ "$r" -eq 0 ] && printf '%s' "$out" | grep -q 'ok    marked read'; then
  ok "read succeeds and reports the move"
else
  bad "read failed (rc=$r)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi
[ -f "$HUB/AI-2/inbox/read/$base" ] && ok "the message is in read/" || bad "the message is not in read/"
[ ! -f "$HUB/AI-2/inbox/$base" ] && ok "and gone from the unread folder" || bad "still in the unread folder"
out=$(AI_ID=AI-2 bash "$MAIL" list 2>&1)
printf '%s' "$out" | grep -q 'no unread mail' && ok "list now reports no unread mail" || bad "list still reports mail"
# A read receipt is the only evidence the sender gets. Assert it exists.
grep -q "read \`$base\`" "$HUB/MAILBOX.md" && ok "a read receipt was logged" || bad "no read receipt was logged"

echo
echo "=== TEST 8: re-sending the same subject in the same minute does not clobber ==="
# Retries after a partial failure are normal. Silently overwriting a delivered
# message would destroy the only copy of what was actually said.
AI_ID=AI-1 bash "$MAIL" send AI-2 "collision test" "$BODY" >/dev/null 2>&1
first=$(ls "$HUB/AI-2/inbox"/*collision-test.md 2>/dev/null | head -1)
if [ -n "$first" ]; then
  out=$(AI_ID=AI-1 bash "$MAIL" send AI-2 "collision test" "$BODY" 2>&1); r=$?
  if [ "$r" -ne 0 ] && printf '%s' "$out" | grep -qi 'already exists'; then
    ok "the duplicate is refused rather than overwriting"
  else
    bad "a same-minute duplicate send was not refused (rc=$r)"
  fi
  [ -f "$first" ] && ok "the original message is still there" || bad "the original was lost"
else
  bad "the first collision-test send did not land"
fi

echo
echo "=== TEST 9: no lock was left behind ==="
if [ -e "$HUB/ai.lock" ]; then
  bad "an ai.lock is still held on the scratch hub"
  cat "$HUB/ai.lock" 2>/dev/null | sed 's/^/        /'
else
  ok "no lock held - every take had a matching drop"
fi

echo
echo "=== TEST 10: the LIVE tool is the one under test, and carries the fixes ==="
# Byte-identity with the reviewed source is a build-time check, and install-hub.sh
# already does it with cmp. What matters at runtime is that the live file is the
# fixed one - so assert the three fixes are present in it, by name.
live=$(readlink -f "$MAIL")
if [ "$live" = "$(readlink -f "$WIKI/bin/mail.sh")" ]; then
  ok "this suite is testing the live tool at wiki/bin/mail.sh"
else
  bad "unexpected tool path: $live"
fi
has() { grep -qF -- "$1" "$MAIL" && ok "live tool has: $2" || bad "live tool is MISSING: $2"; }
has 'MSG_GLOB='                              'the message-shape filter (fix 3)'
has 'is_message()'                           'the non-message guard (fix 3)'
has 'want_from="$AI_ID ($FROM_HOST)"'        'the corrected From check (fix 2)'
has 'ORDER MATTERS, and the first version had this backwards' 'the recipient-before-body order (fix 1)'
# And it must not still contain the bug that shipped.
if sed 's/[[:space:]]*#.*$//' "$MAIL" | grep -q '\[ "$got_from" = "$AI_ID" \]'; then
  bad "live tool still compares From against the bare id (fix 2 reverted)"
else
  ok "live tool no longer has the bare-id From comparison"
fi

printf '\n'
if [ "$rc" -eq 0 ]; then echo "=== MAIL SUITE PASSED ==="; else echo "=== MAIL SUITE FAILED ==="; fi
exit $rc
