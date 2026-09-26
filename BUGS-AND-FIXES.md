# FartPack — Bug Catalogue & Fix Plan

> Living document. Read this before touching the pack.
> Companion to the server journals (`~/homelab/AI-JOURNAL.md`, `~/homelab/server-info/JOURNAL.md`).
> Last updated: 2026-09-26 14:15 local (UTC 07:45). v18 deployed.

## 0. Ground rules / orientation

| Fact | Value |
|---|---|
| MC version | 1.21.11, Fabric Loader 0.19.5, Java 25 (server "Cleopatra", Crafty SID `241920ac-…0457`) |
| Datapack path on server | `~/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/world/datapacks/fartpack.zip` |
| RP path (NOT on server) | Discord CDN URL in `server.properties`, sha1 pinned in `resource-pack-sha1` |
| **Deployed now** | **v18** sha1 `a0b5d6f6d50b4ff9fc102fcc8a81b3ee12524acf` |
| Deployed before this session | v16 sha1 `916e97718c131fc0e5b2f8688bd4da9a2afb711a` (local v17 was never shipped) |
| Local backups | `backups/fartpack/v11 … v18.zip` |

### Source-of-truth (bug #24)
Three copies existed with no build script and no git. **Decision: `fartpack-latest/` is the single
source of truth; `src/datapack/` is a byte-identical mirror** (`rsync -a --delete` after each edit).
Build is `cd fartpack-latest && zip -rX ../fartpack-vNN.zip . -x '*.DS_Store'`. Formalise in Pass D.

### Deployment gotchas (learned the hard way)
1. Replacing `fartpack.zip` in place + `/reload` **can drop the pack from the enabled list**.
   Always follow with `datapack enable "file/fartpack.zip"` then `reload`.
2. `damage_type` is a **non-reloadable** registry — any NEW damage type needs a full server restart.
3. RCON is only reachable on the crafty container bridge IP (`docker inspect` → `172.17.0.2:25575`).
   The fish alias `server` = `ssh nept@192.168.99.56`; fish does **not** expand aliases in `ssh -c`.
4. A function that fails to parse is **dropped entirely** and the error only appears in
   `logs/latest.log` as `Failed to load function <id>`. It never surfaces in-game. Always read the
   log after a reload.
5. Unrelated pre-existing noise: `lifesteal:utility/quickdeath` gamerule parse error (leave it),
   `Graves v3.0.0` pack (available, not enabled), `.DS_Store` warnings from lifesteal.

### Vanilla-behaviour facts established empirically this session (do not re-derive)
| Question | Answer | How verified |
|---|---|---|
| Is `actionbar` a Java command in 1.21.11? | **No.** Use `title <targets> actionbar <json>`. | RCON parse test |
| Does a failed `execute store result` write anything? | **It stores 0** (not "leaves unchanged"). | set 42 → probe missing bar → read 0 |
| Is `bossbar get <bar> max` valid? | Yes. `get <bar>` with no field, and `get <bar> color`, are **not**. | RCON parse test |
| Are bossbars persisted across restart? | **No** — runtime only. Player tags/scores **are** persisted. | design knowledge; drives #2 |
| Is `minecraft:display` a valid selector type? | **No** — "Invalid or unknown entity type". Must list `text_display`, `block_display`, `item_display` separately. | RCON parse test |
| Tag directory in 1.21.11 | `tags/entity_type/` is still correct (vanilla jar has it). Not renamed to `tags/entity/`. | vanilla jar listing |
| Does a macro function accept a line with no `$(var)`? | **No** — `No variables in macro`, the whole function is dropped. | datapack load error |
| Is function execution concurrent? | **No** — synchronous, `execute as` is sequential. Global scratch `#fake` players are therefore safe. | Mojang behaviour |

---

## 1. Architecture map

