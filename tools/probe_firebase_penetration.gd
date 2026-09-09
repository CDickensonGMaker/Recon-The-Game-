## probe_firebase_penetration.gd - does the REAL firebase obey the penetration grammar?
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --pen-probe
##
## probe_structure_ballistics.gd proves the WORLD path: a hut placed through
## SitePlanner.place_structure, material decided by CollisionTable. The firebase does not
## use that path at all - it uses _tag_fsb_ballistics, which matches NAME PREFIXES and
## defaults everything else to bulletproof. That function had no test, and the re-export
## regenerates every one of those node names.
##
## Two halves, both required:
##   STATIC   the tagging census the load pass published, ratcheted against a baseline -
##            soft may not fall, the unheard-of family list may not grow.
##   LIVE     a man inside a real hooch must die through its wall; a man behind a real
##            sandbag parapet must take nothing. Same discipline as the older probe: the
##            shot axis is verified to cross a TAGGED surface before the result is believed,
##            or a doorway proves the wrong thing.
extends Node3D

const BASELINE_PATH: String = "res://tools/firebase_ballistics_baseline.json"
## The garrison, the nav bake and the interior cull all land after frame one.
const SETTLE_S: float = 25.0
## Stand-off for the firing eye, and how far inside the wall the target stands.
const EYE_M: float = 7.0
const INSIDE_M: float = 1.6
const M16: String = "res://data/weapons/m16a1.tres"
const TARGET_DATA: String = "res://data/enemies/vc_rifleman.tres"

var _world: Node3D = null
var _fails: int = 0


