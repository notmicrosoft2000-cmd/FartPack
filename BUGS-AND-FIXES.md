# FartPack — Bug Catalogue & Fix Plan

> Living document. Read this before touching the pack.
> Companion to the server journals (`~/homelab/AI-JOURNAL.md`, `~/homelab/server-info/JOURNAL.md`).
> Last updated: 2026-09-26. **v19 deployed**; **v20 built, pending deploy** (Passes A–D shipped,
> Pass E is the three player-reported fixes #22–#24).
> Source of truth and history: https://github.com/notmicrosoft2000-cmd/FartPack

## 0. Ground rules / orientation

| Fact | Value |
|---|---|
| MC version | 1.21.11, Fabric Loader 0.19.5, Java 25 (server "Cleopatra", Crafty SID `241920ac-…0457`) |
| Datapack path on server | `~/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/world/datapacks/fartpack.zip` |
| RP path (NOT on server) | Discord CDN URL in `server.properties`, sha1 pinned in `resource-pack-sha1` |
| **Deployed now** | **v19** sha1 `95604ea8fe102299c4672eade4c6983f34a4299a` |
| Previous deploys | v18 `a0b5d6f6…` (Passes A+B), v16 `916e9771…` (pre-session) |
| Local backups | `backups/fartpack/v11 … v19.zip` |
| Git | `main`, first commit `a8c36e7`; source only, zips/mirror gitignored |
| Build | `./build.sh [19|v19]` → `fartpack-latest.zip` + `backups/fartpack/vNN.zip` |
| Pack version constant | `19`, in **both** `core/bootstrap.mcfunction` and `tick.mcfunction:1` |

### Source of truth (bug #20 — now resolved)
`fartpack-latest/` is the only place datapack code is edited; `fartpack_sounds/` is the only place
the RP is edited. `src/` is a **generated** mirror that `build.sh` syncs — it is gitignored precisely
because keeping two live copies is what caused the pre-v18 divergence. Everything is under git.

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
6. **One bad value in a `tags/block/*.json` silently kills the whole tag.** A nonexistent block id
   makes the tag file fail to parse, so `#fartpack:utility` vanishes, every utility block in the
   world stops farting, and **nothing appears in the log**. Always verify block ids against the
   live registry with `build/checkblocks.py` before editing any block tag. This is how
   `minecraft:chain` was caught — it genuinely is **not** in this server's registry.
7. **`pause-when-empty-seconds=60`.** The server stops ticking the world 60s after the last
   player leaves (log: `Server empty for 60 seconds, pausing`). While paused, gametime, `#scan_c`
   and every per-tick counter are frozen and the JVM sits at ~0% CPU — **the pack is not broken**.
   Any "is the pack still ticking?" check performed with 0 players online is meaningless. To
   runtime-test with nobody online, drive the entry point by hand over RCON instead
   (`build/smoke.sh`); it works fine while paused.
8. `tick query` is the cheap health check: it reports real per-tick timing
   (0.5 ms avg, P99 0.7 ms, 20 TPS here) and is far more informative than a frozen counter.
9. RCON replies longer than one packet are split across several packets. A client that reads only
   one **silently truncates** output — `scoreboard objectives list` then looks like objectives are
   missing when they are not. This cost real time during the v19 deploy; `build/rcon.py` now
   drains until the type-2 empty terminator. Do not "simplify" it back.
10. **Vanilla rotates `logs/latest.log` on every boot** (renames it to a dated `.gz` and starts a
    fresh one). So a line-number mark taken *before* a restart points past the end of the new
    file, and any "check the new lines for errors" step silently inspects **nothing** and reports
    success. My first post-restart check reported `0 Failed to load` over an empty range. Use
    `build/postrestart.sh`, which checks the whole new file and asserts the `Done (...)` line.
    Line-number windows are only valid for a *reload*.
11. **Crafty's real endpoints are `/api/v2/servers/<id>/action/{start,stop,restart}_server`.** The
    plausible-looking `/api/v2/commands/<id>` and `/api/v2/servers/<id>/start` return
    `404 API_HANDLER_NOT_FOUND` and the server never restarts. The failure is nasty because a
    naive "is it back?" poll then reports success on a server that never moved — always assert
    you *observed* it go down. The creds file is JSON and the token is at `data.token`.

### Vanilla-behaviour facts established empirically (do not re-derive)
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
| Is `scoreboard players list *` a way to enumerate rows? | **No** — `No relevant score holders could be found`. The bare `scoreboard players list` does list all ~110 holders, but it is a human-readable output command, so a datapack still cannot loop over them. Decides #14. | RCON parse test |
| Does an unset score match `matches 0`? | **No.** Use `unless score X matches 1..`. | live probe |
| Data pack vs resource pack format numbering | **Separate.** For 1.21.11: data pack **94**, resource pack **75**. RP `min_format:[75,0]/max_format:[75,0]` is correct — see the #19 correction. | minecraft.wiki |
| Does `minecraft:chain` exist on this server? | **No.** Absent from the registry; `setblock` and `if block` both error. | `build/checkblocks.py` |

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
All of these live in the `fart.var` objective (except `#stats`, which lives in `fart.total`).
Persistent: `#loaded` (version int, currently **19**) `#enabled` `#neg1 #one #ten #twelve #noplayer
#scan_c` (30-tick cycle, 1..30 then 0) `#rc` (gas reaper, fires at 200) `#stats` `#pid_counter
#cloud #eb_tmp`
Per-call scratch (safe: execution is synchronous): `#power #vy #radius #ppx #ppz #ppx10 #ppz10 #tx #tz
#dx #dz #adx #adz #dist #dist10 #vx #vz #ux10 #uz10 #vy10 #steps #hop #mx10 #mz10 #curx10 #curz10 #fpx #fpz #fdist
#sdx #sdz #smx #smz` (the last four are the movement detector in `player/stress`, added in v20)

### Player / entity tags
`fart.has_pid` `fart.sneak` `fart.releasing` `fart.healtick` `fart.healing` `fart.warnfull`
`fart.etick` `fart.blocktimer` `fart.pushersrc` `fart.pushtarget` `fart.hopper` `fart.selfsrc`
`fart.gas_atomic` `fart.gas_legendary`

---

## 2. Bug catalogue

Status: `FIXED-18` = fixed in the v18 deploy. `FIXED-19` = fixed in the v19 deploy.
`FIXED-20` = fixed in the v20 build, not yet deployed.
`OPEN-C` / `OPEN-D` = deferred.
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

#### #13 — atomic / legendary gas is an undodgeable guaranteed kill  · **FIXED in v19**
Was: `clouds/atomic` `Duration:200` with 8 damage every 20 ticks inside 4.5 → **~80 damage,
armour ignored**; `clouds/legendary` `Duration:300` with 8 damage every 15 ticks inside 8.5 →
**~160 damage**. `world/cloud_random` picks atomic 1-in-6 from *every* mob and dropped item in a
16-block radius, so ordinary mob activity was frequently an instant kill.

Now every damaging cloud has **exactly one damage number and one cadence**, so the total is
`damage × (Duration / cadence)` and that arithmetic is written in the file:

| cloud | damage | cadence | duration | max total |
|---|---|---|---|---|
| atomic | 3 | 20t | 200t | **30** (+ poison I ×100t ≈ 5–10) |
| legendary | 4 | 30t | 300t | **40** |
| legendary (player mega-fart) | 4 | 30t | 100t | **~16** |

Also: atomic's poison dropped from poison **IV**×140t to poison **I**×100t (that alone was ~28
extra damage), the damage selector is now `type=!#fartpack:no_push` (was a 5-type list that
happened to be lit up with item drops), and the player mega-fart's levitation was raised to
amplifier 2 for the full 100t so it is genuinely an escape hatch rather than a death sentence.

