## test_actor_damage_contract.gd - every damageable actor is REACHABLE.
##
## Run: godot --headless --path . res://tests/test_actor_damage_contract.tscn
##
## Two tiers, and neither alone is sufficient.
##
## TIER 1 scans source for every `func take_damage(` and checks it against
## ACTOR_CONTRACT. A NEW actor type that declares take_damage and is not in the
## table FAILS THE BUILD - that is the ratchet. Adding a row is a deliberate act;
## it is not a snooze button. Tier 1 also enforces the ARITY CONTRACT: callers
## pass four arguments and has_method() checks the NAME, not the signature, so a
## 3-arg take_damage binds fine and errors on the first hit. That is exactly how
## civilians shipped with an unreachable damage function.
##
## TIER 2 spawns a live civilian and proves the whole chain end to end: zones
## exist on the masked layer, a bullet-shaped call kills, gib donors are present
## by name, and the zones are GONE from the corpse.
extends Node

const CIV_LAYER: int = 512

## actor script -> what it must carry.
##   hitzones: declares zones on a layer inside a fire mask
##   gib: calls GibSystem on death
##   rig: zones are derived from a skeleton, so HitzoneBuilder is their only authority
##        (ADR-023). Absent = true. A PROP has no skeleton and HitzoneBuilder cannot
##        serve it, so a prop row sets rig:false and must construct its own Hitzone.
## Grow this table when a new damageable actor lands. Never edit it to silence red.
const ACTOR_CONTRACT: Dictionary = {
	"res://scripts/world/civilian.gd": {"hitzones": true, "gib": true},
	"res://scripts/enemies/enemy_base.gd": {"hitzones": true, "gib": true},
	"res://scripts/allies/ally_base.gd": {"hitzones": true, "gib": true},
	"res://scripts/player/player.gd": {"hitzones": true, "gib": false},
	"res://scripts/levels/gore_dummy.gd": {"hitzones": true, "gib": true},
	"res://scripts/combat/punji_trap.gd": {"hitzones": true, "gib": false, "rig": false},
	# HealthSystem is the player's damage SINK, not a spawnable actor: it owns no
	# body and no zones. player.gd delegates to it.
	"res://scripts/player/health_system.gd": {"hitzones": false, "gib": false},
	# Blast-bus props (AgentRegistry PROP kind): only explosions reach take_damage via
	# combat_manager's props loop. No Hitzone (rifle fire is merely blocked - cover),
	# no gib (death is a state swap / scripted fell, not a body).
	"res://scripts/world/destructible.gd": {"hitzones": false, "gib": false},
	"res://scripts/world/fellable_tree.gd": {"hitzones": false, "gib": false},
}

## Layers a player or AI round can actually hit. A zone outside this set is
## bullet-transparent no matter how correctly it is built.
const FIRE_MASK_LAYERS: Array[int] = [32, 64, 512]

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	_tier1_source_contract()
	await _tier2_live_civilian()
	if failures > 0:
		print("FAIL: test_actor_damage_contract - %d failure(s) across %d checks" % [failures, checks])
	else:
		print("PASS: test_actor_damage_contract - %d checks" % checks)
	get_tree().quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	failures += 1
	print("  FAIL: " + msg)


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		_fail(msg)


# ---- TIER 1: source contract ------------------------------------------------

