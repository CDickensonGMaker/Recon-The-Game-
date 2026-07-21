# WAR ROOM — THE PLACED FIRE MISSION, 2026-07-20

Arbiter: inline council (no subagent fan-out — the Summoner was mid-session and the
findings were measurable rather than contested). Shipped as `37af5f6d`.

## THE ASK

Summoner, testing the RTO net in the AI stress arena: *"i was working on the ai stress
test with the RTO and how fire support works and with a visual to see where your fire
support mission goes"* — then, refining it: *"thats different depending on what youre
calling. small or bigger circle for mortar or artillery and than the napalm and spooky
are various sized large rectangle you place. after you grab the radio and choose your
fire misison you get a preview of what youre dropping"* — and on orientation: *"i would
envision they come in over the right horizon and speed to the left but either way the
preview is a perpendicular rectangle to the players FOV so its easier to call in major
strikes fast"*.

## THE MEASURED STARTING STATE (read from code, not from a plan)

Two defects in the same loop, both verified before any design:

**1. The call was blind.** `mission_hud.gd:162-180` took a number key and
`field_director.gd:240 request_fire_support()` immediately raycast the ground under the
crosshair (`_cas_ground_target()`, `:509`), spent the mission and dispatched. Nothing
showed the aim point, the footprint, or that the player's own squad stood inside it.

**2. Nothing that killed you existed.** Every one of the six calls was a
`create_timer()` plus an instant area-damage call:

| Call | What flew | What killed |
|---|---|---|
| Mortar | nothing | 3s timer → AoE 140/r10 (`field_director.gd:427-432`) |
| Arty | nothing | 6 timers → AoE 200/r14, 2 of 6 crater |
| Snake Eye | the plane; no bomb left it | 0.8s timer → AoE 220/r16 + crater + 40m suppression |
| Napalm | nothing fell | 5 timed AoEs — the `FireHazard` burn WAS real (r10, 15s, 25dps) |
| CBU | nothing | 16 timed micro-AoEs 55/r5 in an ellipse |
| Spooky | tracers were **cosmetic** | proximity check: within 4m takes 60 (`spooky_gunship.gd:79-85`) |

**The pipeline to fix it already existed and fire support had never used it:**
`ProjectileData` → `ProjectileBase` (gravity `:225`, arming, AoE detonation `:355`) →
`CombatManager.spawn_projectile` (`:289`). `data/projectiles/m79_he.tres` was already an
arcing HE round. **No new projectile system was needed, and none was built.**

## THE FINDING THAT RESHAPED THE WAVE

`projectile_pool.gd:29-31` capped at **30 active** and, when full, silently evicted the
**oldest** active round. A CBU dispenser opening (16 bomblets) or a Spectre burst would
have recycled an artillery shell in mid-air — **the footprint drawn, the explosion never
arriving.** The preview would have become a liar on the day it shipped.

Worse, the obvious probe misses it: an evicted round is handed straight back out as the
next bullet, so it is still `is_instance_valid` and still `is_active`. The assertion has
to ask what the round is **carrying**, not whether it lives. That correction was made
only because the mutation test failed to bite the first time.

## RULINGS (Summoner)

1. **Both waves in one run** — warheads first, because the preview must promise what the
   ordnance delivers.
2. **The gunship becomes an AC-130 Spectre.** He was told the AC-47 Spooky was the
   period-correct aircraft (the mixed battery is 1968+) and chose the weapon over the
   date. Per the FOSSIL LAW, Spooky was **deleted**, not parked beside it. Bead `c69o`
   carries the anachronism to an ADR.
3. **LMB commits, RMB cancels.** The number key ARMS and spends nothing.
4. **Spectre previews as a circle** — its true beaten zone. The preview does not lie to
   match a mental picture. Same reasoning kept CBU an **ellipse**: its bomblets fall in
   an ellipse, and a rectangle would claim four corners of coverage that do not exist.
5. **Run-delivered ordnance flies broadside** — in over the right shoulder, out to the
   left — so the strip lies across the view at readable length.

## THE ARCHITECTURE DECISION THE COUNCIL FORCED

The plan as approved had FirePlan *reading* the weapons' constants. That is a **cyclic
script dependency** in GDScript (`FieldDirector` → `FirePreview` → `FirePlan` →
`FieldDirector`) and would not have parsed. Inverted: **`FirePlan` OWNS every sheaf,
blast and pattern figure, and the weapons read from it.** One direction, consumers →
table. That is also the stronger version of the original goal — there is now exactly one
place these numbers live, and the shape drawn cannot drift from the ground covered.

Second correction: rather than copy damage values into the new `.tres` files, the old
impact functions became the shell's `terminal_effect` callback. **No damage number moved,
and none was duplicated.** The `.tres` carries flight only.

## WHAT THIS SACRIFICES (named — no free lunches)

- **A ground reticle is not diegetic.** No 1967 grunt saw a glowing ring on the earth.
  Bought because a screen has no depth cues and blind calling is guesswork rather than
  difficulty — but it is a real concession against Pillar 2, and it is the one thing in
  this wave the playtest bead (`qqor`) asks him to overrule if it reads wrong.
- **Fire missions got slower** — two inputs instead of one. In a hot contact that is a
  real cost, paid to stop him dropping artillery on his own point man.
- **Real ordnance costs frames.** Six warhead types through a pooled Area3D on an already
  CPU-bound frame (ADR-026). Mitigated by keeping 20mm saturation as tracers and the
  40mm as the only pooled gunship round, but a Spectre call plus a CBU run is now the
  heaviest moment in the game.
- **The broadside run retires the old approach vector.** The fast mover no longer flies
  up the player's line of sight.
- **One table speaks for six ordnance types.** `fire_plan.gd` is probe-locked, but it
  remains the one place a lie could live if edited by hand.

## VERIFICATION

`tests/test_fire_mission` — 36 assertions. **Mutation-checked**: the naive pool eviction
and the dropped integrator correction were both reintroduced, both observed to FAIL, then
reverted to green. The arc solver measures **0.000m** miss at 4s (0.33–0.49m with the
correction removed).

Guards green on assertions: `test_handset_fire_net`, `test_firebase_defense` (33/33),
`test_arena_sandbox`, `test_fire_support_grant`, `test_flat_damage`, `test_night_sight`,
`test_rto_point_hud`, `test_field_item_hud`, `test_autoload_api`.

Fossil count **23 → 22** — one buried (`clear_all_projectiles`), none added. The probe is
red both before and after; the 4 flagged symbols (`world_sim` ×3, `weapon_data.get_bore_dir`)
were **measured identical at HEAD on a clean tree**, not assumed.

The arena boots clean: fire support wires, zero script errors over 45s of headless runtime.

## OPEN

- `qqor` (P1, awaiting-summoner) — the playtest. Four questions a probe cannot answer.
- `c69o` (P2) — record the Spectre anachronism in an ADR.
- `zo81` (P2) — the arena has no fire-menu list; calls are discoverable only by toast.
