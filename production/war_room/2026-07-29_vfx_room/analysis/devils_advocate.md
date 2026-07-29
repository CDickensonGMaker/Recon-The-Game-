# Devil's Advocate — VFX Realism Pass (2026-07-29)

Independent analysis. Read: briefing, ADR-026 (full, incl. Amdt A and the struck "+8.6 fps" note),
`scripts/combat/gun_fx.gd`, `scripts/combat/smoke_cloud.gd`, `scripts/vehicles/fire_hazard.gd`,
`scripts/main/mission_scope.gd`, and every repo caller of the explosion/smoke/fire entry points
(grep results cited inline). My job is to attack the premise. I attack six ways, then name the price
of every road.

---

## 1. "Realistic" is the wrong word and the council should refuse it as written

The Summoner's verbatim ask is "more realistic smoke clouds, realy fire, real explosions." Taken
literally, that request contradicts THREE ratified canons at once:

- **ADR-001 / briefing constraint 7:** PSX-era low-poly, 2000s-FPS FX school. "Real fire" in 2026
  vocabulary means volumetrics, GPU sims, lit smoke — the exact modern-AAA look the aesthetic decree
  forbids.
- **ADR-026 Part A.1:** explosions are FAKE — sprites, never lights. Real explosions light the canopy.
  Ours may not. The ADR's own sacrifice clause says so in plain words: *"explosions no longer dance
  light on the canopy... Traded for a stable frame and an authentic PS2 feel."* That trade was RATIFIED.
  A realism pass that quietly re-litigates it is an ADR change wearing a paint bucket.
- **ADR-026 Part A.5:** FX = "animated texture planes + sprite particles." That sentence IS the ceiling.

**The contrast trap (attack angle 1, the sharpest edge).** The world is vertex-lit low-poly at 0.75
render scale with nearest-neighbor filtering. Drop a high-frame-count, soft-edged, self-shadowed smoke
plume into that frame and the smoke doesn't look better — the WORLD looks worse. The eye calibrates to
the best-rendered object on screen; everything else becomes "the cheap part." MoHAA and Vietcong never
had this problem because their FX were made of the same pixels as their walls. The line is precise and
statable: **any FX element whose texel density, frame smoothness, or lighting response exceeds what the
jungle itself can answer is a net-negative for Pillar 2.** Concretely:

- Flipbook smoke at 8–16 frames, palette-limited, alpha-clipped or dithered: INSIDE the line. This is
  literally what MoHAA shipped, and the blood layer (`assets/textures/fx/blood/`, 4x2 sheets,
  `gun_fx.gd:365-368`) proves the pipeline exists in-repo.
- 64-frame smooth-gradient smoke, per-particle soft fade, fire with emissive bloom trails: OUTSIDE.
  It will read as a Unity asset-store effect pasted on a PS2 game — the uncanny seam is worse than the
  current crude sphere, because the sphere at least matches its world.

The honest reframe the council should hand back: not "realistic," but **period-correct** — "what would
this explosion look like in MoHAA/Vietcong 2002." The research trail already on file
(`production/research/engine_mining_2026-07-18/`) points the same way. If the Summoner actually wants
modern realism, that is a Pillar/ADR conversation, not a VFX task.

**Sacrificed by my own position:** the wow-screenshot. Period-correct FX will never produce a
marketing-grade explosion still. That is the price of a coherent frame, and it was already paid when
ADR-026 was ratified — I am only refusing a refund scam.

---

## 2. Perf: "GPU has headroom" is an unmeasured folk claim on the worst possible GPU

The briefing asserts "GPU has headroom; CPU does not" (constraint 3). Interrogate that:

- The 23.1 fps / ~43ms CPU-bound reading is from the **bench** (`ADR-026:120-123`), a fixed wide-jungle
  view — and the ADR itself documents how many times bench numbers on this project were later struck as
  artifacts (sun-shadow twice, the +8.6 fps light win, the contaminated 2026-07-17 A/B). The perf
  history of this project is a graveyard of confident deltas. "Headroom" has never been measured
  **during a barrage**, which is exactly when the new FX bill comes due.
