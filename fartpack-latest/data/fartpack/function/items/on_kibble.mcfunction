# v34, the kibble window. 900 ticks = 45 seconds, ticked down once per tick in
# tick.mcfunction and read as `matches 1..` by player/fill_gas, where it swaps
# the per-pass fill of 2 gas for a 1-in-100 roll. That is the "fills at 1%" the
# user asked for: 1% of 2 gas per movement pass is 0.02 gas, and a scoreboard
# holds integers only, so the rate is a probability rather than a fraction.
scoreboard players set @s fart.slow 900
#
# v34: THE INSTANT DROP NOW SCALES WITH THE PLAYER'S OWN CAP - 10% of it, not a
# flat 15. The flat 15 was 15% of a 100-cap bar and under 3% of the 500-cap bar
# admin/cap permits, so the item did almost nothing for anyone but a default
# player. Scaling is the same shape as the thresholds in admin/recalc and
# admin/cap: divide the cap by a constant held on the scoreboard, because there
# is no way to write "remove 10% of my cap" as one command.
#
# #rc_ten is a real scoreboard constant rather than a literal in the command.
# Two reasons, both learned the hard way in this pack: `scoreboard players
# operation` takes its divisor as another holder rather than a number, and a
# literal-free line is what keeps the `div=`-style syntax out of a file that
# runs on every movement pass. It is re-seeded here rather than trusted from
# core/bootstrap, so a mid-session reset of #rc_ten cannot silently turn the
# drop into a divide-by-nothing.
scoreboard players set #rc_ten fart.var 10
scoreboard players operation #rc_tmp fart.var = @s fart.cap
scoreboard players operation #rc_tmp fart.var /= #rc_ten fart.var
scoreboard players operation @s fart.pressure -= #rc_tmp fart.var
# A cap small enough that a 10th of it is 0 would leave the score NEGATIVE, and
# every comparison in the pack is written against 0 as the floor. Clamped to 0
# on the same pass, because `matches ..0` also catches the negative values that
# removing nothing would leave behind on a cap of 0.
execute if score @s fart.pressure matches ..0 run scoreboard players set @s fart.pressure 0
# v34: the message says what it actually does now. It used to say "your gut
# settles" and never mentioned that a kibble changes the fill rate at all, which
# was the whole point of eating one.
tellraw @s [{"text":"Mmm, anti-fart kibble! Your gut settles - your bar now fills at 1% for 45s.","color":"green"}]
# An advancement's rewards fire ONLY the first time it is granted. Without this
# revoke, a second piece of kibble - or any piece eaten on a later day - does
# absolutely nothing, with no error anywhere. Revoke first, then the next eat
# re-grants it and the reward runs again.
advancement revoke @s only fartpack:items/eat_kibble
