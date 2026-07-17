# Devil's Advocate — bead 37mj: dressing in the real ally spawn path

Read: ally_base.gd (whole), grunt_randomizer.gd, grunt_dresser.gd, hitzone_builder.gd,
gib_system.gd, squad_system.gd, ai_stress_arena.gd (~1090–1220), gore_lab.gd (~340–405),
rescue_objective.gd, test_grunt_dresser.gd, test_ai_stress_arena.gd, model_actor.gd (flash/setup).
Verified GLB contracts by grepping the binaries. NOTE: a parallel session executed the file move
(step 1) **while this analysis ran** — scripts/tools/grunt_randomizer.gd is already gone,
scripts/visuals/grunt_randomizer.gd + .uid exist. Analysis raced the build; the P0s below still stand.

## P0 LANDMINES — the plan as written produces the octuplet bug it exists to kill

### 1. Both seeds are unavailable at the moment the plan dresses (ally_base.gd:938–955)
`spawn_ally()` runs `parent.add_child(ally)` — which fires `_ready()` → `_setup_visual()` —
**BEFORE** `ally.global_position = pos` and long before the caller assigns `ally.member`
(squad_system.gd:38–47, rescue_objective.gd:65–66, arena :1160–1164). At `_setup_visual` time:
- `member` is ALWAYS empty → the "hash of member name" branch can never fire in `_ready`.
- `global_position` is ALWAYS the parent origin → "quantized spawn position + unit" quantizes
  **(0,0,0) for every man** → identical seed → identical face → a full squad of octuplets,
  reintroduced through seeding instead of shared materials. The dresser's own header calls this
  the one trap; the plan walks into it via spawn ordering, not material sharing.
Fix shape: dress must happen POST-spawn (deferred, or an explicit `dress()` step callers invoke
after member/position are set, or reorder spawn_ally — which is its own behavior change since
`_ready` code reads position). Item 2 as specified is unimplementable in `_setup_visual`.

### 2. The unit gate is wrong in both available forms
- `begins_with("us_")` includes `us_pilot_white/black` (no `helmet_shell_worn` in GLB — verified;
  own skin doctrine per NON_ROLES) and `us_grunt_m14/m60/m79` (**no stock helmet mesh in the GLB**
  — verified — so `_swap_helmet` push_warnings per man and no helmet variant hangs).
- `GruntRandomizer.roles()` EXCLUDES `us_grunt_v3` — which is the DEFAULT ally body
  (ally_base.gd:174), 1/3 of the rifle pool (squad_system.gd:71), and the arena's ONLY US body
  (ai_stress_arena.gd:80 `ARENA_US_BODIES = ["us_grunt_v3"]`). v3 DOES carry the contract
  (helmet_shell_worn=1, face material=1 — verified in the GLB), it is a non-ROLE, not
  non-dressable.
Neither list is the dressable-set. A third explicit list is required, and the probe must pin it —
this ambiguity is exactly where the bug will live.

### 3. `set_sprite` force-rebuild widens a live hurtbox landmine (ally_base.gd:231–243, 315–317)
`set_sprite()` frees the ModelActor and rebuilds the visual but **never rebuilds `_hitzone_sync`**.
Hitzones were built in `_ready` against the ORIGINAL us_grunt_v3 skeleton: v3 hull points, v3 bone
indices, plus a `skeleton_updated` callback + `hz_sync_cb` meta left on the freed skeleton.
After rebuild, `_physics_process` drives `HitzoneBuilder.sync(new_model, old_entries)` — stale bone
indices against a different rig, silently misplaced flesh. This ALREADY fires for every specialist
(MG/grenadier/marksman/RTO/pointman swap bodies today). Adding `force` makes the rebuild universal
(every rifleman) and DOUBLES the dressing work (dress in `_ready`, free it, dress again) — and the
new probe asserts faces, not hitzones, so it ships past the gate. If force lands, `_setup_hurtbox`
must re-run after rebuild (retire old zones first), or riflemen must dress once post-spawn with no
rebuild at all (cheaper AND safer — prefer this).

## P1 LANDMINES

