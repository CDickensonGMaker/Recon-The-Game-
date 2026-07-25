# SYSTEMS-DESIGNER — The Player Field-Marking Layer

**Lens:** how marking bolts onto existing code without a parallel system (ADR-023) and the deterministic imprecision model (ADR-010). All claims carry `file:line`.

---

## 0 · THE FOSSIL ALREADY EXISTS — this is the headline

A binocular-marking system is **already live** in `scripts/player/player.gd:154-182`. While glassing, a 0.5s ray (`:162`, mask `1|4`, 200m) hits an `EnemyBase`, sets `enemy.set_meta("marked", true)` (`:168`), and spawns a floating `Label3D` "v" billboard over the enemy (`:169-176`) that self-frees after 10s (`:178-182`).

**This is a world-space enemy tag, NOT a map grease-pencil mark.** If we build the field-marking layer beside it, we ship exactly the divergent-parallel-system disease ADR-023 exists to kill: two "marking" verbs, two truths, and the next agent wires the wrong one. **The new `mark_field()` MUST absorb and delete this stub in the same change** (Fossil Law, ADR-023). The binocular glass-of-an-enemy becomes `mark_field("contact", world_pos)` — one verb, one store. The Label3D-over-head can stay as *diegetic feedback* only if it is re-sourced FROM the map mark, not a second record; cleanest MVP is to drop it and let the map be the memory (ADR-022).

---

## 1 · REPORT-VERB REUSE — where the verb lives, where marks live

**The aim point reuses `_cas_ground_target()` (`field_director.gd:688`)** — the existing camera ray-march to the terrain surface (origin `cam.global_position` `:692`, dir `-basis.z` `:693`, 12m march + 8-step bisection `:698-709`). No third aim path is created; this is the same march the fire-mission placement already calls at `:345`. The RTO-gated fire path (`_radio_check:512` → `arm_fire_mission:276` → `commit_fire_mission:301`) stays **untouched and separate** — marking never opens the net, spends no ordnance, and has no danger-close confirm.

**No new manager node (council ruling honored).** The verb lives on **FieldDirector**, because:
- It already owns `_cas_ground_target()` (`:688`), `world`, and `world.player` (`:689`).
- It already owns `MissionState` (`:9`) — the natural mark store.
- `topo_map.gd` already holds `director: FieldDirector` (`topo_map.gd:29`) and already reads `director.patrol_location` to draw the CO circle (`:138-144`). Marks render by the identical path — zero new coupling.

**Two new FieldDirector methods:**
```gdscript
func _aim_world_target() -> Vector3:      # thin: return _cas_ground_target()  (NO third path)
func mark_field(kind: String, world_pos: Vector3) -> void
```
`mark_field` applies imprecision (§2), then appends a pure dict to the store.

**Marks live on MissionState** — add one field:
```gdscript
var field_marks: Array[Dictionary] = []   # mission_state.gd, beside flags:11
```
This choice is load-bearing for persistence (§4): `_bank_patrol()` already does `state = MissionState.new()` (`field_director.gd:1088`), so **reset-per-patrol is free** — the marks die at the wire with the ledger, no teardown code.

**Input seam.** The stamp key set (TRAIL / TUNNEL / CAMP / etc.) is read in `player.gd` where binocular state already lives (`_update_binoculars:143`), calling `director.mark_field(kind, director._aim_world_target())`. CONTACT auto-classifies: if the LOS ray (§3) hits an `EnemyBase` (the check already written at `player.gd:165`), kind is forced `"contact"`; otherwise the player's chosen stamp is used.

---

## 2 · THE IMPRECISION MODEL (deterministic — ADR-010)

**Formula (grease-pencil estimate, not GPS):**
```
range        = player.global_position.distance_to(true_pos)
error_radius = clampf(BASE + K * range, 0.0, CAP)
if glassing (binoculars raised): error_radius *= 0.5
```
Proposed constants: `BASE = 3.0`, `K = 0.08` (8m drift per 100m), `CAP = 60.0`.

- **CONTACT** (close, direct, ~20m): `3 + 1.6 = 4.6m` → effectively precise. ✓
- **TRAIL/TUNNEL** (read on foot, ~10-40m): 4-6m → close enough to walk back to. ✓
- **CAMP** (glassed at 300m): `3 + 24 = 27m`, halved by optic → **13.5m off**; without the optic you cannot make this mark at all (§3), and if range were 500m the cap holds it to 30m. Tens of meters wrong, exactly as decreed. ✓

**Applied at placement, ONCE, then frozen:**
```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = hash(Vector2i(int(true_pos.x), int(true_pos.z))) ^ state.seed_value
var a: float = rng.randf_range(0.0, TAU)
var r: float = rng.randf() * error_radius
var map_pos: Vector3 = true_pos + Vector3(cos(a) * r, 0.0, sin(a) * r)
```

**Why this is ADR-010-clean:**
- `state.seed_value` is the op seed (`= patrol_count`, set at `_bank_patrol:1090`; `mission_state.gd:10`). The mark is a **pure function of the point and the operation** — a dedicated seed-derived RNG, never the global stream, exactly the discipline ADR-010 mandates for anything persisted/generated.
- The offset is **computed once at placement and stored in the dict**, not recomputed per-frame — so the wrong mark is *stably wrong* and never jitters. A camp glassed from 300m sits 13.5m off in the same direction every time you open the map. That is the fantasy (ADR-022 grease-pencil law): the map holds *what you thought*, and it is allowed to be wrong. The game NEVER corrects it — no re-derivation on approach.

