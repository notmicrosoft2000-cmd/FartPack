# FartPack — Bug Catalogue & Fix Plan

> Living document. Read this before touching the pack.
> Companion to the server wiki and journals (`~/homelab/wiki/` — index at
> `00-README.md`, per-AI journals under `journals/AI-<N>/`).
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
| Is a macro expanded line-by-line as it runs, or all at once first? | **All at once, first.** A macro cannot write the storage key it reads — the write lands long after `$(…)` was substituted. This is why `bar/tick_gas_bar` has to hand `$(cap)` to `bar/ensure_bar` from the caller. Found by writing the sensible version and noticing it sized every bar from the previous player; see #29. | design reasoning, then confirmed by `PARSE FAILURES` staying 0 with the caller-side write |
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

### #29 — nothing in the pack was configurable · **FEATURE in v26**
Not a defect so much as a gap, and the only entry in this file that is a request rather than a
failure. There were exactly two ways to change how FartPack behaves: edit the functions and
redeploy, or hand a player a consumable. Every number that decides how the gas bar feels was a
constant in a file.

Five are now per-player and settable with `/function` — see the table in `README.md` for the exact
commands, ranges and defaults. `rate`, `every`, `cap`, `rel`, `pow`, plus `show` and `reset`.

**The obstacle is that a scoreboard cannot multiply.** `player/fill_gas` added a hardcoded `+1` or
`+2` per pass depending on whether the player had moved, and there is no command meaning "add
pressure times this player's rate". The fix is to compute the base once into a scratch score and
then repeat the *same* addition once per rate step:

```mcfunction
execute unless score @s fart.rate matches ..0 run scoreboard players operation @s fart.pressure += #famt
execute if score @s fart.rate matches 2.. run scoreboard players operation @s fart.pressure += #famt
…
```

