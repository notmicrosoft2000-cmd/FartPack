# The spawn book: what the yellow clouds actually are. Run as the joining player.
#
# The item form was MEASURED on this server rather than written from memory, which
# matters because a malformed item is a runtime error on every single join and the
# deploy gate cannot see it - it only reports FUNCTIONS that failed to load, and
# this one loads fine and then throws. probe-book2.sh put each candidate through
# `item replace block <chest> container.0` and read the block entity back:
#
#   minecraft:written_book[minecraft:written_book_content={title,author,pages}]
#     accepted; stored as components:{"minecraft:written_book_content":{pages:[{raw:...}]}}
#   same, with pages:["bare string"]
#     accepted too, but the pages come out as raw text with no colour or formatting
#   minecraft:not_a_real_thing={...}     REJECTED - "Unknown item component"
#   written_book_content={title:5}       REJECTED - "Malformed ... No key author"
#
# Those two rejections are the reason to believe the two acceptances: without a
# case the test rejects, "accepted" only means the command did not visibly fail.
#
# The pages are single-quoted SNBT strings holding JSON text components, which is
# the only way to get colour into book pages. So: no apostrophes and no
# backslashes anywhere inside a page, or the SNBT string ends early and the whole
# item becomes malformed. The pack's existing world/fart_msg does the same thing.
#
# Only handed out once, tracked with a tag. There is no way to ask "does this
# player already own a book" from a function - a player's inventory is not
# readable as entity NBT - so a rejoin would otherwise stack a second copy on
# top of the first. An admin who wants to reissue it clears the tag.
execute unless entity @s[tag=fart.got_book] run give @s minecraft:written_book[minecraft:written_book_content={title:"What Are The Yellow Clouds?",author:"FartPack",pages:['{"text":"THE YELLOW CLOUDS","bold":true,"color":"gold"}','{"text":"Every furnace, chest, cow and goat here has its own fart timer. When it fires, a coloured gas cloud appears. Do not stand in one. The clouds are the entire point of this place.","color":"dark_gray"}','{"text":"YELLOW = the normal fart cloud. It fills your GAS bar, and a full bar is what lets you fart. The colour is not decoration: it is the bar being filled, made visible.","color":"gray"}','{"text":"Also: gas in a cloud makes you strain, heal you while crouched, and damage you while you strain. And whoever is highest on the FARTS board wears the crown, which doubles their gas.","color":"gray"}']}] 1
tag @s add fart.got_book
