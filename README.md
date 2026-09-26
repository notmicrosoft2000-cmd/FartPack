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
./build.sh v20      # -> fartpack-v20.zip + backups/fartpack/v20.zip, refreshes fartpack-latest.zip
```

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