A stock player runs exactly one add and pays four failed comparisons. Critically it adds **no**
entity selector and no `data get`, because the two `data get entity` calls that decide whether the
player moved stay in `fill_gas` where they already were. This pack cares a great deal about
per-tick cost (#17) and the naive version of this feature — running `fill_gas` N times — would
have cost N times the most expensive part of the fill.

The whole feature costs **one** extra command per player per tick (see the macro rule below) and
two comparisons per gas pass.

**Three traps, all of which produced working-looking code:**

1. **`fart.rate 0` and "unset" are the same to a scoreboard.** Both fail `matches 1..`, so the
   obvious guard — `if score @s fart.rate matches 1.. run <add>` — silently stops a player's bar
   filling entirely if they were never initialised, and that failure is indistinguishable from an
   admin having deliberately frozen them. The first add is therefore
   `unless score @s fart.rate matches ..0`, which treats unset as stock and only an explicit 0 as
   frozen. This is also why config is initialised by the `fart.has_cfg` **tag** rather than by
   testing values.

2. **A macro is expanded in full before any of its lines run**, so a macro cannot write the storage
   key it reads. `bar/ensure_bar` wants `$(cap)`, and a `store result storage … macro.cap` inside
   `ensure_bar` would execute long after `$(cap)` had been substituted — sizing every bossbar from
   the previously-processed player. The write had to move to the caller,
   `bar/tick_gas_bar`. This cost one extra command per player per tick, which is the entire
   per-tick price of the feature.

3. **A macro line with no `$(var)` drops the entire file**, and `checkrefs.py` reports the result
   as *uncallable*, not as a parse error — so the failure surfaces as "this function doesn't
   exist" with nothing in the log explaining why. Three of the new files hit this: the bossbar
   resize, the `/4` division, and `admin/show`'s body all wanted lines that had no argument to put
   a variable in. All three moved to plain functions (`admin/resync_bar`, and the arithmetic
   written directly against `$(arg0)`). `build/checkmacro.py` now checks the rule statically,
   because the only other way to find out is a live reload.

**`cap` had to move two thresholds that were hardcoded against the constant 100.** `player/press`
tested `matches 25..` for the hunger warning and `matches 100..` for the forced legendary fart. Left
alone, a 200 cap would have fired the legendary fart at half a bar, and a 40 cap would have made it
unreachable. Both are now derived — `fart.warn` is a quarter of the cap, `fart.leg` is the cap — so
at the stock cap of 100 nothing changes for anybody.

**Verified:** `build/simfill.py` models the fill arithmetic against transcribed command semantics
and asserts 24 properties, including the regression that matters most — *stock behaviour is
byte-identical* — plus that the throttle fires on every Nth pass rather than every Nth+1, that the
two knobs compose exactly (`rate 2` + `every 2` is stock), and that the throttle counter cannot
grow without bound. `build/verifycfg.sh` then exercises the real macros on the live server after
each deploy, against a **fake scoreboard holder** (`#cfgtest`) — scoreboard operations work on fake
players, so the whole clamp-and-derive path is testable at 0 players, which is the only time we are
allowed to run anything. It covers argument substitution, both clamps on every knob, the `/4`
derivation including a non-multiple-of-4 cap, and that `pow 0` is honoured rather than rewritten to
stock.

**Not verified, and not verifiable at 0 players:** that the bar actually fills at the new rate, that
the bossbar resizes, and that the knockback distance changes. `admin/reset`, `admin/show` and
`admin/resync_bar` also begin with `execute as <name>`, which resolves only against real entities,
so those three are untested by construction. The test script says all of this in its own output
rather than reporting a green tick that means less than it appears to.

**Deliberately not scaled by `cap`:** the Anti-Fart Kibble still removes a flat 15. Scaling it would
be more internally consistent and would also have changed how strong it feels for every existing
player the moment this system shipped.

---

### #30 — v26 shipped two files that could not load · **FIXED in v27**

**Symptom.** v26 deployed, the lint said `PARSE FAILURES: 0`, and the deploy script printed
`=== DONE. v26 deployed. ===`. Then the gas bar silently stopped filling for **every player**, and
`/function fartpack:admin/rate` did nothing. Two files had failed to load:

```
[17:06:12] [Server thread/ERROR]: Failed to load function fartpack:admin/recalc
[17:06:12] [Server thread/ERROR]: Failed to load function fartpack:player/apply_gas
  java.lang.IllegalArgumentException: Whilst parsing command on line 28: Unknown or incomplete
  command. See below for error at position 104: ...e += #famt<--[HERE]
```

**Cause.** Eight lines, all the same mistake:

```
scoreboard players operation @s fart.pressure += #famt
```

`scoreboard players operation` takes **five** fields — target, target objective, operator, source,
**source objective** — and stops at four. The existing pack code gets this right everywhere
(`*= #dx fart.var`); I dropped the trailing objective on every line I wrote for #29. In
`player/apply_gas` that is the line that puts gas in the bar, so the bar stopped filling pack-wide.
`admin/recalc` had the same fault twice, and `admin/cap` once.

The error message is close to useless for this: the caret points at the **end** of the line, so it
names neither the missing field nor which line is at fault, and "Unknown or incomplete command" does
not suggest arity. The only clue was the one ERROR line per file naming the file itself.

**Why four separate checks missed it.** This is the part worth remembering, because the bug was not
really the missing field — it was that **every gate reported the failure and then continued anyway**:

| Check | What it did | Why it did not stop the deploy |
|---|---|---|
| `lint.sh` parse lint | `PARSE FAILURES: 0` | It untarred **`/tmp/v25src.tar.gz`**, a leftover from the abandoned v25 attempt, while `deploy.sh` installed `/tmp/fartpack-latest.zip`. It faithfully validated v25. |
| `lintpack.py` exit code | printed the count | Never called `sys.exit`, so `deployauto.sh`'s `if [ $rc -ne 0 ]` could not see a parse failure at all. |
| `deploy.sh` log check | printed `count: 2`, naming both files | Printed and carried on. |
| `deployauto.sh` | printed `DONE. v26 deployed.` | Treated `verifycfg.sh`'s **29 failing checks** as a warning. |

A gate that reports a failure and then proceeds is worse than no gate, because it is trusted. Three
of those four were mine and all four were in the same script chain I had extended that session.

**Also worth recording:** `lintpack.py` substituted only `$(pid)`, so the new `$(arg0)`/`$(arg1)`
lines were sent to the server with a literal `$(arg0)` in place. That *parses* — `$(arg0)` is a legal
scoreboard holder name — which is exactly why `admin/cap`'s arity error hid: the line had the right
shape and the wrong field count, and a literal token did not reveal it.

**Fixes, layered so one is not enough again:**

- `build/checkcmds.py` — **new, static, no server.** Checks field counts for the scoreboard
  subcommands whose arity is fixed. Catches this class in milliseconds and cannot be stale.
- `build/pack.sh` — **new.** Builds the zip deterministically (sorted entries, pinned 1980 timestamps,
  pinned mode and deflate level). The hash was being quoted as if it identified a build; nothing
  enforced reproducibility. Verified by building twice and comparing.
- `build/lint.sh` — lints **the zip that gets installed**, not a source tree, and writes
  `/tmp/linted.sha1`.
- `build/deploy.sh` — refuses to install if the zip's hash moved since the lint, so a rebuild landing
  between gate and copy cannot slip through. Also now **aborts** if any pack function failed to load
  since *this* reload, scoped by recording the log length beforehand (a reload does not rotate
  `latest.log`; only a boot does, so a whole-file grep counts old failures forever).
- `build/lintpack.py` — substitutes every `$(…)`, not just `$(pid)`, and **exits non-zero** on
  `PARSE FAILURES > 0` so the result can reach a branch.
- `build/verifycfg.sh` — new section 0a fails on any `Failed to load function fartpack`. Section 0b
  no longer conflates "did not load" with "errored at runtime": a macro called with no arguments
  answers `Missing arguments to function X`, which distinguishes the two exactly.
- `build/deployauto.sh` — a `verifycfg.sh` failure is now a **failed deploy** (exit 1), not a warning
  on a successful one.
- `build/crown.sh` — waits on **`#cfgok`**, set only after `verifycfg.sh` passes, instead of on
  `#loaded == 26`. This matters: on v26 the config layer was *half* alive — `admin/rate` and friends
  all worked while `apply_gas` was dead — so a version-number check would have gone green, crowned
  the player, and announced a 2× bar on a bar that could not fill at all.
- `build/journal-append.sh` — had a stray `done` from an earlier refactor and **did not parse at
  all**. Found by syntax-checking every script in `build/` rather than only the ones being changed.

**v27 is a repair release, not a feature release.** It bumps the gate to 27 so `bootstrap` re-runs,
and adds one line to it: re-derive `fart.leg` and `fart.warn` for *every* player tagged
`fart.has_cfg`, not just the unconfigured ones. v26's broken `recalc` meant `admin/defaults` set the
tag after calling a function that did not exist, leaving players tagged as configured with no
thresholds — and re-running `defaults` would not repair them, because the tag now says they are
fine. Self-healing the half-written state is the whole point of that line.

**Still not verifiable at 0 players:** `player/apply_gas` itself, which is the function that broke. It
needs an entity for `@s`, so no test at 0 players can cover it. Its correctness rests on
`checkcmds.py` and the load-time abort in `deploy.sh`. That is a real gap, stated rather than papered
over.

### #31 — nine reported defects, all player-facing · **FIXED in v28**

v28 is a behaviour release, not a repair release. v27 fixed two files that could not
load; v28 changes what the pack *does*. All nine items below came from the same
report. They are grouped by subsystem rather than numbered 1–9 in the order asked,
because the interesting content is the reasoning, not the ordering.

#### The push, and why it was a player-only bug

**Symptom.** Crouch-farting did nothing to anybody else. Mobs shoved fine.

**Diagnosis, and the part that is worth not re-deriving.** `push/player` was
measured working on a chicken: probe v3 drove the real function and read
`#dx=20 #dz=0 #dist=20 #ux10=300 #vy10=200`, the chicken's `Motion` came back
`[0.3, 0.2, 0.0]`, and `push/one` — the mob path — was byte-identical. So the
arithmetic was right and the `Motion` write was accepted. The fault was
player-specific, and the mechanism is this: **`Motion` on a player is accepted and
then overwritten by the client's movement packet on the next tick.** A mob's
velocity is integrated by its own physics and survives; a player's is not
authoritative, the client is. Nothing in the datapack can make a `Motion` on a
player stick. That is why the mobs worked and the players did not, and why no
amount of adjusting the numbers would have fixed it.

**Fix.** `push/player` now writes a **relative `tp`** instead of `Motion`, because
`tp` is a displacement the server honours rather than an impulse the client
overwrites.

**The trap in the fix, and the reason for the second new function.** A `tp` is a
displacement and does *not* decay. `player/press` runs every tick and
`player/release_gas` calls `push/core` every tick for the whole length of a crouch
release, so an ungated 0.3-block `tp` would drag a player at 6 blocks a second for
as long as they held the crouch — nothing like the mob shove it is meant to match.
Hence **`push/player_cd`**, a per-player counter that shoves on every 5th call
(4 shoves/second, which reads as being shoved rather than dragged).

It is a **separate function** and that is the entire design point. `push/self` also
calls `push/player`, and it wants to fire *immediately*: it drives two one-shot
events, the crouch self-push from `player/press` and the 0.9-block self-launch at
the end of `world/fart_forced`. Gating those would delay the forced mega-fart's
launch by up to 5 ticks and could swallow it outright if the counter happened to be
high. **A gate that silently eats a one-shot is worse than no gate.** The per-player
counter (rather than a single `#shovecd`) is because one global counter would make a
crowd shove each other in sequence rather than all at once.

**What is still unverified, and it is the important item.** `probe-shove.sh` proves
the new `tp` path displaces an entity by exactly the amount the arithmetic predicts,
and that 5 calls through the gate produce exactly one shove. It does **not** prove a
player is moved, and it cannot: a player's movement is reconciled with the client
every tick in a way a chicken's is not, and no test at 0 players can rule that out.
That reconciliation is the very reason the old path failed, so the probe's own
subject is the mechanism it cannot test. `tp` is chosen *because* it is the
primitive the server honours for a player — that is an argument, not a measurement.
**Someone has to crouch-fart next to somebody and confirm it.** The probe is
deliberately explicit about this in its own output rather than reporting a green
result that implies more than it checked.

#### The heal — the one that broke the deploy twice

Requested: crouch-farting heals ½ heart per second. **½ heart = 1 health point, and
1 HP/second is the target.**

The first thing that is wrong here is the obvious replacement. v27 used
`effect give @s minecraft:regeneration 100000 0 true` — Regeneration I, which
restores 1 HP every 50 ticks. That is half a heart every **2.5 seconds** against a
spec of half a heart every **second**: it was running at a fifth of the intended
rate, and read as "doesn't work" rather than "is slow" because 0.2 HP/sec is
roughly cancelled by whatever damage lands at the same moment.

The second, worse thing: `damage @s -1` — the "negative damage heals" trick — **is
not a valid command.** The amount is a non-negative float:

```
java.lang.IllegalArgumentException: Whilst parsing command on line 36:
Float must not be less than 0.0: found -1.0 at position 90: ...damage @s <--[HERE]
```

I shipped it, and the v28 deploy **installed the pack, reloaded, printed
`PARSE FAILURES: 0`, and reported `player/press` as FAILED TO LOAD** — aborting
with "It is live but INCOMPLETE". The server log is the authority here and
`deploy.sh` caught it, so nothing broken was claimed as working, but a whole
reload was spent finding out. See the lint section below for why the parse gate
let it through.

**The heal that works** is a `data merge` on `Health`, driven by a one-line macro
(`player/heal`), with the number computed by the caller in centi-health points
and rescaled to a double at the boundary:

```
execute ... run data get entity @s Health 100      -> #php, integer centi-HP
execute ... run scoreboard players add #php fart.var 100
execute ... run store result storage fartpack:data macro.hp double 0.01 run scoreboard players get #php
execute ... run function fartpack:player/heal with storage fartpack:data macro
```

Why not `instant_health`, which is the idiomatic heal: it is wrong twice. Instant
Health I is **+4 HP (2 hearts)** and II is +8 — there is no amplifier that is
+1 HP, so the specified rate cannot be expressed at all. And effects apply on the
entity's next tick, and this server runs `pause-when-empty-seconds=60`, so at 0
players **no effect applies and no effect can be tested**. Measured: instant
health at every amplifier left a chicken at exactly 4.0/4.0 HP. `data merge` and
`damage` are immediate, so the mechanism is measurable at 0 players — measured:
0.5→1.5, 1.0→2.0, 2.0→3.0, 3.0→4.0, 3.5→4.5, and three consecutive heals from
0.5 giving 1.5/2.5/3.5, so half-heart granularity survives the ×100/0.01 round
trip. Writing above max health **clamps** rather than overflowing, so healing at
full health is a no-op. A mechanic that cannot be tested has a rate that is a
guess; this one was measured before it shipped.

Two ordering rules, both learned by getting them wrong first:

- **The reset comes LAST**, not before the `tag remove`. All six lines gate on
  `fart.healcd matches 20..`, so resetting first means nothing after it ever sees
  20 and the heal never fires. (An earlier note in `player/press` claimed the
  reset had to precede the tag removal "to be in time" — that is about a
  different line, and following it here silently disables the mechanic.)
- **The caller writes the macro's argument, never the macro itself.** A macro
  expands in full before any of its lines run, so a `store result` inside the
  macro would substitute the *previous* player's value.

The second version of this was still dead, and that is the part worth keeping.
It computed the sum into `#php` and then called a macro reading `$(hp)` from
`fartpack:data macro.hp` — **a key nothing in the pack ever wrote.** The macro
would have failed to expand with "Missing argument hp" once a second. The file
loads, the line parses, the function is called, every gate in this repo reports
the file as healthy. The rule it broke ("the caller stores the value") was
written in `player/heal`'s own comment, which is the problem: a rule that lives
only in a comment is documentation, not a gate. `checkmacro.py` grew a check for
it — see the gates section below.

**Still unverified, stated rather than hidden:** the sequence is measured on a mob
at 0 players, never on a real **player**. `data merge entity` accepts players,
but "accepts players" is not "measured on a player". It also bypasses the
entity's damage/heal events and does not interact with absorption — a player
carrying absorption is healed on top of it rather than through it. For a joke
pack that is the right trade, because the alternative was an unverifiable rate.

#### Hunger

Two separate lines, both removed:

- `player/press` — the per-tick hunger gain while crouch-farting. Deleted.
- `world/fart_forced` — the `hunger 60 1` on the forced mega-fart. Deleted.

`clouds/sulfuric`'s cloud hunger is **kept**: that is a different mechanic (the
cloud applies nausea/hunger to whoever stands in it) and removing it would have
changed a cloud's identity to satisfy a request about crouch-farting. `fart.warn` is
left in place though nothing reads it — noted rather than churned, because deleting
it means touching two macros and `verifycfg.sh` for no behavioural gain.