- The GPU is an **Intel UHD** (ADR-026:35) — an integrated part whose scarcest resource is precisely
  what smoke costs: **fill rate on overlapping transparent quads** (attack angle 5, folded in here).
  An 8m-radius smoke cloud near the player can cover 50–100% of a 960x540 frame. Stack 4 grenade
  clouds + napalm + explosion smoke and you are shading the same screen area 6–10 times over. Alpha
  overdraw does not show up in primitive counts — the metric this project's perf ledger habitually
  quotes — so the regression will be invisible to the usual instruments until someone throws smoke in
  a firefight and the frame halves. Forward+ also pays per-transparent-surface sorting cost.
- **CPU is not exempt either.** The proposed medium is particles, and the current codebase is 100%
  `CPUParticles3D` (`gun_fx.gd:149,165,289,345,376`). Every particle simulated is a CPU-side cost on
  a frame ALREADY at its CPU wall. The briefing's own constraint 3 says GPUParticles3D vs
  CPUParticles3D "matters here" — correct, but note the trap on the other side: GPUParticles3D in
  Godot pays a per-system CPU dispatch and buffer cost, and dozens of small one-shot GPUParticles3D
  spawned per explosion can cost more CPU in node churn than 16 CPU particles ever did. Node
  allocation itself (`Node3D.new()` + material + tween per event) is CPU work at spawn time; a siege
  night (d50 arty rounds, `siege_director.gd:299`) multiplies it.
- **Is shipping prettier FX before the perf gate irresponsible?** Partly yes. There is NO gating FPS
  number anywhere in canon — ADR-026 names 30/60 as an aspiration and Part B (the actual FPS lever)
  has not landed. Presentation work that ADDS GPU+CPU load onto a 23fps frame, with no floor number to
  test against, cannot even be declared regression-free — there is nothing to regress FROM except a
  bench that measures a different scene. The defensible version: **a fixed A/B bill.** Before/after
  windowed bench (Blender closed, per the contaminated-A/B lesson), same seed, a scripted barrage +
  4 smoke clouds, fps + draw calls recorded in PERF_LEDGER.md. If the pass costs >1ms GPU or ANY
  measurable CPU in that scene, it shrinks until it doesn't.

**Sacrificed if we demand the bench first:** velocity. The measurement discipline costs half a day.
Cheap insurance against this project's single most repeated failure mode (unmeasured perf claims
later struck under NO DRIFT).

---

## 3. Scope creep: "exempt presentation work" is a costume an epic can wear

The ask names: explosions (grenade/M79/RPG/arty), smoke grenades, napalm, "real fire," PLUS the
briefing volunteers "impact dust, lingering battlefield smoke" as supporting pieces. Count the systems
that touch: `gun_fx.gd` (explosion, impact — 15+ call sites), `smoke_cloud.gd` (gameplay-live),
`fire_hazard.gd` (gameplay-live), `ambient_war.gd:77` (horizon FX at 12x scale), `game_world.gd:227`,
plus new texture assets, plus a possible shared FX-manager if anyone says the word "pooling."

That is not a polish task. Unbounded, it is a **presentation epic touching two live gameplay systems**,
and the session entry gate (PLAYTEST R4) technically parks gated feature work — the "presentation
exemption" is doing a LOT of load-bearing here. Where the line actually is:

- **Still presentation:** new flipbook textures, retuned particle params, replacing the sphere/cylinder
  meshes with sprite stacks, reusing the existing `_expire`/cap architecture. Touches look-code only.
- **A feature epic in disguise, and it should be named as one the moment it appears:** any new manager
  or autoload; any pooling framework; any change to `blocks_sight()` geometry or FireHazard damage
  logic "while we're in there"; per-surface impact FX matrices; lingering battlefield smoke as a
  persistent world system (that one has SPAWN POLICY questions — who spawns it, who caps it, who
  tears it down — i.e., it is a system, not a texture).

Ratchet I'd demand: the decree enumerates the exact files it may touch and states that gameplay
functions (`blocks_sight`, damage ticks, radii, `FLASH_SECONDS`, all caps) are byte-identical or
diff-justified line by line. "Lingering battlefield smoke" gets CUT from wave 1 or gets its own
gated decree.

**Sacrificed:** the fun of building the ambitious version. Correctly — it's parked behind a gate the
Summoner himself stood up.

---

## 4. Teardown/lifecycle: the current code is a MUSEUM of the bugs the new code will reintroduce

`gun_fx.gd` and `mission_scope.gd` document, in their own comments, every trap. A VFX pass that
rewrites these paths re-rolls the dice on ALL of them. The register, so nobody re-learns any of it:

