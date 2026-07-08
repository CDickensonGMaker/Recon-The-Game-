# RECONgame - Claude Development Guidelines

**RECONgame** is a hardcore Vietnam War mission-based tactical FPS (Godot 4.5+/4.6, GDScript): randomized insertion → 2–4 generated objectives in an open AO → exfil. Arma/OFP sandbox bones, SOCOM/Vietcong flavor, RECON RPG (1982) rules backbone, HLL lethality, AI fireteam, 8-directional billboard sprite characters (CULTIC-style).

**Read these before designing anything:**
- `DESIGN.md` — vision, pillars, game loop, system specs, M0–M8 roadmap (APPROVED)
- `STATE_OF_PROJECT.md` — origins (merged from HellOfDuty + TerrainEngine copies), decisions log
- `MISSION_DESIGN_RESEARCH.md` — RTCW/MoHAA-derived mission/AI architecture
- `RECON_ADAPTATION.md` — tabletop rules → real-time mappings (damage dice, detection, XP scoring)

**Pillars (test every decision):** 1. Outstanding gunplay · 2. Atmosphere · 3. Freedom (no rails, stealth optional, escalation not fail-states) · 4. The squad is the RPG · 5. Fail forward.

**Origins:** `scripts/`, `scenes/`, `assets/`, `data/` = Hell of Duty FPS core (copied; HellOfDuty project untouched). `terrain/` = TerrainEngine copy (res:// paths remapped to res://terrain/; original project untouched). RTS assets (structures, weapon data, unit data) get copied in from `C:\Users\caleb\RealVietnamRTS` as needed — never edit that project from here.

## Architecture Patterns (Quake 3/Spearmint Inspired)

### Core Principles
- **Tactical, deadly combat** - 1-2 shots to kill, player must be strategic
- **No armor pickups** - Fast and lethal, not arcade-style
- **Goal-driven AI** - Enemies make tactical decisions, not just react

### Key Patterns Implemented

#### 1. Timestep Capping (Framerate Independence)
```gdscript
# In _physics_process:
var capped_delta: float = minf(delta, 0.066)  # Max 66ms like Quake 3
```

#### 2. Separate Think/Execute (AI)
```gdscript
# Think on schedule (6-7 Hz), execute every frame
const THINK_INTERVAL: float = 0.15
think_timer += delta
if think_timer >= THINK_INTERVAL:
    think_timer = 0.0
    _think()  # Goal evaluation, target finding
_execute(delta)  # Smooth movement and aiming
```

#### 3. Goal-Driven AI
Goals (high-level): `ENGAGE_TARGET`, `SEEK_COVER`, `FLANK_TARGET`, `ADVANCE`, `RETREAT`
States (low-level): `COMBAT`, `SEEKING_COVER`, `FLANKING`, `ADVANCING`

#### 4. Smooth Aim Interpolation
```gdscript
current_aim_dir = current_aim_dir.lerp(target_aim_dir, aim_speed * delta).normalized()
```

#### 5. Multi-Point Visibility (Explosions)
Check 8 points around target - if ANY point visible, explosion damages target.

#### 6. Suppression System
- Enemies have `suppression_level` (0-1)
- Sustained fire increases suppression
- High suppression forces cover-seeking behavior

## GDScript Strict Typing Rules

Godot 4.5 with strict typing enabled. Follow these rules to avoid type inference errors:

### 1. Float Interpolation
```gdscript
# GOOD
var mult: float = lerpf(1.0, 0.5, t)

# BAD - lerp() returns Variant
var mult := lerp(1.0, 0.5, t)
```

### 2. Float Min/Max
```gdscript
# GOOD
var val: float = minf(x, 1.0)
var val: float = maxf(0.0, x)

# BAD - min()/max() return Variant
var val := min(x, 1.0)
```

### 3. Integer Min/Max
```gdscript
# GOOD
var damage: int = maxi(1, calculated)
var clamped: int = mini(value, 100)

# BAD
var damage := max(1, calculated)
```

### 4. Method Returns That Could Be Variant
```gdscript
# GOOD - explicit types
var aim_dir: Vector3 = controller.get_aim_direction()
var target: Node = area.get_parent()
var hit_collider: Object = result.collider
var enemies: Array[Node] = get_nodes_in_group("enemies")

# BAD - can't infer type
var aim_dir := controller.get_aim_direction()
var target := area.get_parent()
var hit_collider := result.collider
```

### 5. Raycast Results
```gdscript
# GOOD
var result: Dictionary = space_state.intersect_ray(query)
if result:
    var hit_collider: Object = result.collider
    if hit_collider is Node and (hit_collider as Node).is_in_group("enemies"):
        var enemy: Node = hit_collider as Node

# BAD
var result := space_state.intersect_ray(query)
if result:
    var target := result.collider
    if target.is_in_group("enemies"):  # Error: Object has no is_in_group
```

### 6. Node Method Calls on Object Types
```gdscript
# GOOD - check type then cast
if hit is Node and (hit as Node).is_in_group("enemies"):
    damage_target = hit as Node

if hit is Node and (hit as Node).get_parent():
    var parent: Node = (hit as Node).get_parent()

# BAD - Object doesn't have Node methods
if hit.is_in_group("enemies"):
if hit.get_parent():
```

### 7. Vector Operations
```gdscript
# GOOD - explicit Vector3 for computed values
var direction: Vector3 = (target_pos - global_position).normalized()
var right: Vector3 = aim_dir.cross(Vector3.UP).normalized()
var origin: Vector3 = global_position + Vector3.UP * 1.5

# BAD when method returns could be ambiguous
var direction := some_method_returning_vector()
```

### 8. Function Parameter Types
```gdscript
# GOOD - use base types that work for multiple implementations
func setup(ctrl: CharacterBody3D, equip: EquipmentManager) -> void:

# BAD - overly specific types that may not match
func setup(ctrl: FPSController, equip: EquipmentManager) -> void:
```

## Project Architecture

### Physics Layers
| Layer | Name | Usage |
|-------|------|-------|
| 1 | world | Static geometry |
| 2 | player | Player body |
| 3 | enemies | Enemy bodies |
| 4 | player_hitbox | Player attack areas |
| 5 | enemy_hitbox | Enemy attack areas |
| 6 | player_hurtbox | Player damage receivers |
| 7 | enemy_hurtbox | Enemy damage receivers |
| 9 | projectiles | Bullets, grenades |

### Damage System
- Weapons use dice notation: `[count, sides, modifier]`
- Example: `[1, 6, 45]` = 1d6+45 = 46-51 damage
- Body multipliers: HEAD (4x), TORSO (1.5x), LIMB (0.6x)
- Player HP: 100, Enemy HP: 60-80

### Key Classes
- `Hitzone` - Body part damage detection (extends Area3D)
- `Hurtbox` - Generic damage receiver (extends Area3D)
- `Hitbox` - Damage dealer (extends Area3D)
- `WeaponData` - Weapon stats resource
- `EnemyData` - Enemy configuration resource

## Weapon Viewmodel System

### CRITICAL: Camera/Viewmodel Setup (DO NOT CHANGE)
The viewmodel editor and in-game camera must stay perfectly synchronized:

**Player Scene (`scenes/player/player.tscn`):**
- Head node at Y=1.7
- Camera3D as child of Head (no transform offset)
- WeaponHolder as child of Camera3D with **NO transform offset** (identity transform)

**Viewmodel Editor (`scenes/weapons/viewmodel_editor.tscn`):**
- Camera3D at Y=1.7, FOV=75
- WeaponHolder as child of Camera3D with **NO transform offset**

**Rules:**
1. WeaponHolder must have identity transform (no offset) in both scenes
2. FOV locked at 75.0 everywhere (no ADS zoom)
3. Weapon positions set in WeaponData .tres files, not in scene transforms
4. Scale baked into viewmodel .tscn root node, not applied at runtime

### Viewmodel Scene Structure
```
WeaponViewmodel (Node3D) <- Scale goes here (e.g., 0.03 for Thompson)
├── Model (GLTF instance) <- Rotation offset to orient barrel to -Z
└── MuzzlePoint (Marker3D) <- Tracer spawn position
```

### Adding New Weapons
1. Create `scenes/weapons/{weapon}_viewmodel.tscn`
2. Set root node scale (start with 0.03, adjust as needed)
3. Set Model rotation to orient barrel toward -Z
4. Add MuzzlePoint at barrel tip
5. Create `data/weapons/{weapon}.tres` with positions
6. Use viewmodel editor to fine-tune hip/ads positions
7. Keep hip_rotation and ads_rotation values numerically close (within 90°) to prevent spinning during ADS transition


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
