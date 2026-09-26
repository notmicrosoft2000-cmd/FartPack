tag @e remove fart.etick
execute at @a[name=!"Server"] as @e[tag=!fart.etick,tag=!fart.blocktimer,type=!minecraft:marker,type=!minecraft:player,type=!minecraft:experience_orb,type=!minecraft:area_effect_cloud,type=!minecraft:firework_rocket,distance=..16] run tag @s add fart.etick
execute as @e[tag=fart.etick] at @s run function fartpack:entities/timer
execute as @e[type=minecraft:area_effect_cloud,tag=fart.gas_atomic] at @s run function fartpack:clouds/gas_apply
execute as @e[type=minecraft:area_effect_cloud,tag=fart.gas_legendary] at @s run function fartpack:clouds/gas_apply
execute as @e[type=minecraft:marker,tag=fart.blocktimer] at @s if entity @a[name=!"Server",distance=..24] run function fartpack:blocks/timer