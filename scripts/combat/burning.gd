## burning.gd - A man on fire: the flame that rides his body, and the clip chain
## that shows him losing the fight with it.
##
## The animation is SPLICED FROM PROVEN LIBRARY CLIPS, not authored cold (the
## project's standing animation law). There is no burn clip among the 216 in
## anim_library.glb, so this borrows the civilian panic beat and then hands the
## body to physics:
##
##   RUN   running_unarmed   the civilian FLEE clip (civilian.gd:466) - frantic,
##                           arms free, no weapon carry. A burning man runs.
##   DOWN  play_any_death()  he falls and STAYS DOWN, burning on the ground.
##                           Deliberately NOT a ragdoll: physics needs a collider
##                           under him and drops him through anything that has
##                           none, and a lit corpse that slides is worse than one
##                           that simply lies there.
##
## Ends in death, always - a burn that expires and leaves a man standing is worse
## than no burn at all.
class_name Burning
extends Node3D

## Whole burn, ignition to dead. Kept short on purpose: at 7s the beats sat far
## enough apart that the chain read as three separate poses instead of one man
## losing a fight.
const BURN_S: float = 4.2
const DPS: float = 22.0           ## burn damage while alight
## Flame height standing vs lying: the fire has to come down WITH him or it
## burns in the air above a body on the ground.
const PRONE_Y: float = 0.28

const CLIP_RUN := "running_unarmed"
## Fallbacks: a body without the civilian clip still gets a stagger.
const CLIP_RUN_ALT := "stumble_hit"
const CLIP_ROLL := "falling_to_roll"
const CLIP_CRAWL := "wounded_crawl"
const CLIP_COWER := "crouching"

## How a given man loses the fight. Rolled once, at ignition. Men do not all
## behave the same way on fire, and a strip where every body performs the same
## beat at the same moment reads as a machine.
enum Style { DROP, ROLL, COWER }
const STYLE_NAMES: Array[String] = ["DROP", "ROLL+CRAWL", "COWER"]
## Fraction of the burn at which each style stops performing and goes down.
const STYLE_DOWN: Array[float] = [0.55, 0.84, 0.80]

## Torso height on the PSX humanoid (~1.71m tall). The flame is parented to the
## body, not the world, so it tracks whatever the man is doing.
const TORSO_Y: float = 0.95

var _t: float = 0.0
var _host: Node3D = null
var _dmg_accum: float = 0.0
var _dropped: bool = false
var _style: int = Style.DROP


## Construction lives in the CALLER (fire_hazard.gd), not in a static factory
## here. A `class_name` is not registered until the editor rescans, and a script
## that names its own class in a signature cannot compile before that - which
## takes every script depending on it down with it. This file therefore never
## refers to `Burning` by name.
func setup(host: Node3D) -> void:
	_host = host
	_style = randi() % Style.size()
	_build_flame()


func style_name() -> String:
	return STYLE_NAMES[_style]


## Walking back into the strip refreshes the burn instead of stacking flames.
func refresh() -> void:
	if not _dropped:
		_t = 0.0   # a man already on the ground does not get back up


func is_burning() -> bool:
	return _t < BURN_S


## The clip this man should be playing, or "" once he has dropped - after the
## ragdoll starts, ANY clip would fight the physics for the same skeleton.
## Callers must skip playing when this returns "".
func clip() -> String:
	if _dropped:
		return ""
	var f: float = _t / BURN_S
	match _style:
		Style.ROLL:
			# Stop, drop and roll - the instinct - then he cannot get up again.
			if f < 0.28:
				return CLIP_RUN
			if f < 0.44:
				return CLIP_ROLL
			return CLIP_CRAWL
		Style.COWER:
			# He never really runs: a few steps, then folds up and takes it.
			if f < 0.18:
				return CLIP_RUN
			return CLIP_COWER
		_:
			return CLIP_RUN


## Second choice if the body's library lacks the civilian panic clip.
func clip_alt() -> String:
	return CLIP_RUN_ALT


## The ModelActor on this body, found by CAPABILITY not by class - enemies,
## allies and the burn lab all hold theirs in a different place.
func _find_actor() -> Node:
	if _host == null or not is_instance_valid(_host):
		return null
	var stack: Array[Node] = [_host]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != _host and n.has_method("play_any_death"):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