#### The bar standing still

`player/fill_gas` had four cases: moving/not-slowed → 2, moving/slowed → 1,
still/not-slowed → **1**, still/slowed → 0. The third is now 0. The line that set it
is **deleted rather than set to 0**, because the file already seeds `#famt` to 0 and
an explicit `set … 0` would be a second statement of the same fact that can drift.

This is also what makes `player/stress` reachable at all — see that file's note.

#### Empty bar while still crouching

2 hearts/second of damage. `damage` counts **health points, not hearts**: 1 HP = ½
heart, so 2 hearts/second is `damage @s 4`. The v26 value was `damage 1`, a fifth of
what was asked for.

#### Colours

The report: *"the colors are random they do not look like farts so yellow, green
disgusting colors must be used to make them that color."* Decoded rather than
eyeballed:

| cloud | was | verdict |
|---|---|---|
| methane | `#FFAA00` | orange |
| blessed | `#FFD700` | gold |
| greensmoothie | `#55FF55` | neon |
| atomic | `#82002B` | dark magenta |
| legendary | `#4EFED9` | cyan |
| goat_signature | `#FFFFFF` | white |
| sulfuric | `#C0C0C0` | silver — *this is why the palette was computed, not typed; it had been mentally filed as olive* |
| stinky | `#95D27E` | already in the band |
| creeper_signature | `#57D061` | already in the band |

Seven of nine were outside the band. All nine are now **G > R > B** — green dominant,
red substantial, blue near zero. The red component is what separates "sickly
yellow-green" from "grass"; the near-zero blue is what keeps it off the magic end.
The rationale lives in `world/cloud_random.mcfunction`, the file that actually
chooses between these clouds, rather than being copied into nine files.

The two worst offenders were not the odd colours but the `dragon_breath` clouds:
**that particle is the vanilla spelling of sorcery and no tint turns it into a
fart.** `atomic` and `legendary` moved to `campfire_cosy_smoke` — the pack's own
fart particle, which is what `stinky` already used — and `goat_signature`'s `cloud`
went with them. Kept because they are apt and nobody asked: methane's `flame` (it
ignites), greensmoothie's `happy_villager` (it *is* called the smoothie), creeper's
`explosion`, blessed's `end_rod` (the one deliberately pleasant cloud).

#### Titles

`/title` added to `event_surge`, `event_cyclone`, `event_swarm`, `event_blessing`,
`clouds/legendary`, plus `world/fart_forced`, `player/fart`, `player/stress_hurt`,
`world/fart_rain_start`, `world/fart_rain_end`. **One title per event.** Two
screen-wide titles from a single event reads as a bug, not as emphasis. The chat
`tellraw` is kept alongside every one of them: the title is what you notice while
playing, the chat line is what you can find again in the scrollback.

Fart-rain's nausea is **deliberately kept**. The complaint was that the rain was
invisible, and the fix is to make it visible (`world/fart_rain_active` now doubles
the green dust layer), not to remove the awareness. Removing the nausea would have
made an unnoticeable feature harmless instead of a noticeable one.

