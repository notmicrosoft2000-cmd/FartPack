# FartPack

Minecraft 1.21.11 datapack + resourcepack. Every utility block, mob and dropped item has its own
independent fart timer that releases a different flavour of deadly gas.

## Layout — one source of truth per pack

| Path | What it is |
|---|---|
| `fartpack-latest/` | **datapack source. This is the only place datapack code is edited.** |
| `fartpack_sounds/` | **resourcepack source (the fart sounds).** |
| `fartpack-latest.zip` | build artifact (gitignored) — the file you deploy |
| `fartpack_sounds.zip` | build artifact (gitignored) — the file you upload as a release asset |
| `backups/fartpack/vNN.zip` | one archive per released version (gitignored) |
| `backups/MANIFEST.sha256` | expected sha256 of every versioned zip — `sha256sum -c` is a real check |
| `src/` | **generated** mirror, kept in sync by `build.sh`. Gitignored. Do not edit. |
| `build/lintpack.py` | parse-checks every command line against the live server via RCON |
| `build/checkrefs.py` | static: every `run function` resolves, every function is reachable |
| `build/lint.sh` | the full pre-deploy gate: 0-player assert, block tags, parse lint |
| `build/rcon.py` | tiny RCON command runner |

### The source is tracked. Keep it that way.

`fartpack-latest/` was briefly untracked, then deleted from disk, and `git status` reported a clean
tree the whole time — so the repo held no pack at all while looking healthy. Recovery came from an
older commit purely by luck. See BUGS-AND-FIXES.md **#25**.

Two consequences you can rely on now:

- **The build is deterministic.** `zip` stores entry mtimes, so identical source used to give
  different sha1s, which made a zip's sha1 useless as an identity and a stored backup impossible to
  prove against a commit. `build.sh` now stages a copy and normalises every mtime to the zip epoch.
  Two builds of the same source are byte-identical.
- **Zips are gitignored on purpose, because they are now reproducible from source.** What is
  committed is the source and `backups/MANIFEST.sha256`. The exception is v11–v17, for which no
  source survives anywhere: those zips are uploaded as release assets under the `archive` tag,
  because a release asset is the only copy that exists outside this machine.

## Build

```sh
./build.sh          # -> fartpack-latest.zip
./build.sh v25      # -> backups/fartpack/v25.zip, refreshes fartpack-latest.zip, updates the manifest
```

A versioned build goes straight into `backups/fartpack/`, so the working directory only ever holds
the two current artifacts. Older versions live in exactly one place — three copies of one zip in
three directories is how they drifted apart originally.

`build.sh` also **regenerates** `world/block_name.mcfunction` from `tags/block/utility.json`
before zipping, so the block-name announcements can never drift from the tag. That file is
committed, but treat it as build output — edit `build/genblocknames.py` or the tag, never the
generated file.

## Publishing the resource pack

The sound pack must be reachable at a URL that does not expire. Discord CDN links carry a signed
`ex=` parameter that dies ~30 hours after upload, and with `require-resource-pack=true` an expired
URL means **nobody can join the server at all**.

It is published as a **GitHub release asset**, whose URL is permanent:

```sh
SHA=$(sha1sum fartpack_sounds.zip | cut -d' ' -f1)
gh release create rp-v20 --repo notmicrosoft2000-cmd/FartPack \
  --title "Resource pack rp-v20" --notes "sha1: $SHA" fartpack_sounds.zip
```

Then point the server at it and restart (the sha1 is only read at boot):

```
resource-pack=https\://github.com/notmicrosoft2000-cmd/FartPack/releases/download/rp-v20/fartpack_sounds.zip
resource-pack-sha1=<sha1>
```

Always download the URL back and compare sha1s **before** restarting. A resource pack URL that
404s locks every player out of the server, and you find out at the worst possible moment.

**Use `curl -fsSL`.** The `-L` is not optional. A GitHub release-asset URL answers `302` and
redirects to `release-assets.githubusercontent.com`; without `-L`, curl writes the empty redirect
body to disk, whose sha1 is `da39a3ee5e6b4b0d3255bfef95601890afd80709`. A naive preflight then
concludes the pack is corrupt and blocks a deploy that was completely fine. Browsers and
Minecraft both follow the redirect, so only a naive fetch is wrong. `build/rpdeploy.sh` does this
correctly and prints the final URL.

## Verifying changes on the live server

`build/verifyv20.sh` and `build/stresstest.sh` (copy both to `/tmp/` on the server) exercise the
features the parser cannot check. They are worth reading before trusting their output, because
each of these produces a **confident wrong answer** rather than an error:

- **The world is paused when 0 players are online, and chunks unload.** `execute if block` in an
  unloaded chunk fails *silently*, which is indistinguishable from a broken lookup. Everything
  runs inside a `forceload`ed chunk. This also means every liveness probe taken with 0 players
  online is meaningless — use `build/smoke.sh`, which drives `fartpack:tick` by hand.
