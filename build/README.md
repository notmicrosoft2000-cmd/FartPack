# build/ — tooling

Nothing in here ships to the server. These are the scripts used to verify and
deploy. Copy one to `/tmp` on the server with `scp` and run it there (the server
shell is **fish**, which does not expand aliases in `ssh -c` and cannot parse
heredocs — hence script files rather than inline commands).

## Datapack

| script | what it does |
|---|---|
| `lintpack.py <extracted-root>` | Parse-checks **every** command line in the pack against the live server's parser. Gate: must print `PARSE FAILURES: 0`. |
| `deploy.sh` | Installs `fartpack.zip`, enables it, reloads, then greps the log. |
| `verify.sh` | Post-deploy: lists every `Failed to load function` **with its timestamp** (so historical errors are not mistaken for new ones) and confirms the version gate fired. |
| `checkblocks.py <ids-file>` | Asks the live server whether each block id exists. **Required** after editing any `tags/block/*.json` — one unknown value silently kills the whole tag. |
| `smoke.sh` | Drives `fartpack:tick` by hand ~70 times over RCON and checks the 30-tick cycle wraps and nothing errors. The only way to runtime-test while the server is paused. |
| `ticktest.sh` | Is the pack ticking right now, and did the last reload log anything bad? |
| `reaptest.sh` | Arms `#rc` to 199 and proves `core/reap` wipes stale `fart.gtick` rows and resets itself. |

## Resource pack

| script | what it does |
|---|---|
| `rpcheck.sh` | Downloads the RP the server is *currently* advertising and dumps its contents, so local-vs-served drift is visible instead of guessed at. |
| `rpupload.py <file> [caption]` | Uploads to the Discord webhook (read from `~/homelab/.discord_webhook`, never printed or passed in argv) and prints the public CDN URL + sha1. |
| `rpverify.sh` | Downloads the just-uploaded URL and asserts it is byte-identical to what we built, and dumps the `ex=` expiry. **Do this before** pointing the server at a new URL — `require-resource-pack=true` means a bad URL locks players out. |
| `rpexpiry.sh` | Reports when the currently configured RP URL expires. |

## Server

| script | what it does |
|---|---|
| `rcon.py <cmd>…` | Minimal RCON client. Drains multi-packet replies (reading only one silently truncates long output). |
| `craftyrestart.py` | `patch <url> <sha1>` edits `resource-pack` + `resource-pack-sha1` and verifies the write; `restart` bounces the server through the **Crafty API** (the watchdog drives Crafty too, so this keeps one owner of the lifecycle); `status`. |

## Known server facts these scripts work around

- `pause-when-empty-seconds=60` — the world stops ticking 60s after the last
  player leaves. Any "is it alive?" probe run with 0 players online is
  meaningless; use `smoke.sh`.
- `require-resource-pack=true` + Discord CDN URLs that carry an `ex=` signature
  expiring ~30h after upload. Check with `rpexpiry.sh`.
- The server shell is fish: no `VAR=$(...)`, no heredocs. `scp` a script instead.
- A reload can drop the pack from the enabled list — always
  `datapack enable "file/fartpack.zip"` then `reload`.