#### Three gates that were wrong, and the two v28 deploys they cost

The v28 release took **three** deploy attempts and the first two aborted. Both
abortions are worth more than the feature work, because in both cases a gate
reported a clean verdict about something it had not examined.

**Attempt 1 — a real error, caught before anything was installed.**
`push/player_cd` line 25, `execute if score @s fart.shovecd matches 1..4 return 0`,
was rejected with `Incorrect argument for command`. The non-`run` form of
`execute if` will not take `return`; the server wants `… run <command>`. Asked
directly over RCON: the `run` form is accepted, the no-`run` form is rejected,
`return` takes a bare integer (`return 0 1` and `return true` are both rejected).
`tick.mcfunction:60` already had the `run`; `player_cd` was the only line in the
pack written without it, and it was written minutes earlier. The caret in the
error sits past the end of the line and does not name the missing token — the
same unhelpful failure shape as #30's arity error. This is the gate working as
designed: `PARSE FAILURES: 1`, nothing deployed.

**Attempt 2 — a gate that passed a line the server cannot load.**
`damage @s -1` (above) is rejected with `Float must not be less than 0.0`. The
parse lint reported **`PARSE FAILURES: 0`** for it. The cause is that the lint
decided success by matching a **fixed allow-list of seven error strings**, and
"Float must not be less than 0.0" is not one of them:

```python
PARSE_ERR = ("Unknown or incomplete", "Incorrect argument for command", "Expected",
             "No variables in macro", "Can't parse function line", "Expected whitespace",
             "Unknown registry key")
```

A gate built from an allow-list of known failures **passes anything new by
default** — it gets weaker exactly when the codebase does something it has not
done before, which is the only time a lint is worth running. The pack installed,
reloaded, and the server logged `Failed to load function fartpack:player/press`.
`deploy.sh` caught *that* and refused to claim success, which is the only reason
a broken release is not being reported as a good one, but a whole reload was
spent on it.

The fix is that the list is no longer the mechanism. **Every command-parser error
the server emits ends in `<--[HERE]`**, whatever the message says, so that one
substring covers the whole parser family; the strings are kept only for errors
that never reach the parser (a macro with no variables, an unreadable function).
Verified against the real responses in both directions — 11 cases, 0 misjudged —
and then end-to-end on the box: a clean build exits 0, and a build with the
`damage @s -1` line put back exits 1 and names the file and line.

**Attempt 3 — false positives, from over-correcting.** Broadening the error list
("Invalid", "Too many", "Out of range", "is not allowed", "Malformed",
"not a valid") produced **3 false positives on a clean build**. All three were
bossbar macro instantiations: the lint skips lines containing `bossbar`, but
`function fartpack:admin/set_max with storage …` contains no such word, and
executing it *ran the bossbar line inside the macro*. The blind spot was being
reached a second way. All six added strings were removed — the caret already
catches real parser errors, and a lint that cries wolf is a lint that gets
switched off.

The skip is now computed from the tree rather than from the line: find every
function containing a bossbar command, and skip any line that **calls** one. Two
bugs lived in that fix and both are the same shape:

- The function-id pattern was `[a-z0-9_.-]+/[a-z0-9_./-]+` — **no colon**. A
  command's function id is `namespace:path`, so the pattern matched **0 of 84**
  ids, the skip list never fired once, and the three false positives came straight
  back. The first run of the "fix" reported "still 3", which reads like a partial
  success rather than like a fix that never fired.
- The bossbar-bearing ids were built as file paths
  (`data/fartpack/function/admin/set_max`) and compared against command ids
  (`fartpack:admin/set_max`). Zero overlap.

**A skip list that never matches is indistinguishable from no skip list.** Both
were caught by checking the pattern against the real tree *before* trusting it —
84 ids matched, 12 of the 13 bossbar functions reached — rather than by reading
the code and believing it.

#### What each gate can and cannot tell you

| gate | catches | cannot catch |
|---|---|---|
| `checkcmds.py` | `scoreboard players` arity; `execute` chains missing `run` | anything about the command after `run` |
| `checkmacro.py` | a macro line with no `$(var)`; a `$(arg)` no line in the pack ever writes | `with scoreboard` args; a storage written by another pack; whether the write happens *before* the call |
| `checkrefs.py` | uncallable functions, dangling calls | whether a function does anything when called |
| `lintpack.py` (live) | anything the server's own parser rejects | load-time errors that are not per-line; bossbar commands (skipped) |
| `deploy.sh` log scan | `Failed to load function` after reload | anything that loads but does nothing |
| `simfill.py` | **nothing relevant to v28** | it takes `famt` as a parameter and never opens `fill_gas.mcfunction` — its green result is not evidence about the fill change |

`checkcmds.py` gained the `execute`/`run` check and `checkmacro.py` gained the
supplied-argument check. Both were verified in **both directions** — clean on the
fixed tree, failing on a reverted fixture — because a gate that has never been
seen to fail is a gate whose failure behaviour is unknown. The argument check
took three attempts and produced 8 false positives before it worked; the fix
required measuring `with storage`'s addressing on the live server rather than
assuming it, because **the optional second token is a sub-path prefix** and
arguments resolve at `storage + prefix + name`. Established both directions:
writing `fartpack:data macro.pid` and calling `… with storage fartpack:data macro`
resolves `$(pid)` from `data.macro.pid`, and `fartpack:msg` holding `{name:…}`
works with one token but answers "Found no elements matching macro" with two.

`checkcmds.py` also carries a second, smaller claim worth stating: "every
`execute` chain ends in `run`" is *this pack's convention*, not a rule vanilla
imposes. It has no false positives here and would in a pack written the other way.

#### The world is paused at 0 players, and that changes what can be verified

`pause-when-empty-seconds=60` on this server, so with nobody online **the pack's
tick function does not run at all**. Measured: `#scan_c` does not advance over
four seconds. Three consequences that are easy to get wrong:

- **Effects cannot be tested.** `instant_health` at every amplifier left a chicken
  at exactly 4.0/4.0 HP, because nothing ticks. `damage` and `data merge` are
  immediate, so they can be. This is why the heal is built the way it is.
- **`bootstrap` cannot run**, so `#loaded` does not advance by itself. It reached
  28 only because a probe happened to invoke it. A deploy that waits for the
  version gate to confirm itself will hang or misreport at 0 players.
- **Anything requiring a player cannot be verified at all** — which is the case
  for the shove (§ push above) and for the heal on a real player. Both are
  documented as unverified rather than measured on a mob and reported as working.
---

### #32 — the whole admin config layer has never been callable · **FOUND in v28, NOT FIXED**

Not one of the nine v28 items, and not a v28 regression: this is a **v26-era
defect** that surfaced while verifying v28, and it is recorded here rather than
buried in a journal because a whole feature is dead and the comment headers
still advertise it.

`build/verifycfg.sh` has a section that machine-checks the admin clamps. On its
first ever completed run it reported **30 failures, every one of them `UNSET`** —
and the deploy refused to call the version working, correctly.

**The 30 failures were not 30 broken clamps.** The script was issuing a command
that does not exist:

```
/function fartpack:admin/rate #cfgtest 2
    -> Expected a valid unquoted string
```

**Positional macro arguments cannot be passed as bare command arguments** on this
server version. Measured — every form rejected, none reached the macro:

