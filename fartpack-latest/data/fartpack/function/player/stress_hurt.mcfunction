# v28: `damage @s 1` -> `damage @s 4`. 1 HP is HALF A HEART, so the old number was
# 0.5 hearts per second, not the 2 hearts per second the mechanic is specified to
# do. `damage` counts health points, not hearts: 4 HP = 2 hearts.
#
# The cadence is unchanged and is what makes the rate exact. player/stress only
# calls this once #fart.stress has climbed to 20 from 0, and line 12 below resets
# it, so this runs once every 20 ticks = once per second. 4 HP per second.
#
# HONEST WARNING, because 2 hearts/second is lethal: from full health that is
# 10 seconds. There is a 1-second grace (stress must reach 20 first), and since
# v29 there is NO way out of it by moving - player/stress forgives the strain on
# gas only, and the user asked for the damage to land whether you move or not.
# So the only exit is standing up, or filling the tank. If that proves too harsh
# in practice, drop `damage @s 4` to `damage @s 2` for 1 heart/second. That is one
# number, repeated on the four lines below, and it is the only tuning here.

# v29: varied death messages, and the text no longer promises an escape.
#
# WHY THE VARIETY IS VANILLA DAMAGE TYPES rather than new fartpack: ones. The
# custom types in this pack (fartpack:atomic_gas, fartpack:legendary_gas) already
# carry message_id, but the pack shipped NO lang file at all, so every one of them
# resolved to nothing and the player got the generic "X died" fallback. That is
# the message the user reported. A lang file fixes those two.
#
# Adding MORE custom types was the obvious next step and it does not work here.
# Measured (probe-shake3.sh): registering a new damage type does not take effect
# on /reload. A probe pack containing a byte-for-byte valid control type came back
# "Can't find element" exactly as the invalid one did, while the two types already
# in the live pack resolved fine. So a new damage type needs a WORLD RESTART, and
# a restart is not something to spend on a cosmetic change - and one that could
# not be verified by the deploy gate, because an unresolvable damage type is a
# RUNTIME error: player/stress_hurt would still load, so "failed function loads: 0"
# would stay green while the pack quietly threw an error once a second.
#
# So the extra messages come from damage types the server already has, all
# confirmed present on this server (probe-dmgtypes.sh, and the control direction
# too: minecraft:bad_omen and minecraft:with_fire are MISSING, so the check can
# report absence and was not just printing "exists" for everything):
#     minecraft:explosion     "blew up"                    - a fart, obviously
#     minecraft:dragon_breath "suffocated in a wall of..." - the cloud, fitting
#     fartpack:atomic_gas     this file's own lang entry
#     fartpack:legendary_gas  this file's own lang entry
# Four variants from one damage line becomes five, which is once a second at worst
# and only on an empty tank.
execute store result score #sv fart.var run random value 1..4
execute if score #sv fart.var matches 1 run damage @s 4 minecraft:explosion
execute if score #sv fart.var matches 2 run damage @s 4 minecraft:dragon_breath
execute if score #sv fart.var matches 3 run damage @s 4 fartpack:atomic_gas
execute if score #sv fart.var matches 4 run damage @s 4 fartpack:legendary_gas
particle minecraft:crit ~ ~1.2 ~ 0.6 0.6 0.6 0.3 20
effect give @s minecraft:nausea 3 0
playsound minecraft:entity.player.hurt player @s ~ ~ ~ 1.0 0.6
# The old text here said "Get moving to build pressure!", which was wrong twice
# over: gas clouds build pressure (player/fill_gas), not walking, and since v20
# moving was precisely how you STOP straining. See player/stress.
#
# v29: that escape hatch is gone, so the subtitle stopped advertising it. Telling
# a player to MOVE to stop the damage when moving no longer does anything is worse
# than saying nothing - it is a false instruction at the exact moment the player
# is looking for one.
#
# v28: actionbar -> title. Reported as "make the events more obvious". The
# actionbar sits above the hotbar and is easy to talk past; a title owns the
# middle of the screen. Gated on fart.hurtt so it appears once per 5 seconds
# rather than every tick - an un-gated title every tick is a strobe.
execute unless score @s fart.hurtt matches 1.. run title @s title [{"text":"STRAINING!","color":"red","bold":true}]
execute unless score @s fart.hurtt matches 1.. run title @s subtitle [{"text":"Nothing left to squeeze out - stand up.","color":"yellow"}]
execute unless score @s fart.hurtt matches 1.. run scoreboard players set @s fart.hurtt 100
scoreboard players set @s fart.stress 0