#### #14 — unbounded per-entity scoreboard leak  · **PARTIALLY FIXED in v19 (unfixable in part)**
`core/reap` now wipes `fart.gtick` every 200 ticks, which is the dominant term: one row leaked
per gas AEC and AECs are the most-spawned thing in the pack. 200t is far longer than the 20/30-tick
gas cadences, so a reap can never permanently swallow a damage tick.

`fart.cooldown` / `fart.target` are **deliberately left alone** and cannot be fixed in pure
datapack commands — wiping them would make every mob fart simultaneously. Two things established
empirically:
- `scoreboard players list *` is **not** valid (`No relevant score holders could be found`).
- `scoreboard players list` (no args) *does* dump every holder — but it is a human-readable
  output command, so a datapack still cannot loop over the names.

Severity was **overstated** in the original audit: the whole server tracks ~110 holders across
all packs, not "thousands". Re-evaluate before spending more effort here.

#### #15 — the crouch detector is a fragile trick (it does work)  · **DOCUMENTED in v19**
Vanilla has no "is this entity crouching" selector, so the eye-height probe is the *only* signal
available — there is no `unless block ~ ~ ~ minecraft:air` equivalent that is equivalent. Extracted
into `player/sneak.mcfunction` with the derivation written down: sneaking puts the eye anchor at
exactly 1.27 above the feet, so `positioned ~ ~-1.27 ~` lands on your own feet only while crouched
(distance 0) and 0.35 above them when standing. Radius widened 0.1 → 0.2 for float tolerance,
still safely under the 0.35 standing offset.

Real fragility, now documented in-file: it breaks if anything changes eye height — notably the
`minecraft:player_scale` attribute (1.21.4+) or a mod altering sneaking.

