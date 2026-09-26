scoreboard players set @s fart.slow 900
scoreboard players remove @s fart.pressure 15
execute if score @s fart.pressure matches ..0 run scoreboard players set @s fart.pressure 0
tellraw @s [{"text":"Mmm, anti-fart kibble! Your gut settles - bar fills slower for 45s.","color":"green"}]
