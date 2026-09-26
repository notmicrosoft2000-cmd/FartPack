execute unless score #loaded fart.var matches 18 run function fartpack:core/bootstrap
scoreboard players enable @a fart.toggle
execute as @a[scores={fart.toggle=1..}] run function fartpack:core/do_toggle
execute as @a[scores={fart.toggle=1..}] run scoreboard players set @s fart.toggle 0
execute if score #enabled fart.var matches 0 run return 0
function fartpack:world/tick
execute as @a[name=!"Server"] unless entity @s[tag=fart.has_pid] at @s run function fartpack:core/assign_pid
execute as @a[name=!"Server",tag=fart.has_pid] run function fartpack:bar/tick_gas_bar
scoreboard players add #scan_c fart.var 1
execute if score #scan_c fart.var matches 10.. as @a[name=!"Server"] at @s run function fartpack:blocks/scan
execute if score #scan_c fart.var matches 10.. as @e[type=minecraft:marker,tag=fart.blocktimer] at @s unless block ~ ~ ~ #fartpack:utility run kill @s
execute if score #scan_c fart.var matches 10.. as @a[name=!"Server"] at @s run function fartpack:player/fill_gas
execute if score #scan_c fart.var matches 10.. run scoreboard players set #scan_c fart.var 0
execute as @a[name=!"Server"] if score @s fart.slow matches 1.. run scoreboard players remove @s fart.slow 1
execute as @a[name=!"Server"] at @s run function fartpack:player/press