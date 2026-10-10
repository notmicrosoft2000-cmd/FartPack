execute store result score #fpx fart.var run data get entity @s Pos[0] 100
execute store result score #fpz fart.var run data get entity @s Pos[2] 100
scoreboard players operation #dx fart.var = #fpx fart.var
scoreboard players operation #dx fart.var -= @s fart.lastx
scoreboard players operation #dz fart.var = #fpz fart.var
scoreboard players operation #dz fart.var -= @s fart.lastz
execute if score #dx fart.var < #neg1 fart.var run scoreboard players operation #dx fart.var *= #neg1 fart.var
execute if score #dz fart.var < #neg1 fart.var run scoreboard players operation #dz fart.var *= #neg1 fart.var
scoreboard players operation #fdist fart.var = #dx fart.var
scoreboard players operation #fdist fart.var += #dz fart.var
scoreboard players operation @s fart.lastx = #fpx fart.var
scoreboard players operation @s fart.lastz = #fpz fart.var
# How much gas one movement-derived pass is worth, into #famt. This is the same
# four cases as before the config system existed, just parked in a score instead
# of added directly, because a scoreboard cannot multiply - there is no way to
# write "add pressure times this player's rate" as one command. Parking the base
# lets player/apply_gas repeat `operation += #famt` once per rate step instead,
# which is 2 commands per step and adds no selector or data get.
#
#   moving, not slowed -> 2      moving, slowed  -> 1
#   still,  not slowed -> 0      still,  slowed  -> 0
#
# v28: "still, not slowed" was 1 and is now 0. Reported by the user as "make it
# so the bar doesn't fill when the player stands still", which is also what makes
# player/stress reachable at all - see the long note there. The `matches 0` line
# that used to set 1 is DELETED rather than set to 0, because line 22 above
# already seeds #famt to 0 unconditionally: writing a redundant 0 would be a
# second statement of the same fact, and the next person to edit this table would
# have to work out which of two zeros was the real one.
#
# The consequence worth stating plainly: the bar is now filled by MOVEMENT ONLY.
# Standing still produces no gas at all, so the bar can only be emptied by
# crouch-releasing it (player/release_gas), by world/fart_forced resetting it to
# 0, or by toggling. All three still exist, so an empty tank is still reachable.
#
# v33: and since then MOVING WHILE CROUCHING DOES NOT COUNT AS MOVEMENT either -
# see the last line of this file. So the full rule is: walk to fill, crouch to
# spend, and the two are mutually exclusive.
scoreboard players set #famt fart.var 0
execute if score #fdist fart.var matches 1.. run scoreboard players set #famt fart.var 2
#
# v34: THE TWO CONSUMABLES STOPPED SHARING A FLAG. Up to v33 both the kibble and
# the tonic wrote fart.slow, and both of these lines read it the same way - one
# line halved the fill for "slows your bar". That was true of the kibble and
# false of the tonic: the user asked for the tonic to make the bar NOT fill for
# 90 seconds, and halving is not that. So they are two mechanisms now:
#
#   fart.nofill  1.. = the tonic is drunk. #famt is forced to 0 and NO gas is
#                added this pass, at all. This is checked FIRST and is not
#                guarded by the crouch or nofill conditions below, because "no
#                fill" is absolute - a player who drinks a tonic and then
#                crouch-walks, or drinks one on top of a kibble, still gains
#                nothing until the tonic runs out.
#   fart.slow    1.. = a kibble is digesting. The fill is replaced by a 1-in-100
#                roll per movement pass, which is the closest a scoreboard can
#                get to "fills at 1%". Normal fill is 2 gas per pass, so 1% of
#                that is 0.02 gas - scores are integers and there is no
#                fractional score, so the rate is expressed as a probability
#                instead: each movement pass has a 1% chance of granting 1 gas.
#                A kibble on a 100-cap bar takes roughly 200 ticks of walking to
#                add one point of gas.
#
# WHY A ROLL AND NOT AN ACCUMULATOR: a 1-gas-every-100-passes version would be
# exactly 1% and fully deterministic, but it needs a second per-player counter
# objective plus a compare-and-reset, and the difference only shows up as
# variance the player cannot perceive either way. The roll is the same rate with
# two commands and no new holder.
#
# ORDER IS LOAD-BEARING. The nofill test has to be able to override everything
# below it, so it is applied AFTER the table rather than as a fourth row: rows
# below are additive cases and the crouch rule is already the last row, so
# appending keeps "last writer wins" as the mechanism instead of adding a
# `tag=!` clause to each row.
execute if score @s fart.nofill matches 1.. run scoreboard players set #famt fart.var 0
# The roll. `store result score` belongs BETWEEN `execute` and `run` - writing it
# after the subcommand (`run random value ... store result`) is a syntax error,
# and it would have silently done nothing.
execute if score #fdist fart.var matches 1.. if score @s fart.slow matches 1.. if score @s fart.nofill matches ..0 store result score #froll fart.var run random value 1..100
# ...and the win test carries the SAME three conditions as the roll above, which
# is what makes a stale #froll harmless: on any pass where the roll does not
# happen - the player is standing still, the kibble ran out, the tonic is drunk -
# one of these three is false, so the leftover value cannot be read. Resetting
# #froll each tick would work too and costs a command; repeating the conditions
# costs none and cannot be forgotten at a later call site.
execute if score #fdist fart.var matches 1.. if score @s fart.slow matches 1.. if score @s fart.nofill matches ..0 if score #froll fart.var matches 1 run scoreboard players set #famt fart.var 1
# v33: CROUCHING DOES NOT FILL THE BAR. The user asked for this directly, and the
# reason is an exploit rather than a preference: gas fills from movement and a
# crouch drains it, so before this a player could crouch-walk in a small circle
# and land in a state where the fill outran the drain - crouch-moving forever,
# never straining, never emptying. That deleted the entire cost of the mechanic.
# The heal threshold added in v32 made the farming less efficient but did not
# close it, because the tank only had to cross 11 once per circle.
#
# So crouching is now strictly a DRAIN. You fill by walking, you spend by crouching,
# and the two can never happen at once. The consequence, which is the intended
# shape of the mechanic rather than a side effect: healing only works when you
# have stopped moving, so the loop is walk-to-fill, stop, crouch-to-spend.
#
# This is a THIRD gate on the crouch heal and they now stack: the `fart.healing`
# tag, then `pressure > #healmin`, and now no inflow while crouching. Each was
# added because the previous one was insufficient, and the file's history is the
# evidence for that - it has shipped an ungated heal three separate times.
#
# Set to 0 rather than skipping the two lines above, so the table stays readable
# as a table and the crouch rule is one visible line rather than a `tag=!` clause
# repeated on every row.
execute if entity @s[tag=fart.sneak] run scoreboard players set #famt fart.var 0
# Throttle (admin/every): advance this player's counter and add only on the pass
# where it reads 1. The counter is clamped as well as wrapped, because with
# `every` at 1 the wrap branch never runs - the guard is `matches 2..` - and an
# unclamped counter would climb forever, one point per pass, forever.
scoreboard players add @s fart.cyc 1
execute if score @s fart.every matches 2.. if score @s fart.cyc >= @s fart.every run scoreboard players set @s fart.cyc 0
execute if score @s fart.cyc matches 64.. run scoreboard players set @s fart.cyc 0
execute unless score @s fart.every matches 2.. run function fartpack:player/apply_gas
execute if score @s fart.every matches 2.. if score @s fart.cyc matches 1 run function fartpack:player/apply_gas