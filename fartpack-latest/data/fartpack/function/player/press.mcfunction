execute at @s anchored eyes positioned ^ ^ ^ positioned ~ ~-1.27 ~ if entity @s[distance=..0.1] run tag @s add fart.sneak
execute at @s anchored eyes positioned ^ ^ ^ positioned ~ ~-1.27 ~ unless entity @s[distance=..0.1] run tag @s remove fart.sneak
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
execute if score @s fart.pressure matches 80..99 unless entity @s[tag=fart.warnfull] run title @s title {"text":"GAS PRESSURE NEAR MAX!","color":"gold","bold":true}
execute if score @s fart.pressure matches 80..99 unless entity @s[tag=fart.warnfull] run tag @s add fart.warnfull
execute if entity @s[tag=fart.warnfull] unless score @s fart.pressure matches 80..99 run tag @s remove fart.warnfull
execute if score @s fart.pressure matches 100.. at @s run function fartpack:world/fart_forced