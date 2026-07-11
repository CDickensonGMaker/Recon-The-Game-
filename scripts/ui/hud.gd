## hud.gd - In-game heads-up display with bleed-out indicator
class_name HUD
extends CanvasLayer

## References to UI elements
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/TopRow/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/TopRow/HPBar/HPLabel
@onready var bleed_container: Control = $MarginContainer/VBoxContainer/TopRow/BleedContainer
@onready var bleed_label: Label = $MarginContainer/VBoxContainer/TopRow/BleedContainer/BleedLabel
@onready var weapon_label: Label = $MarginContainer/VBoxContainer/BottomRow/WeaponPanel/WeaponInfo/WeaponLabel
@onready var ammo_label: Label = $MarginContainer/VBoxContainer/BottomRow/WeaponPanel/WeaponInfo/AmmoLabel
@onready var mag_label: Label = $MarginContainer/VBoxContainer/BottomRow/WeaponPanel/WeaponInfo/MagLabel
@onready var grenade_label: Label = $MarginContainer/VBoxContainer/BottomRow/GrenadeLabel
@onready var medkit_label: Label = $MarginContainer/VBoxContainer/BottomRow/MedkitLabel
@onready var healing_bar: ProgressBar = $MarginContainer/VBoxContainer/HealingBar
@onready var crosshair: Control = $Crosshair
@onready var death_screen: Control = $DeathScreen
@onready var slot_indicator: Label = $MarginContainer/VBoxContainer/BottomRow/SlotIndicator
@onready var action_progress: ActionProgress = $ActionProgress

## When true, GameFlow owns death UX (fail-forward debrief) - hide restart UI.
var managed_by_flow: bool = false

## Player references
var health_system: HealthSystem
var weapon_holder: WeaponHolder
var equipment_manager: EquipmentManager
var grenade_handler: GrenadeHandler

## Bleed flash effect
var bleed_flash_timer: float = 0.0

## "HOLD [F] TO PATCH UP" - shown while the medkit is out and idle
var _heal_prompt: Label = null

func _ready() -> void:
	death_screen.visible = false
	healing_bar.visible = false
	if bleed_container:
		bleed_container.visible = false
	add_to_group("combat_hud")  # R96: photo mode hides this


func _process(delta: float) -> void:
	# Flash bleed warning
	if health_system and health_system.is_bleeding:
		bleed_flash_timer += delta * 4.0
		var flash := (sin(bleed_flash_timer) + 1.0) / 2.0
		if bleed_label:
			bleed_label.modulate = Color(1.0, flash * 0.3, flash * 0.3)


func setup(hp: HealthSystem, wpn: WeaponHolder, equip: EquipmentManager, gren: GrenadeHandler) -> void:
	health_system = hp
	weapon_holder = wpn
	equipment_manager = equip
	grenade_handler = gren

	# Connect signals
	health_system.health_changed.connect(_on_health_changed)
	health_system.health_pack_changed.connect(_on_health_pack_changed)
	health_system.died.connect(_on_player_died)
	if weapon_holder.has_signal("target_hit"):
		weapon_holder.target_hit.connect(_on_target_hit)
	health_system.healing_started.connect(_on_healing_started)
	health_system.healing_progress.connect(_on_healing_progress)
	health_system.healing_interrupted.connect(_on_healing_stopped)
	health_system.healing_finished.connect(_on_healing_stopped)
	health_system.bleeding_started.connect(_on_bleeding_started)
	health_system.bleeding_progress.connect(_on_bleeding_progress)
	health_system.bleeding_stopped.connect(_on_bleeding_stopped)

	# Medkit affordance (r4bk law: no prompt = the feature doesn't exist).
	equipment_manager.slot_changed.connect(_on_slot_changed_prompt)
	_heal_prompt = Label.new()
	_heal_prompt.text = "HOLD [F] TO PATCH UP"
	_heal_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_heal_prompt.position = Vector2(-120, -140)
	_heal_prompt.add_theme_font_size_override("font_size", 18)
	_heal_prompt.add_theme_color_override("font_color", Color(0.85, 0.95, 0.8, 0.95))
	_heal_prompt.visible = false
	add_child(_heal_prompt)

	weapon_holder.magazine_changed.connect(_on_magazine_changed)
	weapon_holder.weapon_switched.connect(_on_weapon_switched)
	weapon_holder.weapon_jammed.connect(_on_weapon_jammed)   # R09 emitted this into the void
	weapon_holder.reload_started.connect(_on_reload_started)
	weapon_holder.reload_progress.connect(_on_reload_progress)
	weapon_holder.weapon_reloaded.connect(_on_reload_finished)
	weapon_holder.switch_started.connect(_on_switch_started)
	weapon_holder.switch_progress.connect(_on_switch_progress)

	equipment_manager.slot_changed.connect(_on_slot_changed)
	equipment_manager.grenade_count_changed.connect(_on_grenade_count_changed)

	# Initialize display
	_on_health_changed(health_system.current_hp, health_system.max_hp)
	_on_health_pack_changed(health_system.health_packs)
	_on_grenade_count_changed(equipment_manager.grenade_count)
	_on_magazine_changed(weapon_holder.current_ammo, weapon_holder.spare_magazines)
	_update_weapon_display()
	_update_slot_display()


func _on_health_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [current, maximum]

	# Color code based on health
	if current <= maximum * 0.25:
		hp_bar.modulate = Color.RED
	elif current <= maximum * 0.5:
		hp_bar.modulate = Color.YELLOW
	else:
		hp_bar.modulate = Color.GREEN


func _on_health_pack_changed(count: int) -> void:
	medkit_label.text = "MED: %d" % count


