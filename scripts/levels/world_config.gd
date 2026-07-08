## world_config.gd - Single tuning point for AO generation + performance.
## NS04 perf-gate fallback ladder: if FPS < 30 sustained ->
##   1) VEGETATION_DENSITY_MULT 0.6   2) MAP_SIZE 1024 + BILLBOARD_DISTANCE_MULT 0.7
class_name WorldConfig
extends RefCounted

const MAP_SIZE: float = 1280.0
const CHUNK_SIZE: float = 256.0
const CELL_SIZE: float = 4.0
const LOAD_DISTANCE: int = 2
const UNLOAD_DISTANCE: int = 3

## Vegetation tuning (1.0 = TerrainEngine defaults).
const VEGETATION_DENSITY_MULT: float = 1.0
const BILLBOARD_DISTANCE_MULT: float = 1.0

## Water
const SEA_LEVEL: float = 15.0
const OCEAN_EDGES: int = 0b0000  # inland AO

## Debug
const LOG_FPS: bool = true
const FPS_LOG_INTERVAL: float = 2.0
