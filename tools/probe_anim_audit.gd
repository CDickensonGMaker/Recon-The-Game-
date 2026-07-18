## probe_anim_audit.gd - THE ANIMATION CONTRACT AUDIT: every model x every
## clip the code demands x what actually resolves. Three verdicts per intent:
##   OK      asked clip (or its weapon-family variant) plays as asked
##   ALIAS   plays, but through the MODEL_ALIASES forgiveness layer
##   GAP     nothing plays - the code's ask has NO answer on this rig
## Also lists each rig's unused clips (authored but never demanded).
##   godot --headless --path . -s res://tools/probe_anim_audit.gd
extends SceneTree

## unit -> the weapon its enemy/ally data hands it (drives __family suffix).
const UNIT_WEAPON: Dictionary = {
	"us_grunt_v2": "m16a1",
	"vc_guerilla": "ak47",
	"vc_guerilla_mosin": "mosin", "vc_guerilla_ppsh": "ppsh41",
	"vc_guerilla_rpd": "rpd", "vc_guerilla_rpg": "rpg2",
}
## Clips code calls straight, outside the intent funnel.
const DIRECT_CALLS: Array[String] = ["laying_breathless"]


func _initialize() -> void:
	var units: Array[String] = ModelActor.all_units()
	if units.is_empty():
		quit(1)
		return
	units.sort()
	for unit in units:
		await _audit(unit)
	quit(0)


func _audit(unit: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		print("\n=== %s: SETUP FAILED ===" % unit)
		holder.queue_free()
		return
	var weapon: String = str(UNIT_WEAPON.get(unit, ""))
	var have: Dictionary = {}
	for c in model.clip_names():
		have[String(c)] = true
	print("\n=== %s (%s, %d clips) ===" % [unit, weapon, have.size()])
	var demanded: Dictionary = {}
	var gaps: int = 0
	for intent in SpriteStateMap.MODEL_CLIP.keys():
		var asked: String = SpriteStateMap.clip_for(true, "", unit, weapon, str(intent))
		var base: String = asked.split("__")[0]
		var ok: bool = model.play(asked, true)
		var actual: String = model.current_action if ok else "-"
		demanded[base] = true
		demanded[actual] = true
		if not ok:
			gaps += 1
			print("  GAP   %-14s -> %s: NOTHING PLAYS" % [intent, asked])
		elif actual != base and actual != asked:
			print("  ALIAS %-14s -> %s: plays '%s'" % [intent, asked, actual])
	for clip in DIRECT_CALLS:
		var ok2: bool = model.play(clip, true)
		demanded[clip] = true
		if ok2:
			demanded[model.current_action] = true
		else:
			gaps += 1
			print("  GAP   direct call     -> %s: NOTHING PLAYS" % clip)
	var unused: Array[String] = []
	for c in have.keys():
		var cs: String = String(c)
		# death*/walk_*/turn variants get pulled by prefix searches and
		# locomotion - not orphans even when no intent names them.
		if not demanded.has(cs) and not cs.begins_with("death") \
				and not cs.begins_with("walk") and not cs.contains("turn"):
			unused.append(cs)
	unused.sort()
	if gaps == 0:
		print("  contract: CLEAN (%d unused clips: %s)" % [unused.size(), str(unused)])
	else:
		print("  contract: %d GAPS  (%d unused clips)" % [gaps, unused.size()])
	holder.queue_free()
