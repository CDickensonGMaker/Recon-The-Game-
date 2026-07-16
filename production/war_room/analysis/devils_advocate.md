# Devil's Advocate — ADR-026 "THE PS2 BUDGET" (DRAFT, amended)
**War Room 2026-07-16 · RECONgame**

Read code, not the plan. Sources: `scripts/combat/gun_fx.gd`, `scripts/levels/ai_stress_arena.gd`,
`ADR-005` (witness rule), `ADR-013` (world streaming), `terrain/water/water_system.gd`,
`scripts/enemies/enemy_base.gd`.

**Amendment (Summoner, via Overseer):** entity cap DROPPED. PS2 Budget is GRAPHICS ONLY (fake/limited
real-time lights, fog-walled draw distance + hard LOD, low-poly vertex-lit veg, sprite/plane water).
Big firefights are a PILLAR — target real 30v30 (~60 combatants), all visible + animated. CPU solved by
**activity-tiered AI** (a fully-simulated "hot-set" + cheap behaviors on the rest + promote-on-death
reassignment owned by EnemySquad), NOT by culling. My verdict re-aims to this.

The perf wound (19 fps night jungle) is real. Uncapped bodies + compute-tiering is the *right* call — it
dodges the culling landmine below. But three holes still bind, and the cheap-tier design has one trap that
recreates the very Law-breakage the cap would have caused.

---

## HOLE 1 (was BLOCKER, now the ARGUMENT FOR the amendment) — never cull, but the cheap tier must not go blind

Culling as `set_physics_process(false)` (the pattern at `enemy_base.gd:121, 2243, 2304`) turns off
perception, LOS, and NoiseBus receive. ADR-005 stamps the mission COMBAT beacon ONLY on a **witness** — a
living enemy other than the victim with LOS or a NoiseBus hit (ADR-005:36-39, 44) — so a culled/slept unit
100-140m off can neither witness a loud kill nor be witnessed/killed persistently. Culling silently
inverts the Pillar-3 stealth fix that closed days ago and voids squad permadeath. **This is exactly why
the amendment is right: keep the bodies, tier the compute.**

**The trap the amendment inherits:** "cheap behaviors on the rest (move/hold/suppress/fire-in-general-
direction)" must NOT drop the **perception + NoiseBus heartbeat.** If the cheap tier skips its awareness
tick to save CPU, a cold-tier unit becomes functionally slept for ADR-005 purposes — same beacon
breakage, arrived at through the tier system instead of through culling. The witness heartbeat is cheap
(a distance check + occasional LOS/noise poll); it is the thing that must survive tiering. Compute-tier
the *expensive* AI (cover selection, grenade arcs, flanking pathfinding), never the perception that the
alarm Law rides.

**Guard-rail clause the ADR needs:**
> Activity-tiering governs render/animation LOD and **expensive** cognition (cover, grenades, flanking nav)
> only. The perception + NoiseBus heartbeat (witness eligibility per ADR-005) and persistent state
> (HP/alive/alert/last-known) tick on **every tier, hot and cold**, at every distance. No unit is ever a
> non-witness because of its AI tier. `set_physics_process(false)` is never used to shed AI cost.

---

## HOLE 2 (BLOCKER for the recon/sniper fantasy) — Fog-wall vs Pillar 3 long sightlines AND a FAIRNESS break

Still fully in scope (graphics). ADR-013 loads the 1280m AO whole and resident **specifically because**
"the far edge of the map is visible" on "hillside sightlines" (ADR-013:19-20). Pillar 3 names "open AO,
any route, **long sightlines**," sniper/recon. A short fog wall hides that far edge — the fog is a wall
over un-rendered geometry, i.e. a soft gate on an open map.

**Sharper: a FAIRNESS collision.** AI open-ground sight cap = **SIGHT_CAP_OPEN 140m** (`ai_stress_arena
.gd:515`, driving `enemy_base._sight_cap()`). If player draw distance < AI sight cap, the AI fires from
inside the fog at a player who cannot render the AI's body. The near-miss telegraph (tracer from the murk)
fires, but the player can never locate or return fire. Recon fantasy dead.

**Guard-rail clause the ADR needs:**
> Player draw distance ≥ AI `SIGHT_CAP_OPEN` (140m) at ALL times, and ≥ the longest weapon's effective
> range. An AI may never acquire or fire on a player the player cannot render. Fog is a weather- and
> elevation-modulated atmosphere layer, never a fixed render wall: clear weather / high ground reopens the
> far edge (ADR-013 premise stands). A fixed draw distance below 140m is an ADR-level change, not tuning.