func _tier1_source_contract() -> void:
	var found: Array[String] = []
	_scan_dir("res://scripts", found)

	for path in found:
		checks += 1
		if not ACTOR_CONTRACT.has(path):
			_fail("%s declares take_damage() but is NOT in ACTOR_CONTRACT. A new damageable actor must declare whether it carries hitzones and gib - add a row." % path)
			continue
		var src: String = FileAccess.get_file_as_string(path)
		var spec: Dictionary = ACTOR_CONTRACT[path]

		# The arity contract binds anything a BULLET can reach. An internal sink
		# (HealthSystem) is called only by code that knows its signature.
		if bool(spec["hitzones"]):
			var arity: int = _take_damage_arity(src)
			_check(arity >= 4,
				"%s take_damage() takes %d args; the bullet resolver passes 4 (bullet_system.gd:147, weapon_holder.gd:634). has_method() checks the NAME, not the signature - it will bind and error on the first hit." % [path, arity])

		if bool(spec["hitzones"]):
			var rigged: bool = not spec.has("rig") or bool(spec["rig"])
			if rigged:
				_check(src.contains("HitzoneBuilder.build(") or src.contains("HitzoneBuilder._build_static("),
					"%s is contracted to carry hitzones but never calls HitzoneBuilder. Rounds will pass through it." % path)
			else:
				_check(src.contains("Hitzone.new()") and src.contains("set_owner_entity("),
					"%s is a prop contracted to carry a zone, but it never constructs a Hitzone with an owner_entity. bullet_system resolves damage through the zone's owner or not at all." % path)
			_check(_declares_masked_layer(src),
				"%s builds hitzones on a layer no fire mask contains %s - it is bullet-transparent." % [path, str(FIRE_MASK_LAYERS)])
		if bool(spec["gib"]):
			_check(src.contains("GibSystem."),
				"%s is contracted to gib but never calls GibSystem." % path)

	# The player carried TWO overlapping zone sets - one from HitzoneBuilder, one
	# hand-placed - and only the builder's set stamped the `region` meta, so the
	# reported region was whichever shape the ray met first (ADR-010).
	var pl: String = FileAccess.get_file_as_string("res://scripts/player/player.gd")
	_check(not pl.contains("_create_hitzone("),
		"player.gd hand-places hitzones again. HitzoneBuilder is the single zone authority (ADR-023).")