func _drop() -> void:
	_dropped = true
	var actor: Node = _find_actor()
	if actor == null:
		return
	# A real death clip ends flat on the ground and holds there.
	if not bool(actor.call("play_any_death")):
		actor.call("pose_end_of", "death_from_the_front")


func _build_flame() -> void:
	position.y = TORSO_Y

	var flame := GPUParticles3D.new()
	flame.amount = 10
	flame.lifetime = 0.85
	flame.local_coords = true
	flame.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 8, 6))
	var fp := ParticleProcessMaterial.new()
	fp.direction = Vector3.UP
	fp.spread = 14.0
	fp.initial_velocity_min = 0.5
	fp.initial_velocity_max = 1.3
	fp.gravity = Vector3(0, 0.9, 0)
	fp.scale_min = 0.5
	fp.scale_max = 0.95
	fp.lifetime_randomness = 0.4
	fp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fp.emission_box_extents = Vector3(0.22, 0.55, 0.16)   # a man, not a bonfire
	GunFX._play_sheet_once(fp)
	flame.process_material = fp
	var fmat := GunFX._sheet_mat("burn_body_mat", "sheets/fire_loop_sheet", 4, 4, false)
	fmat.particles_anim_loop = true
	flame.draw_pass_1 = GunFX._fx_quad("burn_body_quad", 1.15, fmat)
	add_child(flame)
	flame.emitting = true

	var core := GPUParticles3D.new()
	core.amount = 5
	core.lifetime = 0.5
	core.local_coords = true
	core.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 5, 4))
	var cp := ParticleProcessMaterial.new()
	cp.direction = Vector3.UP
	cp.spread = 8.0
	cp.initial_velocity_min = 0.4
	cp.initial_velocity_max = 0.9
	cp.gravity = Vector3(0, 0.6, 0)
	cp.scale_min = 0.3
	cp.scale_max = 0.5
	cp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	cp.emission_box_extents = Vector3(0.16, 0.45, 0.12)
	GunFX._play_sheet_once(cp)
	core.process_material = cp
	var cmat := GunFX._sheet_mat("burn_core_mat", "sheets/fire_core_sheet", 4, 4, true)
	cmat.particles_anim_loop = true
	core.draw_pass_1 = GunFX._fx_quad("burn_core_quad", 0.75, cmat)
	add_child(core)
	core.emitting = true

	var emb := GPUParticles3D.new()
	emb.amount = 8
	emb.lifetime = 1.5
	emb.local_coords = false      # embers shed into the world as he runs
	emb.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 12, 12))
	var ep := ParticleProcessMaterial.new()
	ep.direction = Vector3.UP
	ep.spread = 30.0
	ep.initial_velocity_min = 0.8
	ep.initial_velocity_max = 2.0
	ep.gravity = Vector3(0, -1.2, 0)
	ep.scale_min = 0.03
	ep.scale_max = 0.07
	ep.color_ramp = GunFX._smoke_fade_ramp()
	emb.process_material = ep
	var emat := GunFX._plain_mat("burn_ember_mat", "particles/ember")
	emat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	emb.draw_pass_1 = GunFX._fx_quad("burn_ember_quad", 0.22, emat)
	add_child(emb)
	emb.emitting = true


func _process(delta: float) -> void:
	_t += delta
	if not _dropped and _t >= BURN_S * STYLE_DOWN[_style]:
		_drop()
	if _dropped:
		# Bring the fire down onto the body; it must not hang where he was stood.
		position.y = lerpf(position.y, PRONE_Y, minf(delta * 5.0, 1.0))
	if _t >= BURN_S:
		# A burning man DIES. Without this he ran out of burn time and stood back
		# up mid-crawl, or crawled forever on whatever health survived the DPS.
		# Routed through take_damage rather than a private kill so the death clip,
		# the casualty ledger and every listener behave exactly as normal.
		if _host != null and is_instance_valid(_host) and _host.has_method("take_damage"):
			_host.call("take_damage", 9999, Enums.DamageType.FIRE, null)
		queue_free()
		return
	# Burn damage is applied HERE, not by the hazard, so a man who runs out of
	# the strip still burns - leaving the fire does not put you out.
	_dmg_accum += DPS * delta
	if _dmg_accum >= 1.0 and _host != null and is_instance_valid(_host):
		var whole: int = int(_dmg_accum)
		_dmg_accum -= float(whole)
		if _host.has_method("take_damage"):
			_host.call("take_damage", whole, Enums.DamageType.FIRE, null)
