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
## A battery mission is a BARRAGE (decree 2026-08-04): 8-12 rounds, count drawn per call.
const ARTY_ROUNDS_MIN: int = 8
const ARTY_ROUNDS_MAX: int = 12

## Air-delivered.
const BOMB_BLAST_M: float = 16.0
const NAPALM_DROPS: int = 5
const NAPALM_SPACING: float = 15.0
const NAPALM_BLAST_M: float = 20.0
const NAPALM_BURN_S: float = 15.0
const CBU_BOMBLETS: int = 16
const CBU_SPREAD: float = 22.0
## The cluster pattern is an ellipse laid ALONG the run; this is its cross-run axis.
const CBU_CROSS_FRAC: float = 0.6
const CBU_BOMBLET_BLAST_M: float = 5.0
## The CBU is a RAID, not one bomb (decree 2026-08-04): several dispensers off the
## rack down the run line, each opening into its own bomblet ellipse.
const CBU_CANS: int = 3
const CBU_CAN_SPACING: float = 45.0

## Illumination: the circle the flare takes the dark away from.
const ILLUM_LIGHT_M: float = 180.0

## White phosphorus: a small barrage that leaves burning ground (decree 2026-08-04).
const WP_ROUNDS: int = 3
const WP_SPREAD_M: float = 10.0
const WP_BLAST_M: float = 8.0
const WP_BURN_M: float = 6.0
const WP_BURN_S: float = 12.0

## Gunship. The Vulcan fires real rounds through BulletSystem, so it no longer has a "kill
## radius" - it has DISPERSION, the slop around the aim point that widens the beaten zone
## on the map ring beyond the zone the aircraft is walking.
const SPECTRE_BEATEN_M: float = 25.0
const SPECTRE_DISPERSION_M: float = 4.0

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
			return _circle(SPECTRE_BEATEN_M + SPECTRE_DISPERSION_M, "SPECTRE")
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
				"along": float(CBU_CANS - 1) * CBU_CAN_SPACING + 2.0 * (CBU_SPREAD + CBU_BOMBLET_BLAST_M),
				"across": 2.0 * (CBU_SPREAD * CBU_CROSS_FRAC + CBU_BOMBLET_BLAST_M),
				"label": "CLUSTER",
			}
		"wp":
			return _circle(WP_SPREAD_M + WP_BLAST_M, "WILLY PETE")
		"illum":
			return _circle(ILLUM_LIGHT_M, "ILLUM")
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