func _ready() -> void:
	_world = get_parent() as Node3D
	await get_tree().create_timer(SETTLE_S).timeout
	if _world == null or not is_instance_valid(_world):
		print("[PEN-PROBE] no world - nothing measured")
		get_tree().quit(1)
		return
	print("\n=== FIREBASE PENETRATION PROBE ===")
	_check_census()
	await _shoot_through(["fb_hwall"], "soft_cover", true)
	await _shoot_through(["fb_bunker_fighting", "fb_bunker_mg", "fb_sandbag_stack"],
		"hard_surface", false)
	if _fails == 0:
		print("*** THE FIREBASE OBEYS THE PENETRATION GRAMMAR. ***")
	else:
		print("=== PEN-PROBE: %d FAILURE(S) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_fails += 1


## ---- STATIC: the ratchet ----

func _check_census() -> void:
	var now: Dictionary = SitePlanner.fsb_ballistic_report
	if now.is_empty():
		_fail("the firebase tagging pass published nothing - _tag_fsb_ballistics did not run")
		return
	print("[PEN] census: %d soft (%d figure parts), %d hard, %d famil(ies) hard BY DEFAULT" % [
		int(now.soft), int(now.figures), int(now.hard), int(now.families)])
	var base: Dictionary = _load_baseline()
	if base.is_empty():
		print("[PEN] no baseline yet - writing one. Re-run to ratchet against it.")
		_write_baseline(now)
		return
	# Soft may only RISE. A re-export that renames a family silently moves it to hard, and
	# hard is the dangerous default: the count falling is the signature of that.
	if int(now.soft) < int(base.get("soft", 0)):
		_fail("soft colliders fell %d -> %d: a family lost its prefix and is now bulletproof"
			% [int(base.soft), int(now.soft)])
	if int(now.figures) < int(base.get("figures", 0)):
		_fail("casualty-figure parts fell %d -> %d: bodies are reading as sandbag walls again"
			% [int(base.figures), int(now.figures)])
	var known: Dictionary = {}
	for n in base.get("family_names", []):
		known[String(n)] = true
	var grew: PackedStringArray = PackedStringArray()
	for n in now.get("family_names", []):
		if not known.has(String(n)):
			grew.append(String(n))
	if grew.size() > 0:
		grew.sort()
		_fail("%d NEW famil(ies) defaulted to bulletproof: %s" % [grew.size(), ", ".join(grew)])
	else:
		print("[PEN] ratchet holds: no new family defaulted to hard")


func _load_baseline() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		return {}
	var txt: String = FileAccess.get_file_as_string(BASELINE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_baseline(now: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[PEN] cannot write %s (read-only build?) - the ratchet is unarmed" % BASELINE_PATH)
		return
	var names: Array = (now.get("family_names", []) as Array).duplicate()
	names.sort()
	f.store_string(JSON.stringify({"soft": int(now.soft), "hard": int(now.hard),
		"figures": int(now.figures), "families": int(now.families),
		"family_names": names}, "\t"))
	f.close()


## ---- LIVE: put a round through it ----

## Stand a man just inside one of these surfaces, fire through it, and judge. `must_die` is
## the whole contract: plywood is concealment, sandbags and timber are cover.
##
## CANDIDATES, not one wall. A firebase is a crowded place - the first hooch this picks may
## have a sandbag revetment, a generator or another hooch on the firing line, and a probe
## that fires anyway measures whatever it hit instead. It walks candidates until one gives a
## clean line to the surface under test, and FAILS only if none of them does.
const MAX_CANDIDATES: int = 24
## Bearings tried per candidate, as a fraction of a turn off the outward radial.
const BEARING_OFFSETS: Array[float] = [0.0, 0.12, -0.12, 0.25, -0.25]

func _shoot_through(prefixes: Array, want_group: String, must_die: bool) -> void:
	var walls: Array[CollisionObject3D] = _candidates(prefixes, want_group)
	if walls.is_empty():
		_fail("no %s collider in group %s - the probe cannot judge what is not there"
			% [", ".join(PackedStringArray(prefixes)), want_group])
		return
	var centre: Vector3 = _fsb_centre()
	for wall in walls:
		var outward: Vector3 = wall.global_position - centre
		outward.y = 0.0
		if outward.length() < 0.5:
			continue
		outward = outward.normalized()
		for turn in BEARING_OFFSETS:
			var dir: Vector3 = outward.rotated(Vector3.UP, float(turn) * TAU)
			if await _try_line(wall, dir, want_group, must_die):
				return
	_fail("no clean firing line onto any of %d %s candidate(s) - every axis was blocked by "
		% [walls.size(), want_group] + "something else first, so nothing was judged")


## One attempt: a man INSIDE, an eye OUTSIDE on `dir`, and the shot only taken if the
## surface under test is genuinely the thing standing between them. Returns whether the
## attempt produced a verdict.
func _try_line(wall: CollisionObject3D, dir: Vector3, want_group: String,
		must_die: bool) -> bool:
	var stand: Vector3 = wall.global_position - dir * INSIDE_M
	stand.y = _world.call("floor_y", stand)
	var man: Node = EnemyBase.spawn_enemy(_world, stand + Vector3.UP * 0.2, TARGET_DATA)
	await get_tree().create_timer(0.6).timeout
	if man == null or not is_instance_valid(man):
		return false
	var chest: Vector3 = (man as Node3D).global_position + Vector3(0.0, 1.25, 0.0)
	var eye: Vector3 = wall.global_position + dir * EYE_M
	eye.y = chest.y
	# THE AXIS MUST CROSS THIS SURFACE. Without it the probe measures a doorway - or, in a
	# compound this crowded, somebody else's revetment.
	var blocker: Object = _world_blocker(eye, chest)
	if blocker != wall:
		_despawn(man)
		return false
	var bname: String = String(wall.name)
	print("[PEN] on the line: %s (%s)" % [bname, want_group])
	var hp0: int = int(man.get("current_hp"))
	var gun: WeaponData = load(M16)
	for _i in range(6):
		CombatManager.bullets.fire(gun, null, eye, (chest - eye).normalized(), 1 | 32 | 64, [], false)
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.6).timeout
	var dead: bool = not is_instance_valid(man) or bool(man.call("is_dead"))
	var dmg: int = hp0 - (0 if dead else int(man.get("current_hp")))
	print("[PEN] 6x M16 through %s -> %d damage (dead: %s)" % [bname, dmg, dead])
	if must_die and not dead:
		_fail("%s is CONCEALMENT and the man behind it lived on %d damage" % [bname, dmg])
	elif not must_die and dmg > 0:
		_fail("%s is COVER and %d damage went through it" % [bname, dmg])
	_despawn(man)
	return true


func _despawn(man: Node) -> void:
	if man != null and is_instance_valid(man):
		man.queue_free()


## The firebase's own centre, measured from the parapet ring rather than guessed. The ring
## is the thing this probe is judging, so deriving the centre from it keeps the two honest
## together: a parapet that has collapsed to a point produces a centre ON that point, and
## the inward vector below then refuses to fire rather than measuring nonsense.
func _fsb_centre() -> Vector3:
	var sum := Vector3.ZERO
	var n: int = 0
	for node in get_tree().get_nodes_in_group(SitePlanner.FSB_PARAPET_GROUP):
		var d := node as Node3D
		if d == null:
			continue
		sum += d.global_position
		n += 1
	return sum / float(n) if n > 0 else Vector3.ZERO


## Real colliders of these families carrying the group they are supposed to. Sorted by
## name, so two runs judge the same walls in the same order (ADR-010).
func _candidates(prefixes: Array, group: String) -> Array[CollisionObject3D]:
	var out: Array[CollisionObject3D] = []
	for n in get_tree().get_nodes_in_group(group):
		var body := n as CollisionObject3D
		if body == null:
			continue
		for p in prefixes:
			if String(body.name).begins_with(String(p)):
				out.append(body)
				break
	out.sort_custom(func(a: CollisionObject3D, b: CollisionObject3D) -> bool:
		return String(a.name) < String(b.name))
	if out.size() > MAX_CANDIDATES:
		out.resize(MAX_CANDIDATES)
	return out


func _world_blocker(from: Vector3, to: Vector3) -> Object:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.collider if hit.has("collider") else null
