## mission_scope.gd - one place that undoes a mission.
##
## GameFlow builds mission after mission IN ONE PROCESS. Static vars and autoload
## state survive _teardown_world(), so mission 5 inherits mission 1's world.
## Every leak below was found by audit and, where cheap, proven by probe:
##
##   MissionDirector.any_fire_menu_open  die with [T] open -> every kit key is
##       dead for the rest of the session. GDScript does not run a setter for a
##       member initializer, so a fresh director never clears the static.
##       PROVEN: tests/probe_smoke_all.gd section B.
##   DamageSystem.scar_decals/damage_zones  decal_container is a child of the
##       AUTOLOAD, not GameWorld. Mission 2 opens with mission 1's craters
##       floating on a different heightmap. clear_all_damage()'s only caller was
##       in the dead terrain_lab subgraph.  PROVEN: probe_smoke_all section D.
##   EnemyBase._cover_claims  Vector3i world cells, held by freed enemies.
##   GunFX._sting_cooldown_until  absolute Time.get_ticks_msec(), so a sting at
##       the end of mission N mutes the CONTACT drum for the first 25s of N+1.
##   SpriteLibrary  a 1024x1280 RGBA8 sheet is 5.24 MB of VRAM.
##   SurviveWaves  a long await chain whose stop() had zero callers.
##
## Not reset here, deliberately: CampaignState (that IS the campaign),
## GameSettings (a player setting), WeaponHolder.session_shots/hits (already
## zeroed by game_flow.gd:172).
class_name MissionScope
extends RefCounted


static func reset() -> void:
	# Long-lived coroutines first: they may touch the world we are about to free.
	for n in Engine.get_main_loop().root.get_tree().get_nodes_in_group("wave_runners"):
		if n.has_method("stop"):
			n.call("stop")

	MissionDirector.any_fire_menu_open = false
	EnemyBase._cover_claims.clear()
	GunFX.reset_session()
	GunFX.clear_decals()
	SpriteLibrary.clear()
	NavBaker.clear()
	EnemySquad.clear()   ## stale AABBs would put mission 5's enemies in mission 1's village
	GruntRandomizer.reset_bench()   ## bench-face walk restarts, mission N+1 repeats deterministically
	TerrainZoning.reset()   ## static patch-noise field outlives teardown (ADR-010)

	var dmg: Node = Engine.get_main_loop().root.get_node_or_null("DamageSystem")
	if dmg != null and dmg.has_method("clear_all_damage"):
		dmg.call("clear_all_damage")
	var clr: Node = Engine.get_main_loop().root.get_node_or_null("ClearingSystem")
	if clr != null and clr.has_method("clear_all_zones"):
		clr.call("clear_all_zones")
