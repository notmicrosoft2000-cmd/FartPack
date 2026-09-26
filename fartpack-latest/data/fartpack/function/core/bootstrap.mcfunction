# core/bootstrap - full initializer. Bump the version at the bottom whenever an
# objective is added or removed; tick.mcfunction runs this on a version mismatch
# so new objectives actually get created on an existing world.
scoreboard objectives add fart.cooldown dummy
scoreboard objectives add fart.target dummy
scoreboard objectives add fart.var dummy
scoreboard objectives add fart.pressure dummy
scoreboard objectives add fart.stress dummy
scoreboard objectives add fart.pid dummy
scoreboard objectives add fart.slow dummy
scoreboard objectives add fart.lastx dummy
scoreboard objectives add fart.lastz dummy
scoreboard objectives add fart.hurtt dummy
scoreboard objectives add fart.gtick dummy
scoreboard objectives add fart.sndt dummy
scoreboard objectives add fart.total dummy {"text":"Total Farts","color":"gold"}
scoreboard objectives add fart.toggle trigger
scoreboard players enable @a fart.toggle
scoreboard players set #neg1 fart.var -1
scoreboard players set #noplayer fart.var 0
scoreboard players set #scan_c fart.var 0
scoreboard players set #rc fart.var 0
scoreboard players set #stats fart.total 0
execute unless score #enabled fart.var matches 0 run scoreboard players set #enabled fart.var 1
scoreboard objectives setdisplay sidebar fart.total
data modify storage fartpack:data macro set value {}
scoreboard players set #loaded fart.var 19
