# admin/show_one - the body of admin/show, operating on @s.
#
# A plain function. See admin/show for why this is not inline in the macro.
#
# The five scratch holders are zeroed FIRST, on purpose. `store result` only
# writes when the command it captured succeeds, so for a player who was never
# configured - where `scoreboard players get` fails - the holder would keep
# whatever the last invocation put there and the admin would be shown a
# confident, entirely fictional number. Zeroing first means an unconfigured
# player honestly reads as all zeros.
#
# Every value in the chat is a `score` component, so it renders the live number
# rather than a string captured when the function ran.
#
# Goes to @a, not just @s: this is an admin diagnostic and the admin is the one
# who needs to read it.
scoreboard players set #rc_e1 fart.var 0
scoreboard players set #rc_e2 fart.var 0
scoreboard players set #rc_e3 fart.var 0
scoreboard players set #rc_e4 fart.var 0
scoreboard players set #rc_e5 fart.var 0
execute store result score #rc_e1 fart.var run scoreboard players get @s fart.rate
execute store result score #rc_e2 fart.var run scoreboard players get @s fart.every
execute store result score #rc_e3 fart.var run scoreboard players get @s fart.cap
execute store result score #rc_e4 fart.var run scoreboard players get @s fart.rel
execute store result score #rc_e5 fart.var run scoreboard players get @s fart.pow
tellraw @a [{"text":"[FartPack] ","color":"green"},{"text":"config for ","color":"gray"},{"selector":"@s","color":"gold"},{"text":":","color":"gray"}]
tellraw @a [{"text":"   fill ","color":"gray"},{"score":{"name":"#rc_e1","objective":"fart.var"},"color":"gold"},{"text":"x   every ","color":"gray"},{"score":{"name":"#rc_e2","objective":"fart.var"},"color":"gold"},{"text":"   cap ","color":"gray"},{"score":{"name":"#rc_e3","objective":"fart.var"},"color":"gold"}]
tellraw @a [{"text":"   release ","color":"gray"},{"score":{"name":"#rc_e4","objective":"fart.var"},"color":"gold"},{"text":"/tick   knockback ","color":"gray"},{"score":{"name":"#rc_e5","objective":"fart.var"},"color":"gold"}]
tellraw @a [{"text":"   (stock is 1x / every 1 / cap 100 / release 1 / knockback 30)","color":"dark_gray"}]
