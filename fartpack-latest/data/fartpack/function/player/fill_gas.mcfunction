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
#   still,  not slowed -> 1      still,  slowed  -> 0
scoreboard players set #famt fart.var 0
execute if score #fdist fart.var matches 1.. if score @s fart.slow matches 1.. run scoreboard players set #famt fart.var 1
execute if score #fdist fart.var matches 1.. unless score @s fart.slow matches 1.. run scoreboard players set #famt fart.var 2
execute if score #fdist fart.var matches 0 unless score @s fart.slow matches 1.. run scoreboard players set #famt fart.var 1
# Throttle (admin/every): advance this player's counter and add only on the pass
# where it reads 1. The counter is clamped as well as wrapped, because with
# `every` at 1 the wrap branch never runs - the guard is `matches 2..` - and an
# unclamped counter would climb forever, one point per pass, forever.
scoreboard players add @s fart.cyc 1
execute if score @s fart.every matches 2.. if score @s fart.cyc >= @s fart.every run scoreboard players set @s fart.cyc 0
execute if score @s fart.cyc matches 64.. run scoreboard players set @s fart.cyc 0
execute unless score @s fart.every matches 2.. run function fartpack:player/apply_gas
execute if score @s fart.every matches 2.. if score @s fart.cyc matches 1 run function fartpack:player/apply_gas