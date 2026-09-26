## v15 (Sep 25 22:56) — Crouch farting now heals
- User request: "make it so crouch farting heals half a heart per two secs! so something is good"
- Design: sustained ONLY while actively releasing (fart.releasing). When the release starts, give the player minecraft:regeneration amplifier 0 (1 HP = half a heart ~every 2.5s) + tag fart.healing; when the player stops sneaking, clear fart.healing + clear minecraft:regeneration + hunger. hunger still applies while releasing (unchanged).
- Changes in tick.mcfunction (release-start block): add tag fart.healing, effect give regeneration 100000 0 true. On stop (% fart.releasing unless sneak): remove tag fart.healing + effect clear regeneration (alongside existing hunger clear).
- assign_pid.mcfunction + load.mcfunction welcome text updated: CROUCH now also "HEALS you while you hold it!"
- Bottleneck: release-start already requires fart.pressure=1.. so it only triggers with actual gas; regen persists while sneaking even after pressure empties (matches "while you hold it"). Removed when you stand up.
- Deployed as world/datapacks/fartpack.zip sha1 869abb3bd23b1e36bc5640cc9006162f44e5bbef via full Crafty API restart (stop/start). Clean load, no fartpack errors. Live playtest pending (server empty).
- Local mirror updated: /home/neptune/Documents/Fartpack/fartpack-latest.zip, backup in backups/fartpack/v15/.