#### #16 — `#fartpack:utility` is missing ~19 modern blocks  · **FIXED in v19**
21 → **64** blocks, every one verified against the live server's own registry with
`build/checkblocks.py` (`execute if block` + error sniffing). That check earned its keep:
**`minecraft:chain` does not exist in this server's registry** and would have failed the whole
tag file, silently killing `#fartpack:utility` and every block fart in the game with nothing in
the log. See the gotchas list — *a single unknown value in a `tags/block/*.json` kills the entire
tag.* Do not hand-add block IDs without re-running the checker.

`world/fart_block` was also collapsed: it had 18 hard-coded `if block <id>` + `tellraw` pairs, one
per tagged block, so the tag drove the timer while the copy drove the chat and the two could drift
silently. It is now one generic line that cannot drift.

#### #17 — per-tick cost is the real TPS ceiling  · **FIXED in v19 (measured, see caveat)**
- `world/etick` (new): the `tag @e remove` + per-player `tag @e add` rebuild moved out of
  `world/tick` and onto a 10-tick cadence — **10× fewer** tag sweeps. This was the real hot spot
  (2 writes per entity *per player* *per tick*).
  ⚠ The exclusion list is deliberately unchanged. Do **not** "simplify" it to `type=!#fartpack:no_push`:
  that tag contains `minecraft:item`, and dropped items farting is a core feature.
- `blocks/scan` (147 lines, all three y-levels on one tick) split into `scan_low` / `scan_mid` /
  `scan_high`, one per 10-tick phase → **3× fewer** block checks (147 per 30 ticks, not per 10).
  ⚠ Each gate must be an **exact** tick (`matches 1`), not a range (`matches 1..9`) — a range runs
  the branch on all nine ticks and the total is then unchanged, only the spike moves. I got this
  wrong on the first attempt; the cycle sim caught it.
- `push/core`: investigated and **deliberately left alone** — its four radius branches are not four
  `@e` scans. `execute if score … run <selector>` only evaluates the selector when the score
  matches, and callers set `#radius` to exactly one of 3/4/5/12, so exactly one scan happens.
  Now documented in-file so nobody "optimises" it into a worse version.
- The two gas passes in `world/tick` were left as-is: merging them would need a tag on every AEC
  and the two selectors are already cheap and mutually exclusive.

**Caveat on the win:** `tick query` reports 0.5 ms/tick, P99 0.7 ms, 20 TPS, 6.7% CPU. The pack
was never the bottleneck on this hardware, so this work is headroom, not a rescue.

#### #18 — `fart_forced` applies slowness but not the documented hunger penalty  · **FIXED in v19**
`fart_forced` now gives `hunger 60 1` alongside the slowness, and `player/press` gives
`hunger 5 0` while `fart.pressure ≥ 25` and you are not already releasing, so the
"you'll get hungry from holding that in" warning on the release prompt is now literally true.
Hunger only drains once saturation is gone, so it is a nudge, not a death sentence.

#### #19 — RP drift: the local resource pack is not what the server serves  · **PARTLY FIXED, restart pending**
Server advertises `resource-pack-sha1=834edd3c…`. Downloading that exact URL and diffing against
local proved the drift is real and **is an audio change, not just a rebuild**:
- served: 6 `.ogg` (12 076 / 12 076 / 14 626 / 10 043 / 7 253 / 14 664 bytes), description
  "real synthesized fart audio"
- local: 7 `.ogg` (8 902 / 17 804 / 6 568 / 28 169 / 8 857 / 12 754 / 48 081 bytes), description
  "real CC0 flatulence audio (BigSoundBank)", and `sounds.json` lists **six** `fart.*` entries

So the local CC0 audio was built and **never uploaded**. Any local RP edit is a no-op until it is
re-uploaded to Discord **and** `server.properties` sha1 is patched **and** the server restarts.

**CORRECTION to the original audit of this bug:** the claim that the RP `pack.mcmeta` "has no
`pack_format` at all" was **wrong**, and the RP file must not be changed. minecraft.wiki confirms
**resource pack format 75 = 1.21.11**, and resource-pack and data-pack formats are *separate*
numberings (RP 75 vs data pack 94 for the same version). `min_format: [75,0] / max_format: [75,0]`
is the idiomatic 1.21.9+ form and is correct as written. The datapack's `pack_format: 94` is
likewise correct — vanilla's own built-in pack in the jar uses `min_format: [94,1], max_format: 94`.

#### #20 — three divergent pack copies, no build script, no git  · **RESOLVED**
`fartpack-latest/` and `fartpack_sounds/` are the only editable sources; `src/` is a generated
mirror that `build.sh` syncs and git ignores. `build.sh` is verified deterministic — it
reproduces a known deployed sha1 byte-for-byte. Everything is in git on `main`.

#### #21 — 6 legitimate zero-reference functions  · **NOTE, not a bug**
`fartpack:items` and `fartpack:player/fart` are manual admin commands; `fartpack:load` and
`fartpack:tick` are entrypoints via `tags/function/*.json`; `fartpack:items/on_kibble` and
`on_tonic` are advancement rewards. `player/fart.mcfunction:1` also had a redundant no-op
`if entity @s` (removed) and a tellraw whose closing `")"` was split into its own text component
(merged).

