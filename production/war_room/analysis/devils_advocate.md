# Devil's Advocate — 2026-08-11 Playtest Defect Sweep (attack on the pre-DA synthesis)

Every finding: claim attacked → code evidence → verdict. Verified against code on
2026-08-11; nothing edited outside this file.

---

## W1 — Audio

**1. Limiter swap breaks a script that indexes Master effects.**
Evidence: `player.gd:1901-1906` appends its lowpass and remembers `get_bus_effect_count-1`;
`:1969-1971` retrieves by that stored index and casts `as AudioEffectLowPassFilter` (a wrong
node would just null out). The limiter stays effect 0; count is unchanged by a type swap.
`spectre_gunship.gd:142`, `cas_airplane.gd:100`, `helicopter.gd:102` route by bus NAME with
SFX fallback. **CONFIRMED-SAFE.**

**2. "Swap the sub_resource to AudioEffectHardLimiter (ceiling −0.8)".**
`default_bus_layout.tres:3-5` carries `threshold_db = -1.0`. `AudioEffectHardLimiter` has NO
`threshold_db` (its properties are `ceiling_db`, `release`, `pre_gain_db`).
**ADJUSTMENT:** drop the `threshold_db` line in the same edit or the .tres carries a dead
property that warns on load.

**3. Vehicles bus −6 survives boot.**
`game_settings.gd:58-63` `apply_audio()` re-stamps only Master/SFX/Ambience/Music from saved
settings; Vehicles is untouched. **CONFIRMED-SAFE.**

**4. "Per-shot mech layer skips cleanly after the rename."**
`audio_manager.gd:192-198` `_single` has no class-bank fallback (only `_next_fire` falls back,
`:210-213`); `:330-331` `if mech:` skips on null. Repo-wide, nothing loads `mech_ak47.wav` by
literal path (grep: only the `.import` sidecar and war-room docs). **CONFIRMED-SAFE.**

**5. "Rack recording preserved in the reload/bolt slot" — implies it will be HEARD.**
`play_bolt_player` (`audio_manager.gd:348-355`) is reached ONLY from
`weapon_holder.gd:400-407`, the `FiringMode.BOLT_ACTION` arm. The AK is automatic; empty
reload plays `reload_ak47.wav` via `play_reload_player`. So `bolt_ak47.wav` will be a
**dormant asset** — preserved, never played. Acceptable (recordings are sacred), but the
synthesis's "empty slot … changes what an empty reload sounds like" is wrong on both counts:
nothing about the AK reload changes, and nothing plays the file.
**ADJUSTMENT:** say this in the change; do not promise Caleb an audible bolt.

**6. ".import sidecar rename — safe outside the editor?"**
`mech_ak47.wav.import:6,10-11` embeds the old filename in `path`, `source_file` and
`dest_files` (hash `mech_ak47.wav-35be27dd…`). Renaming both files works at RUNTIME (the old
`.sample` still exists in `.godot/imported`), but the internals are stale: a cleaned
`.godot/` fails to load the stream until an editor import pass regenerates it.
**ADJUSTMENT:** rename both, update `source_file=` in the sidecar, and open the editor once
before the next playtest so the reimport lands. Same for `mech_car15.wav` if it moves
(102,078 B, same 20:35-20:43 Jul-29 batch on disk — the audit is warranted).

**7. Per-ship pitch jitter "in `_build_rotor_audio`".**
`helicopter.gd:121` `_drive_rotor_audio` re-stamps `pitch_scale` from the formula EVERY frame
— a jitter applied only at build time is overwritten on the first tick.
**ADJUSTMENT:** store a per-ship `_pitch_jitter` member at build, add it inside the `:121`
formula. Constants `ROTOR_DB_FULL/IDLE/UNIT_SIZE/max_db` all confirmed at
`helicopter.gd:89-92,105`; no test references any of them.

---

## W2 — LZ dispersal

**1. "unseat_all → PASSENGER_SEATS only" breaks another caller or a test.**
Sole production caller: `heli_lift.gd:280`. `tests/test_seat_system.gd:186-205` never calls
`unseat_all` — it unseats per-seat via `unseat()` (its `:204` failure STRING says
"unseat_all"; message drift, not a dependency). `tests/test_only_liveness_baseline.json:9`
still lists `unseat_all` as test-only — stale against `heli_lift.gd:280` (pre-existing
drift, note in passing). Pilots staying aboard is what `heli_lift.gd:119` already promises,
and `_deliver` (`heli_lift.gd:282-314`) walks `_pax` only. **CONFIRMED-SAFE**, and it kills
the pilot hard-teleport (`civilian.gd:330-333` → `:993-1004`) for free.

