# The Fart King pass, once a second (hooked into tick.mcfunction on #scan_c 20).
#
# THE RULE, and the reason it is written as "strictly greater": the crown goes to
# the highest fart total, and a TIE is broken in favour of whoever got there
# first. A challenger must BEAT the incumbent, not match them. That single choice
# of comparison is the whole tie-break - no timestamps, no join order, no
# floating-point equality to get wrong. If two players are level, the one who was
# already holding the crown keeps it, which is the same answer as "first to
# reach this number" for as long as the crown is only ever lost by being passed.
#
# The incumbent's total is the bar, and it is read from whichever ONLINE player
# carries the fart.king tag. If the king logs out, nobody carries it, the bar
# falls to 0, and the next pass crowns whoever is highest - so a crown is never
# held by someone who is not in the world. The flip side is handled in
# core/on_join: a returning ex-king still has the tag, so on join they are
# demoted and have to win it back by farting. Without that, an ex-king would walk
# back in still holding the crown's tag and an invisible claim nobody could take.
# (v31: that sentence used to end "...still holding fart.rate 2", because the rate
# WAS the crown. It is a tag now, so the tag is the thing that has to be cleared.)
#
# `unless entity @a[tag=fart.king_new] run return 0` is the no-op guard: on the
# overwhelming majority of seconds nothing overtakes anybody, and without it every
# one of those seconds would broadcast a false "crowned" and reset the rate.
execute as @a[tag=fart.king] run scoreboard players operation #kbest fart.var = @s fart.total
# v30: keep the king's bonus hearts up. health_boost is a timed effect, and
# king/crowned gives it 400 ticks, so without this top-up the king's extra
# hearts would blink out every 20 seconds and a player could watch themselves
# lose the reward while still wearing the crown. This runs once a second (the
# #scan_c 20 hook in tick.mcfunction), so the effect is always re-applied well
# inside its own duration and the crown and the hearts cannot disagree. v31: the
# amplifier is 2, matching king/crowned - the two MUST agree, and they are two
# separate files, which is exactly the kind of pairing that drifts.
#
# `true` is hideParticles. The top-up is invisible by design - the crown already
# announced itself, and a golden swirl every second would be noise.
execute as @a[tag=fart.king] run effect give @s minecraft:health_boost 400 2 true
tag @a remove fart.king_new
execute as @a[name=!"Server"] unless entity @s[tag=fart.king] run function fartpack:king/consider
execute unless entity @a[tag=fart.king_new] run return 0
execute as @a[tag=fart.king] unless entity @s[tag=fart.king_new] run function fartpack:king/demote
execute as @a[tag=fart.king_new] run function fartpack:king/crowned
tag @a remove fart.king_new