1. **The cap-leak bug** (`gun_fx.gd:122-125`): teardown frees an explosion node early → the tracking
   array holds freed refs → the cap counts ghosts → ALL future explosions silently vanish. Fixed by
   the validity-filter, with the subtle sub-trap documented right there: the lambda param must stay
   UNTYPED because a freed object can't convert to Node. Any new cap (fire instances, smoke systems,
   lingering plumes) that counts with an `int += 1` instead of a validity-pruned array recreates this
   bug on day one. Note `_active_flashes`/`_active_impacts` ARE bare ints — they survive only because
   `reset_session()` zeroes them; a new FX class with a static counter and no reset hook leaks.
2. **The `_expire` pattern** (`gun_fx.gd:191-197`): expiry Timer must be a CHILD of the dying node.
   A `get_tree().create_timer()` lambda dangles when teardown frees the node first → "Lambda capture
   was freed" spam. Every new one-shot FX must use `_expire` or replicate its reasoning. Tweens have
   the sibling trap: `root.create_tween()` is bound to the node and dies with it — a tween created on
   another node animating a freed material won't.
3. **Static-state survival across missions** (`mission_scope.gd:3-16`): GameFlow runs missions in one
   process. ANY new static — texture cache, shared material, particle pool, active-clouds array —
   MUST be wired into `GunFX.reset_session()` / `MissionScope.reset()` or it ships mission 1's state
   into mission 5. Precedents already paid for: `_sting_cooldown_until` (absolute ticks muting the
   next mission's drum), `_blood_tex` (static texture cache held to process exit — the leak scan
   caught it, `gun_fx.gd:29`). New flipbook sheets cached statically = same leak, guaranteed.
4. **Parent choice is a contract** (`gun_fx.gd:36-38`): nodes parented to `current_scene` SURVIVE
   `_teardown_world()` and must be tracked for MissionScope to cut. Nearly every explosion caller
   passes `get_tree().current_scene` (grenade.gd:113, claymore.gd:61, field_director.gd:641/700/812,
   siege_director.gd:299, projectile_base.gd:383, cas_airplane.gd, spectre_gunship.gd:146...). A
   long-lived "lingering smoke" node on that parent plays over the debrief screen exactly like the
   sting did.
5. **SmokeCloud's own teardown is the array, not the node** (`smoke_cloud.gd:62,69-70`):
   `active_clouds` is a static Array pruned in `_exit_tree` and validity-checked in `blocks_sight`.
   It is NOT in MissionScope.reset() — it survives on the `_exit_tree` contract alone. Replace the
   node type or bypass `_exit_tree` (e.g., free the visual but keep a manager entry) and stale
   entries either crash or silently blind the AI. Any rewrite must preserve or formally replace this
   contract.
6. **Mid-teardown spawns** (`gun_fx.gd:494,503`): units die while the scene is tearing down —
   `blood_pool` guards with `is_inside_tree()` twice. New FX spawned from death/damage callbacks
   need the same guard.
7. **`test_fake_lights.gd:77` exercises the explosion path.** Any new Light3D anywhere in the new FX
   fails the build — good — but the test must be EXTENDED to cover new fire/smoke classes, or the cap
   is guarded only where the old code lived.

This is the strongest argument FOR heavy reuse: `gun_fx.gd`'s architecture (caps, `_expire`,
`reset_session`, validity pruning) is scar tissue from real bugs. A rewrite discards paid-for lessons.
**Demand: new FX extends the existing lifecycle skeleton; it does not get its own.**

---

## 5. Visual truth: prettier smoke and fire will LIE unless the pass is geometry-first

Constraint 5 is where "realistic" and "gameplay" collide hardest, and nobody has priced it:

- `blocks_sight()` (`smoke_cloud.gd:15-28`) is a **hard-edged sphere test** feeding LIVE AI perception
  (`enemy_base.gd:752,866`). Realistic smoke has wispy translucent edges. The moment the rendered
  volume is billowy and soft, its edge no longer matches the binary sphere: the player WILL stand in
  visually-convincing haze and be shot through it (reads as cheating AI — a Pillar 1 fairness wound),
  or hide behind thin wisp that fully blinds the AI (reads as exploit). The current ugly sphere is at
  least an honest sphere. Ratifiable rule: **rendered opaque core ≥ and ≈ the `current_radius()`
  sphere at all ages** — including the grow-in (0–3s) and the 5s fade-out, which the visual must track,
  not just the steady state.