**2. "Will a 140° fan with radius up to 2.5+0.9·11 stay on the pad — 12 pax?"**
Real numbers: `PASSENGER_SEATS` = **10** (8 pax + 2 gunners, `seat_system.gd:27-31`;
`SEAT_NAMES` = 12 incl. pilots — the file header's "11-seat" is its own drift), and
`heli_lift.gd:27` `PAX_MAX = 6`, so the demo fan tops out at index 5 → **6.9 m** radius.
Fine on any pad. **CONFIRMED-SAFE** at demo loads; clamp radius at ~7 m anyway so a future
10-body unseat cannot fan to 10.6 m.

**3. Bunk clamp via raw `NavigationServer3D.map_get_closest_point` (heli_lift.gd:294-300).**
The precedent (`nav_router.gd:67-69, 84-88`) guards with map-valid + `map_get_iteration_id
> 0` + a 12 m `CLAMP_MAX_M` cap. A naked call against an unsynced map, or with no region
covering the point, returns garbage/far-region points. The firebase is always baked
(`nav_baker.gd:124` comment) so steady-state is fine, but the guard is three lines.
**ADJUSTMENT:** copy all three guards, cap at ~12 m else keep the raw bunk.

**4. Stick line vs `BOARD_NEAR_M`.**
Gate measures to the SHIP, not staging (`seat_system.gd:424-426`); 6th man ≈ 7.4 m from the
airframe (2.5 m push + 5×1.4 m lateral) — inside the 8 m gate with 0.6 m margin.
**CONFIRMED-SAFE at 1.4 m spacing; do not widen it.**

---

## W3 — Squad catch-up

**1. File path.** There is no `scripts/allies/squad_system.gd`. It lives at
`scripts/squad/squad_system.gd`; `_physics_process` at `:397-419` with the cited 0.4 s
cadence pattern (`:407-411`), `members` at `:23`, player via `world.player` (`:122,371`),
camera precedent `:256`. **ADJUSTMENT:** fix the path in the plan. Fields confirmed:
`order_mode`/`enum OrderMode {FOLLOW, HOLD, MOVE_TO, RESCUE}` (`ally_base.gd:169,185`),
`squad_member` (`:174`), `target_last_seen_time` (`:27`), `_slot_valid` (`:199,1082-1086`).
FOLLOW-only gating leaves HOLD/MOVE_TO/RESCUE untouched. `is_position_behind` is real
Camera3D API with in-repo precedent (`squad_nameplate.gd`, guarded by
`test_playtest_bundle.gd:139`) and returns true behind the camera plane — the right
direction.

**2. LANDMINE — nav-clamping the teleport destination drags the squad BACK TO BASE.**
The plan clamps placement with `map_get_closest_point` "precedent nav_router.gd:86" — but
the precedent only clamps AFTER proving the point is inside the agent's own baked box
(`nav_router.gd:59` `box_contains`) and caps the correction at 12 m (`:37,87`). Regions
exist only at the firebase and enemy-anchored sites (`nav_baker.gd:109-117` `should_bake`);
the ground the player walks OUT INTO has none. An unguarded clamp there returns the nearest
point on a FAR region — the firebase — and the "catch-up" teleports a lagging man to the
wire, the exact inverse of the defect. **Required guard:** clamp only when
`NavBaker.box_index_at(dest) >= 0` (`nav_baker.gd:81`), or accept the clamp only if it moved
the point < ~12 m; otherwise use the raw dest + ground ray. Plus the map-iteration guard
(`nav_router.gd:67-69`).

**3. LANDMINE — individual gate release guts the opening beat.**
`demo_game.gd:296-306`: the beat IS "your own squad leaving without you". Release a man to
FOLLOW on HIS OWN arrival (`ally_base.gd:1028-1093` FOLLOW walks to the player) and the
first arrivals turn around and walk BACK to the player still sitting on his bunk — the squad
ping-pongs and never assembles at the wire. The defect Caleb hit needs only the third
expiry. **ADJUSTMENT:** keep the collective release (`demo_game.gd:334-349`) exactly as-is,
ADD ONLY "release-all when the player himself passes the gate radius". The M-4 canary print
(`:352-353`) then survives with its semantics intact.

**4. Player dead / end card.** The plan never gates on the player's state. Distance is
static around a corpse so the 40 m tier rarely fires, but the end-card camera can face
anywhere. **ADJUSTMENT (minor):** add `GameManager.can_player_act()` to the gate. Player
seated flag exists as claimed (`player.gd:1294` `is_seated`).

---

## W4 — Ragdoll pose bake

**1. `body_offset` and the inverse math.** `PhysicalBone3D.body_offset` exists in 4.x, and
the engine's own simulator applies exactly
`bone_global = skel.global_transform.affine_inverse() * body.global_transform *
body_offset.affine_inverse()` — the plan's formula matches the engine's direction.
**CONFIRMED.**

**2. Feedback while simulating.** Once `physical_bones_start_simulation()` runs
(`model_actor.gd:785`), simulated PhysicalBone3D bodies are dynamic — they are driven by
physics only and never read bone poses back as targets; the modifier's per-frame output is
the same values the bake writes (idempotent). The clip is paused (`:676-678,773`) so no
AnimationPlayer fights the writes. **CONFIRMED-SAFE.**

**3. Write order / non-simulated bones.** Naive iteration of `sim.get_children()` can
convert a child bone against a STALE parent global. **ADJUSTMENT:** write in ascending
bone-index order using `Skeleton3D.set_bone_global_pose()` (4.4+, present in 4.7) so each
conversion sees the just-written parent; skip bones that failed to bind (reuse the
`get_bone_id()`/`find_bone` fallback at `:763-766`). Non-simulated bones (fingers) keep
their animation locals and ride their baked parents — same as the engine modifier. Real cost
is ~11-15 physical bones per ragdoll, not "~50" — cheaper than the synthesis budgets.

**4. Cap interaction.** A capped kill never gets a sim (`:746-747` returns false) → falls to
`settle_flat_corpse`, which no-ops only when a ragdoll EXISTS (`:843-845`); the per-frame
bake keys on `_ragdoll_sim`/`is_simulating_physics()` and never runs for capped corpses.
**CONFIRMED-SAFE.**

**5. Fossil.** With the per-frame bake live, `sleep_ragdoll`'s `get_bone_global_pose` bake
(`:706-716`) reads back the very poses the bake wrote — a redundant no-op.
**ADJUSTMENT:** delete it in the same change (Fossil Law), keep only `stop_simulation`.

**6. `_physics_process` on ModelActor.** None exists today (grep). Hundreds of ModelActors
are alive at once. **ADJUSTMENT:** `set_physics_process(false)` in `_ready`, enable in
`start_ragdoll`, disable in `sleep_ragdoll`/`_release_ragdoll_slot` — don't pay an
early-return on every actor every frame. Note `wake_ragdoll` (`:906-908`) restarts the sim;
re-enable there too.

**7. Civilian 90° pitch delete (`civilian.gd:712-713`).** Confirmed: death clip AND
`rotation_degrees.x = 90` double-lay. But the pitch is the only prone GUARANTEE if a rig
carries none of the three clips. **ADJUSTMENT:** replace the pitch with
`actor.settle_flat_corpse()` (the guaranteed-prone path, `model_actor.gd:843-860`), not a
bare delete.

---

## W5 — Civilian/VC nav

**1. LANDMINE — the suspected mis-clamp is real.** Quiet villages bake NO region:
`should_bake` (`nav_baker.gd:109-117`) requires an enemy anchor within radius+60 m. A naked
`map_get_closest_point` on the shared map then returns the closest point on a FAR region —
clamping a villager's home/work/flee target onto the firebase mesh 100+ m away, teleporting
him there via `place_for_current_hour` (`civilian.gd:1003`). **Required guard (same as W3):**
clamp only when `NavBaker.box_index_at(target) >= 0`, cap the correction at ~12 m
(`nav_router.gd:37,87` `CLAMP_MAX_M`), and copy the map-iteration guard
(`nav_router.gd:67-69`). Where no region covers the point, fall back to the
`nav_blockers`-box rejection the synthesis already names — that path has no far-region
failure mode. Same guard on the FLEE clamp: in a no-region village, flee DIRECT, don't clamp.

**2. Cited functions all exist as claimed:** `place_for_current_hour` `:993-1004`,
`_resolve_target` `:1007-1014`, `_bt_settle` jitter `:1083-1099`, FLEE `:380-386`,
`_step_toward` 1 m zero-band `:658-671`, router only at LOD_FULL `:662-663`, and no unstick
logic anywhere in `civilian.gd` (grep). **CONFIRMED.**

**3. Escalation snap "to `_self_out`".** That is NavRouter PRIVATE cache, populated only
after a failed on-mesh query (`nav_router.gd:106-109`) — a civilian who direct-steered all
day has never filled it. **ADJUSTMENT:** expose a guarded
`NavRouter.nearest_mesh_point(from)` (same iteration + box + cap guards) rather than reading
`_self_out`, and accept "no snap available" at unbaked villages — the blocker-box rejection
in (1) is the fix that actually covers them.

---

## Demo path + test blast radius

- Demo runs every touched path: `AIR_OPENING` huey beats incl. `lz_cycle`
  (`demo_game.gd:153-166`), gate order `:301-353`, garrison civilians, ragdolls on every kill.
- Grep of `tests/` for `ROTOR_DB_FULL`, `unseat_all`, `mech_ak47`, `GATE_ORDER`, bus layout:
  only `test_seat_system.gd` (per-seat `unseat`, unaffected) and `test_playtest_bundle.gd:139`
  (the 2026-07-19 nameplate guard, unrelated). No suite goes red from these changes.
- Pre-existing drift found, correct on contact: `seat_system.gd:1-2` "11-seat" vs 12
  `SEAT_NAMES`; `test_seat_system.gd:204` message says "unseat_all" over per-seat code;
  `test_only_liveness_baseline.json:9` lists `unseat_all` as test-only vs `heli_lift.gd:280`.