| invocation | server says |
|---|---|
| `function …/rate #cfgtest 2` | Expected a valid unquoted string |
| `function …/rate #cfgtest "2"` | Expected a valid unquoted string |
| `function …/rate "#cfgtest" "2"` | Expected a valid unquoted string |
| `function …/rate abc 2` | Expected compound tag |
| `function …/rate abc 2.5` | Expected compound tag |
| `function …/rate a` (one arg) | Expected compound tag — it wants a **tag path** |
| `function …/rate` (no args) | runs, then *Missing arguments* |
| `function …/rate with storage …` | reaches the macro — *Missing argument arg0* |

The grammar, asked for directly, is `function <id> [<tag path>]` or
`with <storage|scoreboard|entity>`. There is no "two bare words" form. The **only**
working way to pass `$(arg0)`/`$(arg1)` is a storage that already contains them,
which is how v28's own `player/heal` does it — measured working:

```
data modify storage fartpack:data macro set value {"arg0":"Steve","arg1":2}
function fartpack:admin/rate with storage fartpack:data macro
```

**Scope: 9 of the 12 files in `admin/` take positional arguments** — `rate`,
`every`, `cap`, `rel`, `pow`, `reset`, `show`, `recalc`, `resync_bar` — so the
entire per-player configuration layer added in `50f17cf` *“v26: per-player config
layer”* (#29) has never been usable. The only places the bare-arg form appears
anywhere in the pack are **five comment headers**, e.g. `admin/rate.mcfunction:3`
`#   /function fartpack:admin/rate Steve 2`. Nothing in the pack calls them
internally, so no tick, no test, and no player had ever exercised the path.

**A second, independent blocker at 0 players**, even with the syntax fixed: every
setter ends in `$tellraw $(arg0) […]`, and `tellraw` needs a real player, so
`#cfgtest` cannot stand in for one. `verifycfg.sh`'s own header claimed otherwise
— *“SCOREBOARD OPERATIONS WORK ON FAKE PLAYERS … Nothing needs to be connected”* —
and that premise is false for these macros. A fake holder is not a substitute for
a player when the command targets one.

#### What was changed, and what deliberately was not

- **The 30 checks were not deleted and not relaxed into a pass.** They are
  replaced by a **detector**: it asserts the documented form is *still* rejected.
  The day someone fixes the admin layer this gate starts failing and says the
  clamp sections are worth re-enabling — instead of the fix passing unnoticed,
  which is exactly how this defect survived v26, v27 and two v28 deploys.
- **The clamps are now reported as NOT RUN.** Not passing, not failing. No test
  executed, so there is no verdict to report.
- **`deployauto.sh` no longer sets `#cfgok` from `verifycfg`'s exit status.**
  Exit 0 now means only *“nothing this gate can examine is broken”*, and `#cfgok`
  is the single flag `crown.sh` waits on before telling a player their buff is
  live. Setting it on that evidence would repeat the exact mistake this entry is
  about. `#cfgok` stays 0.
- **`crown.sh` refuses in one second, with the reason.** It used to sit for 5400s
  waiting for a flag that can no longer be raised. It already verified the config
  actually applied before announcing, so its safety property held; it just failed
  slowly and without saying why. Verified: `crown.sh <player>` exits 2, prints
  the parser error, announces nothing, and that player's scores are untouched
  (`rate 1`, `pow 30` — both stock).
- **`verifycfg.sh` section 0a is now bounded to the last reload.** It was
  `grep -c`ing the whole of `latest.log`, and a reload does not clear the log, so
  it counted the two earlier broken v28 deploys and reported 4 load failures
  against a reload where `player/press` loads perfectly. It now finds the last
  `Reloading!` line and scans only what follows — and when it **cannot** find
  that bound it fails rather than falling back to counting history, because a
  check that cannot say what it examined must not return a pass.

#### The fix, for whoever picks it up

Convert the setters to take the player as `@s` and the value from a scoreboard,
so no macro argument is needed — e.g. an admin types
`/scoreboard players set Steve fart.rate 2` and then a non-macro
`fartpack:admin/rate_apply` reads `@s` and derives `fart.leg`/`fart.warn` from it.
That keeps the clamps, the derivations and the read-back, and it works with
`execute as` so `admin/reset`, `admin/show` and `admin/resync_bar` become
testable too. Re-enable `verifycfg` sections 2–6 against a real player at the
same time, or the arithmetic stays unverified for a third release.

### #33 — v29: two v28 regressions, four dead features, three new ones · **FIXED in v29**

Everything below is either a defect measured on this server or a feature whose
implementation is measured. Where something could not be verified from here it
says so, and where a first attempt was wrong it says that too.

#### #33a — crouch healing was invisible · **v28 regression**

`player/press` set `fart.healing` while crouched and removed it only on standing
up (lines 89–92). But the gas bar drains during the crouch, so the trace went

```
8.0 → 9.0 → 5.0     net −3.0 HP/sec
```

Healing worked, then the strain damage in the same second took it straight back,
and the player saw nothing but a number going down. The cause is that the empty
tank was still being charged at `#power 24` per tick, so an empty bar *caused* the
strain that cancelled the heal.

Fixed by three lines in `player/press`, each gated on `fart.pressure matches 1..`:
reset `fart.healcd 0`, remove `fart.healing`, remove `fart.healtick`. `healtick`
is in that list deliberately — leaving it set is what turns an empty tank into a
per-tick self-inflicted shove at lines 85–86.

#### #33b — straining while moving dealt no damage · **v28 regression**

`player/stress` forgave the strain on a movement delta. The comment claimed it
read the delta "exactly as `player/fill_gas` reads them", and that was false:
`fill_gas` **negates** the delta first (`#dx *= #neg1`) and only then tests
`matches 1..`, which forgives a *negative* (moving backwards). `stress` tested the
raw delta, so `matches 1..` forgave **forward** motion and punished standing still.

Measured, one fresh cow per trial, because `damage` grants ~0.5 s of hurt immunity
and a reused fixture reads exactly like "the mechanic does nothing":

| delta | result |
|---|---|
| +50 (forward) | **no damage** |
| −50 (backward) | −4.0 HP |
| 0 (still) | −4.0 HP |

`HurtTime` went 0→10 on exactly the two damaging trials, confirming the reads were
real and not a scoring artefact.

Fixed by deleting the six delta commands (`#sdx`/`#sdz`/`#smx`/`#smz`) outright
rather than negating them. The user asked for the movement escape hatch to be
gone, and a negated copy of a private set of variables is more machinery than the
thing it replaces. All four were private to that file, so nothing dangles.
`fart.lastx`/`fart.lastz` are `fill_gas`'s and were left alone.

#### #33c — every death message was the generic fallback

The pack shipped **no `lang` file at all**. The two custom damage types
(`fartpack:atomic_gas`, `fartpack:legendary_gas`) both carry a `message_id`, both
resolved to nothing, and the player got the plain "X died" text. `data/fartpack/lang/en_us.json`
now exists with both keys, named `death.attack.fartpack.<message_id>`.

The user asked for `/damage` with custom parameters. **New custom damage types
cannot be delivered this way, and that is a measured dead end, not a preference:**
registering a new `damage_type` needs a world restart, not `/reload`. A probe pack
containing a byte-for-byte valid control type failed to register exactly as the
invalid one did. A restart is the superuser's call, and it is not worth spending
on a cosmetic change that the deploy gate **cannot verify** — an unresolvable
damage type is a *runtime* error, so the function still loads, `failed function
loads: 0` stays green, and the pack throws once a second with nothing to catch it.

So the extra variety comes from damage types the server already has. Confirmed
present, with the check proven able to report absence (it correctly rejects
`minecraft:bad_omen` and `minecraft:with_fire`, which do not exist here):
`minecraft:explosion`, `minecraft:dragon_breath`, `fartpack:atomic_gas`,
`fartpack:legendary_gas`. `player/stress_hurt` now rolls `random value 1..4`
between them.

#### #33d — the clouds were never yellow, and re-tuning the colour could not have fixed it

v28 had already shipped a yellow-**green** `#9EC11A` and the user still saw a
non-yellow cloud. The reason is that `custom_particle` **forces** a particle type
per cloud, and every one of those carries its own fixed colour:

| particle | renders as | used by |
|---|---|---|
| `campfire_cosy_smoke` | grey | stinky, atomic, legendary, goat_signature |
| `campfire_signal_smoke` | grey | sulfuric |
| `happy_villager` | green | greensmoothie |
| `end_rod` | white/gold | blessed |
| `flame` | orange | methane |
| `explosion` | grey | creeper_signature |
| `dragon_breath` | magenta | fart_forced |

A forced particle is not tinted by the cloud's colour, so
`potion_contents.custom_color` never reached the screen. Changing the hex value
was a no-op dressed up as a fix. All ten AECs now use `minecraft:effect`, the
vanilla particle that *does* render in the cloud's colour, with a yellow
`custom_color`.

**The trade-off, stated plainly:** vanilla has no tinted *smoke* particle — `smoke`
and both campfire smokes are grey whatever colour is set. "Smoke" and "yellow"
cannot both be had. The user asked for yellow twice; this is yellow, and it is a
one-word revert per file if they want grey smoke back.

A tenth cloud was found outside `clouds/`: `world/fart_forced` had a Radius-8
dragon-breath cloud in mint `#4EFED9`. It is yellow now too.

**Discarded first attempt:** an earlier pass added a top-level `Color:` field to
all nine clouds "so the next failure would be unambiguous". Measured: the server
stores no such field and `data get entity … Color` reports no elements, so it was
silently discarded — dead weight implying a control it did not have. Removed.
(With the honest caveat that my "must survive" control, `Particle:`, also failed
to round-trip, so the test cannot strictly prove `Color:` is absent rather than
merely unset. What it does prove is that `Color:` does nothing.)

#### #33e — `camera_shake` was not a camera shake, and rotation jitter is impossible here

The whole function was one line: `effect give @a[…distance=..3] minecraft:nausea 2 0`
— two ticks, amplifier 0, bystanders only. The person who farted felt nothing.

The honest implementation would jitter the player's `Rotation`. Five mechanisms
were measured; all five are dead ends, recorded here so nobody re-derives them:

| mechanism | result |
|---|---|
| `tp <t> ~ ~ ~ #scoreholder ~` | runtime error — `RotationArgument` is a plain double and, unlike the x/y/z slots, takes no score holder |
| `tp <t> ~ ~ ~ $(macro) ~` | will not **load** — `Incorrect argument for command at position 6: tp @s` |
| `tp <t> ~ ~ ~ 47.0 ~` | works, but nothing can compute the `47.0` |
| `data merge entity <t> {Rotation:[47.0f,-20.0f]}` | **works** — seed 45/−20 reads back exactly `[47.0f, −20.0f]`, pitch preserved — but needs a literal |
| `data merge entity <t> {Rotation:[$(macro).0f, …]}` | will not **load** — `Expected literal B at position 32` |

So macros work inside NBT in *some* commands (v28's `player/heal` merges `$(hp)`
into `Health`) and inside JSON text, but never in a coordinate, a rotation, or an
NBT list element. Both ends of the computation are unavailable, which makes this
impossible rather than awkward. Same family as #32.

Nausea is therefore not a fallback — it is the only camera-wobbling lever a
datapack has here. What changed is that it is turned up: it now reaches the farter,
lasts 1–2 s instead of a fifth of one, and scales with the fart's own `fart.pow`,
so a boss fart hits like a boss.

Also measured on the way: a literal negative in `scoreboard players add` is
rejected at load (`Integer must not be less than 0`). Use `remove`.

**NOT VERIFIED:** the world is paused at zero players, so how any of this *looks*
cannot be checked from here. Same class as #28.

#### #33f — "Total Farts" was one global counter, not a leaderboard

`fart.total` was only ever incremented on the fake player `#stats`
(`world/fart_entity:1`, `world/fart_block:18`). There was no per-player counter at
all, so the sidebar showed a single line — a global total wearing a leaderboard's
name. The user was right that it needed remaking.

* `fart_entity:1` now credits the farter, `if entity @s[type=minecraft:player]`.
* Block farts have no owner to credit, so they go to a new **undisplayed**
  `fart.blocks` rather than pretending to be a player.
* `#stats` is `reset` off `fart.total` — `set … 0` would have left a zero-scoring
  fake player sitting at the bottom of the board forever.
* The heading needed `scoreboard objectives **modify** … displayname`. Editing the
  `objectives add` line changed nothing on the live server, because `add` is a
  no-op on an objective that already exists. Caught by the lint's response census,
  which still read `Total Farts` after a bootstrap run.

**NOT VERIFIED:** vanilla sidebar sort order cannot be observed without a client.
Whether it sorts high-to-low needs a human to confirm; if it is inverted, the fix
is one line in bootstrap.

#### #33g — new: the Fart King and the spawn book

**Fart King.** The crown goes to the highest `fart.total`, and a tie is broken for
whoever got there first. That is implemented as **strictly greater** and nothing
else: a challenger must *beat* the incumbent, not match them, so the incumbent
keeps a tie. No timestamps, no join order, no float equality to get wrong. The
winner is unique because the first player to beat the bar raises it, so the next
player must beat *that*.

"2× more" is `fart.rate 2`, the pack's own gas multiplier, **not** extra
leaderboard credit — reading `player/apply_gas`, `#famt` is added once for any
non-zero rate and once more per step from 2 up, so rate 2 applies it twice: double
pressure, harder farts. Crediting the king extra points would have made the
leaderboard lie, since he would climb the very board he is meant to be leading.

The incumbent's total is read from whichever **online** player holds the
`fart.king` tag, so a crown is never held by someone who is not in the world. The
cost of that is handled in `core/on_join`: a returning ex-king still holds the tag
and still holds `fart.rate 2`, so on join they are demoted and must win it back —
otherwise they would walk in as an uncrowned, double-rate player and `king/crown`
would not notice, because the tag still says they are king.

**Spawn book.** `written_book[minecraft:written_book_content={title,author,pages}]`,
measured rather than written from memory, because a malformed item is a runtime
error on *every join* and the load gate cannot see it. The probe put each
candidate through `item replace block <chest> container.0` and read the block
entity back; `minecraft:not_a_real_thing={…}` is **rejected** ("Unknown item
component") and `{title:5}` is **rejected** ("Malformed … No key author"), which
is what makes the two acceptances mean something.

Handed out once, gated on a `fart.got_book` tag. There is no way to ask "does this
player already own a book" from a function — a player's inventory is not readable
as entity NBT — so a rejoin would otherwise stack a second copy.

`core/on_join` does the crown repair **before** the book, on purpose: a `give` that
throws aborts the rest of its function, so this way a broken book can only ever
cost the player their book, never their in-game state.

**NOT VERIFIED:** the book's page contents and the crown's feel both need a human
in the world.

#### Two gates that were wrong before the work was

Recorded because both would have shipped a broken v29:

* `scoreboard players operation #kbest fart.var = #mine` — the **source objective
  is required on both sides**. The lint caught it: `Unknown or incomplete command`.
* `tag @a[remove=fart.king_new]` — there is no `remove=` selector option on this
  server. The command form is `tag @a remove fart.king_new`. Caught twice.

And one gate of my own that reported a verdict about something it never
examined: the first written-book probe used a horse's `weapon.0` slot, which does
not exist ("Unknown slot"), so every case aborted before the item NBT was parsed —
and the case-match labelled all five **rejected** cases as "accepted". A chest
fixed the fixture; the two rejections above are what make that run trustworthy.


### #34 — v30/v31/v32: the heal, and a measurement that was right about the wrong thing · **FIXED in v32**

Five versions of the same mechanic, and the reason it is written up as one entry
is that the *symptom* was constant ("the crouch heal doesn't work") while the cause
was different every time. A player reporting a bug is evidence about their
experience, not a pointer at a line number, and three of the five causes were
found by reading a number rather than by reading code.

#### 1. It was unreachable, then it was invisible, then it was absurd

* **v28** shipped no crouch heal at all — a deliberate revert.
* **v29** re-added it as `regeneration 100000 0`. Vanilla heals **1 HP every
  `50 >> amplifier` ticks**, so amplifier 0 is half a heart every 2.5 seconds. The
  `100000` was duration, not strength, and reading it as strength is the whole
  mistake. It was in fact removed again in the same pass.
* **v30** shipped `regeneration 2 0` and it "worked" and nobody noticed, for the
  same arithmetic reason wearing a different hat.
* **v31** shipped `regeneration 2 5` — **Regeneration VI, 1 HP per tick**, a full
  health bar in one tick, 16× amplifier 4. The player reported "god its too much".

So "it does not work" and "it is absurd" were the same number read from opposite
ends, and neither report identified the line. Amplifier 3 is the current default:
a full heal in about six seconds, slow enough to read as a heal rather than a
heal button. It is a live score (`#healamp`) precisely because this has now been
re-tuned twice and there is no reason it should not be re-tuned a third time
without a version bump.

#### 2. The gas was not being charged for the heal

`fart.healing` is added on the second tick of a crouch and the only line that
removes it is the "no longer sneaking" one. It is **not** removed when the tank
empties. Gating the effect on that tag alone meant a player could crouch on an
empty tank and keep the tag — and at 1 HP/tick the heal simply out-paced the
strain damage `player/stress` charges for having no gas. Free full health for
holding a key, which deletes the gas economy the whole pack is built on. This is
the third time this file has shipped an ungated heal.

v31 fixed it with `fart.pressure=1..`. The player then found the next hole in it:
gas is **movement**-fed and a crouch drains it, so a `pressure > 0` gate can be
farmed by crouch-moving in small circles to keep trickling the tank over the line
and collecting a tick or two of regen each pass. v32 requires `> #healmin` (10),
so healing is bought with a genuinely full bar and the total is bounded by the gas
rather than by how finely that gas can be dribbled past a threshold.

#### 3. The six syntax traps, all of which cost a version

* **An UNSET score matches no range at all** — not `matches 0`, not `matches 1..`.
  The self-seed therefore has to be `unless score … matches ..-1`, not `matches 0`;
  the latter would have left the heal silently dead while every other line kept
  working. Same trap as `fart.rate`.
* **`effect give` cannot take a score**, only a literal, so a tunable amplifier is
  six branches — the same enum trap as `#radius`.
* **`matches #healmin+1..` is not a thing.** A range needs literals, so the
  threshold comparison is `if score @s fart.pressure > #healmin fart.var`.
* **That 4-field comparison needs the source objective for a FAKE player and must
  omit it for an entity.** All five fields is rejected outright.
* **A `title` actionbar is last-write-wins**, so two of them in one function means
  the second silently replaces the first.
* **RCON drops the connection above ~1450 characters of command text** (1433
  accepted, 1455 lost). The profile book had to be cut from 2149 to 1329 chars to
  fit. `RCON_MAX=1400` now fails the lint closed.

#### 4. A component that PARSES is not a component that PRINTS WHAT YOU THINK

The real find, and the reason this entry is long. v31's profile readout used

```
{"selector":"@s","scores":{"fart.rate":1}}
```

to display the player's `fart.rate`. It parses. It does not do that. A `selector`
component prints the **name** of whatever the selector matched, and the `scores`
argument only decides whether to print at all — so the function rendered

> bar fills at **rate Fartgod** | bar size **Fartgod** | knockback **Fartgod**

and a genuine `0` deleted the field rather than showing it. Every gate passed,
because the command succeeded. The correct form is the other component type,
`{"score":{"name":"@s","objective":"fart.rate"}}`, which the pack has used in
`admin/*` since v29 without anyone having to wonder what it did.

The instructive part is how it got in. `profile/apply` carries a comment recording
that a `scores` filter on a selector component was **measured** to be accepted —
with a deliberately malformed control alongside it, precisely so the acceptance
would mean something. The measurement was sound. **The inference drawn from it was
not**: "it accepts a `scores` filter" was read as "so this prints the score", when
the filter's entire job is to filter. A probe that establishes a fact about the
*parser* was used to conclude something about the *renderer*, and no amount of
probing the parser could ever have caught it. Rendering is the one thing RCON
cannot read back.

Two rules came out of it. One, the obvious one: **probe the thing you are going to
claim.** Two, the one that cost the most: **a negative control that the server
rejects proves your probe can fail; it does not prove the positive case renders.**
A component pointed at a nonexistent objective was *accepted silently*, so "no
error" was worthless as a signal in the same run — which is now recorded in
`build/README.md` as the standing rule.

#### 5. Two gates of my own that lied about what they checked

* **`lintpack.py` used one socket for ~1200 commands.** The connection was closed
  partway through and `BrokenPipeError` killed the run, so a pack with real parse
  failures could report clean. It now reconnects and retries, and **an
  over-long or uncheckable line is a hard failure, not a skip** — failing closed
  is the only safe direction for a gate.
* **`build/probe-booklen.py` reported a verdict about a command it never saw.** It
  wrapped "accepted, empty response" in the same `<< >>` markers used for transport
  loss and tested `startswith("<<")`, so a **success was reported as a dropped
  connection** — the exact inverse of the truth. It now distinguishes ANSWERED /
  SILENT / LOST explicitly and runs a mandatory control command before trusting any
  negative. Same root cause as §4: a probe that reports on something it did not
  examine is worse than no probe, because it is believed.

#### 6. A determinism check run against a file that was never built

The v32 deploy aborted with **8 parse failures** in `player/apply_gas` and
`admin/recalc` — lines I had personally edited earlier the same session to add
the trailing source objective, and lines whose own comments document the fix as
belonging to #30. `scoreboard players operation` takes five fields; the lint
reported four, on files whose gas bar demonstrably fills in-game.

The tempting move was to "fix" the pack by deleting `fart.var` from those lines,
because that is what would have made the lint go green. That would have
**reintroduced the v26 gas bug for real** — the one where the whole file fails to
load and the bar silently stops filling for everyone. The gate was right and the
code looked wrong, and the only reason that was resolvable is that the two
disagreed in a way that could be checked rather than argued about.

The actual cause was one layer up. `build/pack.sh` defaulted its output to
`/tmp/fartpack-latest.zip`, while a **stale `fartpack-latest.zip` from the
previous day sat in the working directory**. The script wrote the real build to
`/tmp`; I hashed `./fartpack-latest.zip` in the repo. So:

* the sha1 I reported as "v32" was a **day-old artifact**,
* the "two builds are byte-identical" check hashed that same untouched file
  twice, which is not a determinism check at all — it is a tautology,
* the freshly built artifact was never inspected once,
* and that stale 64 KB zip really did contain the v26 four-field bug, so the lint
  was reporting a true finding about a file that was not the one I believed I
  was shipping.

Three fixes, in increasing order of how much they actually prevent:

1. **The stale file was deleted.** It was untracked (`*.zip` is in `.gitignore`),
   so it would never have shown up in a diff or a status, and it sat in the one
   directory anyone would build from. A file that is ignored by git and named
   exactly like the build output is the worst of both worlds: invisible and
   authoritative.
2. **`pack.sh` now writes into the repo**, next to the source it builds from, so
   there is one artifact and one name.
3. **`pack.sh` now reads its own output back and compares it to the source tree**,
   in both directions — every entry must match its file, and every file must
   appear. This is the check that matters, and it is the one that was missing:
   **a hash proves an artifact is stable, never that it is current.** The shipped
   file was perfectly reproducible and two days out of date at the same time.

The transferable rule, and it is the same one as §4 and §5 from a new direction:
**when a gate contradicts something you are confident about, the cheapest
explanation is that the gate is looking at a different artifact than you are.**
Check the artifact's provenance before you edit the code it is complaining about.
Every one of these entries is a verifier reporting a verdict about something it
did not examine — the linter, the probe, the determinism check, and me.


The rendered text of a `score` component naming `@s` — accepted by the server,
but per §4 acceptance is not rendering, and there is no way to read an actionbar
back over RCON. Needs one human glance at `profile/stats`. The *feel* of
amplifier 3 also needs a human: the number is chosen by arithmetic, and arithmetic
is not what "noticeable" means.


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

**v25 was never deployed.** The auto-deploy sat behind the 0-player gate for the whole session while
players were on, and by the time the per-player config layer (#29) was written it was more honest to
skip straight to 26 than to reload twice. The server went from `#loaded 20` to `#loaded 26` in one
operation, so **there is no v25 rollback point** — v25 exists only as this section of the changelog.
The weather and event work is in v26 unchanged.

---

## 3. Fix order (passes)

| Pass | Scope | Status |
|---|---|---|
| **A** | Safety. Complete `core/bootstrap` + unify `load`; version-gate `#loaded`; init `#noplayer`/`#scan_c`/`#stats`; fix `actionbar`; probe-based `ensure_bar` + `#eb_tmp`; drop `fart.lasty`, `#ppy`, `bar/hide*`, `bar/show*`, `push/gentle`; clean live bossbar/scoreboard junk. | **shipped in v18** |
| **B** | Felt bugs. `no_push` tag (#6); explicit `#power` (#11); `unless 1..` in stress (#8); stress cadence + de-spaghetti (#9); `fart.pressure` clamp (#10); real sound throttle (#7). | **shipped in v18** |
| **C** | Tuning + perf. Gas rebalance (#13, #18); gas-scoreboard reaper (#14); crouch detector documented (#15); `utility` block tag 21→64 (#16); `blocks/scan` 3-way split + `world/etick` cadence (#17). | **shipped in v19** |
| **D** | Packaging. Build script + git + one source of truth (#20) **done**; RP re-upload + `server.properties` sha1 bump + restart (#19) **done**. | **done in v19/v20** |
| **E** | Player-reported fixes. Crouch strain unreachable (#22); block-name announcements restored from a generated lookup (#23); player knockback via `Motion` instead of `tp` (#24). | **shipped in v20, all three machine-verified** |
| **F** | Weather + events ported from an independent fork; consumable once-ever fix (#26); toggle-off stops the weather (#27); player-vs-player knockback restored (#28); lifesteal datapack removed; per-player config layer (#29); v26's two unloadable files repaired and the four gates that let them through made into real gates (#30). | **v27, lint-clean, pending deploy** |

### Verify-before-deploy (learned the hard way — use this every time)

Run the static gates first. They need no server, so they cannot be stale, and they are fast:

```bash
bash build/pack.sh                        # deterministic zip; prints its sha1
python3 build/checkcmds.py fartpack-latest   # scoreboard arity  (#30)
python3 build/checkmacro.py fartpack-latest  # macro rule
python3 build/checkrefs.py fartpack-latest   # dangling / uncallable functions
python3 build/simfill.py                     # fill-rate arithmetic
```

Then the server-side gate, which is `build/deployauto.sh <version>` and does the rest in order:

1. Wait for 0 players across a 2-poll, 30-second window, then re-confirm immediately before acting.
2. `build/lint.sh` parse-checks **every** command line in **the zip that is about to be installed**
   against the live server parser, and writes `/tmp/linted.sha1`. It exits non-zero on
   `PARSE FAILURES > 0`. (It used to untar a hardcoded leftover tarball — see #30. If you ever see
   `linting sha1:` missing, the gate is not running and nothing below can be trusted.)
3. If you touched a `tags/block/*.json`, re-verify every value with `build/checkblocks.py`.
4. `build/deploy.sh` refuses to install if the zip's hash moved since step 2, copies it, then
   `datapack enable "file/fartpack.zip"` + `reload`.
5. `grep 'Failed to load' logs/latest.log` **scoped to lines added by this reload** — the script
   records the log length first, because a reload does not rotate the file and a bare `grep -c`
   counts old failures forever. Any pack function in that window **aborts the deploy**. (Valid for
   a reload only — see gotcha 10.)
6. `scoreboard players get #loaded fart.var` to confirm the version gate fired.
7. `build/verifycfg.sh` exercises the real admin macros on a fake scoreboard holder. A failure here
   makes the whole deploy report **FAILED** and leaves `#cfgok` at 0. `build/crown.sh` waits on
   `#cfgok`, so a broken config layer cannot be announced as a working buff.
8. Because of `pause-when-empty-seconds`, step 1's "0 players" also means the pack will not tick
   afterwards. Runtime-verify with `build/smoke.sh`, which drives `fartpack:tick` by hand over
   RCON and works while the server is paused.
9. `tick query` for a real per-tick timing number.
10. For a **restart** (needed for any `resource-pack-sha1` change), use `build/postrestart.sh` and
    `build/craftyrestart.py` — and expect to re-verify the whole new `latest.log`, not a window.

**The rule underneath all of these:** a check that reports a failure and then lets the deploy
continue is not a check. Every step above now *stops* the deploy. If you add a gate, make sure it
propagates a non-zero exit status, or it is decoration.

## 4. Revert
Every pass is a standalone zip in `backups/fartpack/vNN.zip`, and the pre-session v16 is also at
`/tmp/fartpack-v16-safety.zip` on the server. To revert: copy the desired zip over
`world/datapacks/fartpack.zip`, then `datapack enable "file/fartpack.zip"` + `reload`.