- **`R="python3 /tmp/rcon.py"` then `"$R" 'cmd'` does nothing.** The quoted form passes the whole
  string as one argv entry, so the shell looks for an executable literally named
  `python3 /tmp/rcon.py`. It fails silently. Use an array: `R=(python3 /tmp/rcon.py)` / `"${R[@]}"`.
- **`say` is not captured by rcon.py.** Broadcast chat never comes back in the response, so a
  `run say` probe prints nothing whether it fired or not. Assert with `data get` or
  `scoreboard players get`, which do round-trip.
- **Only use block ids that exist on this server.** `minecraft:undyed_shulker_box` is not one of
  them on 1.21.11. `setblock` with an unknown id fails *and leaves the previous block in place*,
  so a lookup then correctly names the leftover block from the prior test case. Also, `setblock`
  reports "Could not set the block" when it is a no-op, so its output is not evidence a block
  exists — confirm with `execute if block ... run data modify storage ...`.
- `data modify <storage> <key> add value 1` is rejected by this server; count entities by
  appending to a list and counting the commas.
- **`limit` goes INSIDE the selector brackets.** `@e[...],limit=1` puts it outside, which parses as
  an unlimited selector and errors. And writing the explanation *inside* the quotes
  (`SEL="@e[...],limit=1]   # limit goes inside"`) makes the prose part of the selector — every read
  then returns nothing while looking like a passing assertion. `verifyv20.sh` and `stresstest.sh`
  now assert the selector is clean before running.
- **A test subject that moves will lie to you.** `player/stress` detects movement by comparing
  `Pos*100` against `fart.lastx`/`lastz`, so a wandering chicken triggers the movement branch and
  the result reads as a failure when the fix is in fact working. Use `NoAI:1b`.
- **Do not assert absolute health on a mob.** `summon ... {Health:20.0f}` does not give a chicken
  20 HP — `max_health` clamps it to 4 on the first tick, so every read is `4.0` whether or not
  damage landed. Assert the delta from a baseline captured immediately before the call.
- **A mid-line `#` is not a comment**, it is a scoreboard fake-player name (`#scan_c`, `#loaded`).
  Only a `#` in the leading whitespace starts a comment.

## Before deploying the datapack — always lint

A datapack function whose lines fail to parse is **dropped entirely** and only complains in
`logs/latest.log`. It never shows up in-game. So linting is not optional.

One command does the whole gate — 0-player assert, block tag validation, then the parse lint:

```sh
tar czf /tmp/vsrc.tar.gz fartpack-latest
scp /tmp/vsrc.tar.gz build/lint.sh build/lintpack.py build/checkblocks.py nept@192.168.99.56:/tmp/
ssh nept@192.168.99.56 "bash /tmp/lint.sh"
```

It refuses to run if anyone is online (**and aborts if the player count cannot be read**, rather
than assuming the server is empty) because `lintpack.py` is a real parse test: it *executes* every
line it checks, so the pack's own `setblock` / `give` / `kill` / `tag` lines run for real.

Must print `PARSE FAILURES: 0`, and `checked N, bad 0` for the block tags. Then check every macro
file has a `$(var)` on each command line.

Run the static check too — it needs no server and catches a different class entirely:

```sh
python3 build/checkrefs.py fartpack-latest   # DANGLING CALLS: 0, UNCALLABLE FUNCTIONS: 0
```

A mistyped `run function` target is **not** a parse error, so the lint above will not see it: the
pack loads, `PARSE FAILURES: 0`, and the branch silently never runs.

## Deploy

```sh
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
scp fartpack-latest.zip nept@192.168.99.56:/tmp/
ssh nept@192.168.99.56 "cp /tmp/fartpack-latest.zip \
  ~/crafty/servers/$SID/world/datapacks/fartpack.zip"
# in-place replace + reload DROPS the pack from the enabled list -> always re-enable:
scp build/rcon.py nept@192.168.99.56:/tmp/
ssh nept@192.168.99.56 "python3 /tmp/rcon.py 'datapack enable \"file/fartpack.zip\"' reload"
# then ALWAYS verify:
ssh nept@192.168.99.56 "grep -A2 'Failed to load' \
  ~/crafty/servers/$SID/logs/latest.log | tail -20"
```

Adding a new `damage_type` needs a **full server restart** — it is a non-reloadable registry.

## Rules for editing datapack functions

1. **Never** write a bare `actionbar` — Java has no such command. Use `title <targets> actionbar <json>`.
2. A macro function (`function … with storage`) rejects any command line with no `$(var)`.
3. An unset score does **not** match `matches 0`. Use `unless score X matches 1..`.
4. When adding/removing a scoreboard objective, bump the version constant in
   `core/bootstrap.mcfunction` **and** `tick.mcfunction:1`, or it will not reach an existing world.
5. Bossbars are runtime-only (wiped on restart); player tags and scores persist. Never track
   bossbar existence in a tag or score — probe with `bossbar get <bar> max`.
6. Function execution is synchronous, so a single shared `#fake` scratch scoreholder is safe.

See `BUGS-AND-FIXES.md` for the full bug catalogue and what's still open.
