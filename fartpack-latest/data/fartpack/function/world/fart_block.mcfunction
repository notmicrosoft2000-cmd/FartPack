# world/fart_block - a utility block let one rip.
#
# The message is deliberately generic. It used to be 18 hard-coded
# `if block <id>` + tellraw pairs, one per tagged block, which meant adding a
# block to tags/block/utility.json silently gave you a fart with no announcement
# (the tag drives the timer, the copy drove the chat). One line cannot drift.
scoreboard players add #stats fart.total 1
function fartpack:world/fart_sound
execute at @s run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a utility block farted!","color":"yellow"}]
function fartpack:world/cloud_random
execute at @s run function fartpack:push/block
