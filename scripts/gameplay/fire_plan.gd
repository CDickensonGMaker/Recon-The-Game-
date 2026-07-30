## fire_plan.gd - the one table of what a fire mission covers.
##
## Every sheaf, blast and pattern figure in the fire-support chain lives HERE, and
## the weapons read them from here: field_director's shells, cas_airplane's drops,
## the Spectre's beaten zone. The footprint the player places on the ground is
## computed from the same constants that do the killing, so the preview cannot
## drift away from the ordnance. Retune a number and the ring moves with it.
##
## Nothing in this file may reference FieldDirector, CASAirplane or SpectreGunship -
## the dependency runs one way, consumers -> table.
class_name FirePlan

## Indirect fire, in METRES. SHEAF is how far a round strays from the aim point
## before fo_fac tightens it; SPOT is the wider ranging shot; BLAST is the kill.
const MORTAR_SHEAF_M: float = 8.0
const MORTAR_SPOT_M: float = 15.0
const MORTAR_BLAST_M: float = 10.0
const ARTY_SHEAF_M: float = 18.0
const ARTY_BLAST_M: float = 14.0

## Air-delivered.
const BOMB_BLAST_M: float = 16.0
const NAPALM_DROPS: int = 5
const NAPALM_SPACING: float = 15.0
const NAPALM_BLAST_M: float = 10.0
const NAPALM_BURN_S: float = 15.0
const CBU_BOMBLETS: int = 16
const CBU_SPREAD: float = 22.0
## The cluster pattern is an ellipse laid ALONG the run; this is its cross-run axis.
const CBU_CROSS_FRAC: float = 0.6
const CBU_BOMBLET_BLAST_M: float = 5.0

## Gunship.
const SPECTRE_BEATEN_M: float = 25.0
const SPECTRE_VULCAN_KILL_M: float = 4.0

## fo_fac tightens every sheaf the same way: 1.0 in a green radioman's hands,
## 0.45 in a veteran's. A better RTO draws a smaller circle, and the player sees it.
static func sheaf_scale(fo: int) -> float:
	return lerpf(1.0, 0.45, clampf(float(fo) / 8.0, 0.0, 1.0))


## What this call covers on the ground.
##   shape:  "circle" | "rect" | "ellipse"
##   radius: circles only
##   along / across: the run-aligned pair, for rect and ellipse
## `along` runs down the aircraft's line of flight.
static func footprint(kind: String, fo: int = 0) -> Dictionary:
	var scat: float = sheaf_scale(fo)
	match kind:
		"mortar":
			return _circle(MORTAR_SHEAF_M * scat + MORTAR_BLAST_M, "MORTAR")
		"arty":
			return _circle(ARTY_SHEAF_M * scat + ARTY_BLAST_M, "ARTILLERY")
		"bombs":
			return _circle(BOMB_BLAST_M, "SNAKE EYE")
		"spectre":
			return _circle(SPECTRE_BEATEN_M + SPECTRE_VULCAN_KILL_M, "SPECTRE")
		"napalm":
			return {
				"shape": "rect",
				"radius": 0.0,
				"along": float(NAPALM_DROPS - 1) * NAPALM_SPACING + 2.0 * NAPALM_BLAST_M,
				"across": 2.0 * NAPALM_BLAST_M,
				"label": "NAPALM",
			}
		"cbu":
			return {
				"shape": "ellipse",
				"radius": 0.0,
				"along": 2.0 * (CBU_SPREAD + CBU_BOMBLET_BLAST_M),
				"across": 2.0 * (CBU_SPREAD * CBU_CROSS_FRAC + CBU_BOMBLET_BLAST_M),
				"label": "CLUSTER",
			}
	return {}


static func _circle(r: float, label: String) -> Dictionary:
	return {"shape": "circle", "radius": r, "along": r * 2.0, "across": r * 2.0, "label": label}


## Furthest reach of the footprint from its centre - what a danger-close test has
## to measure against, since a man just outside a napalm strip's mark is still
## inside the strip.
static func reach(kind: String, fo: int = 0) -> float:
	var fp: Dictionary = footprint(kind, fo)
	if fp.is_empty():
		return 0.0
	if String(fp.shape) == "circle":
		return float(fp.radius)
	return maxf(float(fp.along), float(fp.across)) * 0.5