func _scan_dir(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var full: String = dir_path + "/" + name
		if d.current_is_dir():
			_scan_dir(full, out)
		elif name.ends_with(".gd"):
			var src: String = FileAccess.get_file_as_string(full)
			if src.contains("func take_damage("):
				out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _take_damage_arity(src: String) -> int:
	var i: int = src.find("func take_damage(")
	if i < 0:
		return 0
	var start: int = i + len("func take_damage(")
	var depth: int = 1
	var args: String = ""
	var j: int = start
	while j < len(src) and depth > 0:
		var ch: String = src[j]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				break
		if depth > 0:
			args += ch
		j += 1
	if args.strip_edges().is_empty():
		return 0
	# Commas inside Array[...] / default Vector3(...) would over-count; take_damage
	# signatures are flat, but strip bracket groups to stay honest.
	var depth2: int = 0
	var flat: String = ""
	for ch in args:
		if ch == "[" or ch == "(":
			depth2 += 1
		elif ch == "]" or ch == ")":
			depth2 -= 1
		elif depth2 == 0:
			flat += ch
	return flat.split(",").size()


func _declares_masked_layer(src: String) -> bool:
	for layer in FIRE_MASK_LAYERS:
		if src.contains("_build_static(self, %d," % layer) \
				or src.contains("build(self, ma, %d," % layer) \
				or src.contains("_build_static(civ, CIVILIAN_HURTBOX_LAYER,") \
				or src.contains(", %d, 16," % layer):
			return true
	return _assigns_masked_layer(src)


## The forms above are the rigged-actor BUILDER CALL shapes. A prop assigns the layer
## on the zone directly, and usually through a named const, so resolve one level of
## indirection: `collision_layer = TRAP_HURTBOX_LAYER` -> `const TRAP_HURTBOX_LAYER: int = 512`.
## Without this a prop can only satisfy the contract by inlining a magic number.
func _assigns_masked_layer(src: String) -> bool:
	for raw: String in src.split("\n"):
		var line: String = _strip_comment(raw)
		var i: int = line.find("collision_layer")
		if i < 0:
			continue
		var eq: int = line.find("=", i)
		if eq < 0:
			continue
		var rhs: String = line.substr(eq + 1).strip_edges()
		if rhs.is_valid_int():
			if FIRE_MASK_LAYERS.has(int(rhs)):
				return true
			continue
		if FIRE_MASK_LAYERS.has(_const_int(src, rhs)):
			return true
	return false


## Value of `const <ident>[: int] = <literal>` in this same source, or 0 if absent.
func _const_int(src: String, ident: String) -> int:
	if ident.is_empty():
		return 0
	for raw: String in src.split("\n"):
		var line: String = _strip_comment(raw).strip_edges()
		if not line.begins_with("const " + ident):
			continue
		var tail: String = line.substr(len("const " + ident))
		# guard against `const FOO_BAR` matching a request for `FOO`
		if not (tail.begins_with(":") or tail.begins_with(" ") or tail.begins_with("=")):
			continue
		var eq: int = line.find("=")
		if eq < 0:
			continue
		var rhs: String = line.substr(eq + 1).strip_edges()
		if rhs.is_valid_int():
			return int(rhs)
	return 0


func _strip_comment(line: String) -> String:
	var h: int = line.find("#")
	return line if h < 0 else line.substr(0, h)


# ---- TIER 2: live civilian --------------------------------------------------

func _tier2_live_civilian() -> void:
	var civ: Civilian = Civilian.spawn(self, Vector3(0, 0, 0), null, false)
	await get_tree().process_frame
	await get_tree().process_frame

	var zones: Array[Hitzone] = []
	for c in civ.get_children():
		if c is Hitzone:
			zones.append(c as Hitzone)
	_check(zones.size() >= 7,
		"civilian spawned with %d hitzones; the static band set is 7." % zones.size())

	var head_found: bool = false
	for hz in zones:
		_check(hz.collision_layer == CIV_LAYER,
			"civilian hitzone on layer %d, expected %d." % [hz.collision_layer, CIV_LAYER])
		_check(hz.is_in_group("civilian_hurtbox"),
			"civilian hitzone missing the civilian_hurtbox group.")
		_check(hz.owner_entity == civ,
			"civilian hitzone owner_entity is not the civilian - bullet_system resolves damage through it.")
		_check(hz.has_meta("region"),
			"civilian hitzone carries no `region` meta - the gore channel needs it.")
		if hz.zone_type == Hitzone.ZoneType.HEAD:
			head_found = true
	_check(head_found, "civilian has no HEAD zone.")

	# Hitzone._setup_groups() only branches on the `player` and `enemies` groups.
	# A civilian falls through it, so the layer build() was given must survive.
	_check(not zones.is_empty() and not zones[0].is_in_group("enemy_hurtbox"),
		"civilian hitzone landed in enemy_hurtbox - it would be treated as a combatant.")

	# The gib contract is by-name node inspection at call time; there is no
	# registration, so the donor MESH NAMES are the contract.
	if civ.actor != null and civ.actor.has_visual():
		var root: Node = civ.actor.instance_root()
		for donor in ["grunt_head", "grunt_forearm_l", "grunt_leg_r", "cap_head"]:
			_check(root.find_child(donor, true, false) != null,
				"civilian model '%s' is missing gib donor '%s' - GibSystem resolves donors by name." % [civ.actor.unit, donor])
	else:
		_fail("civilian spawned with no visual - cannot verify gib donors.")

	# The full bullet-shaped call: four args, the way bullet_system.gd:147 makes it.
	civ.take_damage(999, Enums.DamageType.PHYSICAL, self, "BODY")
	await get_tree().process_frame
	_check(civ.state == Civilian.CivState.GONE,
		"civilian survived 999 damage - take_damage did not reach the death path.")

	# The body is laid flat on death. Zones ride it, so a surviving HEAD zone
	# swings out to chest height a metre and a half away, invisible, and eats
	# rounds for the whole 30s corpse linger.
	var live_zones: int = 0
	for c in civ.get_children():
		if c is Hitzone and not (c as Hitzone).is_queued_for_deletion():
			live_zones += 1
	_check(live_zones == 0,
		"%d hitzone(s) survive on the civilian corpse; the body is rotated 90 degrees and they rotate with it." % live_zones)

	# The ROE hook must stay CALLED and EMPTY: a signal or an uncalled function
	# is a fossil and turns test_fossils red.
	_check(civ.has_method("_record_noncombatant_death"),
		"the ROE hook _record_noncombatant_death() is gone - future war-crime scoring has no attach point.")
	var civ_src: String = FileAccess.get_file_as_string("res://scripts/world/civilian.gd")
	_check(civ_src.contains("_record_noncombatant_death(attacker)"),
		"_record_noncombatant_death() is never called - an uncalled function is a fossil (ADR-023).")

	civ.queue_free()
