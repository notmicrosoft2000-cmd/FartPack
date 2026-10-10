# core/bootstrap - full initializer. Bump the version at the bottom whenever an
# objective is added or removed; tick.mcfunction runs this on a version mismatch
# so new objectives actually get created on an existing world.

scoreboard objectives add fart.cooldown dummy
scoreboard objectives add fart.target dummy
scoreboard objectives add fart.var dummy
scoreboard objectives add fart.pressure dummy
scoreboard objectives add fart.stress dummy
scoreboard objectives add fart.pid dummy
scoreboard objectives add fart.slow dummy
scoreboard objectives add fart.lastx dummy
scoreboard objectives add fart.lastz dummy
scoreboard objectives add fart.hurtt dummy
scoreboard objectives add fart.gtick dummy
scoreboard objectives add fart.sndt dummy
scoreboard objectives add fart.blocks dummy
scoreboard objectives add fart.total dummy {"text":"  \u2500\u2500 FARTS \u2500\u2500","color":"gold"}
scoreboard objectives add fart.toggle trigger
# Per-player config (v26). These are the knobs admin/* expose. All of them have a
# fail-safe default that reproduces the pre-v26 behaviour when UNSET, so a player
# who somehow never gets initialised still fills and drains at stock speed -
# see player/apply_gas for the specific trap that "unset" and "0" look identical
# to a scoreboard, and why `fart.has_cfg` exists to tell them apart.
scoreboard objectives add fart.rate dummy
scoreboard objectives add fart.every dummy
scoreboard objectives add fart.cyc dummy
scoreboard objectives add fart.cap dummy
scoreboard objectives add fart.leg dummy
scoreboard objectives add fart.warn dummy
# v33: the 80%-of-your-own-cap line the "GAS PRESSURE NEAR MAX" warning fires at.
# Derived in admin/recalc (and mirrored in admin/cap) as cap - cap/5, because the
# v19 version of this warning was a literal `pressure matches 80..99` and that was
# only correct while every player had the same cap of 100. Profiles give every
# player a different cap from 60 to 180, so a literal would warn a 180-cap player
# at 44% and never fire at all for a 60-cap player whose bar cannot reach 80.
scoreboard objectives add fart.near dummy
# v33: the live percentage shown on the bossbar name, and the last value the name
# was set to. The bar is already drawn proportionally (its max is the player's own
# cap), so this is the NUMERIC readout on top of the visual fill. `fart.pct_shown`
# exists so the name is only re-set when the integer percentage actually changes -
# a bossbar name is FROZEN at rename time (measured: the name kept an old value
# until re-set), so it has to be re-set to stay live, but re-setting it every tick
# for every player is 1 extra command x players x ticks for a string that changes
# only when the rounded percent moves. Comparing against the last-shown value
# means the common case is one failed comparison and no command at all.
scoreboard objectives add fart.pct dummy
scoreboard objectives add fart.pct_shown dummy
scoreboard objectives add fart.rel dummy
scoreboard objectives add fart.pow dummy
# v34: the tonic gets its OWN flag. It used to write fart.slow, and fill_gas read
# that as "halve the fill", which is right for the kibble (1-in-100 roll) and
# wrong for the tonic (fill not at all). A scoreboard cannot hold two meanings for
# one holder, so the tonic needs a separate score:
#   fart.slow   kibble window, already added at the top of this file. While it is
#               1.. fill_gas rolls 1-in-100 instead of filling outright.
#   fart.nofill tonic window, also a tick-down timer. While it is 1.. fill_gas
#               does not fill AT ALL, and this beats fart.slow - a player who
#               drinks a tonic on top of a kibble stays at zero until the tonic
#               runs out, which is what "does not fill for 90s" has to mean.
# Both are 1.. = active. 0 or unset = inactive, so assign_pid seeds both to 0.
# NOTE: fart.slow is deliberately NOT re-added here. `scoreboard objectives add`
# against an existing objective is a command error, and this file runs on the
# version gate for every player on the server.
scoreboard objectives add fart.nofill dummy
# v28: two per-tick counters added for the two mechanics that had to become
# exact rather than approximate.
#   fart.healcd  drives the crouch heal, firing player/heal once every 20 ticks
#                for exactly 1 HP = half a heart. It replaced a Regeneration I
#                effect, which was running at a fifth of the specified rate. It
#                does NOT fire `damage @s -1`, which is not a valid command - see
#                player/heal and BUGS-AND-FIXES #31.
#   fart.shovecd gates the radial player shove to every 5th call, because the
#                player path is now a `tp` (displacement) rather than a `Motion`
#                (impulse) and does not decay on its own - see push/player_cd.
# Both are safe to leave unset: `add` on an unset score makes it 1, so neither
# depends on bootstrap having run, and neither can be left stranded at a value
# that skips its own first firing.
scoreboard objectives add fart.healcd dummy
scoreboard objectives add fart.shovecd dummy
# v30: the crouch heal is paid for out of gas actually expelled, so this counts
# the gas, not the ticks. See player/press for why the tick counter could not
# work: fill_gas only produces while the player MOVES (#famt is 0 when
# stationary) while the crouch drains fart.rel every tick, so the tank always
# reaches 0 during a stationary crouch and a "20 consecutive ticks with gas"
# heal was unreachable in steady state. Measured peak: healcd 12 of 20.
#
# Left unset on purpose, exactly like fart.healcd: `add` on an unset score makes
# it the added amount, so a player who joins mid-session cannot inherit a
# stranded value that skips their own first heal.
scoreboard objectives add fart.healgas dummy
# v30: scratch space for "gas in the tank before this release tick", used only by
# player/release_gas to measure how much was really expelled. Per-player, not a
# `#` fake player, because two players crouching on the same tick would
# overwrite each other's value and one would be paid for gas the other expelled.
scoreboard objectives add fart.presspre dummy
# v33: THE PROFILE SYSTEM IS REMOVED. The whole gender/age/weight block below is
# deleted - the four /trigger objectives, the three committed-input dummies, the
# decided/handshake flags - along with profile/* and the nag/remind calls.
#
# The user judged it too complicated, which is a fair verdict on a system that cost
# four trigger objectives, an eleven-file feature, a written book and a whole
# handshake protocol to vary three numbers that admin/defaults already sets to
# rate 1 / cap 100 / pow 30 for everyone. admin/defaults (run by core/assign_pid
# on every join) is now the single source of a player's numbers.
#
# The objectives are NOT merely unseeded but DELETED, which is a real decision: a
# datapack cannot un-create a scoreboard objective, so a player who set a profile
# under v31 keeps `fart.pg` and friends on the live server forever. That is inert -
# nothing reads them any more - but it means the objective list will still show
# them until the world is reset, and the pack must never reference them again.
# v32: how hard the crouch heal hits, as a REGENERATION amplifier 0-5. An objective
# rather than a literal in player/press, because the user reported the v31 heal
# as far too strong and the next report will be a number between "still too much"
# and "not enough". With it in a score, that is one RCON command and no redeploy;
# as a literal in the function it is a version bump and a full gated deploy every
# time somebody changes their mind about a number.
#
#   0  Regeneration I     1 HP / 2.5s   a nudge
#   1  Regeneration II    1 HP / 1.25s
#   2  Regeneration III   1 HP / 0.6s
#   3  Regeneration IV    1 HP / 0.3s   <- v32 default
#   4  Regeneration V     1 HP / 0.15s
#   5  Regeneration VI    1 HP / 1 TICK  a full heal in a single tick
#
# WHY THE CURVE IS A CLIFF AND NOT A SLOPE, because it explains the whole
# "far too strong" report. Vanilla heals 1 HP every `50 >> amplifier` ticks, and
# the shift saturates: 50, 25, 12, 6, 3, 1. Amplifier 5 is not "a bit more than 4",
# it is sixteen times amplifier 4 and it is a full health bar per tick. v31 shipped
# at 5 and a single crouch tick took a player from nearly dead to full, which is
# why it read as broken rather than strong. 3 is the last value before the cliff
# gets steep, and it is six times slower than 5 while still finishing a full heal
# in about six seconds of crouching.
#
# `#healper` is unrelated and is dead: it was the gas-per-heal divisor in v30 and
# is kept only so a reader chasing it finds the note explaining it is gone.
scoreboard objectives add fart.healamp dummy
# v32: the bar level healing starts from. 10 means "more than 10 gas", i.e. 11+.
# It exists as a score for the same reason #healamp does, and for one more: the
# anti-exploit threshold is a balance number, and balance numbers are the ones most
# likely to want changing after players have actually played with it.
#
# WHY A THRESHOLD AT ALL, since v31 healed from any gas at all. Gas is fed by
# movement and drained by crouching, so a `pressure > 0` gate can be farmed: crouch
# in a small circle, let the tank trickle up to 1, take a tick or two of regen,
# repeat. Each individual tick is cheap and the total is unbounded, which is
# exactly the shape of a bug that a player spots in ten seconds. Requiring a
# genuinely full bar makes the healing bought with a given quantity of gas, instead
# of bought with the number of times you can dribble that gas past a line.
scoreboard objectives add fart.healmin dummy
scoreboard players enable @a fart.toggle
scoreboard players set #neg1 fart.var -1
# The constant 4, used to turn a bar cap into a quarter-of-full hunger warning.
# Seeded here because admin/cap's macro cannot set it - a macro line has to
# carry a $(arg) and `set #rc_four ... 4` has nowhere to put one. admin/recalc
# re-seeds it too, so the two paths cannot drift.
scoreboard players set #rc_four fart.var 4
# v33: the /5 for the 80% near-full line. Paired with #rc_four, and both are
# re-set at the top of admin/recalc and admin/cap rather than trusted from here, so
# a datapack that half-loaded cannot leave these dividing by nothing.
scoreboard players set #rc_five fart.var 5
# v33: the 100 for the bar percentage. Multiplied into the pressure before the
# division by the cap, because `scoreboard players operation` has no `*= literal`
# and no way to write "pressure times 100 over cap" in one line. Same treatment as
# #rc_four and #rc_five: a real scoreboard constant, re-seeded per use where the
# caller can be reached without bootstrap.
scoreboard players set #rc_hundred fart.var 100
# v34: the /10 that items/on_kibble uses to drop 10% of a player's own cap rather
# than a flat 15. Seeded here for symmetry with the pair above, though the file
# that uses it re-seeds it locally anyway, so a reset here cannot break it.
scoreboard players set #rc_ten fart.var 10
scoreboard players set #noplayer fart.var 0
scoreboard players set #scan_c fart.var 0
scoreboard players set #rc fart.var 0
scoreboard players reset #stats fart.total
scoreboard players set #stats fart.blocks 0
scoreboard players set #kbest fart.var 0
# v30: gas (in tank units) that buys 1 HP = half a heart of crouch healing, and
# the Fart King's knockback multiplier. Both are `#` constants rather than
# per-player objectives on purpose: they are not part of anyone's gas config,
# so putting them in admin/defaults would mean teaching verifycfg.sh to assert
# two numbers that are not player settings.
#
# #healper 10 with the stock fart.rel of 1 reproduces the rate player/heal has
# always documented - half a heart every SECOND - so the tuning is unchanged
# and only the REACHABILITY is new. A full 100 tank is therefore worth 10 HP,
# 5 hearts, which is a real decision rather than a rounding error.
scoreboard players set #healper fart.var 10
# v31: #healper is NO LONGER USED. The crouch heal is a Regeneration effect now,
# not a per-10-gas purchase - see player/press. The constant is left in place
# rather than deleted because fart.healgas still counts gas expelled and is shown
# in profile/stats, and because removing a seeded `#` constant is a change with no
# upside and a small chance of leaving a reader looking for where it went.
#
# v31: the four profile divisors. `scoreboard players operation` cannot divide by
# a literal - the source has to be a score holder, which is the entire reason
# #rc_four exists - so every constant in the age/weight curve needs seeding. They
# are re-seeded at the top of profile/apply as well, for the reason #rc_four gives:
# a function that divides by a constant bootstrap has not reached yet fails
# loudly and only on the tick a player first chooses a profile.
#   /25  age curve      /17, /12, /7  weight curve
scoreboard players set #pf25 fart.var 25
scoreboard players set #pf17 fart.var 17
scoreboard players set #pf12 fart.var 12
scoreboard players set #pf7 fart.var 7
# v32: the crouch heal strength. 3 = Regeneration IV. Change it live with
#   scoreboard players set #healamp fart.var <0-5>
# and it takes effect on the next tick, because player/press reads it every tick
# rather than baking it into the effect command. See the objective's note for the
# table and for why 5 was far too much.
scoreboard players set #healamp fart.var 3
scoreboard players set #healmin fart.var 10
# v31: the king's farts hit three times as hard and reach 30 blocks. Applied in
# push/core, which is the only place that knows #radius, and #radius is an enum
# - see the comment there.
scoreboard players set #kpow fart.var 3
# v31: the "you have not chosen a profile yet" nag cadence, in units of the
# 30-tick scan cycle it hangs off, so 40 is 40 x 30 = 1200 ticks = one minute.
# Deliberately NOT seeded here, and the reason is the same one that keeps
# #rain_target and #event_target unset: profile/remind does its `remove` FIRST and
# then treats "not 1.." as due, so it self-seeds on the first pass. Seeding it to
# 0 would make it nag every 1.5 seconds instead of every minute.
# Weather and event state (v25). Every one of these is a fake player on fart.var.
#
# They are seeded here rather than left to first use so the state is readable with
# a plain `scoreboard players get` on a fresh world. #rain_target and
# #event_target are deliberately left UNSET: both countdown functions test
# `matches 1..` to mean "not chosen yet", and an unset score does not match that,
# so a 0 would be a legal-looking target and the storm would fire instantly.
# Do not initialise them to 0.
scoreboard players set #raining fart.var 0
scoreboard players set #rain_c fart.var 0
scoreboard players set #rain_cd fart.var 0
scoreboard players set #rain_dur fart.var 0
scoreboard players set #rain_tick fart.var 0
scoreboard players set #event_cd fart.var 0
scoreboard players set #event_pick fart.var 0
execute unless score #enabled fart.var matches 0 run scoreboard players set #enabled fart.var 1
scoreboard objectives modify fart.total displayname {"text":"  \u2500\u2500 FARTS \u2500\u2500","color":"gold"}
scoreboard objectives setdisplay sidebar fart.total
# v26: give stock config to exactly the players who have none.
#
# The tag test, not a value test. `fart.rate 0` (frozen) and "never set" are both
# invisible to `matches 1..`, so checking scores would either re-freeze a player
# somebody deliberately froze, or skip a player who needs initialising - and the
# second one is the dangerous direction, because an uninitialised player has a
# bar that never fills.
#
# This is also the reason the version gate exists at all: adding the objectives
# above is not enough on a world that already has players, and a version bump is
# what makes this line run exactly once per upgrade rather than every tick.
execute as @a[tag=fart.has_pid,tag=!fart.has_cfg] run function fartpack:admin/defaults
# ...and re-derive the two cap-relative thresholds for EVERY configured player,
# not just the unconfigured ones. admin/defaults is idempotent, but it is not
# self-healing: it sets the tag AFTER calling admin/recalc, so when recalc failed
# to load in v26 the tag was still applied and the player was left with no
# fart.leg and no fart.warn. Re-running defaults would not fix them either,
# because the tag now says they are configured. This line does.
#
# Only on a version bump, so it costs nothing per tick, and it repairs exactly
# the half-written state v26 could produce.
execute as @a[tag=fart.has_cfg] run function fartpack:admin/recalc
data modify storage fartpack:data macro set value {}
# v28: 27 -> 28. The bump is what creates fart.healcd and fart.shovecd on a world
# that already exists, via the gate on line 1 of tick.mcfunction. It is not
# cosmetic and it is not optional - without it the two new counters have no
# objective to live on and `scoreboard players add` fails outright on the
# per-tick path, for every player, every tick.
#
# v31: 30 -> 31. Creates the nine profile objectives above, and is also the ONLY
# thing that runs the welcome regen below exactly once for the players who
# already have a world. Both halves of that are the reason the bump is load-
# bearing rather than a version string.
#
# THE WELCOME REGEN IS A MIGRATION, and it is here rather than in core/on_join
# because bootstrap runs on the version gate and on_join runs per join. A player
# who already exists must be given the "welcome, heal up" buff once when the
# pack is upgraded; a player who joins later gets it from on_join instead. Putting
# it in bootstrap gives the existing players their one-off and NOT the new ones,
# which is the correct way round - a returning player should not be topped up
# every single time they log in.
#   Regeneration II, 200 ticks (10s). Amplifier 1, deliberately modest: this is a
#   "start at full health" gesture, not a reward. The crouch heal is the thing
#   that is supposed to be strong, and it is a separate effect entirely.
execute as @a[name=!"Server"] run effect give @s minecraft:regeneration 200 1 true
# v34: Bumping the number HERE and in tick.mcfunction's version gate is the only
# way a new objective (fart.nofill) reaches an already-existing world - the gate
# is what re-runs this file, and the add is a no-op error if the score exists.
scoreboard players set #loaded fart.var 34
