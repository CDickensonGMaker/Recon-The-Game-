## demo_game.gd - DEMO GAME: the 20-minute firebase-attack slice
## (War Room 2026-07-29, production/war_room/2026-07-29_demo_slice/).
##
## Boots the REAL flow (GameFlow.demo_mode -> plan_demo_world on a 512m map) -
## one world-build path, never a parallel copy (ADR-028). This scene owns only
## the SWITCHBOARD and the ARC CLOCK.
##
## Determinism honesty: layout and arc are seed-fixed; ambient positioners
## (AmbientWar, AirTraffic, hunter spawns) roll their own RNG, so moment-to-
## moment life varies between boots by design.
class_name DemoGame
extends Node

const DEMO_SEED: int = 29072026
const DEMO_NAME := "FIREBASE HOLDOUT"

## ---- THE SWITCHBOARD (skip-only: it may EXCLUDE systems, never fork them; a
## flag flipped true prints at boot so an excluded system is never a mystery) --
const EXCLUDE_SAVES := true          ## campaign writes go to a sandbox file
const EXCLUDE_DEBRIEF := true        ## death/dawn -> end card, no AAR screen
const EXCLUDE_AIR_TRAFFIC := false
const EXCLUDE_AMBIENT_WAR := false

## ---- THE ARC (seconds; pacing knobs for the Summoner's playtest) ----
## dusk arrival -> explore window -> probing attack -> main siege -> dawn card.
const PROBE_AT_S: float = 600.0      ## minute 10: a probe finds the wire
const SIEGE_AT_S: float = 720.0      ## minute 12: the d50 night assault
const DAWN_AT_S: float = 1080.0      ## minute 18: it breaks; card at ~20
const PROBE_STRENGTH: int = 11
const SIEGE_STRENGTH: int = 40

var _flow: GameFlow = null
var _clock: float = 0.0
var _phase: int = 0   ## 0 explore, 1 probed, 2 siege, 3 dawn


func _ready() -> void:
	for x in [["saves", EXCLUDE_SAVES], ["debrief", EXCLUDE_DEBRIEF],
			["air_traffic", EXCLUDE_AIR_TRAFFIC], ["ambient_war", EXCLUDE_AMBIENT_WAR]]:
		if x[1]:
			print("[DEMO] EXCLUDED: %s" % x[0])
	if EXCLUDE_SAVES:
		CampaignState.save_path = "user://campaign_demo.cfg"
	GameFlow.demo_mode = true
	_flow = GameFlow.new()
	add_child(_flow)
	_flow._begin_operation(DEMO_SEED, DEMO_NAME)
	print("[DEMO] booted seed %d, %dm slice, arc probe@%ds siege@%ds dawn@%ds" % [
		DEMO_SEED, int(GameFlow.DEMO_MAP_SIZE), int(PROBE_AT_S), int(SIEGE_AT_S), int(DAWN_AT_S)])


func _exit_tree() -> void:
	GameFlow.demo_mode = false   # never leak demo state into a normal boot
	if EXCLUDE_SAVES:
		CampaignState.save_path = CampaignState.DEFAULT_SAVE_PATH


func _physics_process(delta: float) -> void:
	if _flow == null or _flow.director == null:
		return
	_clock += delta
	match _phase:
		0:
			if _clock >= PROBE_AT_S:
				_phase = 1
				_open_siege(PROBE_STRENGTH, "PROBE ON THE WIRE")
		1:
			if _clock >= SIEGE_AT_S:
				_phase = 2
				_open_siege(SIEGE_STRENGTH, "HERE THEY COME")
		2:
			if _clock >= DAWN_AT_S:
				_phase = 3
				_dawn()


func _open_siege(strength: int, toast: String) -> void:
	var d: FieldDirector = _flow.director
	if d.siege == null:
		d._attach_siege()   # idempotent; needs fsb_center, which the build set
	if d.siege != null:
		# Slice-scale assault geometry: the kilometer-AO defaults spawn cells
		# OFF the 512m map (fsb center is only 256m from every edge).
		d.siege.ring_min = 190.0
		d.siege.ring_max = 235.0
		d.siege.rally_m = 150.0
		d.siege.mortar_standoff_m = 170.0
		d.siege.cell_materialize_m = minf(d.siege.cell_materialize_m, 220.0)
	if d.siege == null:
		print("[DEMO] no siege director - phase skipped")
		return
	if d.siege.active:
		# The probe is still running its ADR-036 chain - let it escalate rather
		# than re-opening on top of the ledger (council flag: double open_siege
		# coherence is unverified).
		d.toast.emit(toast)
		print("[DEMO] phase %d: siege already active, toast only" % _phase)
		return
	d.siege.open_siege(strength)
	d.toast.emit(toast)
	print("[DEMO] phase %d: open_siege(%d) at %.0fs" % [_phase, strength, _clock])


func _dawn() -> void:
	print("[DEMO] dawn at %.0fs - end card" % _clock)
	var d: FieldDirector = _flow.director
	d.toast.emit("DAWN. YOU HELD.")
	# End card: the named men who held with you (mitigates the cut debrief -
	# the squad's long arc is the demo's biggest sacrifice, per the council).
	var card := ReconUI.make_screen_root()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(ReconUI.make_label("FIREBASE HELD", 30, ReconUI.AMBER))
	if _flow.squad != null:
		for a in _flow.squad.members:
			if a == null or not is_instance_valid(a):
				continue
			var status := "KIA" if a.is_dead() else "HELD"
			col.add_child(ReconUI.make_label(
				"%s - %s" % [str(a.member.get("name", "?")), status], 16,
				ReconUI.DIM if a.is_dead() else ReconUI.AMBER))
	col.add_child(ReconUI.make_label("RECON - DEMO", 13, ReconUI.DIM))
	cc.add_child(col)
	card.add_child(cc)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	layer.add_child(card)