```
minecraft:tags/function/load  -> fartpack:load            (calls core/bootstrap, then welcome)
minecraft:tags/function/tick  -> fartpack:tick
                                 |
  tick (every game tick)
   |- core/bootstrap            if #loaded != 18   <-- full objective/global init, version-gated
   |- scoreboard players enable @a fart.toggle
   |- core/do_toggle            (/trigger fart.toggle, gated on #enabled)
   |- return 0                  if #enabled == 0
   |- world/tick
   |    |- tag @e remove fart.etick ; re-tag entities within 16 of each player
   |    |- as @e[fart.etick] -> entities/timer -> world/timer_tick -> world/fart_time
   |    |                                                          |- fart_block  (marker-tagged)
   |    |                                                          \- fart_entity
   |    |- AEC gas clouds -> clouds/gas_apply   (periodic custom-type damage)
   |    \- blocktimer markers -> blocks/timer   (only if a player is within 24)
   |- core/assign_pid           (new player -> bar/make_gas_bar)
   |- bar/tick_gas_bar          (ensure_bar + update_gas_bar, macro w/ storage pid)
   |- every 10t (#scan_c==10):
   |    |- blocks/scan          (147 `execute positioned` per player)
   |    |- kill orphaned blocktimer markers
   |    |- player/fill_gas      (movement-based gas fill, clamped to 100)
   |    \- #scan_c = 0
   \- player/press              (crouch detect, release/heal, warn title, forced legendary)

any fart -> world/fart_time -> fart_block | fart_entity
              -> clouds/*        (summon area_effect_cloud with potion_contents)
              -> push/{small,norm,block,legendary,release}
push/*  -> push/core -> push/player (marker hop; players) | push/one (Motion; mobs)
                     -> push/self   (marker 2 behind player -> forward hop)
```

### Fake-player globals in use
Persistent: `#loaded` (version int) `#enabled` `#neg1 #one #ten #twelve #noplayer #scan_c #stats #pid_counter #cloud #eb_tmp`
Per-call scratch (safe: execution is synchronous): `#power #vy #radius #ppx #ppz #ppx10 #ppz10 #tx #tz
#dx #dz #adx #adz #dist #dist10 #vx #vz #ux10 #uz10 #steps #hop #mx10 #mz10 #curx10 #curz10 #fpx #fpz #fdist`

### Player / entity tags
`fart.has_pid` `fart.sneak` `fart.releasing` `fart.healtick` `fart.healing` `fart.warnfull`
`fart.etick` `fart.blocktimer` `fart.pushersrc` `fart.pushtarget` `fart.hopper` `fart.selfsrc`
`fart.gas_atomic` `fart.gas_legendary`

---

## 2. Bug catalogue

Status: `FIXED-18` = fixed in the v18 deploy. `OPEN-C` / `OPEN-D` = deferred.
`WRONG` = an earlier hypothesis of mine that was **disproved**; kept so it is not re-investigated.

### TIER 0 — the pack was half-dead

#### #0 — `actionbar` does not exist in Java 1.21.11 ⇒ `player/press` never loaded  · **FIXED-18**
**Where:** `player/press.mcfunction:3`, `player/release_done.mcfunction:1`
(and originally `player/stress.mcfunction:6`, since split out)
**How it happens:** both files used the bare command
`actionbar @s [{…}]` / `execute … run actionbar @s [{…}]`.
Java has no `/actionbar`; the actionbar overlay is `title <targets> actionbar <json>`.
`/reload` therefore logged
`Failed to load function fartpack:player/press — Whilst parsing command on line 3: Incorrect
argument for command` and **dropped the entire function**.
**Blast radius — this is the big one.** `player/press` is the whole player-facing game loop, so
ALL of it has been dead in the deployed pack:
- crouch-to-release never emptied the bar
- the "hold it to HEAL" regeneration never applied
- crouching on an empty bar never dealt stress damage
- pressure hitting 100 never triggered the legendary mega-fart
- the "GAS PRESSURE NEAR MAX" title never appeared
- the per-tick forward self-push while crouching never ran
- `player/release_done` ("Ahh, all clear!") never ran either

