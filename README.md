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

## Per-player config (v26)

Every number below is a plain `/function` call with a player name and a value. No menus, no
scoreboard GUI, nothing to hold items.

```sh
/function fartpack:admin/rate  Steve 2      # gas bar fills 2x faster      (0-5, 0 = frozen)
/function fartpack:admin/every Steve 2      # fills only every 2nd pass    (1-4)
/function fartpack:admin/cap   Steve 200    # bar fills to 200             (20-500)
/function fartpack:admin/rel   Steve 3      # drains 3/tick while crouching (1-10)
/function fartpack:admin/pow   Steve 80     # knockback on release         (0-200, 0 = no shove)
/function fartpack:admin/show  Steve        # prints their config to chat
/function fartpack:admin/reset Steve        # back to stock
```

| knob | default | what it does |
|---|---|---|
| `rate` | 1 | How many times the movement-derived base increment is added per fill pass. `2` is twice as fast, `0` never fills on its own. |
| `every` | 1 | Throttle: fill on only 1 pass in N. `2` takes twice as long. Composes with `rate` — `rate 3` + `every 2` is 1.5x. |
| `cap` | 100 | What the bar fills to. Also resizes the bossbar **and** moves the two thresholds that used to be hardcoded — the hunger warning (a quarter full) and the forced legendary mega-fart (full). |
| `rel` | 1 | How much pressure a crouching release drains per tick. |
| `pow` | 30 | Horizontal impulse applied to other entities on release, in 1/100 blocks per tick. This is the number that decides how far a player knocks *other players* back, now that #28 lets them do it at all. |

Out-of-range values are **clamped, not rejected** — a macro can't branch on the literal text of an
argument, and an admin who types `99` wants a big number, not an error. The read-back in chat tells
you what actually landed.

Values are stored per player and persist across restarts. Resetting is explicit (`admin/reset`);
there is no per-reload reset, so a config cannot be lost by a crash.

**Example — the "King of the Farts" crown.** Three calls and a message:

```mcfunction
/function fartpack:admin/rate YOSHIKURO1 2
/function fartpack:admin/pow  YOSHIKURO1 60
/tellraw @a [{"text":"[Fartpack] Player YOSHIKURO1 is now declared the first King of the farts! You will now fart 2x faster!","color":"gold"}]
```

**Not scaled by `cap`, deliberately:** the Anti-Fart Kibble still removes a flat 15. Scaling it
would have changed how strong it feels for everybody the moment this system existed.

## Rules for editing datapack functions

1. **Never** write a bare `actionbar` — Java has no such command. Use `title <targets> actionbar <json>`.
2. A macro function (`function … with storage`) rejects any command line with no `$(var)` — the
   **whole file** silently stops existing, and `checkrefs.py` reports it as *uncallable* rather
   than as a parse error. Run `python3 build/checkmacro.py <pack>` before deploying; it exists
   only because of this rule.
3. An unset score does **not** match `matches 0`. Use `unless score X matches 1..`.
4. When adding/removing a scoreboard objective, bump the version constant in
   `core/bootstrap.mcfunction` **and** `tick.mcfunction:1`, or it will not reach an existing world.
5. Bossbars are runtime-only (wiped on restart); player tags and scores persist. Never track
   bossbar existence in a tag or score — probe with `bossbar get <bar> max`.
6. Function execution is synchronous, so a single shared `#fake` scratch scoreholder is safe.
7. **A macro is expanded in full before any of its lines run.** A macro cannot write the storage
   key it reads — `bar/tick_gas_bar` has to hand `$(cap)` to `bar/ensure_bar` because a
   `store result storage` inside `ensure_bar` would land long after `$(cap)` was substituted, and
   every bar would be sized from the previously-processed player.
8. `fart.rate 0` (frozen) and "never set" are indistinguishable to a scoreboard — both fail
   `matches 1..`. Never initialise per-player config by testing values; use the `fart.has_cfg` tag.
   `build/simfill.py` models the fill arithmetic and asserts unset means stock, not frozen.

See `BUGS-AND-FIXES.md` for the full bug catalogue and what's still open.
