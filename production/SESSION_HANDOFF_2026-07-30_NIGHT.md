# SESSION HANDOFF — 2026-07-30, NIGHT

14 commits, `4897d266..8219e29a`, all pushed. Supersedes nothing; **adds to**
`DEMO_SESSION_HANDOFF_2026-07-30_EVENING.md`.

**READ THIS FIRST: almost everything here is UNPLAYTESTED. The one exception is the
sapper bench, which was RUN four times and iterated against what it actually did.**
A log line is a claim (ADR-015) — every "verified" below means I watched the console,
not that the eyes have judged it.

---

## YOUR TWO ACTIONS BEFORE ANYTHING ELSE

1. **Open the project in Godot 4.7 once.** Five new `class_name`s landed today —
   `WorldWeapon`, `MeleeVerb`, `ItemViewmodel`, `FieldCache`, `PlacedSatchel` — plus a
   re-exported `anim_library.glb` (112 → 124 clips). I hand-registered the classes in
   `.godot/global_script_class_cache.cfg` (gitignored, local) purely to type-check; the
   editor rewrites it and nothing depends on it.
2. **Restart Claude Code, then log into Mixamo once.** See the MCP section below.

---

## VERIFIED BY RUNNING IT — the sapper bench

`godot --path . res://scenes/levels/sapper_room.tscn`

Ran four times, and each run found something a read would not have. The console now
reports the whole chain:

```
[SAPPER-ROOM] targets on the bus: 4 sandbag_wall, 2 sandbag_stack, 2 bunker, 1 bunker_mg, 1 tower, 14 wire
[SAPPER] <man> -> wire at -6,-36        <- wire FIRST, one target each
[SAPPER] planting - 3s                  <- kneels and works
[SATCHEL] placed at -6,-36 - 5.0s fuse  <- he sets it and RUNS
[NavBaker] breach: re-baking 1 region(s)
[NavBaker] bake done: ... geom=14 -> 8 -> 4 colliders   <- obstacles GOING DOWN
[SAPPER-ROOM] assault away: 4 men must cross the wall line
```

Keys: `[R]` new wave · `[K]` kill wave · `[T]` reference blast · **`[B]` send the assault
early, against an INTACT wall** · `[F5]` rebuild from the GLB on disk.

**Press `[B]` first.** Four men fail against a solid wall with no gate; then let the
sappers open a hole and watch them come through. That contrast is the actual proof.

### What the runs found that reading would not have

- **The bench baked the PLAYER AND EVERY SOLDIER into the navmesh as obstacles.** It was
  handed the whole scene as its collider root, and `NAV_IGNORE_PREFIXES` only skips
  vegetation and interior props — it has no idea what a person is. Colliders climbed
  59 → 133 → 221 while walkable polys FELL. Now bakes from a `Targets` root: 14 → 8 → 4.
- **`get_meta(key, null)` ERRORS instead of returning null** — the default IS null, so the
  engine cannot tell it from "no default given". Flooded the console. Guarded with
  `has_meta` here and in `garrison_defender`, which had the same bug.
- **The sapper WAS the bomb.** `_detonate` fired at his own feet then called
  `take_damage(9999)` on him, so three men on one objective died together. Now
  `PlacedSatchel`: he sets it, it keeps its own 5 s fuse, it blows where it was PLACED.
  It does NOT spare him — the fuse is a race he can lose.
- **Bombs appeared before he arrived** (5 m reach) and **landed on the target's ORIGIN**,
  which walked men past the wire to stand behind it. Now 2 m, and it lands where he KNELT.
- **They strolled.** Assault push 1.15 → **1.55**.
- **`cargo_unload_stack` is a STANDING clip** — that is why nobody crouched. Chains
  `mortar_dropper` → `idle_crouching` now. **There is no authored plant-a-charge clip.**
- **The explosion used the MORTAR sound** — my `AudioManager.play_incoming` on the fuse
  warning is literally the incoming-shell whistle. Deleted. Blast is `explosion_heavy`
  now, not `explosion_grenade`.
