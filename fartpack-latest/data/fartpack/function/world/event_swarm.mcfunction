# fart.etick is refreshed every tick in world/tick.mcfunction on every mob and
# dropped item within 16 blocks of a player, so this reuses that tag to fire
# a synchronized mass-fart moment without a separate entity scan.

# v28: /title as well as chat. The report was "make the events more obvious
# by announcing via /title". Both are kept: the title is what you notice
# while playing, the chat line is what you can find again in the scrollback.
# One title per event - two screen-wide titles from a single event reads as a
# bug rather than as emphasis.

title @a title [{"text":"EVERYTHING NEEDS TO GO","color":"green","bold":true}]
title @a subtitle [{"text":"Every creature for miles","color":"yellow"}]
tellraw @a [{"text":"\ud83d\udc65 ","color":"green"},{"text":"Every creature for miles suddenly needs to go...","color":"gold"}]
playsound minecraft:entity.creeper.primed ambient @a ~ ~ ~ 1.0 0.6
execute as @e[tag=fart.etick] at @s run function fartpack:world/fart_time
