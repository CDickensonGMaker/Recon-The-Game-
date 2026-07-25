## skill_catalog.gd - RECON skill definitions + the learn-by-doing curve.
class_name SkillCatalog
extends RefCounted

## skill_id -> {name, desc, max}
const SKILLS := {
	"small_arms": {"name": "SMALL ARMS", "desc": "Tighter spread with all small arms", "max": 8},
	"medic": {"name": "MEDIC", "desc": "Faster revives, more HP restored", "max": 8},
	"detect_ambush": {"name": "DETECT AMBUSH", "desc": "Point man warning radius", "max": 8},
	"demolitions": {"name": "DEMOLITIONS", "desc": "Faster, surer charge planting", "max": 8},
	"fo_fac": {"name": "FO/FAC", "desc": "Faster air support turnaround", "max": 8},
	"silent_movement": {"name": "SILENT MOVEMENT", "desc": "Quieter footsteps", "max": 8},
	"sniping": {"name": "SNIPING", "desc": "Long-range accuracy bonus", "max": 8},
}

## Learn-by-doing curve: cumulative use-points to REACH each level.
## Index = level; L0 is free. ~2-3 missions to L3, ~15+ to L8. Grind is blocked by
## structure (finite enemies, revive cap), not by this table.
const USE_THRESHOLDS: Array[int] = [0, 10, 25, 45, 70, 105, 155, 225, 320]


## Cumulative use-points required to reach `level` (clamped to the curve).
static func uses_for_level(level: int) -> int:
	if level <= 0:
		return 0
	if level >= USE_THRESHOLDS.size():
		return USE_THRESHOLDS[USE_THRESHOLDS.size() - 1]
	return USE_THRESHOLDS[level]

## MOS -> the skill that role consumes. These belong to SQUADMATES only (ADR-018 s2):
## silent, behavioural, learned by doing. The player owns none of them.
const MOS_SKILL := {
	"POINTMAN": "detect_ambush",
	"RTO": "fo_fac",
	"MEDIC": "medic",
	"MG": "small_arms",
	"GRENADIER": "demolitions",
	"MARKSMAN": "sniping",
	"RIFLEMAN": "small_arms",
}

