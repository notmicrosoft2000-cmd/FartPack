# build/ — tooling

Nothing in here ships to the server. These are the scripts used to verify and
deploy. Copy one to `/tmp` on the server with `scp` and run it there (the server
shell is **fish**, which does not expand aliases in `ssh -c` and cannot parse
heredocs — hence script files rather than inline commands).

## Datapack

| script | what it does |
|---|---|
| `lintpack.py <extracted-root>` | Parse-checks **every** command line in the pack against the live server's parser. Gate: must print `PARSE FAILURES: 0`. |
| `deploy.sh` | Installs `fartpack.zip`, enables it, reloads, then greps the log. **Aborts** if anyone is online or the player count cannot be read. |
| `verify.sh` | Post-deploy: lists every `Failed to load function` **with its timestamp** (so historical errors are not mistaken for new ones) and confirms the version gate fired. |
| `postrestart.sh` | Same idea, but for a **restart**: vanilla rotates `latest.log` on boot, so line-number marks are invalid. Checks the whole new file and asserts `Done (...)` is present. |
| `checkblocks.py <ids-file>` | Asks the live server whether each block id exists. **Required** after editing any `tags/block/*.json` — one unknown value silently kills the whole tag. |
| `checkrefs.py <pack-dir>` | **Static, no server needed.** Every `run function` target resolves to a real file, and every function is reachable from `load`/`tick`, an advancement reward, or the `MANUAL` list. Catches a mistyped function name, which is *not* a parse error — the pack loads and the branch silently never runs. |
| `genblocknames.py <pack-dir>` | Regenerates `world/block_name.mcfunction` from `tags/block/utility.json`. Run by `build.sh` on every build, so the lookup can never drift from the tag. |
| `lint.sh` | The full gate in one shot: asserts 0 players online (and **aborts if the count is unreadable**), flattens `tags/block/*.json` into an id list for `checkblocks.py`, then runs `lintpack.py`. |
| `stresstest.sh` | End-to-end test of the #22 crouch-strain fix against a real entity. |
| `verifyv20.sh` | Verifies #23 (block names, one lookup per block, with a control) and #24 (knockback `Motion` against a tagged chicken) and proves the `tp` machinery is gone. |
| `smoke.sh` | Drives `fartpack:tick` by hand ~70 times over RCON and checks the 30-tick cycle wraps and nothing errors. The only way to runtime-test while the server is paused. |
| `livecheck.sh` | Reads a counter twice and prints `ADVANCING` or `FROZEN`, so a paused server stops looking like a broken one. |
| `ticktest.sh` | Is the pack ticking right now, and did the last reload log anything bad? |
| `reaptest.sh` | Arms `#rc` to 199 and proves `core/reap` wipes stale `fart.gtick` rows and resets itself. |

## Ways a test here has lied to me

Every one of these produced output that looked like a real result. A test that
cannot fail is worse than no test, because it gets reported as a pass.

- **`R` must be an array.** `R="python3 /tmp/rcon.py"` then `"$R" 'cmd'` passes the
  whole string as ONE argv entry, so the shell looks for an executable literally
  named `python3 /tmp/rcon.py`. Every call fails. Unquoted `$R` accidentally works;
  quoted `"$R"` silently does nothing. Use `"${R[@]}"`.
- **A contaminated selector fails silently.** `@e[...],limit=1` puts `limit`
  *outside* the brackets, so it parses as an unlimited selector and errors. Worse,
  writing the explanation *inside* the quotes
  (`KBL="@e[...],limit=1]   # limit goes inside"`) makes the prose part of the
  selector. Both scripts now assert the selector is clean before doing anything.
- **Unquoted chunks fail silently.** `execute if block` in an unloaded chunk is a
  no-op with no error, and with 0 players the world pauses and chunks unload 60s
  after the last player leaves. Every scripted check must run inside a
  `forceload`ed chunk.
- **`setblock` lying about success.** It reports "Could not set the block" when it
  is a no-op, and with an unknown id it fails *leaving the previous block in
  place*. A control case that never places anything just re-reports the last loop
  iteration and looks like a lookup bug. Confirm with `execute if block`.
- **The subject must be stationary.** `player/stress` decides "did you move?" by
  comparing `Pos*100` against `fart.lastx`/`lastz`. A live chicken wanders, so it
  moved between priming and the call, the movement branch fired, and stress came
  back `1` instead of `0` — which is the fix *working*, reported as a failure. Use
  `NoAI:1b`.
