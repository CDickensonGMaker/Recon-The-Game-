## The armorer's bench: the rack, and the only place a rifle gets fully cleaned
## (ADR-018, Summoner's decree 2026-07-13). Press [interact] to open the bench menu;
## STRIP AND CLEAN takes BENCH_SECONDS to restore the carried weapon to 100. It
## cannot be done in the field - out there a repair kit buys you 25% and nothing more.
##
## ART GAP: the table is a placeholder BoxMesh. It needs a real bench model (bead).
class_name ArmorersBench
extends Node3D

const BENCH_SECONDS: float = 20.0
const INTERACT_RADIUS: float = 2.6

## The rack. A weapon belongs here only if it has a first-person arms viewmodel -
## m72_law, m79, rpg7 and m26_grenade have no arms model and cannot be carried as
## a primary. tests/test_bench_rack.gd holds this list to that rule.
const RACK: Array[String] = [
	"res://data/weapons/m16a1.tres",
	"res://data/weapons/m14.tres",
	"res://data/weapons/ak47.tres",
	"res://data/weapons/mosin.tres",
	"res://data/weapons/ppsh41.tres",
	"res://data/weapons/m60.tres",
	"res://data/weapons/rpd.tres",
	"res://data/weapons/m70.tres",
	"res://data/weapons/shotgun.tres",
	"res://data/weapons/m1911.tres",
	"res://data/weapons/rpg2.tres",
]

var _progress: float = 0.0
var _prompt: Label3D
var _menu: BenchMenu = null
var _cleaning: bool = false


func _ready() -> void:
	add_to_group("armorers_bench")
	_build_placeholder()
	_build_prompt()


## PLACEHOLDER. Replace with the authored bench model - see the art bead.
func _build_placeholder() -> void:
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.2, 0.08, 0.9)
	top.mesh = top_mesh
	top.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.27, 0.18)
	mat.roughness = 0.95
	top.material_override = mat
	add_child(top)

	for x: float in [-0.95, 0.95]:
		for z: float in [-0.35, 0.35]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.09, 0.86, 0.09)
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.43, z)
			leg.material_override = mat
			add_child(leg)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 0.94, 0.9)
	col.shape = box
	col.position = Vector3(0, 0.47, 0)
	body.add_child(col)
	add_child(body)


func _build_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.font_size = 26
	_prompt.pixel_size = 0.0035
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.95, 0.78, 0.42)
	_prompt.position = Vector3(0, 1.6, 0)
	_prompt.visible = false
	add_child(_prompt)


func _exit_tree() -> void:
	_close_menu()


func _physics_process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_close_menu()
		return
	var wh: WeaponHolder = player.get_node_or_null("Head/Camera3D/WeaponHolder") as WeaponHolder
	if wh == null:
		_close_menu()
		return

	if player.global_position.distance_to(global_position) > INTERACT_RADIUS:
		_prompt.visible = false
		_close_menu()
		return

	_prompt.visible = true

	if _menu != null:
		_tick_clean(wh, delta)
		if Input.is_action_just_pressed("interact"):
			_close_menu()
		return

	_prompt.text = "ARMORER'S BENCH  %d%%\nPRESS [F]" % int(wh.weapon_condition)
	if Input.is_action_just_pressed("interact"):
		_open_menu(wh)


func _open_menu(wh: WeaponHolder) -> void:
	if _menu != null:
		return
	_progress = 0.0
	_cleaning = false
	_menu = BenchMenu.new()
	add_child(_menu)
	var carried: String = wh.primary_weapon.id if wh.primary_weapon != null else ""
	_menu.build(RACK, carried, wh.weapon_condition)
	_menu.weapon_chosen.connect(func(path: String) -> void: _draw_from_rack(wh, path))
	_menu.clean_requested.connect(func() -> void: _cleaning = true)
	_menu.close_requested.connect(_close_menu)
	GameManager.is_in_menu = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close_menu() -> void:
	if _menu == null:
		return
	_menu.queue_free()
	_menu = null
	_cleaning = false
	_progress = 0.0
	GameManager.is_in_menu = false
	if not GameManager.is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## The 20-second strip. It cleans the weapon IN HAND; a racked weapon keeps its
## fouling until you draw it and work on it.
func _tick_clean(wh: WeaponHolder, delta: float) -> void:
	if not _cleaning:
		return
	_progress += delta / BENCH_SECONDS
	if _progress < 1.0:
		if _menu != null:
			_menu.set_clean_progress(int(_progress * 100.0))
		return
	_progress = 0.0
	_cleaning = false
	wh.weapon_condition = 100.0
	wh.refresh_after_load()
	if wh.primary_weapon != null:
		CampaignState.store_rack_condition(wh.primary_weapon.id, 100.0)
	if _menu != null:
		_menu.set_condition(100.0)


## Rack what he carries, draw what he picked. The outgoing weapon keeps its
## fouling on the rack, so cycling weapons can never launder a dirty rifle.
func _draw_from_rack(wh: WeaponHolder, tres_path: String) -> void:
	if _cleaning:
		return
	var data: WeaponData = load(tres_path) as WeaponData
	if data == null:
		push_error("[ArmorersBench] rack entry will not load: %s" % tres_path)
		return
	if wh.primary_weapon != null:
		if wh.primary_weapon.id == data.id:
			return
		CampaignState.store_rack_condition(wh.primary_weapon.id, wh.weapon_condition)

	var ammo: Array[int] = [data.magazine_size, 4]
	wh.primary_weapon = data
	wh.primary_ammo = ammo
	wh.primary_is_captured = false
	wh.weapon_condition = CampaignState.rack_condition_of(data.id)
	wh.is_jammed = false
	wh.refresh_after_load()

	if _menu != null:
		_menu.mark_carried(data.id, RACK)
		_menu.set_condition(wh.weapon_condition)
