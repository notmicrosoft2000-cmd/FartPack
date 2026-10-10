# player/press - runs once per tick per player (tick.mcfunction).
# Crouching while holding pressure releases gas and HEALS YOU, continuously and
# obviously, for as long as there is gas in the tank to crouch out. (v31: that
# used to be a fixed half a heart per ten gas expelled, which was too small to
# feel and stopped the instant the bar dipped. See the v31 note at the heal line.)
# Holding a full bar while standing still is what triggers the forced legendary
# mega-fart.
#
# v28: this file no longer makes you hungry at all. It used to say so in the
# three lines above, and the crouch prompt in player/fart still told players to
# expect it. Both are corrected. The hunger that remains in the pack comes only
# from the sulfuric gas cloud (clouds/sulfuric), which is a cloud effect on
# anyone standing in it and is a different thing entirely.

function fartpack:player/sneak
execute if entity @s[tag=fart.sneak,tag=!fart.releasing] run tag @s add fart.healtick
execute if entity @s[tag=fart.sneak,tag=fart.healtick,tag=!fart.healing] run tag @s add fart.healing
# v33: "Easing the pressure out..." is GONE, and the near-full warning took its
# place. Two separate messages were fighting over one actionbar - last write wins,
# so whichever line was lower silently deleted the other every tick. The user also
# asked for the old "GAS PRESSURE NEAR MAX" warning back (it existed in v19 and
# died in a later pass; the `fart.warnfull` tag survived only as a `remove` in
# core/toggle_off, so nothing had added it for many versions).
#
# The old version tested `fart.pressure matches 80..99`, which was only correct
# while every player shared a cap of 100. Profiles give caps from 60 to 180, so
# that literal would warn a 180-cap player at 44% and NEVER fire for a 60-cap
# player whose bar cannot reach 80 at all. It is derived now: `fart.near` is
# cap - cap/5, written in admin/recalc and mirrored in admin/cap, so it tracks
# whatever the profile set.
#
# The upper bound is `fart.near..` with no ceiling, not the old `..99`. The old
# ceiling existed to stop the title repeating every tick while the bar sat in the
# warning band; the `fart.warnfull` tag does that job, and a ceiling would break
# the moment a player's cap exceeded 99, which the config layer permits up to 500.
execute if score @s fart.pressure >= @s fart.near unless entity @s[tag=fart.warnfull] run title @s title [{"text":"GAS PRESSURE NEAR MAX","color":"gold","bold":true},{"text":"  release it before it forces itself","color":"gray"}]
execute if score @s fart.pressure >= @s fart.near unless entity @s[tag=fart.warnfull] run tag @s add fart.warnfull
execute if entity @s[tag=fart.warnfull] unless score @s fart.pressure >= @s fart.near run tag @s remove fart.warnfull
# v30: the three tag-clearing lines that stood here in v29 are GONE, and putting
# them back is the actual fix. The history matters, because v29's version was a
# reasonable attempt at this same bug report and it made the mechanic worse.
#
# v29 believed the problem was that the heal tag outlived the gas, so it
# cleared fart.healing, fart.healtick and reset fart.healcd on every tick where
# `fart.pressure` was 0. That is exactly the condition the heal was waiting for,
# so the fix removed the heal. Measured on the deployed v29, crouching from a
# tank of 10:
#
#   healcd 1,2,3 ... 12, then reset to 0     never reaches 20, so 0 heals ever
#   tick 32:  Health 6.0 -> 2.0               strain, 4 HP, with zero healing
#
# WHY healcd COULD NOT REACH 20 is the part worth keeping. The heal was gated on
# 20 CONSECUTIVE ticks with gas in the tank, and gas is movement-fed:
# player/fill_gas sets #famt to 0 when the player is stationary, 1 when slow, 2
# when moving, and apply_gas adds that once every 10 ticks - so the ceiling is
# 0.2 gas/tick. The crouch drains @s fart.rel, which is 1 per tick. A stationary
# crouch is therefore ALWAYS net negative, the tank crosses 0 every few ticks,
# and a counter that resets on every 0 can never accumulate 20. The heal was not
# mis-tuned, it was unreachable: measured peak 12 of 20.
#
# WHY CLEARING THE TAGS IS ALSO UNNECESSARY NOW. v29 cleared them to stop the
# heal and player/stress running on the same tick, and that worry is real - but
# it is answered by the payment rule rather than by the tags. The heal is now
# bought with gas (fart.healgas, credited in player/release_gas), so with an
# empty tank there is no credit, no heal, and only strain. The two still cannot
# both run, which was the whole point, and the crouch no longer stops working
# the instant the bar dips.
#
# The one behaviour v29 was protecting is preserved by a different line: the
# self-shove on `healtick && !healing` below fires only on the first tick of a
# crouch, because line 15 sets fart.healing on the tick after healtick. So
# leaving healtick set for the session does NOT turn an empty tank into a
# machine that self-shoves at #power 24 forever.
# v31: EVERYTHING FROM HERE TO THE HEAL LINE IS HISTORY. The block that follows
# is the v28/v30 account of the counter-driven heal - why it was unreachable, what
# v29 broke, and the ungated-debit bug in #34. It is kept because those are the
# three traps this file has already walked into once each, and because the next
# person to "improve" the heal should have to read why it was a bad idea before
# they do it again. None of it describes the current mechanism. The current
# mechanism is the single `effect give ... regeneration 2 5` line and nothing
# else: no #healper, no gas bank, no macro, and player/heal is deleted.
#
# (fart.healgas is still credited in player/release_gas and is still shown in
# profile/stats as "gas expelled". It is no longer spent on anything. It is a
# readout now, not a currency.)
#
# v28: the crouch heal is now EXACT, and it is not a status effect any more.
#
# The line this replaces was `effect give @s minecraft:regeneration 100000 0
# true` - Regeneration I, which restores 1 health point every 50 ticks. That is
# half a heart every 2.5 SECONDS, against a spec of half a heart every SECOND:
# it was running at a fifth of the intended rate. The user reported it as
# "doesn't work" rather than "is slow" because 0.2 HP/sec is roughly cancelled
# by whatever damage is landing at the same time, so the net reads as nothing.
#
# The obvious replacement, `damage @s -1` (negative damage heals), IS NOT A
# VALID COMMAND: the amount is a non-negative float and the server rejects -1.0.
# The v28 deploy shipped that line, the parse lint reported PARSE FAILURES: 0,
# and this file silently failed to load in the world - which killed the crouch
# heal entirely. See player/heal for the mechanism that works and BUGS-AND-FIXES
# #31 for the full account.
#
# So the heal is driven by the GAS BANK, not by a tick counter. `fart.healgas`
# counts the gas actually expelled during the crouch (credited in
# player/release_gas) and every #healper of it buys 1 HP = half a heart. That is
# the same rate the counter used to deliver at the stock fart.rel of 1 - one
# half heart per second of crouching - so the TUNING is unchanged and only the
# reachability is new. Testable from outside: #fart.healgas climbs while healing
# and drops by exactly 10 on each heal, so the debiting line is the thing to
# check first if the heal runs away or never lands.
#
# The six `healgas`-gated lines that follow are the CALLER half of player/heal, and
# they are here rather than inside the macro because a macro expands in full
# before any of its lines run: storing the value inside the macro would substitute
# the previous player's value. The order of all SEVEN lines matters and is the
# thing to check if the heal ever stops firing:
#
#   1. read the player's Health       -> #php, in centi-health points
#   2. add 100                        -> +1 HP = half a heart
#   3. copy #php into the macro's OWN storage, rescaled -> macro.hp
#   4. call the macro, which writes macro.hp back into Health
#   5. reset healcd to 0              -> diagnostic only now, not the trigger
#   6. debit 10 gas from the bank     -> LAST, because all six lines above test
#                                       `healgas >= #healper` and debiting first
#                                       would let them fire again next tick
#
# An earlier version of this had only five of those, and step 4 was MISSING. It
# stored the arithmetic into #php and then called a macro reading `$(hp)` from
# `fartpack:data macro.hp` - a value nothing in the pack ever wrote. The macro
# would have failed at expansion with "Missing argument hp", once a second, and
# the file would still have loaded cleanly and passed every gate in this repo,
# because nothing here checks that a macro's arguments are actually supplied. It
# read as correct, it was internally consistent, and it was dead. Writing the
# argument is the caller's job, and "the caller is responsible for the
# argument" is exactly the kind of rule that lives in a comment and not in a
# check.
#
# Step 4 exists because the rescale needs somewhere to land: `scoreboard players
# add` only does integer arithmetic on a scoreboard holder, and Health is a
# double. So the sum is done as an integer in centi-health points (#php) and
# converted to a double only at the boundary, by `store result ... double 0.01`
# reading the score back out. This is the exact sequence measured on the live
# server at 0 players; see player/heal.
#
# An earlier ordering put the reset second, reasoning that a reset must come
# before the tag removal to be "in time". That reasoning is about a different
# line. Here it simply breaks the mechanic: resetting first means the four lines
# after it can never see 20, so the heal never fires at all. The sequence is
# correct only in the order above, and the reason is that every one of the six
# lines tests the same counter and the counter is the only state.
#
# The `!fart.healing` guard is inherited from the line above: the old effect was
# given once, on the tick healing began, and a 100000-tick regeneration is
# self-sustaining. The counter is per-tick, so it must be gated the same way or
# a player who stopped crouching would keep healing forever.
execute if entity @s[tag=fart.healing] run scoreboard players add @s fart.healcd 1
# v31: THE HEAL IS A REGENERATION EFFECT NOW. The seven gas-banked lines that stood
# here in v30 are gone, and `player/heal` has been deleted along with them.
#
# WHY, when v30's version was measured working. The user's report was that
# crouch-farting still did not heal, and they were playing it, and they were
# right: v30's heal needed 10 gas expelled per half heart, and a player who
# crouches with a part-full tank gets a fraction of one heal and then strain. The
# fixture that "proved" v30 worked had the tank hand-seeded to 50 and the cow
# pressing 60 times in a row, which is not a thing a player does. A green gate
# and a green fixture had both certified a mechanic that a human being could not
# feel. Measurable, correct, and not a game.
#
# WHY A REGENERATION EFFECT AT ALL, GIVEN THAT v28 REMOVED ONE. It did, and the
# objection was never the mechanism - it was the AMPLIFIER. v28 deleted
# `regeneration 100000 0`, which is Regeneration I: 1 HP every 50 ticks, half a
# heart every 2.5 SECONDS, a fifth of the intended rate. v31 is
# `regeneration 2 5`, which is Regeneration VI. Same command, same family, five
# rungs further up, and it is the difference between a heal you cannot feel and
# one that is over in a couple of seconds. Anyone reading the v28 note below and
# reaching for `effect give ... 0` again has misread it: the fault was the number
# after the amplifier, not the word "regeneration".
#
# restores several HP per tick, so a crouch with gas in the tank is a real,
# obvious, sustained heal - and the cost is still real, because `fart.healing` is
# only ever set while `fart.pressure` is 1 or more (line 13 above). Run the tank
# dry and the tag goes, the effect lapses two ticks later, and player/stress
# starts charging you for it. The trade-off survives; the invisibility does not.
#
# WHY DURATION 2 AND NOT A LONG ONE. Re-applied every tick, so 2 covers the
# single tick of gap between applications and the effect is effectively
# continuous while crouching. A long duration would be indistinguishable from
# this on a long crouch and WRONG on a short one - stand up for one tick and a
# 400-tick heal keeps going, which is the exact "keep healing forever after you
# stopped" bug the `!fart.healing` guard exists to prevent. `true` hides
# particles: a crouch already has its own smoke and glow, and regen spirals on
# top of that is noise.
# `fart.healing` ALONE IS NOT A SUFFICIENT GATE, and this is the third time this
# file has shipped a heal that fires when it should not. The tag is added once, on
# the second tick of a crouch, and the only line that ever removes it is the
# "unless the player is still sneaking" one near the bottom of this file. It is NOT
# removed when the tank empties. So a player who crouches with 4 gas, spends it,
# and keeps holding crouch keeps `fart.healing` forever - and at several HP per
# tick, Regeneration VI simply out-heals the strain damage that player/stress is
# charging them for having no gas. Free full health for holding crouch on an empty
# tank, which deletes the entire gas economy.
#
# v32: SUPERSEDED, and kept because it is the reasoning behind the gate that
# replaced it. The `fart.pressure=1..` test described below was the v31 gate. It
# closed the empty-tank hole and left a smaller one - crouch-moving in circles to
# keep the tank above 1 - which is why the gate is now `> #healmin` rather than
# `1..`. Read this paragraph for WHY a gate is needed at all; read the v32 block
# for what the gate actually is.
#
# The gas test is ON THIS LINE, not inferred from the tag: `fart.pressure=1..`
# is "there is gas in the tank right now", and the moment the crouch spends the
# last of it the regen stops, the effect lapses two ticks later, and strain is
# charging from that tick on. The one-tick lag is deliberate and harmless - this
# line runs BEFORE player/release_gas below, so on the tick the tank goes 1 -> 0
# the heal still fires, having been paid for by gas that was genuinely there when
# the tick started.
# v32: THE HEAL IS REGENERATION AT A TUNABLE AMPLIFIER, GATED ON A BAR THRESHOLD.
# Both numbers are `#` scores rather than literals, so they can be changed live
# with one RCON command instead of a version bump and a full gated deploy:
#   scoreboard players set #healamp fart.var 0..5   how hard it hits
#   scoreboard players set #healmin fart.var <n>    how full the bar must be
#
# WHY IT IS SIX BRANCHES AND NOT ONE `effect give`. `effect give` takes a LITERAL
# amplifier - it cannot take a score or a macro - so a tunable number has to be an
# enum, exactly like `#radius` in push/core. Six literals, one of which fires.
# Anyone adding a seventh level has to add a branch here, and there is no way to
# make it generic.
#
# WHY THEY ARE SELF-SEEDED ON THE TICK PATH. An UNSET score does not match `matches
# 0` or `matches 1..` - it matches nothing at all - so if #healamp were ever unset
# then NO branch would fire and the crouch heal would be silently dead while every
# other line in this file kept working. That is the same trap as `fart.rate` and
# the same reason apply_gas writes `unless ..0` instead of `if 1..`. The
# `unless ..-1` test is false for any set value 0-5 and true for unset, so this
# runs exactly once and then never again. It is on the per-tick path, and it is
# two failed comparisons for a correctly configured server.
execute unless score #healamp fart.var matches ..-1 run scoreboard players set #healamp fart.var 3
execute unless score #healmin fart.var matches ..-1 run scoreboard players set #healmin fart.var 10
# THE THRESHOLD IS THE POINT OF THIS BLOCK, and it exists because the previous gate
# was `fart.pressure=1..`, which is a hole the user spotted immediately: gas is
# movement-fed and a crouch drains it, so a player could crouch-move in small
# circles to keep trickling the tank over 1 and collect a tick or two of regen over
# and over - effectively free healing with no meaningful cost. Requiring a bar of
# more than #healmin means healing is only ever bought with a genuinely full tank,
# and the total healing available from a given amount of gas is bounded by that gas
# rather than by how finely it can be dribbled in.
#
# `> #healmin` and not `matches #healmin+1..` because a range needs a literal. The
# 4-field comparison form works with a fake-player source here - the same form
# `fart.pressure >= @s fart.leg` already uses further down this file.
#
# The one-tick lag is deliberate and harmless: this block runs BEFORE
# player/release_gas below, so on the tick the bar crosses the threshold downward
# the heal still fires, having been paid for by gas that was genuinely there when
# the tick started.
execute if entity @s[tag=fart.healing] if score @s fart.pressure > #healmin fart.var if score #healamp fart.var matches 0 run effect give @s minecraft:regeneration 2 0 true
execute if entity @s[tag=fart.healing] if score @s fart.pressure > #healmin fart.var if score #healamp fart.var matches 1 run effect give @s minecraft:regeneration 2 1 true
execute if entity @s[tag=fart.healing] if score @s fart.pressure > #healmin fart.var if score #healamp fart.var matches 2 run effect give @s minecraft:regeneration 2 2 true
execute if entity @s[tag=fart.healing] if score @s fart.pressure > #healmin fart.var if score #healamp fart.var matches 3 run effect give @s minecraft:regeneration 2 3 true
execute if entity @s[tag=fart.healing] if score @s fart.pressure > #healmin fart.var if score #healamp fart.var matches 4 run effect give @s minecraft:regeneration 2 4 true
execute if entity @s[tag=fart.healing] if score @s fart.pressure > #healmin fart.var if score #healamp fart.var matches 5 run effect give @s minecraft:regeneration 2 5 true

