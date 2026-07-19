extends Node
## A2 payoff truth: the gate's target class is the stationary RELAXED man the
## player cannot perceive - which exists in the PATROL WORLD, not the arena
## (hot_start puts every arena unit in COMBAT with no player at all).
## Measures gated share + AI physics cost with the real hub population.

func _ready() -> void:
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(47225, "DIAG-A2")
	var waited := 0.0
	while waited < 180.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(2.0).timeout

	var live: int = AgentRegistry.enemies.size() + AgentRegistry.allies.size()
	var samples: int = 0
	var gated_sum: float = 0.0
	var usec_sum: float = 0.0
	for _s in range(20):
		for _f in range(6):
			await get_tree().physics_frame
		var run: int = CombatManager.bodies_run
		var gated: int = CombatManager.bodies_gated
		var total: int = run + gated
		if total > 0:
			gated_sum += 100.0 * float(gated) / float(total)
			samples += 1
		usec_sum += float(CombatManager.ai_usec_think + CombatManager.ai_usec_move
			+ CombatManager.ai_usec_hitzone + CombatManager.ai_usec_anim)
	var gated_pct: float = gated_sum / maxf(1.0, float(samples))
	print("[A2] patrol world: %d live agents (enemies %d allies %d)" % [
		live, AgentRegistry.enemies.size(), AgentRegistry.allies.size()])
	print("[A2] bodies gated: %.1f%% (target class = stationary RELAXED unperceivable)" % gated_pct)
	print("[A2] ai usec (think+move+hitzone+anim) mean sample: %.0f" % (usec_sum / maxf(1.0, float(samples))))
	print("[A2] VERDICT -> %s" % ("MEASURED" if samples > 0 else "NO SAMPLES"))
	get_tree().quit(0)
