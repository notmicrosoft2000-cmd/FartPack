# fart.etick is refreshed every tick in world/tick.mcfunction on every mob and
# dropped item within 16 blocks of a player, so this reuses that tag to fire
# a synchronized mass-fart moment without a separate entity scan.
tellraw @a [{"text":"\ud83d\udc65 ","color":"green"},{"text":"Every creature for miles suddenly needs to go...","color":"gold"}]
playsound minecraft:entity.creeper.primed ambient @a ~ ~ ~ 1.0 0.6
execute as @e[tag=fart.etick] at @s run function fartpack:world/fart_time
