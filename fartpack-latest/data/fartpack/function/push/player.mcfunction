# push/player - knockback applied to a PLAYER.
#
# WHY THIS IS VELOCITY AND NOT TELEPORTATION
# --------------------------------------------
# This used to be a "hopper": summon a marker, walk the marker forward in small
# steps, and `tp @s` the player onto it, recursing once per step -- all inside a
# SINGLE tick (push/player_step -> push/player_hop -> push/player_step). So a
# player's entire knockback was applied as a burst of instantaneous position
# changes inside one frame. In third person that reads as knockback, because you
# can see the whole body displace. From the player's own first-person camera it
# is literally a teleport, which is how it was reported.
#
# Setting Motion is what vanilla knockback does (it is how an explosion's impulse
# works). The client interpolates it, so it reads as a shove, and the server
# never contradicts the client's own position, so there is no rubber-banding.
#
# Side effect worth knowing: the old tp path only ever wrote Pos[0] and Pos[2], so
# #vy (20 for a normal push, 40 for legendary) was silently DISCARDED for players.
# Nobody was ever popped upward; only mobs were. Using Motion means #vy finally
# applies to players too, which is what the numbers always implied and what the
# mob path already did.
#
# INPUTS
#   #ppx10 / #ppz10  push SOURCE in tenths of a block. Written by push/core for a
#                    radial push, and by push/self for the self-push.
#   #power           horizontal impulse, in 1/100 blocks per tick (35 -> 0.35).
#   #vy              vertical impulse, same units.
#
# The direction used is a manhattan-length normaliser (dx / (|dx|+|dz|)), the same
# one push/one uses, so players and mobs are pushed consistently.
#
# ARITHMETIC
#   velocity_x = (power/100) * dx/dist
# Carrying a factor of 10 through the division means the result lands in
# 1/1000 blocks per tick, which is what the `double 0.001` store expects. The
# factor of 10 is also what stops this truncating: push/one divides down to an
# integer immediately, so at power 12 and distance 12 a component floors to 0 and
# the far edge of the radius gets almost nothing. One decimal place of headroom
# costs nothing and keeps the near and far edges consistent.
scoreboard players set #neg1 fart.var -1
scoreboard players set #ten fart.var 10
execute store result score #tx fart.var run data get entity @s Pos[0] 10
execute store result score #tz fart.var run data get entity @s Pos[2] 10

# target - source
scoreboard players operation #dx fart.var = #tx fart.var
scoreboard players operation #dx fart.var -= #ppx10 fart.var
scoreboard players operation #dz fart.var = #tz fart.var
scoreboard players operation #dz fart.var -= #ppz10 fart.var
scoreboard players operation #adx fart.var = #dx fart.var
execute if score #adx fart.var < #neg1 fart.var run scoreboard players operation #adx fart.var *= #neg1 fart.var
scoreboard players operation #adz fart.var = #dz fart.var
execute if score #adz fart.var < #neg1 fart.var run scoreboard players operation #adz fart.var *= #neg1 fart.var

# Manhattan distance, floored at 1 so a perfectly radial hit cannot divide by zero.
scoreboard players operation #dist fart.var = #adx fart.var
scoreboard players operation #dist fart.var += #adz fart.var
execute if score #dist fart.var matches 0 run scoreboard players set #dist fart.var 1

# impulse in 1/1000 blocks per tick
scoreboard players operation #ux10 fart.var = #dx fart.var
scoreboard players operation #ux10 fart.var *= #power fart.var
scoreboard players operation #ux10 fart.var *= #ten fart.var
scoreboard players operation #ux10 fart.var /= #dist fart.var
scoreboard players operation #uz10 fart.var = #dz fart.var
scoreboard players operation #uz10 fart.var *= #power fart.var
scoreboard players operation #uz10 fart.var *= #ten fart.var
scoreboard players operation #uz10 fart.var /= #dist fart.var
scoreboard players operation #vy10 fart.var = #vy fart.var
scoreboard players operation #vy10 fart.var *= #ten fart.var

# No minimum-velocity floor, deliberately. A hit straight down one axis legitimately
# has a zero component on the other axis, and forcing a non-zero value there would
# shove players sideways for no reason. The divide-by-zero case is the #dist floor
# above, and that is the only thing that needed guarding.

data modify storage fartpack:data motion set value [0.0,0.0,0.0]
execute store result storage fartpack:data motion[0] double 0.001 run scoreboard players get #ux10 fart.var
execute store result storage fartpack:data motion[1] double 0.001 run scoreboard players get #vy10 fart.var
execute store result storage fartpack:data motion[2] double 0.001 run scoreboard players get #uz10 fart.var
data modify entity @s Motion set from storage fartpack:data motion