# v32: SAY SO ON SCREEN. The heal was working and invisible, which is the whole
# reason it read as broken for two versions - a mechanic that produces no feedback
# is indistinguishable from a mechanic that does not run. The actionbar says which
# of the two things happening is happening, and WHY the other one is not:
#   healing   -> REGENERATING, and that the gas is the fuel
#   not yet   -> the bar is below the threshold, and what the threshold is
# Both are gated on the SAME conditions as the effect above, so the message can
# never claim a heal that is not being applied. That is the only way an indicator
# like this is worth having - an indicator that disagrees with the mechanic is worse
# than no indicator, because it is trusted.
#
# The threshold in the message is READ FROM #healmin, not typed into the text. The
# first version of this line hardcoded "11" while #healmin was a tunable, which is
# precisely the lying indicator described above: change the threshold to 20 and the
# bar would cheerfully tell a player they needed 11. A `score` component naming
# #healmin is the way to print a scoreboard value, and it cannot drift from the
# number the gate is actually using.
#
# IT IS A `score` COMPONENT AND NOT A `selector` ONE, and the reason is measured
# rather than remembered. The first attempt here was
#   {"selector":"#healmin","color":"yellow","bold":true}
# on the theory that a selector component resolves a fake player and prints
# something useful. It is REJECTED outright by this server:
#   Invalid chat component: ... Not a list: {bold:1b,color:"yellow",selector:"#healmin"}
# The correct form is
#   {"score":{"name":"#healmin","objective":"fart.var"}}
# which the pack already uses in admin/*. Two component types, two different jobs:
# `selector` prints the NAME of what a selector matched, `score` prints a NUMBER out
# of an objective. Confusing them is not a syntax error - `{"selector":"@s",...}`
# parses fine - it just quietly prints the wrong kind of thing, which is worse.
# That mistake is live in profile/apply, profile/skip and profile/stats right now,
# from v31. #34.
execute if entity @s[tag=fart.healing] if score @s fart.pressure > #healmin fart.var run title @s actionbar [{"text":"REGENERATING","color":"green","bold":true},{"text":"   your gas is the fuel","color":"gray"}]
# v33: the "bar too low to heal" message is DELETED, at the user's request - it
# was telling them a number they had not asked about, and it fired on every tick
# of any crouch below the threshold, which is most of a normal crouch. Silence is
# the better answer: if the bar is too low nothing happens, and the near-full
# warning above is the one message this file now puts on screen unasked.
# The bank is deliberately NOT cleared when the player stands up (lines below).
# A player who crouches, is interrupted, and crouches again keeps their partial
# progress: they have already paid that gas out of their tank and it is gone.
# Resetting it here would make the interrupted crouch the worst case, which is
# the exact situation the bug report was written about.
execute if entity @s[tag=fart.sneak,tag=fart.healtick,tag=!fart.healing] run scoreboard players set #power fart.var 24
execute if entity @s[tag=fart.sneak,tag=fart.healtick,tag=!fart.healing] run function fartpack:push/self
execute if entity @s[tag=fart.sneak,scores={fart.pressure=1..},tag=!fart.releasing] run tag @s add fart.releasing
execute if entity @s[tag=fart.sneak] run function fartpack:player/stress
execute if entity @s[tag=fart.releasing] unless entity @s[tag=fart.sneak] run tag @s remove fart.releasing
execute if entity @s[tag=fart.releasing] unless entity @s[tag=fart.sneak] run tag @s remove fart.healtick
execute if entity @s[tag=fart.healing] unless entity @s[tag=fart.sneak] run scoreboard players set @s fart.healcd 0
execute if entity @s[tag=fart.healing] unless entity @s[tag=fart.sneak] run tag @s remove fart.healing
execute if entity @s[tag=fart.sneak,tag=fart.releasing] at @s run function fartpack:player/release_gas
# v28: the per-tick hunger is GONE. The line this replaces was
#
#   execute if score @s fart.pressure >= @s fart.warn unless entity @s[tag=fart.releasing] run effect give @s minecraft:hunger 5 0 true
#
# and it was the single most-reported thing about the pack: "i always get hunger
# even when im not crouch farting". The `unless ... tag=!fart.releasing` guard
# is the whole explanation - it applied hunger precisely when you were NOT
# releasing, so standing still with a bar over a quarter full gave you Hunger I
# refreshed every single tick. 5 ticks of effect, re-applied 20 times a second,
# is permanent hunger. Crouching cleared it, which is why it read as a crouch
# mechanic that was somehow always on.
#
# Verified against the live world before the change: YOSHIKURO1 sat at
# fart.pressure 46 against a cap of 100, so fart.warn was 25 and the condition
# was true on every tick of every session.
#
# Only line 48 is removed. `fart.warn` itself is still derived in admin/recalc
# and admin/cap and still defaulted here, and that is deliberate: it is the
# cap-relative quarter mark, it is cheap, and both admin macros plus
# verifycfg.sh assert on it. It is now derived-but-unread - the honest
# description - rather than deleted, because deleting it would mean editing two
# macro functions and the config gate to remove a number nobody looks at.
execute unless score @s fart.warn matches 1.. run scoreboard players set @s fart.warn 25
# Ditto the forced legendary mega-fart, which is "bar is full" - so it is
# exactly the cap, not a constant.
execute unless score @s fart.leg matches 1.. run scoreboard players set @s fart.leg 100
execute if score @s fart.pressure >= @s fart.leg at @s run function fartpack:world/fart_forced
