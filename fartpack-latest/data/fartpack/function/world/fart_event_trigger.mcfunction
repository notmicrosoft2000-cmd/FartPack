scoreboard players set #event_cd fart.var 0
execute store result score #event_target fart.var run random value 24000..48000
execute store result score #event_pick fart.var run random value 1..4
execute if score #event_pick fart.var matches 1 run function fartpack:world/event_surge
execute if score #event_pick fart.var matches 2 run function fartpack:world/event_cyclone
execute if score #event_pick fart.var matches 3 run function fartpack:world/event_blessing
execute if score #event_pick fart.var matches 4 run function fartpack:world/event_swarm
