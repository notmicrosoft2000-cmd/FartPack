# world/fart_event_tick - rarer and bigger than fart rain. 24000-48000 ticks is
# roughly 20-40 minutes.
#
# CADENCE: driven from the 30-tick cycle in tick.mcfunction, so it adds 30 per
# call. See the note in world/fart_rain_tick for why this is not 1.
execute unless score #event_target fart.var matches 1.. run execute store result score #event_target fart.var run random value 24000..48000
scoreboard players add #event_cd fart.var 30
execute if score #event_cd fart.var >= #event_target fart.var run function fartpack:world/fart_event_trigger
