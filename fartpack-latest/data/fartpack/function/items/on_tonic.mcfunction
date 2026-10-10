# v34: THE TONIC BLOCKS FILLING OUTRIGHT. It used to write fart.slow, which
# player/fill_gas read as "halve the fill" - the same thing it did for the
# kibble. The user asked for the tonic to make the bar NOT fill for 90 seconds,
# and halving is not that: a player drinking a tonic kept gaining half speed and
# never noticed the difference. So the tonic now writes its own score, and
# player/fill_gas forces #famt to 0 for as long as it is 1..
#
# 1800 ticks = 90 seconds, ticked down once per tick in tick.mcfunction. The
# value is a countdown, not a flag: it is read with `matches 1..`, so there is no
# "off" state to represent and no reset needed when it expires.
scoreboard players set @s fart.nofill 1800
# The instant drop is unchanged and is a separate effect from the timer. It is
# what makes drinking one feel like something, since for the next 90 seconds the
# bar is going to do nothing at all.
scoreboard players set @s fart.pressure 0
tellraw @s [{"text":"Gulp! The gas-warden tonic empties your bar and stops it filling for 90s.","color":"aqua"}]
# Same once-ever trap as on_kibble - see the note there.
advancement revoke @s only fartpack:items/drink_tonic
