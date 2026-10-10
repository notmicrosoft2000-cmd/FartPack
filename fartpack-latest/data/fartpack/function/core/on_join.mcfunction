# Runs once, on the tick a player appears without a pid, ahead of core/assign_pid.
# FIVE jobs, in this order on purpose:
#
# 1. crown hygiene. A king who logged out kept the fart.king tag, because nothing
#    in the pack removes it on logout. Coming back they would be an unsported,
#    uncrowned, double-rate player, and king/crown would not notice because the tag
#    still says they are king. So the crown is dropped here and has to be won again
#    by farting. See king/crown for why an absent king hands the crown on rather
#    than holding it empty.
# 2. the welcome regen. Regeneration II for 10 seconds, so a joining player starts
#    at full health instead of wherever they logged out. This is per join, and it
#    is deliberately WEAKER than the crouch heal - a welcome gesture, not a
#    reward. The crouch heal is a Regeneration VI and that is the interesting one.
# 3. the main book.
#
# The order is the whole reason there are several functions rather than one: a
# malformed `give` throws, and a throw aborts the rest of the function. Putting
# the scoreboard repair FIRST means a broken book can only ever cost the player
# their book, never their in-game state, and putting the welcome regen before the
# books means a player is healed even if a book is malformed.
#
# v33: THE PROFILE SYSTEM IS GONE, at the user's request - the age/weight/gender
# inputs, the /trigger commands, the nag, the profile book and the stats readout
# are all removed. What replaced it is nothing: admin/defaults (run by
# core/assign_pid) already gives every new player rate 1 / cap 100 / pow 30, so
# there is nothing to choose and nothing to seed. The two lines that used to be
# here - profile/ensure and the guarded profile/nag - are deleted, and with them
# the whole `fart.p*` trigger family and the `fart.profiled` tag become
# unreachable. See docs/PROFILE-REMOVED-v33.md in the REPO (not in the pack - a
# .md inside data/fartpack/function/ is an invalid datapack path and the server
# logs "Invalid path in datapack ... ignoring" on every single reload, which is
# exactly the kind of permanent noise that teaches everyone to ignore warnings)
# for the list of what went and why each
# dependent was checked before deletion.
execute if entity @s[tag=fart.king] run function fartpack:king/demote
effect give @s minecraft:regeneration 200 1 true
function fartpack:book/give
# v34: THE ITEMS HANDOUT IS BACK. items.mcfunction -> items/give had no call site
# at all, so the only way to get a tonic or a kibble was crafting them, and the
# "Welcome back" line the pack printed on join had nothing behind it. Restored
# here, LAST on purpose: this file's own header says a malformed `give` throws and
# a throw aborts everything after it, so the two give lines in items/give are the
# most likely thing to fail and must never be able to cost a player their crown
# repair, their regen or their book.
#
# items/give uses @s and is called per-player from this per-player function, so
# each joining player gets their own pair and nobody else's.
function fartpack:items/give
