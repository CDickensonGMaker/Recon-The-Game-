## probe_surface_cache.gd - proves the surface weapons_cache is now a live Destructible in
## the SHIPPING demo world (Q2b, his ruling 2026-08-28). Before this it was a plain
## StaticBody3D with no HP_FOR entry, so "destroy the stash" only existed underground.
## Run: godot --headless --path . res://tests/probe_surface_cache.tscn
extends Node


func _ready() -> void:
	print("=== SURFACE WEAPONS CACHE PROBE (Q2b) ===")
	print("HP_FOR has weapons_cache: %s (%d)" % [
		Destructible.HP_FOR.has("weapons_cache"), Destructible.hp_for("weapons_cache")])
	print("BLAST_FOR has weapons_cache: %s (%s)" % [
		Destructible.BLAST_FOR.has("weapons_cache"), Destructible.blast_for("weapons_cache")])
	print("site_planner maps the model: %s"
		% str(SitePlanner.PLACED_DESTRUCTIBLE_KINDS.get("weapons_cache", "<NONE>")))
	var ok: bool = Destructible.HP_FOR.has("weapons_cache") 		and Destructible.BLAST_FOR.has("weapons_cache") 		and str(SitePlanner.PLACED_DESTRUCTIBLE_KINDS.get("weapons_cache", "")) != ""
	print("=== %s ===" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
