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
# Fix: movement is what lets the strain build. Any movement clears the
# accumulated stress.
#
# v28: the "still, not slowed -> 1" case in player/fill_gas is GONE, so standing
# still no longer refills the bar. That paragraph below which used to defend
# keeping the refill is now false, and this file is the reason it mattered:
#
#   With the refill, `fart.pressure` went back above 0 within 10 ticks of any
#   crouch on an empty tank, line 48 below forgave the strain, and stress was
#   reset long before it reached 20. The mechanic was unreachable. The user
#   reported the same symptom independently ("the bar always doesn't fully empty
#   down to 0 i think") and was right about the cause.
#
# So the dependency runs the other way round from what this file used to claim:
# the no-refill change in fill_gas is what makes THIS file reachable, and this
# file is what makes the empty tank worth having.
#
# An empty tank is still reachable without the refill: crouch-release drains to
# 0 (player/release_gas line 18), world/fart_forced sets pressure to 0 outright,
# and core/toggle_off resets it. So this is not dead code - it is now the only
# thing standing between "empty bar" and "no consequence for sitting on it".
#
# v29: movement no longer forgives the strain. Reported bug, fixed.
#
# The v20 design was "any movement clears the accumulated stress", written as:
#     execute if score #smx fart.var matches 1.. run scoreboard players set @s fart.stress 0
#     execute if score #smz fart.var matches 1.. run scoreboard players set @s fart.stress 0
# on the RAW position delta, with no negation. Two things were wrong with that.
#
# 1. IT WAS NOT SYMMETRIC. `matches 1..` is satisfied by a positive number only.
#    A player who moved so that Pos*100 rose above the last sample was forgiven;
#    a player who moved the other way got a negative delta, which never matches,
#    and took the full damage. Which of the two you were depends on your
#    coordinates on the map, so it is not something a player can act on - the
#    mechanic was effectively random from the inside. Measured (probe-move4,
#    one fresh fixture per trial, both axes held true except the one varied):
#        delta +50  ->  strain forgiven,  no damage
#        delta -50  ->  strain forgiven? no, -4.0 HP
#        delta  0   ->  no forgiveness,   -4.0 HP
#
# 2. IT DEFEATED THE MECHANIC THE USER ASKED FOR. "Crouching on an empty tank
#    hurts" is worth nothing if walking cancels it, and the user reported
#    exactly that: crouching with an empty bar WHILE MOVING gave no damage. The
#    intended play per this file was "you feel it immediately, move and it
#    stops", which made the escape hatch the thing players did by default.
#
# Note also that the comment this block replaces claimed the deltas were "read
# exactly as player/fill_gas reads them". That was false. fill_gas negates them
# first - `#dx *= #neg1` when `#dx < #neg1` - precisely to make the distance
# sign-independent, and stress.mcfunction did not. That is the whole bug in one
# line of prose, and a false comment about a neighbouring file is worse than no
# comment, because it is what stops anyone looking.
#
# So the forgiveness is gone rather than negated. Negating would have kept a
# movement escape hatch the user asked to remove, and would have cost six
# commands per player per tick to maintain a mechanic that is now unwanted.
# #sdx / #sdz / #smx / #smz were used by nothing outside this file, so removing
# them leaves no dangling readers. fart.lastx and fart.lastz are untouched: they
# belong to player/fill_gas's own distance maths, which this file never wrote.
#
# Net effect, which is the intended loop:
#   crouch with gas in the bar  -> heals, no damage (gas forgives the strain)
#   crouch on an empty tank     -> 2 hearts/second after a 1s grace,
#                                  standing still OR moving - there is no escape
#   stand up                    -> no damage; only crouching strains

# 1. the strain forgives itself on gas, builds every crouch tick, and hurts
execute if score @s fart.pressure matches 1.. run scoreboard players set @s fart.stress 0
scoreboard players add @s fart.stress 1
execute if score @s fart.hurtt matches 1.. run scoreboard players remove @s fart.hurtt 1
execute if score @s fart.pressure matches 1.. run scoreboard players set @s fart.stress 0
execute if score @s fart.stress matches 20.. unless score @s fart.pressure matches 1.. run function fartpack:player/stress_hurt