- **Do not assert absolute health on a mob.** `summon ... {Health:20.0f}` does not
  give a chicken 20 HP; `max_health` clamps it to 4 on the first tick, so every
  read was `4.0` whether or not damage landed. Assert the delta from a baseline.
- **A test case that cannot fail.** The #24 "diagonal" case hardcoded the source Z
  to the bird's own Z, so `dz` was 0 and it was secretly identical to the straight
  case. It dutifully reported the straight-case numbers.
- **A range gate looks like an exact one.** `#scan_c matches 10..` runs on all 20
  values in the range. Use exact tick numbers.
- **`data modify <storage> <key> add value 1` is rejected** by this server. Build
  a list and count commas.
- **`say` is not captured by rcon.py.** Assert with `data get` or `scoreboard
  players get` instead.
- **Reading one RCON packet silently truncates.** `rcon.py` drains to the type-2
  terminator; do not hand-roll a single `recv`.
- **A `#` mid-line is not a comment.** It is a scoreboard fake-player name
  (`#scan_c`, `#loaded`). Only a `#` in the leading whitespace starts a comment.
  Stripping from the first `#` deletes the entire 30-tick cycle from your own
  analysis — this is a real bug that shipped inside `checkrefs.py` until the
  first run reported the most-called functions in the pack as dead.


## Resource pack

| script | what it does |
|---|---|
| `rpcheck.sh` | Downloads the RP the server is *currently* advertising and dumps its contents, so local-vs-served drift is visible instead of guessed at. |
| `rpupload.py <file> [caption]` | Uploads to the Discord webhook (read from `~/homelab/.discord_webhook`, never printed or passed in argv) and prints the public CDN URL + sha1. |
| `rpverify.sh` | Downloads the just-uploaded URL and asserts it is byte-identical to what we built, and dumps the `ex=` expiry. **Do this before** pointing the server at a new URL — `require-resource-pack=true` means a bad URL locks players out. |
| `rpexpiry.sh` | Reports when the currently configured RP URL expires. |
| `rpdeploy.sh` | The whole RP rollout: preflight (0 players, URL still correct), patch properties, restart, verify. |

## Server / journals

| script | what it does |
|---|---|
| `rcon.py <cmd>…` | Minimal RCON client. Drains multi-packet replies (reading only one silently truncates long output). |
| `craftyrestart.py` | `patch <url> <sha1>` edits `resource-pack` + `resource-pack-sha1` and verifies the write; `restart` bounces the server through the **Crafty API**; `status`. Uses `/api/v2/servers/<id>/action/restart_server` — the endpoints I first guessed 404 and the server then never restarts. |
| `journal-append.sh` | Appends the session entries to `~/homelab/AI-JOURNAL.md` and `~/homelab/server-info/JOURNAL.md`, and verifies they grew. Works on **files**, not heredocs — see below. |

## Writing prose into a file on this box

Do **not** try to append Markdown with `cat >> file <<EOF` over ssh. It fails in
two ways, both quiet:

- An unquoted heredoc expands backticks, `$(...)` and `$VAR`, so Markdown full of
  `` `code` `` either runs commands or needs fragile `\`` escaping.
- With `set -e` the whole script can die before appending anything, and it looks
  like it worked.

Write the text locally, `scp` it, then `cat file >> target`. The shell never sees
the prose. That is exactly what `journal-append.sh` does.

## Known server facts these scripts work around

- `pause-when-empty-seconds=60` — the world stops ticking 60s after the last
  player leaves. Any "is it alive?" probe run with 0 players online is
  meaningless; use `smoke.sh`.
- **Vanilla rotates `logs/latest.log` on every boot.** A line-number mark taken
  before a restart points past the end of the new file, so "check the new lines
  for errors" silently inspects nothing and reports success.
- `require-resource-pack=true` + Discord CDN URLs carrying an `ex=` signature
  that expires ~30h after upload. Check with `rpexpiry.sh`. An expired URL means
  players cannot join at all.
- The server shell is fish: no `VAR=$(...)`, no heredocs. `scp` a script instead.
- A reload can drop the pack from the enabled list — always
  `datapack enable "file/fartpack.zip"` then `reload`.
- Crafty creds file is JSON, and the API token is at `data.token`.
- RCON packets: an unknown path/command returns a 404-shaped body, and long
  replies span several packets. Never read just one packet.