#### #22 — holding a crouch on an empty tank never did damage  · **FIXED in v20**
Reported by the user in-game: *"continuing to crouching with the bar empty does not give you
damage."* Not intermittent — **mathematically impossible**, in every reachable state.

`player/stress` forgives all accumulated strain while the bar has gas, and only hurts after 20
consecutive empty-bar ticks:

```
execute if score @s fart.pressure matches 1.. run scoreboard players set @s fart.stress 0
execute if score @s fart.stress matches 20.. unless score @s fart.pressure matches 1.. run function fartpack:player/stress_hurt
```

But `player/fill_gas` **adds** pressure when the player is *not* moving, and only runs on 3 of
every 30 ticks:

```
execute if score #fdist fart.var matches 0 unless score @s fart.slow matches 1.. run scoreboard players add @s fart.pressure 1
```

So standing still refilled the bar within 10 ticks, and 10 < 20, so `fart.stress` was reset
before it could ever arrive. The only way to hold an empty tank for 20 straight ticks would have
been to crouch-walk, which is exactly what the mechanic was supposed to punish. The two halves
of the design contradicted each other: the refill existed to punish standing still, and it also
neutralised the damage.

**Fix:** the bar refills *because* you are stationary, so movement is what lets the strain build.
`player/stress` now reads the same position delta `player/fill_gas` reads (`Pos × 100`
differenced against `fart.lastx`/`fart.lastz`) and clears `fart.stress` on any movement. It only
*reads* `fart.lastx`/`fart.lastz` — those are written by `core/assign_pid` and `player/fill_gas`,
so `fill_gas`'s own distance maths cannot be corrupted. Ordering is safe: `player/press` runs on
`tick.mcfunction:48`, after `player/fill_gas` on lines 43–45.

The standing-still refill is deliberately **kept**: an empty tank has to stay reachable, or this
whole file is dead code. It is reached by crouching a full bar down (`player/release_gas`),
by `world/fart_forced` resetting the bar at 100, and by toggling the pack off/on.

Resulting loop, which is what was originally intended:

| you are | result |
|---|---|
| crouching, gas in the bar | heals, no damage — gas forgives the strain |
| crouching, empty tank, standing still | 1 damage/second after a 1s grace |
| crouching, empty tank, moving | no damage — movement is how you recover |
| standing up | no damage — only crouching strains |

The actionbar text was wrong too, and in the opposite direction: it said *"Get moving to build
pressure!"* when gas clouds build pressure, not walking, and since v20 moving is precisely how
you stop straining. Now reads *"Move to steady yourself!"*

Verified on a live `chicken` (a real entity, so `data get entity @s Pos` genuinely resolves):
stationary with `fart.stress`=19 takes the damage; the same bird teleported 3 blocks first does
not. `build/stresstest.sh`.

---

#### #23 — block-fart announcements lost the block name (a v19 regression I introduced)  · **FIXED in v20**
Reported by the user: *"it used to say 'crafting table farted!' now its just a utility block
farted!"* — and they were right. This was self-inflicted by #16 in Pass C.

v13–v18 announced the specific block via 18 hand-written `if block <id>` + `tellraw` pairs. The
problem was drift, not verbosity: the tag drove the timer and the hand-written copy drove the
chat, so they had already diverged (21 blocks tagged, 18 announced). Collapsing it to one generic
line in v19 fixed the drift and deleted the detail. That was the wrong trade.

**Fix:** the names come back and the hand-maintained copy does not, because the list is
**generated from the tag at build time** by `build/genblocknames.py` (called from `build.sh`):

- `world/block_name.mcfunction` (generated, 64 one-line lookups) sets `storage fartpack:msg name`
  to a phrase like `"a crafting table"`, with the a/an chosen by the generator.
- `world/fart_msg.mcfunction` is a string macro holding the one and only copy of the sentence,
  with `$(name)` spliced in.
- `world/fart_block` calls the two in order.

The generated file **resets `name` to `"a utility block"` before the lookup chain**. That is
load-bearing: if a block is in the tag but somehow missing from the generated file, you get the
generic message rather than the name of whatever block matched previously. A missing entry can be
vaguely wrong; it can never be confidently wrong.

Inlining the name into a per-block `tellraw` was rejected precisely because that recreates the
18-pair structure. This way the per-block data is data, the sentence is one line, and neither can
drift from the other.

#### #24 — player knockback was applied as teleportation, so first-person read as a teleport  · **FIXED in v20**
Reported by the user: *"when anything fart it does knockback but in the pov of a player the
knockback looks more like teleportation not knocking back."* Accurate, and the cause was blunt.

