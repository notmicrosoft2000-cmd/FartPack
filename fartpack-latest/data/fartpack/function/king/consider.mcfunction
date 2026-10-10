# One challenger, run as each non-king player by king/crown.
#
# Only a STRICTLY higher total tags the player, and the bar is raised in the same
# step. Those two facts together are what make the winner unique: the first
# player to beat the bar raises it to their own total, so the next player has to
# beat THAT, and a tie can never produce two people wearing the crown. The order
# @a happens to return players in is therefore irrelevant, which is the point -
# a leaderboard that depended on selector order would hand the crown to
# whichever name sorted first whenever two players were level.
execute store result score #mine fart.var run scoreboard players get @s fart.total
execute if score #mine fart.var > #kbest fart.var run tag @s add fart.king_new
execute if score #mine fart.var > #kbest fart.var run scoreboard players operation #kbest fart.var = #mine fart.var