### 4. The dressed face dies on the gib (gib_system.gd:294–317)
`_set_face` stores the face as a per-MeshInstance **surface override material**;
`_spawn_gib(mi.mesh, ...)` clones only the `Mesh` — overrides do not travel. A dressed man's popped
head/limb reverts to atlas cell 0. Answer to the brief's question: donors DO get the face slid on
their MeshInstances (harmless), but the gib pipeline drops it, so "donor slides too" buys nothing.
Fixing it means editing gib_system.gd (copy overrides onto the gib's MeshInstance) — NOT covered by
this bead's scope and adjacent to eq6n pressure. Either fix it consciously or name it sacrificed.

### 5. Perf: unmeasured, and the suite cannot see it
- Per-man material duplication (the dresser's law) breaks batching on every face surface;
  36 men in the 18v18 arena = 36+ unique materials, right after the PS2 wave fought for +9fps.
- `_swap_helmet` `load()`s helmet GLBs **synchronously per man**: worst case 15 disk loads inside
  the first spawn frame; mid-fight reinforcement squads (`_us_reserves_left`) load under fire.
  Trivial fix: preload the 15 helmet PackedScenes once (static const / lazy static cache).
- `test_ai_stress_arena.gd` has NO fps assertion (combat/suppression/NAV only) — a dressing perf
  regression passes the suite invisibly and lands on Caleb's live framerate, where the lights wave
  will absorb the blame. Run ps2_perf_probe before/after, or the perf claim is faith.

### 6. Probe design flaws (item 4 as specified)
- "different names → different faces": 70 atlas cells; two names legitimately collide ~1/70 per
  pair (~13% for a 5-man squad of arbitrary names). Written naively this probe FLAKES, and the
  "fix" someone reaches for will weaken the dresser. Use fixed names pre-verified to map to
  distinct cells, or assert seeds differ, not faces.
- "exactly one HelmetSocket" is a good assert — test_grunt_dresser.gd:156 already documents dress()
  is non-reentrant (double-dress stacks sockets and confuses GibSystem's find-by-name). Keep it,
  and it is the reason "dress exactly once per actor build" must be law.
- The probe spawns via `AllyBase.spawn_ally` with the DEFAULT body us_grunt_v3 — which the gate in
  P0-2 may exclude depending on which list the implementer picks. Probe and gate must agree or the
  probe green-lights a no-op.

### 7. The rescue pilot is the plan's own counterexample (rescue_objective.gd:65–66)
LT. HARLAN: member assigned after spawn, `set_sprite` never called → he gets the (broken,
origin-seeded) `_ready` dressing, never identity dressing — the exact case the member-hash branch
was written for cannot reach it. And flavor: a rescued AVIATOR in a random "BORN TO KILL" M1.
Either exclude him (helmet:false at least) or accept the costume.

### 8. Smaller trips
- `ModelActor.flash()` caches `_flash_mats` on first hit; any re-dress of a LIVE actor swaps in new
  override materials → the cached ones go stale and the face stops flashing. Same law as #6:
  one dress per actor build, ever.
- Dressing RNG must be a private RandomNumberGenerator (plan says so — hold it): one `randf()`
  leak into the global/mission RNG shifts every subsequent sim roll under the mission seed.
- Positional quantization: gore_lab allies spawn 1.3m apart (:349). A quantize cell ≥1.3m makes
  adjacent men twins BY CONSTRUCTION even after P0-1 is fixed. Cell must be well under spacing.
- The moved file's header still says "scripts/visuals/ is owned elsewhere - never edit it from
  here" — now self-referential lint in its own directory.
- Arena `bench_dressing` export (:117) is an unrelated pre-existing flag (arena set-dressing);
  name the new probe/flags to not collide with it.

## WHAT IS SACRIFICED (no free lunches)
- Per-instance materials: batching + memory, paid per US soldier on screen, forever.
- Face continuity through gore (unless gib_system is edited — scope growth).
- VC + civilians stay uniform this wave (accepted by the bead; the visual gap between dressed US
  and clone VC will be NOTICEABLE in the 18v18 arena).
- If force-rebuild is chosen: double actor construction per squad member at mission start AND the
  hurtbox rebuild debt comes due now (P0-3). If post-spawn dressing is chosen instead: every
  spawn-path caller must remember the dress step — enforce it in the probe, not in memory.
