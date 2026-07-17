## hitzone_tuning.gd - per-unit hitzone overrides, authored in the hitzone
## bench (hitzone_editor.bat -> Ctrl+S) and consumed by HitzoneBuilder.
## Keyed by region (HEAD/BODY/GUT + ARM/LEG x L/R x _UP/_LO); each value is a
## Dictionary that may carry:
##   "offset": Vector3   - added to the zone's bone offset (zone-space)
##   "rotation": Vector3 - degrees, composed on the joint-line basis
##   "inflate": float    - hull zones: outward margin in meters
##   "radius"/"height": float - capsule-fallback zones only
##   "damage": float     - zone damage multiplier vs ADR-016 default
##   "fatal": bool       - overrides HEAD-fatal law (ADR-016 Amendment B)
## Absent keys keep the mesh-measured / values-of-record defaults - the bench only
## writes what was actually nudged.
class_name HitzoneTuning
extends Resource

@export var zones: Dictionary = {}