---

## HOLE 3 (BINDS) — Fake muzzle flash + the flash CAP vs the FAIRNESS LAW

`gun_fx.muzzle_flash()` (`gun_fx.gd:241-273`) is ALREADY a real `OmniLight3D` (energy 3.0, range 7m) PLUS
two emissive billboard quads, ALREADY capped: `if _active_flashes >= MAX_FLASHES: return` (`:242`).

1. Killing the real light is FINE for the telegraph — the player reads the emissive sprite + tracer, not
   the 7m bounce. Mitigable.
2. **The cap is the landmine.** The early-return drops the **entire** node — light AND telegraph sprites.
   A tightened light cap over a 30v30 firefight will routinely hit it, and the dropped shot could be the
   **first shot at an unaware player.** The FAIRNESS LAW says muzzle flash ALWAYS telegraphs. A cap that
   can eat the telegraph breaks the Law by omission. Light and telegraph are one node today.

**Guard-rail clause the ADR needs:**
> Muzzle-flash **sprite/tracer/report audio are FAIRNESS-CRITICAL telegraphs, exempt from every light/LOD/
> flash cap.** Caps throttle the atmospheric bounce LIGHT only; the telegraph renders unconditionally. The
> first shot at an unaware player renders its full telegraph with no cap check. Split `muzzle_flash()` so
> light and telegraph gate independently.

---

## HOLE 3b (new, from the amendment) — "fire-in-general-direction" cheap tier vs the FAIRNESS LAW

The cheap-tier behavior "suppress / fire-in-general-direction" is a second fairness risk. If a cold-tier
unit fires without real LOS/aim resolution, it can (a) put rounds through the player with no muzzle-flash/
tracer telegraph if the cheap path skips FX, or (b) "suppress" a player who was never seen — a first shot
at an unaware player that is NOT a near-miss. The FAIRNESS LAW binds every shot regardless of AI tier.

**Guard-rail clause:**
> Any tier that discharges a weapon emits the full FAIRNESS telegraph (flash sprite + tracer + report) and
> obeys the first-shot-is-a-near-miss rule. Cheap-tier "fire-in-general-direction" is suppressive fire into
> the environment, never a resolved hit on an unaware player. A unit that cannot pass the fairness check
> does not get to fire on the player — it stays suppressing or promotes to hot-set first.

---

## HOLE 4 (FOSSIL LAW) — two ways to make a flash, and two AI target paths

Four live real-light paths exist: `gun_fx.muzzle_flash` OmniLight (`:248`), `gun_fx` explosion OmniLight
(`:116`), arena campfire OmniLight (`ai_stress_arena.gd:493`), `IllumFlare` (OmniLight). Water is a real
batched `ArrayMesh` + `water_static.gdshader` (`water_system.gd:231-269`), not a plane. A parallel
fake-flash / plane-water path left beside these = **two ways to make a muzzle flash**, the exact FOSSIL-LAW
(ADR-023) condition: "multiple things interpreted as the same thing."

**Second fossil risk from the amendment:** "promote-on-death reassignment owned by EnemySquad" must be
THE single targeting/coordination authority. `enemy_base.gd` already carries per-unit target selection
(`:730-739`, `_nearest_*`). If the EnemySquad hot-set owner and the per-unit path both assign targets, you
get two coordinators — a fossil in the making.

**Guard-rail clause the ADR needs:**
> DRAFT authorizes no parallel path. A fake-flash/plane-water system deletes the real OmniLight/ArrayMesh
> predecessor **in the same change** (ADR-023), or is explicitly scoped as future work with the fake path
> forbidden to ship beside the real one. Hot-set promotion/reassignment is owned by exactly one
> coordinator (EnemySquad); per-unit target selection it supersedes is deleted, not left dormant.

---

## Verdict on the amended decree

Graphics-only + uncapped 30v30 + activity-tiered AI is the correct shape — it sidesteps the culling
landmine that would have voided ADR-005. Ship it ONLY with: the perception/NoiseBus heartbeat exempt from
tiering (Hole 1), player draw distance ≥ 140m AI sight cap (Hole 2, blocker), the fairness telegraph
exempt from the light cap (Hole 3), the cheap firing tier bound to the fairness check (Hole 3b), and one
FX path + one hot-set coordinator (Hole 4). Hole 2 is the one hard blocker; the rest are guard-rails.
