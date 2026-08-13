# UX DESIGNER — the honest instrument (napalm scale bench)

**Session:** 2026-08-13_napalm_scale · Independent analysis, code read directly, briefing pre-read re-verified.
**Charge:** specify what the bench must SHOW so a size ruling made on it transfers to the game world.

---

## 1. What the instrument shows today (verified in code)

**The draw.** One napalm drop renders at root scale `_KIND_SCALE.explosion_napalm 111.0` ×
`ORDNANCE_VISUAL_MULT 2.0` = 222 (`scripts/combat/gun_fx.gd:132,138,158-162`, applied at
`:321`). Fireball layer: 2.2 m quad (`:370-371`) × particle scale 0.8–1.3, mean 1.05
(`:356-357`) × 222 = **mean ~513 m wide (range 391–635 m), and billboard quads are square, so
~513 m tall**, centred 155 m up (emitter y 0.7, `:372`, × root scale via `_burst` `:282`).
`local_coords = true` (`:279`) scales velocities too: fireball sprites leave at 133–355 m/s
under +266 m/s² upward gravity (`:352-355` × 222) — the bright phase climbs ~666 m in the
first 1.3 s and the smoke tail tops ~2.5 km.

**The event.** The game never fires one drop: `_drop_napalm_strip` fires
`FirePlan.NAPALM_DROPS` = 9 canisters (`scripts/gameplay/fire_plan.gd:31`) on 22 m spacing
(`:32`), 0.1 s ripple (`NAPALM_STAGGER`, `scripts/vehicles/cas_airplane.gd:26,405-422`), each
impact calling the same `GunFX.play_explosion_3d(..., "explosion_napalm")` (`:419`).

**The bench (vfx_range).** Camera fixed at (0, 300, 900), rot −17°, **FOV 70**
(`scripts/levels/vfx_range.gd:32-33,123-128`) — 949 m slant to ground zero, ~912 m to the
fireball centre. Fires **one** drop per key (`:241-244`). Yardsticks: the 512 m map-square
outline (`:73-92`) and, only in the row view, 10 m poles (`:288-303`). No treeline, no man,
no structure anywhere in the scene. Row view camera (0, 900, 2100) (`:41`) stands **3132 m**
from the row line (`:40`).