`player/fill_gas` is a *different* function and did keep working, so pressure silently climbed
to 100 and stuck there. Symptom seen by players: "the bar fills up and nothing happens".
**Fix:** `title @s actionbar [{…}]` on all three lines.
**Lesson:** `src/datapack` had already made this exact change; I initially reverted it as a
"regression" because the change looked cosmetic. It was a genuine fix.

### TIER 1 — hard breakage

#### #1 — `core/bootstrap` created only 6 of 13 objectives  · **FIXED-18**
**Where:** `core/bootstrap.mcfunction`
**How it happens:** `load.mcfunction` created 13 objectives, `bootstrap` only
`fart.slow lastx lasty lastz hurtt toggle` — missing `fart.cooldown fart.target fart.var
fart.pressure fart.stress fart.pid fart.total fart.gtick`. It also never set `#scan_c`/`#stats`/
`#pid_counter`, never created `fartpack:data`, never set the sidebar, and it ends by setting
`#loaded`, so it never re-runs.
**Symptom:** on a fresh world or after any scoreboard wipe the pack half-works forever.
**Fix:** `bootstrap` is now the single complete initializer; `load.mcfunction` just calls it and
then prints the welcome text, so the two cannot diverge again.

#### #1b — new objectives never reach an existing world  · **FIXED-18**
**How it happens:** bootstrap is gated on `unless score #loaded fart.var matches 1`. On a world
where `#loaded` is already 1, bootstrap never runs, so **any objective added in a later version is
never created** and every `scoreboard … fart.sndt` fails with "Unknown objective". This bit
`fart.sndt` during this very session — caught only because I re-checked the objective list.
**Fix:** `#loaded` is now a **version number** (`18`). `tick.mcfunction` runs bootstrap on a
version mismatch, so bumping the constant re-initialises an existing world. Bootstrap also
preserves a user's `/trigger fart.toggle` off-state via
`execute unless score #enabled fart.var matches 0 run scoreboard players set #enabled fart.var 1`.
**Rule for the future: any time you add or remove an objective, bump the number in
`core/bootstrap.mcfunction` and in `tick.mcfunction:1`.**

#### #2 — gas bossbar is not restored after a restart  · **FIXED-18** (see also WRONG-1)
**Where:** `bar/ensure_bar.mcfunction`
**How it happens:** bossbars are **runtime-only** — a restart wipes every one of them — but player
tags and scores are persisted in player NBT. So any existence marker kept in a tag or a score
outlives the bar it describes. (This is the trap I fell into first; see WRONG-1.)
**Fix:** existence is decided by a real probe, `execute store result score … run bossbar get
fartpack:gas_<pid> max`, which is the only thing that reflects the live bossbar list.

#### #3 — gas bossbars are orphaned when a player disconnects  · **PARTIALLY FIXED-18**
**Observed live at audit time:** `bossbar list` → **5 `Gas Pressure` bars** with 0 players online.
Vanilla has no logout trigger and `@a` cannot enumerate offline players, so there is no direct fix.
**Fix now:** because `fart.has_pid` and `fart.pid` persist across logout, a returning player keeps
the same bar id and `ensure_bar` re-creates it. All 5 orphans (one of them `fartpack:gas_0`, a
pid of 0 from some early version) were removed during the session.
**Residual (OPEN-C):** grows by one bar per player who never returns. Bounding `#pid_counter`
would risk two online players colliding on one bar, so it is deferred rather than shipped blind.

#### #4 — `#noplayer` never initialised ⇒ knockback can die permanently  · **FIXED-18**
**Where:** `load.mcfunction` / `core/bootstrap.mcfunction`
**How it happens:** v16.3 made crouch-release non-pushing by setting `#noplayer 1` in
`push/release` and clearing it to 0 right after. **Scoreboard values persist across `/reload` and
restarts**, so a crash or reload inside that window leaves `#noplayer` at 1 forever, and
`push/core` silently strips every player from every push. No symptom except "push feels broken",
no recovery except a manual `/scoreboard players set #noplayer fart.var 0`.
**Fix:** initialise `#noplayer 0` in bootstrap.

