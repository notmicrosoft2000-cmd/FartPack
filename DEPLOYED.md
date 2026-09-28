# Deployed artifacts — what the live server is actually serving

Recorded 2026-09-26. This file exists because a zip's sha1 is easy to change by
accident and impossible to notice until players cannot join.

## Resource pack (LIVE)

    resource-pack=https\://github.com/notmicrosoft2000-cmd/FartPack/releases/download/rp-v20/fartpack_sounds.zip
    resource-pack-sha1=9c73765515734619afa671f2ffd0a5a3065471c5

**The live sha1 is `9c737655…`, and that is what `server.properties` must keep.**

Since `build.sh` was made deterministic (mtime normalisation), a fresh
`./build.sh` produces a resource-pack zip with sha1 `10e7af37da5c67a04a703aac4db2981401ba6511`
— a *different* hash for *identical content*. Verified 2026-09-26 by extracting
both and diffing: 10 files, zero differences. Only the zip's internal timestamps
changed.

So: **if you ever rebuild and redeploy the RP, you must also re-upload the
release asset and update `resource-pack-sha1` together, or every client rejects
the pack and the server becomes unjoinable** (`require-resource-pack=true`).

That is the whole reason the RP is versioned by release tag rather than
re-uploaded in place. To ship an RP change:

1. `./build.sh` and note the new `fartpack_sounds.zip` sha1.
2. `gh release create rp-vNN --repo notmicrosoft2000-cmd/FartPack --title "Resource pack rp-vNN" --notes "sha1: $SHA" fartpack_sounds.zip`
3. `bash build/rpdeploy.sh` with the new URL in `/tmp/rp_url.txt` — it verifies
   the URL serves the exact bytes you built (using `curl -fsSL`; the `-L` is
   required, see README) before it will restart anything.

Never point `resource-pack-sha1` at a hash you have not just downloaded and
confirmed from the live URL.

## Datapack (LIVE)

    #loaded = 33
    file/fartpack.zip, 10 packs enabled, 0 "Failed to load" at last boot

    artifact  /home/neptune/Documents/Fartpack/fartpack-latest.zip
    sha1      2908142ba19863b3c835e894972e07da68691da1
    files     110, build verified deterministic (two builds byte-identical)

v33 removed the entire age/weight/gender profile system — 10 `.mcfunction` files,
9 scoreboard objectives, 6 call sites — and added: the live percentage on the
bossbar name (`fart.pct`, arithmetic verified over RCON across caps 60–180 and an
over-cap clamp), the near-full warning at 80% of the player's OWN cap
(`fart.near`), crouch blocking gas *inflow*, and two actionbar lines deleted.

The datapack is not versioned by URL, so it has no equivalent trap: deploying it
is a matter of installing the zip and reloading. `build/deploy.sh` compares the
installed zip's sha1 against the freshly built one and refuses to continue on a
mismatch, and it refuses to reload at all while anyone is online.

## Version numbering

`#loaded` in `core/bootstrap.mcfunction` is the single source of truth, and
`tick.mcfunction` must `matches` the same number or the bootstrap re-runs on
every tick. `build/deploy.sh` takes the expected version as `$1` and compares it
against the live `#loaded`, so a mismatch is caught instead of assumed.
