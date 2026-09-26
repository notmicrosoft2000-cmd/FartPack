# player/stress - the cost of crouching on an empty tank.
#
# BUG (reported by the user 2026-09-26, fixed in v20): holding a crouch with an
# empty bar never did any damage. The mechanism was unreachable, not just rare:
#
#   line 3 below forgives all stress while fart.pressure >= 1, and the hurt needs
#   20 consecutive empty-bar ticks. But player/fill_gas ADDS +1 pressure when the
#   player is NOT moving, and only runs on 3 of every 30 ticks. So standing still
#   refilled the bar within 10 ticks, every time, and stress was reset long
#   before it could reach 20. The one thing this mechanic exists to do was
#   impossible.
#
# Fix: the bar refills precisely BECAUSE you are standing still, so movement is
# what lets the strain build. Any movement clears the accumulated stress.
#
# Position deltas are read exactly as player/fill_gas reads them - Pos scaled by
# 100 and differenced against the previous sample - so a single sub-block nudge
# counts. fart.lastx / fart.lastz are written by core/assign_pid and
# player/fill_gas; this file only reads them, so it cannot corrupt fill_gas's own
# distance maths. Ordering is safe: player/press runs on tick.mcfunction line 48,
# after player/fill_gas on lines 43-45, so the sample this reads was refreshed
# earlier in the same tick.
#
# The standing-still refill itself is deliberately KEPT. An empty tank has to stay
# reachable, otherwise this file is dead code: you get an empty tank by crouching
# a full bar down (player/release_gas), by world/fart_forced resetting the bar to
# 0 when it hits 100, or by fart.pressure being reset on toggling.
#
# Net effect, which is the intended loop:
#   crouch with gas in the bar  -> heals, no damage (gas forgives the strain)
#   crouch on an empty tank     -> 1 damage/second after a 1s grace
#   crouch-walk on an empty tank-> no damage; movement is how you recover
#   stand up                    -> no damage; only crouching strains

# 1. did the player move since the last sample?
execute store result score #sdx fart.var run data get entity @s Pos[0] 100
execute store result score #sdz fart.var run data get entity @s Pos[2] 100
scoreboard players operation #smx fart.var = #sdx fart.var
scoreboard players operation #smx fart.var -= @s fart.lastx
scoreboard players operation #smz fart.var = #sdz fart.var
scoreboard players operation #smz fart.var -= @s fart.lastz
execute if score #smx fart.var matches 1.. run scoreboard players set @s fart.stress 0
execute if score #smz fart.var matches 1.. run scoreboard players set @s fart.stress 0

# 2. gas in the bar forgives the strain, then the strain itself builds and hurts
scoreboard players add @s fart.stress 1
execute if score @s fart.hurtt matches 1.. run scoreboard players remove @s fart.hurtt 1
execute if score @s fart.pressure matches 1.. run scoreboard players set @s fart.stress 0
execute if score @s fart.stress matches 20.. unless score @s fart.pressure matches 1.. run function fartpack:player/stress_hurt