- **Bodies floated after explosions.** `GibSystem.explosion_kill` called `start_ragdoll`
  and threw the result away, and the death-clip fallback was an `else` it could never
  reach — so a rig that cannot ragdoll lost its limbs and left the torso hanging. It
  reports now, and the GUARANTEED FLOOR settle timer moved OUT of the fallback where it
  had only ever covered clean kills. Same fix in `ally_base`.

### Still true and NOT fixed
The bench builds its wire from INDIVIDUAL cards, so it proves per-sector breaching that
**the shipped firebase cannot do**: in the world the wire is one merged `bwire_card_ring`
of ~450 cards and is not wired destructible at all. Splitting it per sector in
`gen_firebase_v3.py` and re-exporting is what carries this into the game. **That is the
one art dependency on "attacks from all over."** Parapet, bunkers, towers and sandbag
stacks DO breach for real already.

---

## THE REST OF THE SESSION — unplaytested

**Firebase destruction.** One shared lifter (`FireSupportBench.lift_meshes/spawn_lifted`)
feeds both benches from the real GLBs; the arena's three stand-ins (grey box,
`barbwire_tangle.glb`, `bunker.glb`) are DELETED. `site_planner` wires **23 more world
structures** (bunkers, towers, sandbag stacks) on top of the manifest's 80 parapet
segments — those had never been destructible in any shipped build.

**Breaching is real.** `NavBaker.breach_at()` re-bakes the region that owns the ground,
debounced 1.5 s. `_add_colliders` already skipped disabled shapes and `_do_destroy`
already disabled them — the mesh was always correct the moment it was rebuilt, and
nothing ever rebuilt it.

**Four assault squads.** `hash(group_tag)` made all 45 siege men ONE squad, so: one
grenade per 12 s across the whole assault, every man permanently holding
`has_covering_fire`, force_ratio against the whole force, and the assault breaking as one
body. Four squads now, own `squad_id` each, across 150° of arc; **squad 2 is a base of
fire** holding 90 m off the measured parapet. The press rotates BY SQUAD. `reinforce()`
builds through the same splitter — it is the path the demo takes to full strength.
**Watch for:** five squads at a 12 s grenade cooldown is now ~1 grenade/2.4 s, up from
1/12 s. Not a regression — 12 s always meant *a* squad — but a real feel change.

**The demo opens in a minute.** Probe 20 s, assault 60 s, card 420 s, per your ruling.
Sim clock 110× so 17:30 → ~06:20 across the arc: the assault lands ~19:19 in failing
light (which SHOWS the art; pitch dark hides it) and DAWN is true rather than a caption.
Restored on exit.

**Air.** Seven scripted CAS beats across the siege (was one). Combat-load gate: BUSY
thins every formation to one ship, SATURATED holds the flight until the shooting eases.
Transits no longer cross the compound. `MAX_IN_FLIGHT` enforced in `_dispatch` — the sim
schedule had **no airframe ceiling at all**. **The gate thresholds (8/20 fighters,
26/38 ms) are REASONED, NOT MEASURED** — `[AIR] load BUSY - N fighting, X ms` prints on
every tier change so you can judge it.

**Equipment viewmodels.** `grenade_handler` and `health_system` each toggled a bare
`Node3D`'s `visible` and `claymore.gd` had no viewmodel path at all, so a perfect GLB
would render in bind pose forever. One `ItemViewmodel` drives all of them.
**Your `bandage_fp.glb` and `handset_fp.glb` both PASS the validator.** An exported item
needs no wrapper `.tscn` — the driver falls back to `<key>_fp.glb`. The handset
placeholder box retires itself on sight of the file.

**Medical.** `FieldCache` — one deployable, two payloads. Doc's box goes down WHERE HE
TREATED SOMEONE (first revive, no toast, you find it); the ammo box goes down on HOLD.
`revives_left` is `medic_bandages` now: six in the bag, the SAME number gates his revives
and `[F] BANDAGE FROM DOC`. Running him dry is meant to send you home — **do not make it
self-refilling.**

**Knife + pickup/drop.** Full melee verb, slot 5, `[K]` from any slot with a quick-flash
visual. `WorldWeapon`: `[F]` to take, `[L]` to drop, a dead man leaves his rifle.
**Bodies give intel and nothing else** — the `randf()` loot roll is deleted. Intel stash
grants **3 marks, 1 real, 2 seeded decoys**.

