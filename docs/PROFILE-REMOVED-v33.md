# profile/ — REMOVED in v33

> **This file lives in `docs/`, not in the datapack.** It started life at
> `fartpack-latest/data/fartpack/function/profile/REMOVED-v33.md`, which is an
> invalid path inside a datapack — everything under `function/` must be a
> function or macro — and the server logged
> `Invalid path in datapack: fartpack:function/profile/REMOVED-v33.md, ignoring`
> on **every reload**. It was harmless and every gate passed, which is the
> problem: a warning that is always present stops being read, and the next line
> in that log that matters goes unread with it. `deployauto.sh` now greps for
> `WARN` lines naming `fartpack` specifically — other mods emit their own, and a
> gate that is always red is a gate nobody reads. Documentation does not ship
> inside the pack.

The whole age/weight/gender profile system is gone, at the user's request: *"the
stats thing just remove it too complicated."*

The verdict is fair. What it cost: four `trigger` objectives, a three-value
handshake across two ticks, eleven files, a written book, a nag that fired every
minute, and a live stats readout — all to vary three numbers that
`admin/defaults` already sets to the same values for everyone.

## What replaces it

Nothing. `admin/defaults`, run by `core/assign_pid` on every join, is now the only
thing that sets a player's numbers:

    fart.rate 1     how fast the bar fills
    fart.cap  100   how big it is
    fart.pow  30   knockback and nausea
    ...and it calls admin/recalc, which derives fart.leg, fart.warn and fart.near

## Files deleted

    profile/apply.mcfunction      the age/weight/gender → rate/cap/pow arithmetic
    profile/awful.mcfunction      the deliberately-worst fallback profile
    profile/book.mcfunction       the written book with the three /trigger commands
    profile/ensure.mcfunction     put a never-chosen player on the awful profile
    profile/nag.mcfunction        "you are on the WORST profile, choose:"
    profile/nag_all.mcfunction    the @a driver for nag
    profile/remind.mcfunction     the once-a-minute nag clock
    profile/skip.mcfunction       /trigger fart.p_skip handler
    profile/stats.mcfunction      /function fartpack:profile/stats
    profile/triggers.mcfunction   the /trigger reader and handshake

## Call sites removed, and what each one was doing

Three files called into `profile/`, and each was checked before cutting:

* **`core/on_join`** — called `profile/ensure` (seed the awful profile) and
  `profile/nag` (ask an undecided player to choose). Both deleted. The welcome
  regen and `book/give` stay: they are not part of the profile system, and the
  ordering comment about `give` throwing still applies to the remaining book.
* **`tick.mcfunction`** — called `profile/triggers` every tick and
  `profile/remind` every 30th. Both deleted. The four
  `scoreboard players enable @a fart.p*` lines went with them, and those were the
  non-obvious ones: `enable` against an objective that no longer exists is a
  command **error**, in a file that runs every tick, so leaving them would have
  been permanent error spam rather than a single log line.
* **`core/bootstrap`** — created the four trigger objectives and five dummies.
  All removed.

## The one thing that cannot be undone

A datapack cannot un-create a scoreboard objective. Anyone who set a profile under
v31 still has `fart.pg`, `fart.pa`, `fart.pw` and `fart.p_skip` on the live
server, and those objectives will keep appearing in `scoreboard objectives list`
until the world is reset.

This is inert — nothing reads them — and the deleted `enable` lines mean they
cannot be typed into any more, which is the outcome we want anyway. But the pack
must never reference `fart.p*` again, and the objective list will look like the
removal half-failed until someone regenerates the world.

## What was checked before deleting

`build/checkrefs.py` resolves every `fartpack:*` reference in the tree and
reports anything uncallable, so a dangling call into a deleted file is a gate
failure rather than something a player discovers. It reports `0` uncallable.
`admin/defaults` was confirmed to set rate/cap/pow and call `recalc`, which is what
guarantees nobody is left with an uninitialised bar after `profile/ensure` stops
running.

## Unrelated, kept

`fart.healgas` (total gas expelled by crouching) survives. It is written by
`player/release_gas` and is not part of the profile system — it was only
*displayed* by the deleted `profile/stats`, but the underlying counter is live
mechanic state.