#### #5 — `fart.lasty` created, never used  · **FIXED-18**
Present in both `load` and `bootstrap`, zero other references. Removed from bootstrap; the stale
objective was dropped from the live world with `scoreboard objectives remove`.

#### #6 — `push/one` sets `Motion` on entities that have none  · **FIXED-18**
**Where:** `push/core.mcfunction`
**How it happens:** `push/core` excluded only five no-`Motion` types
(`item, marker, experience_orb, area_effect_cloud, firework_rocket`) and routed everything else to
`push/one`, which does `data modify entity @s Motion set from storage fartpack:data motion`.
Not excluded: `minecraft:interaction`, the three display entities, `minecraft:end_crystal`,
`minecraft:leash_knot`, `minecraft:lightning_bolt` — all of which have no `Motion` component.
**Symptom:** `Entity has no 'Motion'` in the log, once per such entity per fart, and those
entities get no knockback at all.
**Note:** the pack already knew these were special — every one is in `tags/entity_type/small_radius.json`.
**Fix:** new tag `tags/entity_type/no_push.json`; `push/core` uses one `type=!#fartpack:no_push`
instead of five inline filters. The unreachable radius-10 branch was dropped (radii in use are
3, 4, 5, 12), so four selector passes instead of five.

#### #7 — crouch-release burp fires 5 ticks out of every 10  · **FIXED-18**
**Where:** `player/release_gas.mcfunction`
**How it happens:** `execute if score #scan_c fart.var matches 5 run playsound …`. `#scan_c` counts
`0→10` and is only zeroed when it `matches 10..`, so it sits on `5` for five consecutive ticks,
and `release_gas` runs every tick while crouched — a 0.5 s machine-gun for the whole crouch.
`#scan_c` is the 10-tick scanner phase, never intended as a sound throttle.
**Fix:** new `fart.sndt` objective as a real per-player sound cooldown (every 15 ticks), reset when
the player stops sneaking.

#### #8 — `player/stress` used the `matches 0` unset-score trap  · **FIXED-18**
**How it happens:** an unset score does **not** match `matches 0` (the documented v12.2 root cause
that killed `fill_gas`). `stress` still used `if score @s fart.pressure matches 0` on 8 lines; it
only worked because `assign_pid` sets pressure to 0 on login.
**Fix:** all conditions are now `unless score @s fart.pressure matches 1..`, which is correct for
both 0 and unset.

#### #9 — stress cadence contradicted its own message, and the file was copy-paste spaghetti  · **FIXED-18**
Threshold `matches 25..` (1 HP per 1.25 s) vs the v13 journal's "1 HP/sec", with five
damage/particle/sound/nausea/message lines each re-evaluating the same two-score condition.
**Fix:** threshold 20 (a true 1 HP/sec), the condition is evaluated **once**, and the payload moved
to a new `player/stress_hurt.mcfunction`.

#### #10 — `fart.pressure` had no upper clamp  · **FIXED-18**
`player/fill_gas` only ever `scoreboard players add`. A player who never crouches climbs past the
bossbar max, and the 80–99 "NEAR MAX" window can be stepped straight over.
**Fix:** clamp to 100 after the fill branches.

#### #11 — `push/self` relied on `#power` being set by its caller  · **FIXED-18**
`world/fart_forced` ran `push/legendary` (which sets `#power 90`) and *then* called `push/self`,
which reads `#power` without setting it. It worked only because of call ordering. `player/press`
did set it explicitly, so the two call sites disagreed.
**Fix:** `fart_forced` now sets `#power 90` explicitly before `push_self`.

