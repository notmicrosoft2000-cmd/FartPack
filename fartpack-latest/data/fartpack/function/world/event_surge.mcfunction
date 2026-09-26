# GAS SURGE - everyone's bar is slammed to full. player/press.mcfunction
# already checks the bar against the player's own cap every tick and calls
# world/fart_forced on its own, so setting the score is all that's needed -
# every online player goes LEGENDARY within the next tick or two.
#
# "Full" is @s fart.cap rather than the constant 100 (v26), so somebody on a
# 200 cap is surged to 200 and somebody on a 20 cap is surged to 20. Both go
# legendary, which is the point of the event.
tellraw @a [{"text":"\u26a0 ","color":"red"},{"text":"GAS SURGE!","color":"gold","bold":true},{"text":" Everyone's pressure just spiked to max!","color":"yellow"}]
playsound minecraft:entity.wither.spawn ambient @a ~ ~ ~ 1.0 0.7
execute as @a[name=!"Server",tag=fart.has_pid] run scoreboard players operation @s fart.pressure = @s fart.cap