- Same for FireHazard: the cylinder is ugly but its radius IS the damage radius (`radius * 0.9`,
  `fire_hazard.gd:29`). Scattered "real" flame clumps with gaps invite the player to read safe lanes
  that do not exist. Damage ticks every 0.5s for 12.5 — walking a fake gap costs real HP.
- AmbientWar (`ambient_war.gd:77`) calls `_spawn_explosion_visual(self, pos, 12.0, 2.5)` — the SAME
  visual at 12x scale for 200–800m horizon events, and parents to ITSELF (not current_scene), the one
  caller with different teardown. A redesign tuned for a 5m grenade must be verified at 12x: particle
  counts, velocities, and fill-rate all scale, and a "realistic" fireball that looks right up close
  may look absurd or cost a full screen of overdraw as a 14m billboard on the horizon.
- `MAX_EXPLOSIONS = 6` is load-bearing fairness-adjacent state: the siege (d50 arty rounds) and CAS
  strafes already saturate it (prior DA analysis, 2026-07-28). If the new visual is longer-lived
  ("realistic" smoke lingers), the cap saturates EARLIER and later shells in a barrage render
  NOTHING — an explosion with audio and damage but no visual is a fairness telegraph failure. Longer
  lifetime and the cap must be retuned TOGETHER, and the fairness-exemption note (ADR-026 A.1) says
  the POP may not die.

**Sacrificed by truth-first:** the prettiest smoke. A volume forced to honor a sphere will always look
somewhat like a sphere. That is the correct trade; the alternative is a game that lies.

---

## 6. Fossil law: name the corpses NOW, or this ships as two smoke systems

ADR-023 demands the replacement delete its predecessor in the same change. The kill list, explicit:

- **SmokeCloud's `SphereMesh` visual** (`smoke_cloud.gd:45-56`): the mesh dies, the CLASS lives —
  `blocks_sight`, `active_clouds`, `current_radius`, the `_exit_tree` contract, and the
  `smoke_color` export (goofy-grape marking smoke is a REAL signaling feature at `player.gd:863`
  default-overridden — new visuals must still take a color).
- **FireHazard's cylinder** (`fire_hazard.gd:26-40`): self-declared "placeholder VFX." The comment
  says "+ light" — verify no Light3D actually ships in the replacement; test_fake_lights must cover it.
- **The explosion quad+particles body of `_spawn_explosion_visual`** (`gun_fx.gd:133-185`): replaced
  in place. The SIGNATURE (parent, pos, scale_mult, lifetime_mult) is API — `ambient_war.gd:77` and
  `game_world.gd:227` call it directly with the multipliers; break it and the horizon war and the
  test hook break.
- **What must NOT die:** `play_explosion_3d`'s audio delegation (a documented facade, per the
  dead-code audit), the caps + `reset_session` + `_expire` skeleton, `FLASH_SECONDS` (fairness floor
  — untouchable by decree), and the muzzle-flash path (not in the ask; scope-fence it out).

The classic failure here: new "FXManager.spawn_smoke()" lands, old `SmokeCloud.spawn_at` stays
because `blocks_sight` needs the class, and six months later an agent "fixes" AI smoke-blindness by
wiring the wrong one. **Two ways to make smoke is exactly the fossil the law forbids.** If a new
entry point is created, every one of the callers enumerated above migrates in the same change and the
old path is deleted, or the pass keeps the existing entry points and swaps only their bodies (my
strong preference — zero caller migration, zero fossil risk).

---

## Verdict shape (the one condition)

I do not oppose the goal — the placeholder sphere and cylinder are self-confessed placeholders, the
flipbook path is proven in-repo, and Pillar 2 is real. I oppose the WORD. Bless the work only as:
**"period-correct 2002-school FX (flipbook sprites + sprite particles), swapped into the EXISTING
entry points and lifecycle skeleton, geometry slaved to gameplay truth, with a before/after windowed
barrage bench recorded in PERF_LEDGER.md, and the placeholder meshes deleted in the same change."**
Every clause above is a named sacrifice: no modern-realism ceiling, no new FX architecture, no
prettiest-possible smoke, half a day of measurement tax, no lingering-battlefield-smoke system in
wave 1. Strike any clause and the corresponding failure mode above is not a risk — on this project's
own written history, it is a scheduled event.
