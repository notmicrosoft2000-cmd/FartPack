# world/fart_rain_tick - lazily picks a random countdown (5-10 minutes) the
# first time it runs, then counts up to it. #raining/#rain_dur/#rain_tick all
# live on the fart.var objective, same scratch-score convention as everywhere else.
#
# CADENCE: this is driven from the 30-tick cycle in tick.mcfunction, so it must
# add 30 rather than 1. The original advanced by 1 on a per-tick call; stepping
# 30 at a time on a 30-tick cadence is the same countdown in wall-clock terms
# (6000-12000 ticks is still 5-10 minutes), at 1/30th of the scoreboard traffic.
# A 1.5s resolution on a 5-10 minute timer is not observable.
execute unless score #rain_target fart.var matches 1.. run execute store result score #rain_target fart.var run random value 6000..12000
scoreboard players add #rain_cd fart.var 30
execute if score #rain_cd fart.var >= #rain_target fart.var run function fartpack:world/fart_rain_start