`push/player` used to be a **hopper**: summon a marker, advance the marker in small steps, and
`tp @s` the player onto it, recursing once per step — and the recursion happened **inside a single
tick** (`push/player_step` → `push/player_hop` → `push/player_step`). So a player's entire
knockback was a burst of instantaneous position changes within one frame. In third person that
reads as knockback, because you watch the whole body displace; from your own first-person camera
it is literally a teleport.

Mobs never had this problem: `push/one` sets `Motion`, which is what vanilla knockback actually is
(an explosion's impulse). The client interpolates it, so it reads as a shove and the server never
contradicts the client's position.

**Fix:** players get `Motion` too, via the same idiom as `push/one`. The whole marker / step /
recurse machinery is gone — `push/player_step` and `push/player_hop` are deleted, along with the
per-step `fart.hopper` marker summons, which were pure overhead.

Two things fixed as a consequence:

- **`#vy` was silently discarded for players.** The old hop only ever wrote `Pos[0]` and `Pos[2]`,
  never `Pos[1]`, so the vertical impulse (20 for a normal push, 40 for legendary) was computed
  and thrown away. Nobody had ever been popped upward — only mobs were. It now applies, which is
  what the numbers always implied.
- **Less integer truncation at range.** `push/one` divides straight down to an integer, so at
  `#power` 12 and distance 12 a component can floor to 0 and the far edge of the radius gets
  almost nothing. `push/player` carries a factor of 10 through the division and stores with
  `double 0.001`, so the impulse lands in 1/1000 blocks per tick and stays consistent across the
  radius. Four extra fake players, no measurable cost.

Deliberately **not** added: a minimum-velocity floor. A hit straight down one axis legitimately
has a zero component on the other, and forcing a non-zero value there would shove players
sideways for no reason. The only thing that needed guarding was division by zero, via the
existing `#dist` floor of 1.

**Not verified by machine:** whether it *feels* right is a human judgement. The scripted check
proves a player now receives a non-zero `Motion` where it previously received a `tp`. Someone has
to stand next to a farting sheep and confirm.

**Machine-verified 2026-09-26** (`build/verifyv20.sh`), driving the function against a tagged
chicken since `push/player` reads only `Pos` and writes only `Motion`, so it is type-agnostic:

| case | expected | actual |
|---|---|---|
| 3 blocks, power 35 | `[0.35, 0.2, 0.0]` | `[0.35000000000000003d, 0.2d, 0.0d]` |
| 3 blocks, power 90 (legendary) | `[0.9, 0.4, 0.0]` | `[0.9d, 0.4d, 0.0d]` |
| 12 blocks, power 12 (long range) | `[0.12, 0.2, 0.0]` | `[0.12d, 0.2d, 0.0d]` |
| diagonal 3+3, power 35 | `[0.175, 0.2, 0.175]` | `[0.17500000000000002d, 0.2d, 0.17500000000000002d]` |
| diagonal 3-3, power 35 | `[0.175, 0.2, -0.175]` | `[0.17500000000000002d, 0.2d, -0.17500000000000002d]` |
| power 0 (control) | `[0.0, 0.0, 0.0]` | `[0.0d, 0.0d, 0.0d]` |

The formula normalises by `dx+dz` (Manhattan), not by true distance, so a 3+3 diagonal splits the
impulse evenly at 0.175 per axis rather than 0.2475. That is the intended behaviour — it is what
makes a hit feel the same whether it lands along an axis or between two.

**Getting this test to tell the truth took four fixes, each of which had produced a table that
looked like a real result:**

1. The "diagonal" case hardcoded the source Z to the bird's own Z, so `dz` was 0 and it was
   secretly identical to the straight case. It dutifully reported the straight-case numbers.
2. The bird was mobile, so it drifted and fell between the scoreboard set, the function call and the
   read, contaminating every row after the first.
3. **The pack was racing the test.** `push/player` takes no arguments — it reads the *global*
   scratch scores `#power` / `#vy` / `#ppx10` / `#ppz10`, which are exactly the globals `push/core`
   writes for every real push. The test bird is a chicken, the pack farts chickens, so the live
   pack overwrote all four in the window between the test setting them and calling the function. A
   `power 0` control came back as `[0.253, 0.2, 0.046]` — a real push, with `#vy` stomped from 0
   to 20. The fix is `#enabled 0` for the section, so `tick.mcfunction` returns before
   `world/tick` and nothing calls `push/core`. `push/player` does not consult `#enabled`, so the
   real code path is still exercised.
4. The control now runs **first** and aborts the section on failure. A row that must be zero and
   is not means the harness is uncontrolled, and every other row is then noise — so it must not be
   printed as one more result.

Point 3 is worth carrying to any other test that pokes pack internals: the pack's scratch globals
are not a stable interface, and anything that writes them from outside while the server is running
is a race.

#### #25 — the source tree was not in git, so the "backup" was empty  · **FIXED**
Found while starting the v25 integration, when the source directory turned out to be absent. This
is the most important entry in this file, because it is a failure of the thing the repo exists to
do, and `git status` reported it as clean the entire time.

Two compounding mistakes:

1. `.gitignore` contains `*.zip`, so **no** versioned zip was ever committed. Every
   `backups/fartpack/vNN.zip` existed on exactly one disk.
2. `fartpack-latest/` and `fartpack_sounds/` were dropped from the index in the Pass C commit
   (`070893a`) and became untracked. They lived only in the working directory. `git status` shows
   untracked files as `??`, but a clean tree plus a passing `git status` reads as healthy, and
   nothing in the workflow asserted "the source is actually tracked".

The directories were then deleted from disk. Recovery was possible only because commit `9f9c4ee`
still had them: 77 datapack files + 10 resource-pack files, verified by extracting both the rebuilt
zip and the zip actually deployed on the server and running `diff -r` — zero differences. The
resource pack matched the deployed sha1 exactly.

Fixes, so this cannot recur quietly:

- The source is tracked. `build/checkrefs.py` and the build both read it from the working tree, so
  an untracked source is now a visible oddity rather than an invisible one.
- **The build is now deterministic.** `zip` stores each entry's mtime, so zipping identical source
  twice produced two different sha1s. That makes a zip's sha1 useless as an identity, which means a
  stored backup can never be proven to match the commit that built it — which is the entire point of
  keeping backups. `build.sh` now stages a copy and forces every mtime to the zip epoch
  (1980-01-01); the source tree itself is untouched. Verified: two builds are byte-identical.
- `backups/MANIFEST.sha256` records the expected sha256 of every versioned zip, so `sha256sum -c`
  is a real check.
- The irreplaceable old zips (v11–v17, for which no source survives anywhere) are uploaded as
  GitHub release assets under the `archive` tag, and the round-trip was verified byte-identical.
  Release assets rather than commits, because with a deterministic build v18+ are reproducible from
  source and committing those binaries would add weight without adding recoverability.
- `DEPLOYED.md` records what the live server is serving, including the trap the determinism change
  created: the live `resource-pack-sha1` is `9c737655…` but a fresh build of the *same* RP content
  now hashes to `10e7af37…`. Verified identical content (10 files, no differences). Rebuilding and
  redeploying the RP without re-cutting the release asset would make every client reject the pack,
  and with `require-resource-pack=true` that makes the server unjoinable.

#### #26 — both consumables worked exactly once per player, ever  · **FIXED in v25**
Found in the independent fork during the v25 integration, and a genuine bug in v20.

`advancement/items/eat_kibble.json` and `drink_tonic.json` are **reward-only** advancements: a
top-level `rewards.function` with no criteria rewards. Minecraft fires an advancement's rewards
**only the first time it is granted**. So the first Anti-Fart Kibble a player ever ate worked, and
every kibble after that — the second one, or any on a later day — did absolutely nothing, with no
error in the log and no message on screen. The item is a recipe ingredient, so players would craft
it, eat it, see the message the first time, and then quietly get nothing forever after.

Fix is one line per item: `advancement revoke @s only <advancement>` after applying the effect, so
the next consumption re-grants the advancement and the reward runs again.

#### #27 — toggling FartPack off did not stop the weather  · **FIXED in v25**
Introduced by the v25 weather system, caught during its own port. `tick.mcfunction` returns early
when `#enabled` is 0, so `world/tick` never runs and the rain particle loop simply freezes — but
`#raining` was still 1, so the storm resumed the instant the pack was re-enabled, possibly with
`#rain_dur` already expired. `core/toggle_off` now clears `#raining`, `#rain_c` and `#event_cd`, so
toggling is an actual stop rather than a pause.

#### #28 — a player crouch-farting could not shove another player, but a sheep could  · **FIXED in v25**
Reported by the user as "bring back players can be knocked back by other players crouch farting".
Not a crash and not an intermittent failure — a deliberate v16.3 change that had gone stale.

`push/release` set `#noplayer 1` around its call to `push/core`, and `push/core` responds to that by
stripping every player out of the target set:

```mcfunction
execute if score #noplayer fart.var matches 1 run tag @e[type=minecraft:player,tag=fart.pushtarget] remove fart.pushtarget
```

The oddity is that `push/release` was the **only** caller in the entire pack that set that flag. So
the four push sources disagreed with each other:

| source of the fart | pushes a nearby player? |
|---|---|
| a sheep / mob farting (`push/norm`) | **yes** |
| a farting furnace or jukebox (`push/block`) | **yes** |
| a small / legendary push | **yes** |
| **another player crouch-farting** (`push/release`) | **no** |

A mob could shove you across a room; the person standing next to you could not. That is the kind of
inconsistency that reads as a bug even when you cannot articulate it.

The fix deletes the two `#noplayer` lines in `push/release` rather than setting them to 0, because
with nothing setting it to 1 the flag is no longer a per-call parameter. It is left in `push/core`
and `core/bootstrap` as what it should have been all along: a **pack-wide admin opt-out**, for the
case where player-vs-player shoving turns out to be griefing in practice.

```
/scoreboard players set #noplayer fart.var 1    # nobody can be shoved, by anything
/scoreboard players set #noplayer fart.var 0    # back on
```

`bootstrap` still initialises it to 0, which is the #4 fix and still correct: a crash inside the old
`push/release` window can no longer strand the flag at 1.

Self-knockback is unaffected either way — it goes through `push/self`, which calls `push/player`
directly and never reads `#noplayer`. And a player can never push themselves through the general
path, because `push/core` tags the source as `fart.pushersrc` and every target selector requires
`tag=!fart.pushersrc`.

**Not machine-verified, by construction.** Proving the shove needs a second player to *be* the push
target, and every deploy in this project is gated on 0 players online. What is verified is that no
executable line anywhere in the pack sets `#noplayer` to 1 any more, so the strip in `push/core`
cannot fire during a crouch release. The shove itself needs two people in-game.

**Also in this version: the lifesteal datapack was removed** at the user's request. It was a
third-party pack (`lifesteal_1.21.11.zip`, authored on a Mac — it carried `__MACOSX` and
`.DS_Store` entries, which is where the `.DS_Store` warnings in the log came from) and it was the
source of the long-standing `utility/quickdeath` parse error, since that function does
`gamerule doImmediateRespawn true` / `kill @s` / `gamerule doImmediateRespawn false`.

It was **backed up before removal** and the copy verified byte-identical by sha256, not trusted from
`cp`'s exit code:

```
/home/nept/crafty/removed-datapacks/removed-from-datapacks/lifesteal_1.21.11.zip
40d208df268981a6ccec223265b48e6fb273add16e080473c45a0d3dbd186ac0
```

That directory is outside `world/datapacks`, so the backup cannot be loaded by accident. `pwr` and
`Graves` were not touched. Script: `build/remove-lifesteal.sh`.

---

## 2b. v25 — the weather and event port

An independent fork of this pack (v18-era, pre-Pass-A) was found with a lot of new content and none
of the safety work. It was a **port, not a merge**: 10 genuinely new files were brought forward and
rewritten against the current architecture, and nothing else was touched.

**Taken:**

- `world/fart_rain_*` (4 files) — putrid fronts every 5–10 minutes. Ambient particles, a mild
  non-lethal nausea pulse every 1.5s as a reminder to get inside, and a burp. No damage and no
  pressure changes, so it cannot interfere with the gas-bar mechanics.
- `world/fart_event_*` (2) and `world/event_*` (4) — random events every 20–40 minutes: gas surge
  (everyone's bar slams to 100, so `player/press` takes everyone legendary on its own), gas cyclone
  (four random clouds around each player), blessing (a wave of `clouds/blessed`), and swarm (every
  tracked entity farts at once, reusing the `fart.etick` set).
- Six utility blocks the fork had and we did not: `cake`, `daylight_detector`, `fletching_table`,
  `lightning_rod`, `lodestone`, `spawner`. Free — the block scan is a 7×7×3 sweep that tests the
  *tag*, not each block, so widening the tag adds no per-tick cost. `world/block_name` is
  regenerated from the tag by `build/genblocknames.py` and picked all six up.
- The #26 advancement-revoke fix and the #27 toggle-off fix described above.

Two changes in v25 came from the user rather than the fork, and are written up as #28: the
player-vs-player knockback was restored, and the unrelated third-party lifesteal datapack was
removed from the server.

**Deliberately NOT taken** — this is the part that matters, because a naive copy would have undone
five shipped fixes:

| From the fork | Why it stays out |
|---|---|
| `push/player_step`, `push/player_hop` | The `tp`-marker knockback deleted in #24. Copying them back reinstates the teleport. |
| `blocks/scan.mcfunction` (147 lines) | Superseded by our 3-way `scan_low`/`scan_mid`/`scan_high` split (#17). |
| `world/tick` rebuilding `fart.etick` every tick | That is the single most expensive thing the pack did — see the numbers in `world/etick`. Already on a 9-in-30 cadence here. |
| `player/stress` (4 lines) | The pre-#22 version. Our 49-line version is the fix. |
| `player/stress_hurt` wording | Carries the old "Get moving to build pressure!", which is wrong twice over. |
| `#scan_c matches 10..` style range gates | Ranges run the branch on every value in the range, which defeats the whole point of the exact-tick-gate cycle. |

**Cadence changes made during the port.** The fork ran the rain particle loop *every tick* — two
`particle` commands per player per tick, so 10 commands/tick for 5 players, for the whole 20–40
second storm. That is exactly the kind of thing that quietly eats the tick budget Pass C reclaimed.
So:

- `fart_rain_tick` and `fart_event_tick` moved onto the existing 30-tick cycle and advance their
  counters by 30 instead of 1. Wall-clock behaviour is identical (6000–12000 ticks is still 5–10
  minutes); it is 1/30th of the scoreboard traffic.
- `fart_rain_active` runs on an exact 3-tick gate and advances `#rain_dur`/`#rain_tick` by 3.
  `#rain_dur` still ends after 400–800 ticks and the nausea still pulses every 30 ticks, so the
  timing is bit-for-bit what the fork intended, at a third of the particle dispatch.
- The gate fires *before* the counter resets. Testing `matches 3` and then zeroing gives
  1,2,FIRE,0,1,2,FIRE; incrementing to 3 and testing `matches 0` instead fires on the tick *after*
  the wrap, i.e. every 4th tick — an off-by-one that still looks like it works.

**`#rain_target` and `#event_target` are deliberately left uninitialised** in `core/bootstrap`. Both
countdown functions use `matches 1..` to mean "not chosen yet", and an unset score does not match
that — so seeding them to 0 would make 0 a legal-looking target and the storm would fire instantly.
Everything else weather-related is initialised so the state is readable on a fresh world.

**Version numbering:** 21–24 were skipped; the user asked for 25 and `#loaded` is 25. The gate is
just `execute unless score #loaded fart.var matches 25`, so the number itself carries no meaning
beyond "different from 20 so bootstrap re-runs".

---

## 3. Fix order (passes)

| Pass | Scope | Status |
|---|---|---|
| **A** | Safety. Complete `core/bootstrap` + unify `load`; version-gate `#loaded`; init `#noplayer`/`#scan_c`/`#stats`; fix `actionbar`; probe-based `ensure_bar` + `#eb_tmp`; drop `fart.lasty`, `#ppy`, `bar/hide*`, `bar/show*`, `push/gentle`; clean live bossbar/scoreboard junk. | **shipped in v18** |
| **B** | Felt bugs. `no_push` tag (#6); explicit `#power` (#11); `unless 1..` in stress (#8); stress cadence + de-spaghetti (#9); `fart.pressure` clamp (#10); real sound throttle (#7). | **shipped in v18** |
| **C** | Tuning + perf. Gas rebalance (#13, #18); gas-scoreboard reaper (#14); crouch detector documented (#15); `utility` block tag 21→64 (#16); `blocks/scan` 3-way split + `world/etick` cadence (#17). | **shipped in v19** |
| **D** | Packaging. Build script + git + one source of truth (#20) **done**; RP re-upload + `server.properties` sha1 bump + restart (#19) **done**. | **done in v19/v20** |
| **E** | Player-reported fixes. Crouch strain unreachable (#22); block-name announcements restored from a generated lookup (#23); player knockback via `Motion` instead of `tp` (#24). | **shipped in v20, all three machine-verified** |
| **F** | Weather + events ported from an independent fork; consumable once-ever fix (#26); toggle-off stops the weather (#27); player-vs-player knockback restored (#28); lifesteal datapack removed. | **v25, lint-clean, pending deploy** |

### Verify-before-deploy (learned the hard way — use this every time)
1. `python3 lintpack.py` against the built zip: parse-checks **every** command line against the
   live server parser. Must report `PARSE FAILURES: 0`.
2. Check every macro file: each command line must contain `$(`. Check only the files that are
   *invoked* `with storage` — not the callers that invoke them.
3. If you touched a `tags/block/*.json`, re-verify every value with `build/checkblocks.py`.
4. Deploy → `datapack enable "file/fartpack.zip"` → `reload`.
5. `grep 'Failed to load' logs/latest.log` **for the new line range only** — old errors stay in the
   file forever and a bare `grep -c` will make you think you broke something. Must show only the
   pre-existing lifesteal `quickdeath` error. (Valid for a reload only — see gotcha 10.)
6. `scoreboard players get #loaded fart.var` to confirm the version gate fired.
7. **Confirm 0 players online *before* reloading, and actually enforce it.** During the v19 deploy
   the check was printed but not asserted, and a player was online for the reload. `deploy.sh`
   now aborts, and refuses to deploy if it cannot read the player count at all.
8. Because of `pause-when-empty-seconds`, step 7's "0 players" also means the pack will not tick
   afterwards. Runtime-verify with `build/smoke.sh`, which drives `fartpack:tick` by hand over
   RCON and works while the server is paused.
9. `tick query` for a real per-tick timing number.
10. For a **restart** (needed for any `resource-pack-sha1` change), use `build/postrestart.sh` and
    `build/craftyrestart.py` — and expect to re-verify the whole new `latest.log`, not a window.

## 4. Revert
Every pass is a standalone zip in `backups/fartpack/vNN.zip`, and the pre-session v16 is also at
`/tmp/fartpack-v16-safety.zip` on the server. To revert: copy the desired zip over
`world/datapacks/fartpack.zip`, then `datapack enable "file/fartpack.zip"` + `reload`.
