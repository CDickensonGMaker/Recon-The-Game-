# BRIEFING — Demo backlog, the code half

**Convened 2026-07-30** on the Summoner's word: *"can you run this list of things thru the council
as were making them, so we get it done properly."*

**Canon binds:** `production/GAME_GUIDE.md`, `production/adr/`, `CLAUDE.md`. Pillars: believable
firefights · atmosphere · freedom · the squad is the RPG and you are IN it · fail forward.

**The ship gate (his words, standing).** The demo's job is scope and spectacle immediately:
more Hueys and jets moving · a few Huey landings with troops disembarking / supplies unloading ·
the base attack blows parts of the base up · the VC ATTEMPT TO OVERRUN the firebase.

**Trackers:** `production/DEMO_SHIP_BACKLOG.md` (24 items A–F) · `production/DEMO_SESSION_HANDOFF_2026-07-29.md`.

---

## THE LIST UNDER DELIBERATION

**1. C3 — THE VC OVERRUN PUSH.** The largest open gate clause.
- `scripts/missions/siege_director.gd` — cells spawn on a 60° sector at ring 300–500 m and march to
  `objective` (= `FieldDirector.siege_aim`, the bench inside the wire, `field_director.gd:881-884`).
- `scripts/enemies/marching_cell.gd:108-129` — sappers get `assault_driven = true` (objective owns
  the legs, pushes through fire); the assault element gets `assault_driven = false`.
- `scripts/enemies/enemy_base.gd:1305-1313` — an UNDRIVEN man marches until COMBAT or arrival, then
  his own brain takes his legs back **and the objective is cleared forever**. So the assault reaches
  the wire, goes to COMBAT, and trades shots there for the rest of the night. There is no doctrine
  that presses in.
- MEASURED 2026-07-30 from `assets/.../kit/firebase_v3_destructibles.json`: the 80 parapet segments
  are a closed perimeter at radius **49.3–96.1 m, mean 75.5** (manifest `pos` is BLENDER order —
  `[x, y, z_up]`; reading index 2 as the second horizontal axis makes the ring look like two straight
  walls, which it is not).
- `scripts/world/destructible.gd` had no way to be asked "are you gone" — added `is_destroyed()`,
  and `site_planner._wire_parapet_destructibles` now puts the segments in a group so the siege can
  read its own perimeter and find a breach.

**2. SPOOKY'S VULCAN IS STILL FAKE.** `scripts/vehicles/spectre_gunship.gd:156-165` picks a ground
point, paints three decorative `BulletTracer`s at it and applies a small explosion there. The
tracers carry no damage and a man behind the berm is spared by a visibility guess instead of by the
berm. The same aircraft's Bofors already fires real arcing shells, so one airframe holds two
different ideas of what a round is. His ruling 2026-07-29: *"what if we made the rounds from all
planes real projectiles that travel from their points of origin."* Pattern to copy:
`cas_airplane.gd:238-258` (`_fire_strafe_burst`) + `data/weapons/aircraft_20mm.tres`.

**3. D3 — AMBIENT WAR AUDIO.** One one-shot per distant engagement event. His note: *"the fire rate
should either be faster or a less occurring event."* `scripts/missions/ambient_war.gd`.

**4. A4 — OFF-DUTY MEN HAVE NOWHERE TO BE.** `off_duty` sits and talks. 191 work markers already
ship in the GLB. Cheap life, big return on "the base is alive". Garrison schedules were rewritten
7/29 (A3) and are themselves unverified.

**5. D1 — CONVOYS DRIVE THROUGH BUILDINGS.** `Convoy._physics_process` assigns `global_position`
directly — no `move_and_slide`, no navmesh, no collision. Backlog says the fix is ROUTING (road +
gate), NOT making trucks collide. `scripts/world/road_network.gd` exists.

**6. F2 — THE MAP'S TWO VERBS COLLIDE.** Only right-click places a mark; left-click is bound to the
order circle. F3 (research how Arma does the map) is his explicit ask and he asked that it WAIT.

**7. NEW, FOUND 2026-07-30 — THE FLOATING ROUND.** His report: *"theres still a floating round above
the rifle."* Measured, it is the MOSIN. `assets/player/viewmodels/mosin_fp.glb` exports
`stripper_clip_Mosin` and `Mosin_clip_round_1` as a ROOT node at translation
`(-0.636, 1.659, -15.633)` against the bolt's `(-0.139, 1.620, -15.775)` — about **0.5 m off the
gun** (the ~-15.7 m is the armory ruler station, cancelled by the .tres). Of the eight clips in the
GLB only `mosin_round_load` touches it, and with a SINGLE channel. Every other clip — including
`mosin_idle` — leaves the charger and its one round hanging in the air beside the rifle.
`tools/viewmodel_manifest.json` lists mosin `parts` as `["Mosin","Mosin_boltknob"]`, so the stripper
is exporting WITHOUT being a declared part.

---

## STANDING CONSTRAINTS

- **Do not launch the game.** He drives testing. Parse-check and hand over.
- `--check-only --script` cannot judge a file that touches an autoload — singletons are not
  registered on that path. Use `godot --headless --path . --editor --quit` and count
  `SCRIPT ERROR|Parse Error|Compile Error`.
- ADR-023 FOSSIL LAW: when you replace a system, delete the old one in the same change.
- COMMENT DISCIPLINE: no history narration in source. No `## WHY:` essays, no tombstones.
- POINTER LAW: every assertion about code state cites `file:line` or names the probe.
- The project is CALL-BOUND (`production/PERF_LEDGER.md`). Draw calls, not triangles.
- Godot 4.7 only. Strict typing per `CLAUDE.md` (`lerpf`/`minf`/`maxi`, explicit Variant casts).

## WHAT THE COUNCIL IS ASKED

For each item: the correct design, the cheapest correct implementation, what it costs at the perf
floor, what it SACRIFICES, and which pillar it serves or strains. Read the code, never this brief.
Where this brief and the code disagree, **the code wins and say so.**