func _on_magazine_changed(current_ammo: int, spare_mags: int) -> void:
	ammo_label.text = "%d" % current_ammo
	mag_label.text = "MAG: %d" % spare_mags


func _on_weapon_switched(_weapon_data: WeaponData) -> void:
	_update_weapon_display()
	if action_progress:
		action_progress.finish_action()


func _update_weapon_display() -> void:
	if weapon_holder and weapon_holder.current_weapon:
		weapon_label.text = weapon_holder.current_weapon.display_name.to_upper()


func _on_slot_changed(_slot_index: int, _slot_type: Enums.SlotType) -> void:
	_update_slot_display()


func _update_slot_display() -> void:
	if not equipment_manager:
		return

	var slot := equipment_manager.get_current_slot()
	var slot_names := ["1:PRIMARY", "2:SIDEARM", "3:GRENADE", "4:MEDKIT"]
	slot_indicator.text = slot_names[slot]


func _on_grenade_count_changed(count: int) -> void:
	grenade_label.text = "GREN: %d" % count


func _on_slot_changed_prompt(_slot_index: int, slot_type: Enums.SlotType) -> void:
	if _heal_prompt == null:
		return
	var packs: int = health_system.health_packs if health_system else 0
	_heal_prompt.text = "HOLD [F] TO PATCH UP  (x%d)" % packs
	_heal_prompt.visible = slot_type == Enums.SlotType.MEDKIT and packs > 0


func _on_healing_started() -> void:
	if _heal_prompt:
		_heal_prompt.visible = false
	healing_bar.visible = true
	healing_bar.value = 0
	if action_progress:
		action_progress.start_action(ActionProgress.ActionType.HEAL)


func _on_healing_progress(percent: float) -> void:
	healing_bar.value = percent * 100
	if action_progress:
		action_progress.update_progress(percent)


func _on_healing_stopped() -> void:
	if _heal_prompt and equipment_manager and equipment_manager.get_current_slot_type() == Enums.SlotType.MEDKIT \
			and health_system and health_system.health_packs > 0:
		_heal_prompt.text = "HOLD [F] TO PATCH UP  (x%d)" % health_system.health_packs
		_heal_prompt.visible = true
	healing_bar.visible = false
	if action_progress:
		action_progress.finish_action()


## R09: the jam roll fired but the HUD never said so - the round simply did not
## leave and the player had no idea why. A dry click + the reload ring is the
## tell that it is a jam, not an empty mag.
func _on_weapon_jammed() -> void:
	GunFX.play_click(self)
	if action_progress:
		action_progress.start_action(ActionProgress.ActionType.RELOAD)


func _on_reload_started() -> void:
	if action_progress:
		action_progress.start_action(ActionProgress.ActionType.RELOAD)


func _on_reload_progress(percent: float) -> void:
	if action_progress:
		action_progress.update_progress(percent)


func _on_reload_finished() -> void:
	if action_progress:
		action_progress.finish_action()


func _on_switch_started() -> void:
	if action_progress:
		action_progress.start_action(ActionProgress.ActionType.SWITCH)


func _on_switch_progress(percent: float) -> void:
	if action_progress:
		action_progress.update_progress(percent)


func _on_bleeding_started(_bleed_time: float) -> void:
	if bleed_container:
		bleed_container.visible = true
	bleed_flash_timer = 0.0


func _on_bleeding_progress(time_remaining: float) -> void:
	if bleed_label:
		bleed_label.text = "BLEEDING OUT: %.1fs" % time_remaining


func _on_bleeding_stopped() -> void:
	if bleed_container:
		bleed_container.visible = false


## W38: hitmarker - brief X at the crosshair + audio tick (deeper on kill).
var _hitmarker: Label = null


func _on_target_hit(killed: bool, headshot: bool = false) -> void:
	if _hitmarker == null:
		_hitmarker = Label.new()
		_hitmarker.add_theme_font_size_override("font_size", 26)
		_hitmarker.set_anchors_preset(Control.PRESET_CENTER)
		_hitmarker.position += Vector2(8, -14)
		add_child(_hitmarker)
	# Distinct read per outcome: kill = red X, headshot = yellow bigger, hit = white.
	var col: Color
	var size: int
	if killed:
		_hitmarker.text = "X"; col = Color(1, 0.25, 0.15); size = 34
	elif headshot:
		_hitmarker.text = "x"; col = Color(1.0, 0.85, 0.2); size = 32
	else:
		_hitmarker.text = "x"; col = Color(1, 1, 1, 0.9); size = 26
	_hitmarker.add_theme_font_size_override("font_size", size)
	_hitmarker.add_theme_color_override("font_color", col)
	_hitmarker.modulate.a = 1.0
	_hitmarker.scale = Vector2(1.4, 1.4) if killed else Vector2.ONE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_hitmarker, "modulate:a", 0.0, 0.28)
	tween.tween_property(_hitmarker, "scale", Vector2.ONE, 0.15)
	var tick := AudioStreamPlayer.new()
	tick.stream = GunFX.IMPACT_HARD
	tick.volume_db = -6.0 if (killed or headshot) else -9.0
	tick.pitch_scale = 0.65 if killed else (1.7 if headshot else 1.4)
	add_child(tick)
	tick.play()
	tick.finished.connect(tick.queue_free)


func _on_player_died() -> void:
	if managed_by_flow:
		# GameFlow routes death to the debrief (fail-forward); no restart UI.
		if bleed_container:
			bleed_container.visible = false
		return
	death_screen.visible = true
	if bleed_container:
		bleed_container.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_restart_pressed() -> void:
	if managed_by_flow:
		return
	death_screen.visible = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()
