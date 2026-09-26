# FartPack

Minecraft 1.21.11 datapack + resourcepack. Every utility block, mob and dropped item has its own
independent fart timer that releases a different flavour of deadly gas.

## Layout — one source of truth per pack

| Path | What it is |
|---|---|
| `fartpack-latest/` | **datapack source. This is the only place datapack code is edited.** |
| `fartpack_sounds/` | **resourcepack source (the fart sounds).** |
| `fartpack-latest.zip` | build artifact (gitignored) — the file you deploy |
| `fartpack_sounds.zip` | build artifact (gitignored) — the file you upload to Discord |
| `backups/fartpack/vNN.zip` | one archive per released version (gitignored) |
| `src/` | **generated** mirror, kept in sync by `build.sh`. Gitignored. Do not edit. |
| `build/lintpack.py` | parse-checks every command line against the live server via RCON |
| `build/rcon.py` | tiny RCON command runner |

## Build

```sh
./build.sh          # -> fartpack-latest.zip
./build.sh v19      # -> fartpack-v19.zip + backups/fartpack/v19.zip, refreshes fartpack-latest.zip
```

## Before deploying the datapack — always lint

A datapack function whose lines fail to parse is **dropped entirely** and only complains in
`logs/latest.log`. It never shows up in-game. So linting is not optional:

```sh
scp build/lintpack.py nept@192.168.99.56:/tmp/
ssh nept@192.168.99.56 "rm -rf /tmp/lintpk && mkdir /tmp/lintpk && cd /tmp/lintpk && \
  python3 -c \"import zipfile;zipfile.ZipFile('/tmp/fartpack-latest.zip').extractall('.')\" && \
  python3 /tmp/lintpack.py /tmp/lintpk"
```

Must print `PARSE FAILURES: 0`. Then check every macro file has a `$(var)` on each command line.

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
