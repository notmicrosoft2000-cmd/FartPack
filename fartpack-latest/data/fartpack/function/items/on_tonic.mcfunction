scoreboard players set @s fart.slow 1800
scoreboard players set @s fart.pressure 0
tellraw @s [{"text":"Gulp! The gas-warden tonic empties your bar for 90s.","color":"aqua"}]
# Same once-ever trap as on_kibble - see the note there.
advancement revoke @s only fartpack:items/drink_tonic
