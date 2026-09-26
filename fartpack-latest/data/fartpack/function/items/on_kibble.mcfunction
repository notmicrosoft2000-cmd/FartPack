scoreboard players set @s fart.slow 900
scoreboard players remove @s fart.pressure 15
execute if score @s fart.pressure matches ..0 run scoreboard players set @s fart.pressure 0
tellraw @s [{"text":"Mmm, anti-fart kibble! Your gut settles - bar fills slower for 45s.","color":"green"}]
# An advancement's rewards fire ONLY the first time it is granted. Without this
# revoke, a second piece of kibble - or any piece eaten on a later day - does
# absolutely nothing, with no error anywhere. Revoke first, then the next eat
# re-grants it and the reward runs again.
advancement revoke @s only fartpack:items/eat_kibble
