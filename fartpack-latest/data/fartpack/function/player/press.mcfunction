# player/press - runs once per tick per player (tick.mcfunction).
# Crouching while holding pressure releases gas, heals you, and makes you
# hungry. Holding a full bar while standing still is what triggers the forced
# legendary mega-fart.
function fartpack:player/sneak
execute if entity @s[tag=fart.sneak,scores={fart.pressure=1..},tag=!fart.releasing] run title @s actionbar [{"text":"Easing the pressure out...","color":"aqua"}]
execute if entity @s[tag=fart.sneak,scores={fart.pressure=1..},tag=!fart.releasing] run tag @s add fart.healtick
execute if entity @s[tag=fart.sneak,tag=fart.healtick,tag=!fart.healing] run tag @s add fart.healing
execute if entity @s[tag=fart.sneak,tag=fart.healtick,tag=!fart.healing] run effect give @s minecraft:regeneration 100000 0 true
execute if entity @s[tag=fart.sneak,tag=fart.healtick,tag=!fart.healing] run scoreboard players set #power fart.var 24
execute if entity @s[tag=fart.sneak,tag=fart.healtick,tag=!fart.healing] run function fartpack:push/self
execute if entity @s[tag=fart.sneak,scores={fart.pressure=1..},tag=!fart.releasing] run tag @s add fart.releasing
execute if entity @s[tag=fart.sneak] run function fartpack:player/stress
execute if entity @s[tag=fart.releasing] unless entity @s[tag=fart.sneak] run tag @s remove fart.releasing
execute if entity @s[tag=fart.releasing] unless entity @s[tag=fart.sneak] run tag @s remove fart.healtick
execute if entity @s[tag=fart.healing] unless entity @s[tag=fart.sneak] run tag @s remove fart.healing
execute if entity @s[tag=fart.healing] unless entity @s[tag=fart.sneak] run effect clear @s minecraft:regeneration
execute if entity @s[tag=fart.sneak,tag=fart.releasing] at @s run function fartpack:player/release_gas
# Holding a lot of gas in costs you, as the release prompt promises. Refreshed
# every tick so it only bites while you are genuinely sitting on a full bar.
execute if score @s fart.pressure matches 25.. unless entity @s[tag=fart.releasing] run effect give @s minecraft:hunger 5 0 true
execute if score @s fart.pressure matches 100.. at @s run function fartpack:world/fart_forced
