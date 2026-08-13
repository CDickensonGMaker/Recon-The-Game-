# GAME DESIGNER — Napalm & the Ordnance Visual Ladder: what it should READ as

War Room 2026-08-13_napalm_scale · independent analysis (no other architect files read).
Everything below was re-derived from code and canon, not taken from the briefing's pre-read.

## 0 · What I verified myself

- Rendered width = fireball quad 2.2 m (`scripts/combat/gun_fx.gd:370`) × particle scale 0.8–1.3,
  avg ~1.05 (`gun_fx.gd:355-357`) × `_KIND_SCALE` (`gun_fx.gd:120-133`) × `ORDNANCE_VISUAL_MULT`
  2.0 (`gun_fx.gd:138`) ⇒ **scale × 4.62 m**. Napalm 111 → **~513 m**; heavy 24 → **~111 m**;
  mortar 10 → **~46 m**; rocket 4.0 → 18.5 m; grenade 1.0 → 4.6 m; 40mm 0.7 → 3.2 m.
- The game never fires one napalm drop: the only world caller is `_drop_napalm_strip`
  (`scripts/vehicles/cas_airplane.gd:405-422`) — 9 canisters (`scripts/gameplay/fire_plan.gd:31`)
  on 22 m spacing (`:32`), rippled 0.1 s apart (`cas_airplane.gd:26`, `:413`) so the chain marches
  up the run nearest-first. Each impact lays a 30 m-radius, 25 s FireHazard patch
  (`cas_airplane.gd:418`, `fire_plan.gd:33-34`, `scripts/vehicles/fire_hazard.gd:35-52`).
- The authored damage/burn lane is **~236 m × 60 m**: `fire_plan.gd:87` footprint `along` =
  8×22 + 2×30 = 236.
- The treeline, measured: `data/veg_break_bands.json` (generated, not authored) — jungle palms
  top out 5.1–8.1 m, bamboo 4.9–8.2 m, broadleafs 8.6–**13.4 m** (`broadleaf_c.top_m`). The
  tallest thing in this world's canopy is 13.4 m.
- Demo geometry: early strike at 210 m from `fsb_center` (`scripts/levels/demo_game.gd:233-234`),
  laid TANGENTIAL so the lane faces the player broadside (`demo_game.gd:302-311`); authored
  treeline runs to ~149 m, siege rallies at 150 m (`demo_game.gd:230-232`). Player eye 1.7 m,
  hip FOV 75 (CLAUDE.md ADR-034 block; `demo_game.gd` boots the real player).
- The siege air show: `SIEGE_AIR_BEATS` (`demo_game.gd:258-266`) — GUNS_NAPALM at 210 m and
  185 m, NAPALM at 195 m, all "sector"; the early beat is MORNING (clock 35 s ≈ sim 06:52,
  `demo_game.gd:43,48,233`), the siege beats are NIGHT (after the ~1184 s seam, `demo_game.gd:47-55`).
- The bench that produced the 8/12 numbers: camera at (0, 300, 900) (`scripts/levels/vfx_range.gd:32-33`)
  ≈ 949 m slant; fires ONE kind per key (`vfx_range.gd:19-22`); the ONLY ruler in the scene is the
  512 m square, built explicitly AS the ruler (`vfx_range.gd:70-73`). No treeline, no chain, no
  eye-height. Second bench: `scripts/levels/support_fire_range.gd:17` `FIELD := 200.0` — a
  different square entirely.
- Callers the briefing did not name (they decide the ladder question):
  - Sapper satchels die with `explosion_heavy` (`scripts/enemies/placed_satchel.gd:69-71`) —
    a 111 m fireball ON THE WIRE, metres from the player, during the breach chain.
  - VC mortars land `explosion_mortar` inside the compound (`scripts/missions/siege_director.gd:705`);
    friendly mortars too (`scripts/missions/field_director.gd:1100`); arty shells are
    `explosion_heavy` (`field_director.gd:881`); the Snakeye bomb too (`cas_airplane.gd:396`).
  - **Thatch/timber huts DIE with `explosion_napalm`** (`scripts/world/destructible.gd:42-44`),
    fired at the full default mult (`destructible.gd:177-178`). Today every village hut death is
    a 513 m fireball. `explosion_napalm` serves two masters: the run's per-drop AND the biggest
    fire-flavoured structure death.
  - Bunkers die with `explosion_mortar` (`destructible.gd:50-51`) — 46 m bursts inside the base.
- Fireball emitter height scales with the root: `_burst(..., y=0.7)` (`gun_fx.gd:372`) × root
  scale 222 puts today's napalm fireball CENTRE ~155 m off the ground — a detonation floating in
  the sky, which is a nuclear read all by itself.

---

## 1 · THE ANCHOR — physical yardstick (treeline), not map fraction

