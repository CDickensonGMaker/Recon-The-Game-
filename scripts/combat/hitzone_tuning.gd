## hitzone_tuning.gd - per-unit hitzone overrides, authored in the hitzone
## bench (hitzone_editor.bat -> Ctrl+S) and consumed by HitzoneBuilder.
## Keyed by region (HEAD/BODY/GUT/ARM_L/ARM_R/LEG_L/LEG_R); each value is a
## Dictionary that may carry "radius": float, "height": float,
## "offset": Vector3 (added to the zone's bone offset),
## "damage": float (zone damage multiplier, replaces the ADR-016 default),
## "fatal": bool (overrides HEAD-fatal law; ADR-016 Amendment B). Absent keys
## keep the bone-measured / values-of-record defaults - the bench only writes
## what Caleb actually nudged.
class_name HitzoneTuning
extends Resource

@export var zones: Dictionary = {}
