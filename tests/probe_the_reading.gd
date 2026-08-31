## probe_the_reading.gd - WHICH PATH READS THE DEAD, measured (Summoner ruling 2026-08-30:
## "lets have the sleep be a post launch idea").
##
## Sleep was made the one ceremony on 2026-08-28. Parking it post-launch would have left the
## campaign banking nothing and naming nobody, which his 8/28 ruling ("game will read the dead
## roster at the end of the play") forbids. This probe proves, by counting the toasts the
## ceremony actually emits, that EXACTLY ONE reading fires per path:
##   DEMO      - dawn, when the siege ends (_on_siege_ended).
##   CAMPAIGN  - the wire bank (_poll_wire_gate inbound -> _bank_patrol).
##   Sleep     - dormant: the rack offers no verb at all.
extends Node

const SLEEP_STATION := preload("res://scripts/world/sleep_station.gd")

var _toasts: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var ok: bool = true
	ok = _t1_dormant() and ok
	ok = _t2_campaign_wire_reads() and ok
	ok = _t3_demo_dawn_reads() and ok
	print("[READPROBE] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _say(name_: String, cond: bool, detail: String) -> bool:
	print("[READPROBE] %s %s - %s" % ["PASS" if cond else "FAIL", name_, detail])
	return cond


func _on_toast(t: String) -> void:
	_toasts.append(t)


## Names spoken by the last ceremony - the "  NAME" lines _read_the_dead emits.
func _named() -> Array[String]:
	var out: Array[String] = []
	for t in _toasts:
		if t.begins_with("  "):
			out.append(t.strip_edges())
	return out


func _director() -> FieldDirector:
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")
	d.fsb_center = Vector3.ZERO
	d.patrol_gate_pos = Vector3(0, 0, 40)
	d.toast.connect(_on_toast)
	return d


## 1. The rack is dormant: no verb, no refusal line, nothing on the HUD.
func _t1_dormant() -> bool:
	# Stand him EXACTLY on the rack, so a pass cannot come from being nowhere near one.
	GameFlow.player_rack = Vector3(10, 0, 10)
	var p := CharacterBody3D.new()
	add_child(p)
	p.global_position = GameFlow.player_rack
	var at: bool = SLEEP_STATION.at_rack(p)
	var prompt: String = SLEEP_STATION.prompt(p)
	var refusal: String = SLEEP_STATION.refusal(p)
	var can: bool = SLEEP_STATION.can_sleep(p)
	p.queue_free()
	GameFlow.player_rack = Vector3.ZERO
	var pass_: bool = FieldDirector.SLEEP_POST_LAUNCH and at and prompt.is_empty() 		and not refusal.is_empty() and not can
	return _say("sleep dormant", pass_,
		"SLEEP_POST_LAUNCH=%s, at_rack=%s, prompt=\"%s\", refusal=\"%s\", can_sleep=%s" % [
			FieldDirector.SLEEP_POST_LAUNCH, at, prompt, refusal, can])


## 2. CAMPAIGN: walking back through the wire banks the run and speaks the names, once.
func _t2_campaign_wire_reads() -> bool:
	GameFlow.demo_mode = false
	var d: FieldDirector = _director()
	var w := GameWorld.new()
	var p := CharacterBody3D.new()
	add_child(p)
	w.player = p
	d.world = w
	d.patrol_out = true
	d.patrol_count = 1
	d.state.flags["squad_kia"] = ["PFC HALVORSEN", "SGT REYES"]
	var banked_before: int = CampaignState.missions_played

	_toasts.clear()
	p.global_position = Vector3.ZERO  # inside the wire
	d._poll_wire_gate()
	var first: Array[String] = _named()
	var banked: bool = CampaignState.missions_played > banked_before

	# And it does not read them a second time on the next walk-out/walk-in.
	_toasts.clear()
	d.patrol_out = true
	d._poll_wire_gate()
	var second: Array[String] = _named()

	d.queue_free()
	w.free()
	p.queue_free()
	var pass_: bool = first.size() == 2 and second.is_empty() and banked
	return _say("campaign wire read", pass_,
		"wire-inward named %s (banked=%s), second crossing named %s" % [
			str(first), banked, str(second)])


## 3. DEMO: the siege ending at dawn is the reading, and it is untouched.
func _t3_demo_dawn_reads() -> bool:
	GameFlow.demo_mode = true
	var d: FieldDirector = _director()
	d.state.flags["squad_kia"] = ["CPL VOSS"]
	_toasts.clear()
	d._on_siege_ended("broken", 30, 45)
	var named: Array[String] = _named()
	_toasts.clear()
	d._on_siege_ended("broken", 30, 45)
	var again: Array[String] = _named()
	d.queue_free()
	GameFlow.demo_mode = false
	var pass_: bool = named.size() == 1 and again.is_empty()
	return _say("demo dawn read", pass_,
		"siege end named %s, repeat named %s" % [str(named), str(again)])