**Ruling: the canon anchor for ordnance visuals is the PHYSICAL YARDSTICK — canopy multiples and
the real-ordnance envelope, dramatized by a uniform factor. The 8/12 map-fraction anchor is
overturned as the product of a lying instrument.**

Five arguments, in pillar order:

**(a) A map fraction cannot be perceived from inside the map.** No player at 1.7 m eye height
ever sees "the 512 m square" — the square is not an object in his frame. The treeline is. Scale
is read against in-frame rulers, and the 8/12 session had exactly one ruler present: the square
outline the bench itself builds (`vfx_range.gd:70-73` — "an absolute ruler... something you can
SEE"). The anchor was captured by the instrument's furniture. His 8/4 ruling named the ruler the
GAME provides: *"a very very very large explosion chain that goes above the treelines"* (memory
`recon-explosion-scale-decree`, verbatim). The treeline is the yardstick the player actually has.

**(b) Metres transfer between benches and world; fractions do not.** "Napalm covers the square"
is 513 m on `vfx_range` and 200 m on `support_fire_range` (`support_fire_range.gd:17`). A
treeline-anchored figure in metres is identical on every bench where a tree stands, and identical
in the world. The physical anchor is the ONLY anchor under which a bench ruling can transfer —
which is this council's whole question.

**(c) Pillar 1, believable firefights — "weapons that kill like weapons"
(`production/bible/BIBLE.md:85`).** The visual is the promise of the kill. The damage lane is
236 × 60 m (`fire_plan.gd:87`, `NAPALM_BLAST_M` 30); a ~690 m visual dome promises ten times the
kill it delivers, and men walk unburnt out of the middle of the fireball. That is the Fairness
law's mirror image — the world lying to the player about danger. Anchoring visuals near the
damage envelope (× drama) keeps the promise honest.

**(d) Pillar 2 + the tonal north star.** The canon names its own reference footage:
*"Platoon · Hamburger Hill · Apocalypse Now"* (`BIBLE.md:100-102`); *"Rule of Cool applies to
action; tone stays grounded"* (`DESIGN.md:42`); *"The player should feel present, not entertained
by spectacle"* (`DESIGN.md:48`). The largest image in the entire grunt-film canon is the
Apocalypse Now treeline strike — a fireball a handful of tree-heights tall, frame-wide. Nothing
in the canon is map-scale. Castle Bravo is out of canon, and rule-one fun-Vietnam is a WAR MOVIE
promise, not a Trinity-test promise.

**(e) His own rulings, read in order.** 8/4 named the yardstick (treeline). 8/5 named the shape
(rolling wall → the ~236 m lane, `fire_plan.gd:26-34`). The 8/12 map-width numbers were tuned
through an instrument the record now shows lied three ways (vantage, composition, context). The
8/12 NIGHT conviction — "comes off like a nuclear bomb" (briefing, from
`production/MORNING_REPORT_2026-08-13.md`) — is the only judgment ever made at the shipping
vantage, and it convicts the map anchor's output. Three of his four rulings support the physical
yardstick; the fourth was made blind.

**Where is the line between Apocalypse Now and Castle Bravo?** State it as four testable reads,
because "big" is not a number:
1. **The ruler survives** — treeline visible in the same frame, fireball ~3–8× canopy height.
   Past ~10× canopy (~130 m+ here) no in-frame object can anchor it and the read escapes to
   "nuclear". (513 m = 38× the tallest tree.)
2. **The chain stays a chain** — per-drop width ≤ ~3× the 22 m spacing, so nine cores ripple
   inside a continuous wall. At 513 m/drop (23× spacing) the nine drops fuse into one dome; his
   8/4 subject — the CHAIN — is erased by its own size.
3. **The shape fits the frame at its authored viewing distance** (210 m). 513 m subtends ~68°
   above the horizon against a 37.5° half-FOV — the top exits the screen; an event with no
   visible top has no size, just "everything". Also the nuclear tell.
4. **Low and rolling, not tall and rising.** Napalm's filmic signature is wider than tall,
   hugging the ground. Today the fireball centre floats ~155 m up (`gun_fx.gd:372` y=0.7 × root
   222) and the plume climbs at 133–355 m/s (velocity × root scale, `gun_fx.gd:273-290`) —
   pyrocumulus behaviour. Intent: the event's total top ≤ ~2× the fireball width; the WALL is
   the subject, not the column.

---

## 2 · THE NUMBER — starting value, derived, awaiting his eye

**Napalm: ~65 m per drop (width AND height; billboard quads are square). `_KIND_SCALE` 14.0
(14.0 × 4.62 = 64.7 m). Chain total read: 8×22 + 65 ≈ 241 m of continuous wall.**

Derivation from his rulings — each anchor independently lands in the same band:

- **8/4 yardstick + the ×5 decree:** 5 × the tallest measured tree (13.4 m,
  `veg_break_bands.json` broadleaf_c) = **67 m** — "very very very large... above the treelines"
  paid in the only currency the ground-level eye can spend, and it echoes his ×5 multiplier
  against the biggest physical ruler in the world.
- **8/5 rolling wall:** chain read 241 m ≈ the ~236 m lane `fire_plan.gd:26-34` authored FROM
  that ruling. **Visual wall == damage lane == 25 s burn lane** — three systems, one shape. When
  the fireballs die, the fire on the ground is the same lane the explosion painted; today the
  513 m dome collapses into a 60 m-wide burn and reads as the strike shrinking to 12%.
- **Era reference (briefing-supplied):** real fireballs 30–60 m per canister; the Trang Bang
  wall ~50–60 m. One drop ≈ the most famous napalm photograph in history — and we field NINE of
  them in a rippling chain. The drama lives in the COMPOSITION, which is exactly what "a chain
  that goes above the treelines" asked for.
- **8/12-night conviction:** 65 m is 13% of the convicted 513. For dimension: a ~513 m fireball
  exceeds the Hiroshima fireball (~370 m across, external figure, approximate) — per canister,
  nine times over. His "nuclear bomb" line was not an impression; it was dimensionally correct.

**Honest bracket:** his verbal anchors span [~23 m (×5 of the ~4.6 m bursts his 8/4 eye was
actually watching — the scale lever was inert until 2026-08-12, `gun_fx.gd:186-191`) … 513 m
(what the god-cam chose)]. His eye has literally never seen the middle: pre-fix everything
rendered identical and tiny; post-fix he has only ever seen 513. 65 m is the canon-derived point
estimate inside that bracket. **Offer the band 55–80 m (scale 12–17) and mark the number
AWAITING HIS EYE (ADR-015)** — judged at ground level, ~210 m, treeline in frame, full 9-can
chain, at night AND at the morning beat, never on the god-cam.

Screen check at the early beat (210 m, eye 1.7 m, FOV 75): fireball top ~17° above the horizon
≈ 45% of the sky half; wall spans ~60° of the ~107° horizontal frame — more than half the screen
burning, trees subtending ~2–4° against it (~5× angular dominance). That IS the Apocalypse Now
frame. Emitter height falls to ~20 m (0.7 × root 28) — the fireball sits ON the treeline, not
150 m above it. Climb budget still needs the systems fix: at scale 14 the fastest fireball
particles rise 17–45 m/s over ~3.2 s (`gun_fx.gd:353-357,372`, `_KIND_LIFE` 2.6 + hold) —
up to ~140 m of climb, ~2.7× the width. Intent bound: total top ≤ ~2× width (~130 m); the
mechanism (velocity–scale coupling in `_burst`, `gun_fx.gd:273-290`) is systems' to solve, but
the READ requirement is design's: **the wall rolls; it does not become a column.**

---

## 3 · THE LADDER — the top three move together; rocket and below stand

**Napalm cannot move alone: leaving heavy at 111 m INVERTS the ordained order** (napalm 65 <
heavy 111), violating the ladder law in the dict's own header (ADR-016 read: "an RPG must READ
bigger than a grenade; arty bigger than both", `gun_fx.gd:112-114`) and his explicit order
napalm > heavy arty > mortar > rocket > grenade > 40mm. And the anchor conviction poisons
exactly the values derived FROM the map fraction: heavy ("half the square") and mortar
("geometric middle" to that half-square, `gun_fx.gd:124-126`). Rocket, grenade and 40mm were
never map-derived — they already sit at ~1–1.5× their real envelopes and survived his
ground-level look without conviction. **Convict the anchor; keep what the anchor didn't poison.**

Proposed ladder (rendered width = scale × 4.62; the drama factor over the real-world envelope is
now roughly UNIFORM ~1.2–2×, where today it runs 1× at the bottom and 10–17× at the top —
uniform dramatization is what keeps class RATIOS legible to an era-literate eye; real
napalm:grenade width is ~12×, proposed is 14×, current is 111×):

| kind | scale (now → proposed) | rendered (now → proposed) | yardstick check |
|---|---|---|---|
| explosion_napalm | 111.0 → **14.0** | ~513 → **~65 m/drop; ~241 m chain** | 5× tallest tree; chain == authored lane |
| explosion_heavy | 24.0 → **10.0** | ~111 → **~46 m** | ~3.5× tallest tree; real 155/750 lb burst 30–60 m; satchel on the wire no longer screen-swallowing |
| explosion_mortar | 10.0 → **6.0** | ~46 → **~28 m** | ~2× tallest tree; > rocket 18.5, < heavy 46; ~geometric middle of rocket→heavy |
| explosion_rocket | 4.0 (keep) | 18.5 m | ~1.4× canopy, unconvicted |
| explosion_grenade | 1.0 (keep) | 4.6 m | near-real, unconvicted |
| explosion_40mm | 0.7 (keep) | 3.2 m | near-real, unconvicted |

Order holds at BOTH readings: per-burst (65 > 46 > 28 > 18.5 > 4.6 > 3.2) and per-EVENT (napalm
run ~241 m wall > arty barrage of 8–12 heavies on the sheaf (`fire_plan.gd:21-22`) ≈ 60–90 m
composite > mortar sheaf). The event ladder is where "napalm > arty" really lives — composition
carries the top of the ladder, exactly as the chain carries napalm.

Free wins from the same three edits: the satchel breach blast (`placed_satchel.gd:71`) drops
from 111 m to 46 m at the player's feet; bunker deaths (`destructible.gd:50-51`) from 46 to
28 m; hut deaths (`destructible.gd:43-44`) from 513 to 65 m — still ~8× the hut, "thatch goes
up", dramatic but no longer a village-ends-in-a-nuke event. If his eye later wants the run
bigger but hut deaths smaller, the split is a new kind for structure fires — deferred until his
eye asks (smallest change wins).

FOSSIL LAW rider: the same change must rewrite `gun_fx.gd:114-119` header arithmetic (its own
"mortar ~37m" disagrees with its formula's 46 m — two computations drifted inside one comment
block), the map-width comments at `:124-132`, and `vfx_range.gd:28-30`, where "napalm now reads
~90m wide" sits directly above "sized to cover [512 m]" — two contradictory sentences, adjacent,
each a fossil of a different ruling.

---

## 4 · THE TWO BEATS — one number serves both

**One number.** The demo already differentiates the beats with geometry and light, not with size:

- **Early (morning, 210 m, "away" bearing):** spectacle at the designed distance — 17° tall,
  60° wide, watched from safety. "SOMEBODY ELSE'S WAR" (`demo_game.gd:270-278`).
- **Siege (night, 185–210 m from centre, "sector"):** the player is on the wire, so his actual
  eye distance is ~120–210 m (wire radius unmeasured; estimate) — the same wall at 125 m
  subtends ~27°, bigger and hotter over the heads of the men coming at him, and the night light
  amplifies the burn glow for free (`fire_hazard.gd`'s 4 fire lights + glow quads). Escalation
  delivered by distance and darkness, not by a second scalar.

Per-context sizing would (a) re-break bench→world transfer — the number tuned anywhere would
again not be THE number, the exact disease this council convened on; (b) fork the one-table law
(`fire_plan.gd:1-10` — consumers → table, one direction); (c) feed the project's named
divergent-systems blindspot. The simplest thing that ships is one dict value; the demo's beat
table already does the per-context work.

---

## 5 · WHAT THIS SACRIFICES

1. **The letter of the 8/12 map-width decree.** Heavy loses ~59% of its width, napalm ~87%.
   That ruling is his; overturning it on instrument grounds still overturns it, and the decree's
   language in `gun_fx.gd` comments and memory (`recon-military-fire-pack`) must be rewritten as
   superseded, not silently edited.
2. **The accidental sublime.** A ~690 m dome IS awesome, once. We trade screenshot-grade
   enormity for a legible wall. If his eye says "bigger", the knob is one dict line — the band
   55–80 is pre-authorized in this analysis.
3. **The satchel's scream.** At 46 m the wire-breach blast is a quarter of its current width.
   The breach chain loses raw shock it arguably never should have had (it filled the screen from
   inside) — but the loss is real and he may feel it before he reasons it.
4. **Per-drop aspect stays square.** A real canister burst is ~2:1 wide:tall; our billboard is
   1:1, so a single drop still reads taller than film reference. The chain restores the low
   aspect at event level (241 × 65 ≈ 3.7:1); re-authoring sheet aspect is art-pipeline work,
   deferred past the demo.
5. **Realism purists lose nothing they had** — 65 m is still ~1.5–2× a real canister fireball.
   The uniform drama factor is a deliberate rule-of-cool spend (`DESIGN.md:42`), named here so
   nobody later "fixes" the ladder down to documentary scale without a ruling.
6. **Horizon ambience dims slightly.** AmbientWar's distant events ride big explicit scales
   (`gun_fx.gd:302-304` comment); if any path inherits the class ladder instead of passing its
   own scale, the 200–800 m horizon show shrinks with heavy — systems must confirm which lever
   AmbientWar actually pulls (`scripts/ai/ambient_war.gd:126` names `_dist` kinds; unverified
   beyond that — flagged, not asserted).
7. **Nothing here is "verified".** ADR-015: every number above is a STARTING value; the
   discharge is his eye, at the demo's vantage, both beats, both lights. Tuning anywhere else —
   god-cam, 200 m bench — re-opens the wound this council exists to close.
