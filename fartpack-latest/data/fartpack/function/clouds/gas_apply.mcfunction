# clouds/gas_apply - per-tick entry point for the two damaging gas clouds.
# Only clouds tagged fart.gas_atomic / fart.gas_legendary reach here (world/tick).
#
# DAMAGE BUDGET (see BUGS-AND-FIXES.md #13)
# Each cloud has exactly one damage number and one cadence, so the total you can
# take by standing in it forever is:  damage x (Duration / cadence).
#   atomic     3 dmg / 20 ticks over Duration 200 =  30 damage
#   legendary  4 dmg / 30 ticks over Duration 300 =  40 damage
#   legendary (player forced mega-fart, Duration 100)              =  ~16 damage
# Anything that cannot be walked out of is not fun; if you raise a number here,
# raise the cadence in the same breath so the budget stays under ~40.
scoreboard players add @s fart.gtick 1
# --- atomic: 3 dmg / 20 ticks ---
execute if entity @s[tag=fart.gas_atomic] if score @s fart.gtick matches 20.. as @e[type=!#fartpack:no_push,distance=..4.5] run damage @s 3 fartpack:atomic_gas
execute if entity @s[tag=fart.gas_atomic] if score @s fart.gtick matches 20.. run scoreboard players set @s fart.gtick 0
# --- legendary: 4 dmg / 30 ticks ---
execute if entity @s[tag=fart.gas_legendary] if score @s fart.gtick matches 30.. as @e[type=!#fartpack:no_push,distance=..8.5] run damage @s 4 fartpack:legendary_gas
execute if entity @s[tag=fart.gas_legendary] if score @s fart.gtick matches 30.. run scoreboard players set @s fart.gtick 0
