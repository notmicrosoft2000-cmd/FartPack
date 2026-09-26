# world/fart_block - a utility block let one rip.
#
# The announcement names the specific block ("a crafting table farted!"), the way
# it did before v19. Getting that detail back without reintroducing the old
# drift problem is why this file is now three lines instead of one:
#
#   v13-v18   18 hard-coded `if block <id>` + tellraw pairs, one per block. The
#             tag drove the timer and this copy drove the chat, so adding a block
#             to tags/block/utility.json silently gave you a fart with no
#             announcement. They had already drifted (21 tagged, 18 announced).
#   v19       one generic "a utility block farted!" line. Cannot drift, but threw
#             away the detail. Reported by the user as a regression.
#   v20       the detail is back, and the list of names is GENERATED from the tag
#             by build/genblocknames.py at build time. There is no hand-maintained
#             copy to drift. The sentence itself lives in exactly one place,
#             world/fart_msg, because a string macro is the only way to splice a
#             computed name into JSON.
scoreboard players add #stats fart.total 1
function fartpack:world/fart_sound
execute at @s run function fartpack:world/block_name
execute at @s run function fartpack:world/fart_msg with storage fartpack:msg
function fartpack:world/cloud_random
execute at @s run function fartpack:push/block