---

## 3 · COST / FRICTION — what gates a mark cheaply

Three cheap gates, no RTO leash (that is fire-only):

1. **LOS raycast to the thing.** The physics ray already written at `player.gd:159-164` (camera origin, aim dir, mask `1|4`) — if it is blocked or clears the 200m horizon with no hit, the mark is denied ("NO LOS — YOU CAN'T SEE IT"). One `intersect_ray`, already in the codebase.
2. **Ranged marks require the optic raised.** Beyond a near threshold (~50m), require `_binocs_active` (`player.gd:146`). Without glass: "TOO FAR — GLASS IT FIRST." This is what makes CAMP a binocular verb and what earns the halved error in §2. Close marks (TRAIL underfoot) need no optic.
3. **Must be roughly still.** Reuse the flat-speed check already computed at `player.gd:990` (`Vector2(velocity.x, velocity.z).length()`); deny while sprinting ("STEADY UP TO MARK"). One float compare.

No net, no cooldown, no ordnance — marking is *free but earned by posture*, which is the ADR-022 "map-as-object-with-cost" made real without touching the fire economy.

---

## 4 · PERSISTENCE — recommend MVP, flag the richer path as Caleb's scope call

**RECOMMEND (MVP): reset-per-patrol.** Marks on `MissionState.field_marks`; they die at `_bank_patrol` because `state = MissionState.new()` (`field_director.gd:1088`). **Cost: zero** — the reset already exists, no save-schema, no teardown, no MissionScope entry. The map is *this patrol's* memory; walking back inside the wire wipes the slate, which fits the perishable-intel engine ADR-022 already describes.

**RICHER (Phase 2, Caleb's call): bank to a firebase AO map.** On `_bank_patrol`, copy surviving marks into a persistent province store (`CampaignState`, ADR-017 persistent province) so multi-patrol AO knowledge accumulates — the "you learn the ground over many walks" hook. **Cost, named (no free lunch):** a save-schema field + migration, a decay/staleness model so the accumulated sheet doesn't become an omniscient god-map (which would breach the ADR-022 topo-sheet-not-minimap line), and a persistence-teardown obligation. This is real scope; do NOT smuggle it into the MVP. Flag it for the Summoner.

Either way the **grease-pencil law holds**: no auto-erase, no "(stale)" tag applied by the game (ADR-022 §Grease-Pencil-Law). Editing/erase is a *player* verb, out of MVP scope.

---

## 5 · THE §4 STRUCTURAL PROBE (guardrail — marks never become objectives)

A mark is **pure data with no verdict field**. The dict is exactly:
```gdscript
{ "kind": String, "map_pos": Vector3, "placed_at": int }   # placed_at = Time.get_ticks_msec()
```
No `completed`, no `objective_id`, no `done`, no `checked`, no `progress`, no `count`.

**Probe (add to the `test_fossils.tscn` family, or a sibling `test_field_marks_guardrail.gd`):**

1. **Shape assert.** Construct a `MissionState`, call `mark_field(...)` via a harness, and assert every dict in `field_marks` has keys ⊆ `{kind, map_pos, placed_at}`. Fail if any forbidden key (`completed|objective_id|done|checked|progress|complete`) appears.
2. **Single-reader structural assert.** Grep-assert that `field_marks` is **written** in exactly one place (`field_director.mark_field`) and **read** in exactly one place (`topo_map._draw_overlay`). Any third referrer — especially in `_bank_patrol`, `build_result` (`mission_state.gd:61`), `DebriefScreen.compute_score`, or `DynamicMissionFactory` — **fails the build.** This is the mechanical proof that command never reads a player mark as an objective and scoring never counts it.
3. **No on-screen count assert.** Grep-assert no source references `field_marks.size()` in any HUD/label path (`ReconUI`, HUD scripts). A mark counter *is* a progress tracker; forbid it structurally.
4. **Draw-only assert.** Assert `topo_map`'s use of `field_marks` occurs solely inside `_draw_overlay` (render), never feeding a gate/toast/completion — mirroring how the CO circle at `topo_map.gd:138` "never checks off" (`:136` comment, ADR-029 §4).

This keeps ADR-029 §4 intact: a TUNNEL mark is a note-to-self, never "OBJECTIVE: CLEAR TUNNEL."

---

## PHASE SLOTTING

- **Phase 1 (spine):** `mark_field` + `_aim_world_target` on FieldDirector, `field_marks` on MissionState, CONTACT auto-classify, **delete the `player.gd:154-182` fossil**, reset-per-patrol, the §5 probe. Ships with the report-verb dissolution — it IS the parked report verb, folded in.
- **Phase 2 (pencil pass):** the TRAIL/TUNNEL/CAMP stamp vocabulary rendered in the grease-pencil aesthetic on `topo_map` beside the route polyline (one pencil, multiple stamps — a `mark_kind` render switch in `_draw_overlay`), erase verb, and the ADR-017 firebase-bank IF Caleb blesses it.

## ADR-022 AMENDMENT NEEDED

ADR-022 §2 lists AMBUSH/danger/rally/cache as annotated marks but predates the world-space report verb. Amend to record: (a) ranged marks are placed by the world-space aim verb reusing `_cas_ground_target`, not map-click; (b) the deterministic imprecision model (§2 here) as the mechanical expression of "he is allowed to be wrong"; (c) the fossil deletion of the `player.gd` glass-tag stub.
