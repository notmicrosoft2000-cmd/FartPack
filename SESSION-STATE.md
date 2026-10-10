# SESSION STATE — v33

Written 2026-09-28. **v33 is live.** `#loaded 33`, `PARSE FAILURES: 0`, 0 failed
function loads, lint/deploy hash handshake matched.

## The one thing to know first

The **profile system no longer exists.** There is nothing to set. Every player
gets the same numbers from `admin/defaults` (run by `core/assign_pid` on every
join):

    fart.rate 1     how fast the bar fills
    fart.cap  100   how big it is
    fart.pow  30    knockback and nausea

The `/trigger fart.pg|pa|pw|p_skip` commands, the profile book, the nag, and
`/function fartpack:profile/stats` are all gone. This was the user's call —
*"the stats thing just remove it too complicated."* Do not add them back, and do
not re-add the `scoreboard players enable @a fart.p*` lines: those objectives
still exist on the live server (a datapack cannot un-create a scoreboard
objective) and enabling them is harmless, but nothing reads them any more.

Full removal record: `docs/PROFILE-REMOVED-v33.md`.

## What v33 changed

| Change | Notes |
|---|---|
| Near-full warning at 80% | `fart.near` = `fart.cap - cap/5`, **derived**, not literal. Profiles gave caps 60–180, so the old `pressure matches 80..99` only worked at cap 100. Re-fires via the `fart.warnfull` tag. |
| Crouch blocks gas **inflow** | `player/fill_gas` sets `#famt` to 0 when `fart.sneak`. Closes the crouch-walk exploit. The loop is now walk-to-fill, stop, crouch-to-spend. |
| Two actionbar lines deleted | "Bar must be over 10 to heal" and "Easing the pressure out…". Both fought over one actionbar; last-write-wins deleted the other every tick. |
| Live % on the bossbar name | `fart.pct` = `pressure*100/cap`, floored, clamped to 100. Name re-set only when the integer moves (`fart.pct_shown`). |

## Verified vs not verified

**Verified over RCON:** the percentage arithmetic, 8 cases — cap 100 and cap 180
and cap 60, the over-cap clamp (103→100, 140→100), and cap 0 (returns 0 and
**does not** divide, because the division is gated on `cap matches 1..`).
Divisors `#rc_four`=4, `#rc_five`=5, `#rc_hundred`=100 confirmed seeded live.

**NOT verified — needs a human with a second pair of eyes:**
- Whether the bossbar actually *renders* "63%" on screen. RCON proved the number
  is right; it cannot prove pixels. State this as acceptance, never as proof.
- That crouch-walking now produces no gas. Needs a player to walk, crouch and
  watch the bar.
- The crouch heal itself, the bar fill rate, bossbar resizing, `fart.rate`/
  `fart.pow` clamp arithmetic, player-vs-player shove (#28).

**Unchanged blockers:** #32 (positional macro args unusable — `admin/rate`,
`/every`, `/cap`, `/rel`, `/pow` all rejected, so the config layer is *not*
verified and `#cfgok` stays 0 and `crown.sh` refuses by design), #28.

## Traps this version added

- **`rcon.py` burns 25 seconds on every error response.** It loops to the
  socket timeout instead of returning, so a batch with bad commands *hangs*
  rather than fails. Three verification scripts hung on this. Causes hit:
  `scoreboard objectives add` on an existing objective; annotation lines leaked
  into the command array; and forgetting that **each argv is a separate
  command** (`rcon.py scoreboard players get #loaded fart.var` sends six
  commands and hangs — quote the whole thing). See `build/README.md`.
- **A bossbar name is re-set, never assumed live.** The claim that the name is
  frozen is *inferred*, not measured: the probe showed the server resolved the
  `{"score":…}` component at rename time, but `bossbar get <id> name` is
  rejected so the name could never be read back, and the source score was never
  changed. The design is correct under either answer (re-set on change), which is
  why it is safe to ship — but do not upgrade that comment to "measured" without
  a test that actually varies the score.
- **A macro line with no `$(var)` drops the whole file** (#12). `admin/cap`
  cannot re-seed `#rc_five` itself, for exactly this reason; it is seeded by
  `core/bootstrap` and `admin/recalc` and consumed in `cap`, the same treatment
  `#rc_four` already got.
- **Documentation must not ship inside `data/fartpack/function/`.** A `.md`
  there is an invalid datapack path and logs
  `Invalid path in datapack: … ignoring` on every reload. `deployauto.sh` now
  greps `WARN` lines naming `fartpack`; other mods emit their own and a gate
  that is always red is a gate nobody reads.

## Resume / rebuild

    bash build/pack.sh          # writes to $PWD, self-checks tree<->artifact
    scp fartpack-latest.zip nept@192.168.99.56:/tmp/
    ssh nept@192.168.99.56 'bash /tmp/deployauto.sh 33'

**Only at 0 players.** `deployauto.sh` waits for two consecutive empty polls 30s
apart and re-confirms. Expect `PARSE FAILURES: 0`.

**If it reports failures, do not delete a trailing objective from a
`scoreboard players operation` to force it green** — that is the v26 gas bug
(#30) and it looks exactly like a passing lint.

**If a gate contradicts something you are confident about, check the
artifact's provenance before editing the code.** A hash proves stability, never
currency. The v26/v29 stale-artifact incident: `pack.sh` wrote to
`/tmp/fartpack-latest.zip` while a day-old copy sat in the working directory,
got hashed, "determinism-checked against itself twice", and uploaded. `pack.sh`
now writes to `$PWD`, reads its own output back and compares it to the source
tree in **both** directions.