#### #12 — macro functions reject any line without a `$(var)`  · **FIXED-18** (self-inflicted, worth remembering)
While adding a player tag to three macro files I wrote `$tag @s add fart.has_bar` — a macro line
with no variable. The datapack loader fails the **entire file** with `No variables in macro`.
**Rule:** every command line in a file invoked with `with storage` must reference at least one
`$(…)`, even if only nominally.

#### WRONG-1 — "`ensure_bar` can never create a bar"  · **DISPROVED**
My first pass claimed the `999` sentinel plus `matches 0` guards made the creation branch
unreachable. **It does not.** A failed `execute store result score … run bossbar get <missing>`
stores **0**, which *does* match the guard, so the original design was correct; the only real
defect was that `#eb<pid>` rows were never reset, leaking one per player. Kept here so nobody
re-investigates it. Fixed anyway by using a single shared `#eb_tmp` scratch holder and dropping
the redundant pre-seed/reset entirely.

#### WRONG-2 — "`push/self` + global tags races with `push/player`"  · **DISPROVED**
Function execution is synchronous and `execute as` iterates sequentially, so each `push/self`
summons, reads, pushes and kills its own marker before the next player starts. There is no race
and no mismaim. The only genuine fragility was the `#power` contract, fixed as #11.

#### WRONG-3 — "`tags/entity_type/` was renamed to `tags/entity/` in 1.21.5"  · **DISPROVED**
The 1.21.11 vanilla jar still ships `data/minecraft/tags/entity_type/`. Current path is correct.

### TIER 2 — still open

#### #13 — atomic / legendary gas is an undodgeable guaranteed kill  · **OPEN-C (tuning)**
`clouds/atomic` summons `Duration:200`, `clouds/gas_apply` deals 8 damage every 20 ticks to
everything within 4.5 → **~80 damage, armour ignored**. `clouds/legendary` is `Duration:300`,
8 damage every 15 ticks within 8.5 → **~160 damage**. `world/cloud_random` can pick atomic
1-in-6 from *every* mob and dropped item in a 16-block radius, so ordinary mob activity is
frequently an instant kill. No opt-out, no difficulty scaling, no escape window.
**Plan:** retune to "dangerous but survivable if you leave the radius" (~25–30 total), add a
per-cloud damage budget, and give a short grace period on spawn.

#### #14 — unbounded per-entity scoreboard leak  · **OPEN-C**
Every entity that farts gets permanent rows in `fart.cooldown` + `fart.target`; every gas AEC gets
`fart.gtick`. `scoreboard players reset` is never called, so a busy world accumulates thousands of
fake-player rows. Same class as #3. A busy world also means `scoreboard players list` becomes
unreadable for diagnostics (it was already 141 entries at audit time).

#### #15 — the crouch detector is a fragile trick (it does work)  · **OPEN-C (rewrite)**
`player/press.mcfunction:1-2`
```
execute at @s anchored eyes positioned ^ ^ ^ positioned ~ ~-1.27 ~ if entity @s[distance=..0.1] run tag @s add fart.sneak
```
Sneak eye height is exactly 1.27, so the probe lands on your feet when crouched (distance 0) and
0.35 above them when standing. It works — but it also fires if any entity is within 0.1 of your
ankles, and it dies the moment Mojang changes sneak eye height.
`unless block ~ ~ ~ minecraft:air` is the maintainable equivalent.

#### #16 — `#fartpack:utility` is missing ~19 modern blocks  · **OPEN-C**
No `crafter, jukebox, enchanting_table, beacon, bell, conduit, decorated_pot, trial_spawner,
copper_*`, etc. Those blocks never fart.

