execute if entity @s[tag=fart.blocktimer] run function fartpack:world/fart_block
execute unless entity @s[tag=fart.blocktimer] run function fartpack:world/fart_entity
scoreboard players set @s fart.cooldown 0
scoreboard players set @s fart.target 0