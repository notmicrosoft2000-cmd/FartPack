execute unless entity @s[type=minecraft:player] at @s run function fartpack:world/fart_entity
execute as @s[type=minecraft:player,name=!"Server"] unless score @s fart.pressure matches 1.. run tellraw @s [{"text":"You don't need to go yet...","color":"gray"}]
execute as @s[type=minecraft:player,name=!"Server"] if score @s fart.pressure matches 1.. run tellraw @s [{"text":"Crouch to release your fart! (Crouching heals you, for as long as the gas lasts)","color":"aqua"}]