#### #17 — per-tick cost is the real TPS ceiling  · **OPEN-C**
- `world/tick`: `tag @e remove fart.etick` + re-tag = 2 tag writes per entity **per player** per tick.
- `blocks/scan`: **147 `execute positioned` per player every 10 ticks** (≈1 470 commands/tick for one player, ×N).
- `push/core`: up to 4 near-identical `@e[…distance=..N]` passes where one pass plus a radius test would do.
- `world/tick`: separate passes for `fart.gas_atomic` and `fart.gas_legendary` where one `tag=fart.gas` pass covers both.
- gas clouds are applied in two passes (AEC tag + `fart.gtick`) where one would do.

#### #18 — `fart_forced` applies slowness but not the documented hunger penalty  · **OPEN-C (cosmetic)**
The v13 journal claims "slowness + hunger 100t". Only slowness is there.

#### #19 — RP drift: the local resource pack is not what the server serves  · **OPEN-D**
Server advertises `resource-pack-sha1=834edd3c…` (uploaded 2026-09-25 22:30). Local
`fartpack_sounds.zip` is `6e6c1c2a…` (rebuilt 2026-09-26 10:31, **never uploaded**). So **any RP
edit made locally is a no-op** until it is re-uploaded to Discord *and* `server.properties` sha1 is
patched *and* the server restarts. The local RP `pack.mcmeta` also has **no `pack_format`** at all
(only `min_format`/`max_format`), unlike the datapack's.

#### #20 — three divergent pack copies, no build script, no git  · **OPEN-D**
See "Source-of-truth" above; formalise the build + git in Pass D.

#### #21 — 6 legitimate zero-reference functions  · **NOTE, not a bug**
`fartpack:items` and `fartpack:player/fart` are manual admin commands; `fartpack:load` and
`fartpack:tick` are entrypoints via `tags/function/*.json`; `fartpack:items/on_kibble` and
`on_tonic` are advancement rewards. `player/fart.mcfunction:1` also had a redundant no-op
`if entity @s` (removed) and a tellraw whose closing `")"` was split into its own text component
(merged).

---

## 3. Fix order (passes)

| Pass | Scope | Status |
|---|---|---|
| **A** | Safety. Complete `core/bootstrap` + unify `load`; version-gate `#loaded`; init `#noplayer`/`#scan_c`/`#stats`; fix `actionbar`; probe-based `ensure_bar` + `#eb_tmp`; drop `fart.lasty`, `#ppy`, `bar/hide*`, `bar/show*`, `push/gentle`; clean live bossbar/scoreboard junk. | **shipped in v18** |
| **B** | Felt bugs. `no_push` tag (#6); explicit `#power` (#11); `unless 1..` in stress (#8); stress cadence + de-spaghetti (#9); `fart.pressure` clamp (#10); real sound throttle (#7). | **shipped in v18** |
| **C** | Tuning + perf. Gas rebalance (#13, #18); entity/gas scoreboard reaper (#14); crouch-detector rewrite (#15); `utility` block tag (#16); `blocks/scan` + `push/core` + gas-pass rewrite (#17). | pending |
| **D** | Packaging. Build script + git + one source of truth (#20); RP `pack_format`; RP re-upload and `server.properties` sha1 bump (#19). | pending |

### Verify-before-deploy (learned the hard way — use this every time)
1. `python3 lintpack.py` against the built zip: parse-checks **every** command line against the
   live server parser. Must report `PARSE FAILURES: 0`.
2. Check every macro file: each command line must contain `$(`.
3. Deploy → `datapack enable "file/fartpack.zip"` → `reload`.
4. `grep 'Failed to load' logs/latest.log` for the new line range — must show only the
   pre-existing lifesteal `quickdeath` error.
5. `scoreboard objectives list` and `scoreboard players get #loaded fart.var` to confirm the
   version gate fired.

## 4. Revert
Every pass is a standalone zip in `backups/fartpack/vNN.zip`, and the pre-session v16 is also at
`/tmp/fartpack-v16-safety.zip` on the server. To revert: copy the desired zip over
`world/datapacks/fartpack.zip`, then `datapack enable "file/fartpack.zip"` + `reload`.
