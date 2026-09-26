# GAS SURGE - everyone's bar is slammed to 100. player/press.mcfunction
# already checks for fart.pressure matches 100.. every tick and calls
# world/fart_forced on its own, so setting the score is all that's needed -
# every online player goes LEGENDARY within the next tick or two.
tellraw @a [{"text":"\u26a0 ","color":"red"},{"text":"GAS SURGE!","color":"gold","bold":true},{"text":" Everyone's pressure just spiked to max!","color":"yellow"}]
playsound minecraft:entity.wither.spawn ambient @a ~ ~ ~ 1.0 0.7
execute as @a[name=!"Server",tag=fart.has_pid] run scoreboard players set @s fart.pressure 100
