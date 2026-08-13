# BRIEFING — the bench-vs-world scale pipeline (napalm reads as a nuclear bomb)

**Convened:** 2026-08-13 · Arbiter session, per the Summoner's ask in
`production/MORNING_REPORT_2026-08-13.md` ("NEXT SESSION STARTS HERE").

## The Summoner's words (2026-08-12 playtest, verbatim from the report)

> the napalm "comes off like a nuclear bomb", and "the scene I've been testing them in isn't
> the right scale as to what the game world scale is, so there's discrepancies between those
> tools and the pipeline to the real thing."

Standing instruction from the report: **measure before touching any scalar** — nudging the
napalm number without understanding the pipeline papers over a pipeline defect. Precedent:
the size ladder was inert once already (`billboard_keep_scale`, fixed 2026-08-12).

## Measured facts (Arbiter's pre-read — VERIFY, do not trust)

1. **Rendered size per drop.** `scripts/combat/gun_fx.gd:120-138` — `_KIND_SCALE.explosion_napalm
   = 111.0`, `ORDNANCE_VISUAL_MULT = 2.0` → root scale 222. Fireball quad 2.2 m × particle scale
   0.8–1.3 → **~513 m wide per drop, and billboard quads are square, so ~513 m tall.**
2. **The game never fires one drop.** `scripts/vehicles/cas_airplane.gd:405-422`
   `_drop_napalm_strip`: **9 canisters** (`FirePlan.NAPALM_DROPS`, `scripts/gameplay/fire_plan.gd:31`)
   on 22 m spacing, each impact → `GunFX.play_explosion_3d(..., "explosion_napalm")` (`:419`).
   Nine overlapping ~513 m fireballs ≈ one ~690 m dome.
3. **The metre AGREES bench↔world.** `scripts/levels/vfx_range.gd:73-92` builds a true-size 512 m
   ruler; `:244` fires the same GunFX path, same default mult. No unit mismatch exists.
4. **The instrument lies three other ways:**
   - **Vantage** — bench camera `(0, 300, 900)` FOV 70 (`vfx_range.gd:32-33,126-128`) ≈ 949 m
     slant range; the demo player is at eye height 1.7 m INSIDE the square, FOV 75, early strike
     at `NAPALM_RANGE_M = 210` (`scripts/levels/demo_game.gd:233-234`).
   - **Composition** — the bench fires ONE `explosion_napalm` per key (`vfx_range.gd:241-244`);
     the game fires nine, always.
   - **Context** — the bench has no treeline, no structures, no men. The Summoner's 8/4 anchor
     was "above the treelines"; the only ruler present on the bench is the map square.
5. **Velocity scaling.** `gun_fx.gd:273-290` `_burst` uses `local_coords = true` — node scale
   multiplies particle velocities. At root scale 222, fireball particles rise at ~133–355 m/s;
   embers at ~555–1330 m/s. The plume climbs like the thing he named.
6. **History.** Every size judgment before 2026-08-12 was made on a DISCONNECTED lever
   (`billboard_keep_scale=false`; see gun_fx.gd:186-191 comment and memory
   `godot-billboard-discards-node-scale`). The 8/12 map-width re-anchor on the god-cam bench was
   the first live tuning; his ground-level playtest the same night was the first honest look.
7. **Damage is untouched by all of this** — `NAPALM_BLAST_M = 30`, 9 × FireHazard patches on
   22 m spacing = the ~240 m burning lane, which he liked. No damage figure reads the visual mult.
8. **Suite exposure** — `tools/probe_fire_parity.gd` PRINTS the ladder (`:46-50`), gates only
   behaviour (canisters, fires, felled). Nothing else found reading `_KIND_SCALE`. Verify.
9. **Second bench** — `scripts/levels/support_fire_range.gd:17` `FIELD := 200.0`, handed to
   `FireSupportBench.wire(self, player, FIELD)` (`:133`) as `map_size`, vs the demo world's 512
   (`demo_game.gd:5`). A real bench/world divergence — in scope or not, rule on it.

## Standing rulings in tension (all three are his)

- **2026-08-04:** napalm = "a very very very large explosion chain that goes above the
  treelines" (memory `recon-explosion-scale-decree`). The chain is the subject; the treeline
  is the yardstick.
- **2026-08-05:** "a rolling huge explosion" → `fire_plan.gd:26-34`: A NAPALM RUN IS A ROLLING
  WALL — a ~236 m lane, 60 m wide, burning 25 s.
- **2026-08-12 (through the lying instrument):** ladder "stated in map widths — napalm ~513 m,
  the whole square" (memory `recon-military-fire-pack`).
- **2026-08-12 night, in the world:** "comes off like a nuclear bomb" — his conviction of the
  current read. The world is the final bench.

## The question before the council

What is the defect, what is the fix, and in what order — such that a size ruling made on a
bench TRANSFERS to the game world and the Summoner's eye rules on the truth? Name what each
option sacrifices. Damage numbers are out of scope. His feel-discharge (ADR-015) is out of
reach — nothing here ships as "verified" without his eyes.

## Constraints

- Pillars: 1 (believable firefights) and 2 (atmosphere) are live here. Rule-one: fun Vietnam.
- FOSSIL LAW / NO-MORE-DRIFT: touched files get their stale comments corrected in the same
  change (gun_fx.gd header arithmetic vs dict comments have drifted — e.g. "mortar ~37m" vs
  computed ~46 m).
- Content-first-optimise-later: no speculative perf work.
- The demo ships 2026-09-06; smallest change that makes the instrument honest wins.
