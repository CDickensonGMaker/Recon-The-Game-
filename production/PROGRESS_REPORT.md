# Progress Report — last night → this morning → today (branch `overnight-claude`, 24 commits)

Everything below is committed, headless-validated (full Godot 4.6 compile), and pushed. Branch not yet merged to master.

## LAST NIGHT — autonomous overnight run
**Research (5 docs, `production/research/`):** squad mechanics · coop feasibility (viable DLC ~6-10wk) ·
air support tuning · gore FX · Godot ragdoll.
**Code (8 tasks, each committed + validated):**
1. Enemies + allies now spawn **blood on flesh** hits (was player-only) — reuse `GunFX.blood`
2. **Firebase interior variety** — `stamp_firebase` uses its rng (closed bug `hi9c`)
3. **Pain-quota stagger** on solid hits — wired the dead `apply_stagger()`
4. **Functional VC punji traps** — new `PunjiTrap` actor + auto-placement in villages
5. **F-4 fast horizontal flyby + CBU cluster** ordnance (reuses `CASAirplane`)
6. **Allies use their own Small Arms skill** (veterans shoot tighter; was player-only)
7. **`WIRING_STATUS.md`** — full wired/stubbed/missing map
8. **`detect_ambush`** wired to the point-man (was a dead skill)
Plus: the 50-task queue + overnight progress log.

## THIS MORNING — full audit (read-only)
Verified every overnight change is wired end-to-end (real call paths, not just parsing). Confirmed clean build,
no regressions. Surfaced 3 loose ends: **CBU was dead code** (built, no menu — fixed today), skill wires **dormant
until purchased**, and `mg_positions` a **pre-existing dead field** (harmless).

## TODAY — War Room + build + polish

### War Room decree (4 architects → `production/war_room/`)
game-designer · systems-designer · technical-director · devil's-advocate → synthesis. Resolved the barracks-vs-use
tension via the **`PLAYER_SKILLS` seam**.

### Living Squad XP (built, A1-A4)
- **No blank recruits** — MOS skill guaranteed L1-3 + `al`-weighted random extras at generation
- **Learn-by-doing** — `credit_use` choke-point on a cumulative curve (cap L8); 4 hooks: kill→small_arms,
  revive→medic, ambush-warning→detect_ambush, fire-call→fo_fac
- **Visibility** — promotion bark at the moment of the deed, earned rank (PVT→SSG), KIA memorial with kills
- Attributes stay purchase-only (no hoarding); old saves back-filled

### Radio Fire Support "made real" (built, B5-B8)
- **CBU cluster exposed** as the 6th call-for-fire (key 6), raid-profile budget 1
- **`fo_fac` tightens fire** — arty + mortar scatter lerp 1.0→0.45 with RTO skill, +1 veteran mortar round
- **Danger-close** — confirm keypress + asymmetric friendly fire (allies take 0.4× ordnance)
- **Per-mission crater ceiling** (perf backstop)

### Fire Support UX + leash (built)
- **"Get on the radio"** — opening the net lowers your rifle (can't fire/ADS), slows you to a shuffle,
  requires a living RTO. Deliberate + exposed, and it fixes the weapon-slot key overloading.
- **10m radioman leash** — must be within 10m of your living RTO to call fire (the radio's on his back)

### Explosions (built)
- Procedural **explosion visual** (flash + fireball + smoke + debris) through `GunFX.play_explosion_3d` —
  every explosion (grenade/claymore/sapper/arty/mortar) gets fire; was a crater + a bang with no visual.

### Research (2 docs, `art_source/characters/fp_arms/`)
- **`IDLE_ANIM_SPEC.md`** — HL1-derived per-gun idle set (idle/fidget/check/inspect), 12-20s cadence
- **`IK_ANIMATION_WORKFLOW.md`** — how to author on the IK rig, Blender 5.0 slotted actions, `bake_action`
  visual keying for glTF, MCP gotchas, Pose Library tooling

## FILED for later (beads — art/Blender-gated, MCP was down)
- Radioman model + PRC-25 backpack, reused as the FPS handset (+ handset-raise anim)
- Per-gun FP idle animations (build from the two research docs)
- **INTERIOR MODE epic** — tunnel-rat + building CQB missions (post-core; entrances already exist)
- (Earlier braindump beads still open: 100 bios, scripted events, vehicles, barbwire, slimmer models, roads, civilians)

## Still gated (need you or Blender/perf test)
Blender: claymore/F-4 models, handset prop, idle animation authoring, rubble, civilian models, slimmer topology.
Perf test: widening the napalm burn (crater cap). Audio: flesh-hit + weapon + VO samples.
