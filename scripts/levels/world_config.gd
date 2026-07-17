## world_config.gd - Single tuning point for AO generation + performance.
## PERF QUALITY LADDER: VEGETATION_DENSITY_MULT scales grass/tree candidate counts.
## Manual quality dial for now (edit + reboot). Weak-GPU rung: VEGETATION_DENSITY_MULT
## 0.6, then MAP_SIZE 1024. NOTE: primitive/draw-call count is NOT the jungle's
## bottleneck (measured — bead t5mo); render scale + renderer are the real FPS levers.
class_name WorldConfig
extends RefCounted

const MAP_SIZE: float = 1280.0
const CHUNK_SIZE: float = 256.0
const CELL_SIZE: float = 4.0
const LOAD_DISTANCE: int = 2
const UNLOAD_DISTANCE: int = 3

## Vegetation tuning (1.0 = TerrainEngine defaults).
const VEGETATION_DENSITY_MULT: float = 1.0

## Water
const SEA_LEVEL: float = 15.0
const OCEAN_EDGES: int = 0b0000  # inland AO

## Debug
const LOG_FPS: bool = true
const FPS_LOG_INTERVAL: float = 2.0


## Perf escape hatch, rung 0: set false and NavBaker is never constructed, no
## NavigationRegion3D exists, and _move_toward() falls back to direct steer.
const NAV_ENABLED: bool = true
const NAV_SITE_KINDS: Array[String] = ["village", "firebase", "aa_site", "outpost", "temple", "pow_camp"]
