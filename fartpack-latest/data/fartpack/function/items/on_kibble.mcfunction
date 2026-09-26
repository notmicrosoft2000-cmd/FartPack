scoreboard players set @s fart.slow 900
# A flat 15, deliberately NOT scaled by the player's cap (admin/cap). Scaling it
# would be more internally consistent, but it would also change how strong kibble
# feels for everybody the moment the config system existed, and a consumable that
# quietly got weaker is worse than one that is slightly too strong on an unusual
# cap. On a 20-cap bar a kibble empties it completely; on a 500-cap bar it is a
# rounding error. Both are defensible, and both are at least predictable.
scoreboard players remove @s fart.pressure 15
execute if score @s fart.pressure matches ..0 run scoreboard players set @s fart.pressure 0
tellraw @s [{"text":"Mmm, anti-fart kibble! Your gut settles - bar fills slower for 45s.","color":"green"}]
# An advancement's rewards fire ONLY the first time it is granted. Without this
# revoke, a second piece of kibble - or any piece eaten on a later day - does
# absolutely nothing, with no error anywhere. Revoke first, then the next eat
# re-grants it and the reward runs again.
advancement revoke @s only fartpack:items/eat_kibble