**The game's vantages (demo_game).** Player eye 1.7 m (ADR-034 contract; `scripts/player/
player.gd:211-212` FOV 75, `scripts/player/weapon_holder.gd:36` BASE_FOV 75). Early beat:
napalm at `NAPALM_RANGE_M` = **210 m** from fsb centre while the player is still inside near
the centre (`scripts/levels/demo_game.gd:233-234,274-277`). Siege beats walk napalm in at
**210 / 195 / 185 m from centre** (`:258-266`) — but the player at the parapet facing the
assault (parapet radius ~96 m, `:471-473` comment) is **~90–115 m** from those strikes. The
strip is laid ACROSS the view (`:304-311`), so its length reads as width on screen.

**The treeline yardstick (measured art, not estimate).** `data/veg_break_bands.json` —
generated from the GLBs: tallest species `broadleaf_c` top 13.378 m (`:89`), `broadleaf_b`
11.19 m, bamboo to 8.22 m, palms 5.1–8.1 m. Instance scale 0.7–1.3
(`terrain/vegetation/vegetation_manager.gd:312`) → **canopy band ~4–17.4 m; tallest possible
treetop 17.4 m; typical mass 6–11 m.**

---

## 2. The angular arithmetic

Projection facts: 1280×720 project window (`project.godot:55-56`) → 16:9. Godot `fov` is
vertical. Bench: vfov 70° → tan(v/2)=0.700, hfov 102.4°, tan(h/2)=1.245. Player: vfov 75° →
tan(v/2)=0.767, hfov 107.5°, tan(h/2)=1.364. A screen-facing billboard of width W centred at
distance D covers **W / (2·D·tan(h/2))** of screen width (same form for height).

### 2a. The current 513 m drop, and the full chain (chain lateral extent = 8×22 + W)

| Vantage | D | one drop, width | one drop, height | 9-drop chain, width |
|---|---|---|---|---|
| Bench god cam (FOV 70) | ~912 m | **23%** | **40%** | 30% |
| Row view camera | 3132 m | 6.6% | 12% | 8.8% |
| Player, early beat (FOV 75) | 210 m | **90%** | **159%** | **120%** |
| Player, closest siege beat (from centre) | 185 m | **102%** | 181% | **137%** |
| Player, siege at the parapet | ~100 m | **188%** | 335% | **253%** |

Vertical read at 210 m: quad top at spawn is 411 m up = 62.8° elevation (screen top when
looking level is +37.5°); the bright-phase column reaches ~666 m = 72.5°; the tail ~2.5 km =
**85° — fire from the horizon to the zenith.** That is the "nuclear bomb", named precisely.

**The lie, quantified.** The same width covers ~4.1× more screen at the 210 m player eye than
at the god cam (573 vs 2355 in the denominator), ~8.6× more at the parapet — before the ×9
composition and the missing treeline are counted. The 8/12 ruling "napalm ~513 m, the whole
square" was made on a frame where 513 m = 23% of screen width. The instrument did not permit
the error; it manufactured it. And the row view — the scene's own comment calls it "the only
honest test" (`vfx_range.gd:267-269`) — is the least honest of all: at 3132 m its 10 m
"absolute ruler" poles render **1.6 px tall, 0.4 px wide** at 720p. A yardstick nobody can
see is scenery.

### 2b. Candidate per-drop widths, both real vantages

k = the `_KIND_SCALE` value that yields W at mult 2.0 (W = 4.62·k). Chain = 176 + W. Flame
top ≈ 0.65·W at spawn. Treetop angles at 210 m: tallest 4.7°, typical canopy 1.6–3.0°.

| W per drop | k | bench god cam w | player 210 m w / h | 185 m w | parapet 100 m w | chain w @210 | chain w @185 | chain w @100 | flame-top elev @210 | × tallest treetop |
|---|---|---|---|---|---|---|---|---|---|---|
| **513 (now)** | 111 | 23% | 90% / 159% | 102% | 188% | 120% | 137% | 253% | 63° (col 85°) | 13× |
| 120 | 26 | 5.1% | 21% / 37% | 24% | 44% | 52% | 59% | 109% | 20.4° | 4.3× |
| 80 | 17.3 | 3.4% | 14% / 25% | 16% | 29% | 45% | 51% | 94% | 13.9° | 2.9× |
| 60 | 13 | 2.5% | 10.5% / 19% | 12% | 22% | 41% | 47% | 87% | 10.5° | 2.2× |
| 50 | 10.8 | 2.1% | 8.7% / 16% | 10% | 18% | 39% | 45% | 83% | 8.8° | 1.9× |
| 30 | 6.5 | 1.3% | 5.2% / 9.3% | 5.9% | 11% | 36% | 41% | 76% | 5.3° | 1.1× |

Reading the table:

- **The spacing, not the drop width, carries "very very very large."** The chain's 176 m of
  centres guarantees ~36–52% of the horizon at 210 m and ~76–109% at the parapet at ANY
  candidate W. His 8/4 decree is structurally safe; only the whiteout margin moves with W.
- **W = 30** (k 6.5): flames top ~1.1× the tallest treetop — "above the treelines" only
  technically. Fails the intent.
- **W = 50–70** (k 11–15): chain ~39–43% of the horizon at 210 m; flame crowns 1.9–2.5× the
  tallest treetop and 4–6× the typical canopy angle; single drops 9–13% of screen width, so
  trees, tracers and men survive on screen at every beat; at the parapet the chain owns
  83–90% of the horizon — the climax still swallows the view without erasing it (single drop
  ≤25% width there). Drop-to-spacing ratio 2.3–3.2 keeps nine pulses articulate: it reads as
  a rolling CHAIN (his 8/4 word) not one fused dome.
- **W = 80** (k 17.3): defensible ceiling; parapet chain 94%, drops fusing (ratio 3.6).
- **W = 120** (k 26): 9 drops fuse into one blob (ratio 5.5); the chain identity his two
  rulings name is gone, and the parapet read exceeds the full horizontal FOV.

**Sweet spot: W ≈ 50–70 m per drop → `_KIND_SCALE` ≈ 11–15 (vs 111 today), centre W≈60 /
k≈13.** The number itself stays HIS to discharge (ADR-015) — this band is what the honest
instrument will show as "dominates the sky above the treeline without whiteout."

**Ladder tension to surface, not resolve:** heavy/arty k=24 draws ~111 m — a single arty
flash would out-size a single napalm drop in this band. Per-EVENT napalm still wins (a ~236 m
chain plus a 25 s burning lane vs one flash). The bench must let him fire heavy then the run
back-to-back at the ruling vantage so the ladder gets re-ruled with honest eyes; the 8/12
map-width ladder was ratified on the lying frame.

---

## 3. The honest instrument — specification

### 3.1 Vantage presets (the core fix)

| Preset | Camera | FOV | Job |
|---|---|---|---|
| GOD (existing) | (0, 300, 900), −17° | 70 | Composition, sheet debugging, the 512 m square. **Signed on-screen: "COMPOSITION ONLY — NOT FOR SIZE RULINGS."** |
| **PLAYER 210 — THE RULING VANTAGE** | (0, **1.7**, 210) looking level at the strike line | **75.0** | The early beat and the far siege beats — the demo's designed first impression of napalm. A size RULES here or it does not ship. |
| PLAYER 100 — the whiteout check | (0, 1.7, 100), level | 75.0 | The parapet during the siege sector beats (185–210 m from centre − ~96 m parapet radius). A size PASSES only if the world survives here. |

The ruling is two-sided and both ends must exist: dominate at 210, no erasure at 100.
Anything between (185/195 from centre) is bracketed by monotonicity. Eye height and FOV are
the ADR-034 player contract numbers, not new inventions — the bench camera must never again
run a different lens than the player (the god cam's FOV 70 alone inflates reads ~10% vs 75).
The vantage name renders in the corner label at all times, so any screenshot self-documents
which instrument setting produced it.

### 3.2 The bench must fire the full run — yes

The ruling fire mode is the real event: **9 drops, laid across the view axis** (as
`demo_game.gd:304-311` lays it), spacing read from `FirePlan.NAPALM_SPACING`, count from
`FirePlan.NAPALM_DROPS`, ripple from `CASAirplane.NAPALM_STAGGER` — **referenced, never
re-typed**, the same no-drift principle `fire_plan.gd:2-7` already states for the preview
ring. Implementation is 9 timer-staggered `GunFX.play_explosion_3d` calls; no aircraft
needed. Single-drop keys 1–6 stay exactly as they are — still the right tool for
sheet/flipbook debugging, and the other five kinds' events ARE single. The row view (0)
keeps single drops but gains one caveat label: "napalm shown as ONE DROP — the game fires 9."

### 3.3 Yardsticks in frame (what the ruling frame contains)

1. **A treeline band at the strike line** — real vegetation GLBs (broadleaf_b/c, palms,
   bamboo from `assets/world/vegetation/`), instance scales 0.7–1.3 matching
   `vegetation_manager.gd:312`, planted along the strike axis x ∈ [−150, 150] at z≈0. His
   stated yardstick is "above the treelines"; the fire must rise FROM canopy, as the demo's
   strip lands in the trees (`demo_game.gd:230-233`). Static meshes; no break system. A
   17.4 m treetop at 210 m subtends 5.1% of screen height (~37 px) — readable.
2. **A man-height reference in the FOREGROUND**, ~30 m ahead of the ruling camera, off-axis
   (±12 m): a 1.8 m figure reads ~4% of screen height (28 px) there. At the strike line a man
   is 4 px — useless; foreground placement is the only honest option.
3. **One 50 m height ladder at the strike line edge** (x ≈ +140), 10 m colour bands — "how
   far above the canopy" becomes a measurement (15.5% of screen height at 210 m).
4. **The 512 m square stays** — god-cam furniture, the absolute ruler for "covers the map"
   claims. The 10 m row poles stay for the row view, with no illusions: at the row camera
   they are sub-2 px and judge nothing.

### 3.4 Keys — extend, break nothing

Current map preserved verbatim: 1–6 kind, SPACE next, A auto, F hazard, G grid, 0 row,
R reset (`vfx_range.gd:209-233`). Add exactly two keys:

- **N** — fire the full napalm RUN at the current vantage (3.2).
- **V** — cycle vantage GOD → PLAYER-210 → PLAYER-100 → GOD. R still snaps home to GOD
  (existing muscle memory untouched).

Hint line (`:179-182`) gains one sentence: "N napalm RUN (9 drops) · V vantage — SIZE
RULINGS AT PLAYER VANTAGE ONLY." The ruling loop becomes: V V → N → watch ~8 s → judge
against canopy → V → N → whiteout check → adjust → repeat. Two keystrokes per look.
Note: auto-cycle's 2.2 s period (`:23`) truncates napalm's 7.2 s visual
(`gun_fx.gd:498`: 1.6×2.6+3.0) — auto mode is a montage, never a judge; the signage on
the god cam covers this.

### 3.5 `support_fire_range` FIELD = 200 — not a defect; leave it

`FIELD` is handed to `FireSupportBench.wire(self, player, FIELD)` as `map_size`
(`scripts/levels/support_fire_range.gd:17,133` → `scripts/levels/fire_support_bench.gd:121,135`).
`map_size` is read by FieldDirector ONLY to clamp hunter LZ bases and decoy positions
(`scripts/missions/field_director.gd:179-180,1355-1358`), and the bench zeroes the hunter
pool anyway (`fire_support_bench.gd:157`). `cas_airplane.gd` never reads `map_size` — zero
hits. **No strike geometry, drop pattern, or visual is touched by FIELD.** That bench's job
is behaviour (cover lab, breach chain, suppression gauges — `support_fire_range.gd:3-15,
100-116`) and it is unharmed. In fact its [2] key already fires the REAL 9-drop run through
the real FieldDirector tier at player eye height (`fire_support_bench.gd:148-156` →
`cas_airplane.gd:405-422`) — it independently confirms the vantage finding — but it cannot be
the ruling instrument: strike distance rides his aim, so there is no fixed, repeatable frame,
and a ruling needs a repeatable frame. Optional one-line header note ("FIELD is bench
furniture, not the demo map; size rulings live on vfx_range's player vantage") to stop the
next architect from "fixing" it.

### 3.6 Fossil-law riders (same change that lands any new scale)

- `gun_fx.gd:113-119` header ladder ("napalm ~513m", "mortar ~37m" vs computed ~46 m) —
  recompute in place.
- `vfx_range.gd:28-30` ("Napalm now reads ~90m wide" directly above "napalm ~513 m" layout
  constants — the comment already contradicts its own file) and `:37` ("spacing must clear
  napalm's ~513m read") — correct on contact.

---

## 4. What this sacrifices (Law 2)

1. **The bench gains a second job.** The diagnostic scene (control quad vs game path) now
   also carries ruling furniture: ~100–150 lines, two keys, a vantage state, tree props. The
   alternative — ruling on a lying frame, or 24-minute demo boots per look — costs more.
2. **Iteration speed at the ruling vantage.** A full run takes ~8 s to play out vs the god
   cam's instant pop; the whiteout check doubles it. ~15–20 s per candidate against ~3 s
   today.
3. **The row view stays structurally unfair to napalm** (single drop in a row of singles);
   a caveat label mitigates, does not fix. Fixing it would clutter the one-glance comparison
   the row exists for.
4. **The bench run is still not the world.** GunFX-only: no FireHazard burn lane (the 25 s
   lane he liked), no night lighting (the siege is at night; fire reads bigger against
   dark), no tracer competition, no siege framerate. The instrument becomes honest about
   GEOMETRY — vantage, composition, context — not about everything. ADR-015 stands: nothing
   ships as verified without his eyes in the world.
5. **God-cam habits die.** Every size intuition he built from (0, 300, 900) is invalidated
   on purpose; the first honest session will feel like re-learning the tool.