**Bandaging shakes the camera**, summed into the ONE shake owner — healing while
suppressed stacks, and that combination is reachable because suppression arrives through
`add_suppression()`, a separate path from `take_damage`.

---

## MIXAMO MCP — installed, needs your login

`C:\Users\caleb\mcp\mixamo-mcp` (V1xel/mixamo-mcp; **no official Adobe MCP exists**),
registered as `mixamo`, own venv, handshake tested, 8 tools live.

- **`mcp` MUST stay pinned `<2`.** The repo asks `mcp>=1.0` → resolves 2.0.0 → 2.x removed
  `mcp.server.fastmcp` → server dies on import. Fix:
  `.venv\Scripts\python.exe -m pip install "mcp<2"`.
- **Auth is a one-time INTERACTIVE Adobe login** in a visible Chromium; persists in
  `browser_profile/`. **Yours to do — never drive his credentials.**
- Audited before install: 1111 lines, talks only to `mixamo.com`, no
  `subprocess`/`eval`/`exec`.
- **Downloading is not the bottleneck — retargeting is.** A Mixamo FBX still has to reach
  `PSXRig` (clips walk −Y, root motion in Hips LOCATION), then
  `tools/sync_clips_into_library.py` → `tools/export_anim_library.py`.

---

## THE ANIMATION GAPS — measured, not recited

**Already yours and unused:** `brutal_assassination` (119 f) had ZERO callers. Wired
today as the takedown's death performance via `EnemyBase.death_clip_override`.

**CRAWLING: ZERO CLIPS EXIST.** No `wounded_crawl`, no prone, nothing. Crippled men
borrow `injured_walk_backwards`. Pull: `Crawling`, `Commando Crawl`, `Army Crawl`,
`Injured Crawl`. **Note: crawl needs the most ENGINE work after import** — a prone
posture the state map can select, speed caps, and transitions.

**CROUCHED WORK:** no plant-a-charge clip. Pull: `Crouch Idle`, `Kneeling Idle`,
`Picking Up Object`, `Plant Bomb`. Also `Stand To Crouch`, `Prone To Standing` — there is
no way into or out of a crawl.

**THREE EMPTY WEAPON FAMILIES.** `__smg` has 9; **`__mg`, `__launcher`, `__bolt` have
ZERO** — the RPD gunner and RPG man hold their weapons like rifles in every firefight.
`__smg`'s nine names are the template. `[MODEL] no '__mg' weapon-family clips` now prints
once per family.

**Singles with code already waiting:** `board_heli` (`BOARD_CLIPS` is empty — extraction
TELEPORTS men into seats) · `grenade_throw` · `surrender_idle` (CHIEU HOI borrows a
combat pose) · `death_from_the_left` · `stumble_hit` · `walk_forward_aiming`.

**NPC MELEE: NPCs cannot melee at all.** `MeleeVerb` is player-only. The animations are
half of it; the AI side is unbuilt. The VICTIM-side clip matters most or a takedown is
one man animating and the other standing still.

**Ranked:** crawl set → crouch-work set → `__mg` family → `board_heli`.

---

## OPEN — needs you

- **The wire split** (`gen_firebase_v3.py` per sector + re-export). The one thing between
  the bench's proof and "attacks from all over" in the real game.
- **Grenade rate** after the squad split — feel judgement.
- **Air gate thresholds** — reasoned, not measured.
- **`SQUAD_SPREAD_DEG 150`** — if the outer squads walk too far around to the gate.
- **Suite not run.** `test_fossils`, `test_destructible`, `test_flat_damage`,
  `test_viewmodel_contract`, `test_field_item_hud`, `test_squad` (its revive assertion was
  rewritten to "spends exactly one bandage"). **Reimport before trusting any red.**
- **Committed under my message by a broad `git add`:** `medical_crate.gd`,
  `make_medical_crate.py`, `make_field_dressing_texture.py`, `export_m26_grenade_prop.py`,
  `huey_load_unload_loop.py`, `fix_huey_rotors.py` — your files, pushed and safe, just not
  separated out.
- **Untouched all session, as instructed:** `fp_arms_rifle.blend`, `mosin_fp.glb`, the
  Huey staging blends. Still uncommitted and yours.
