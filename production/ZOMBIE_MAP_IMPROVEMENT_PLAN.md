# VC ZOMBIES — 10-step map & audio improvement plan

Written 2026-08-05 after his first playtest. Governing constraint unchanged:
**no new art may be authored for this mode.** Every asset named below already
ships in this repo. Verified against disk on the date above.

**His playtest notes, which this plan answers:**
1. *"theres no spots where zombies spawn from in this first area"* — a real bug, not
   a design gap. See step 1.
2. *"i thought you would start it outside in a parking lot with a fence and gate"*
3. *"use the prop models more to build up a level and areas that can be built
   up/have zombies come out of it"*
4. *"in this game mode you cannot lean so it makes holding E the true interaction button"*

**State on arrival:** `zombie_map_lot.gd` (the outdoor fenced-lot layout) is
WRITTEN but NOT YET WIRED — `vc_zombies.gd` still instantiates `ZombieMapDepot`.
Step 1 closes that, and deletes the depot per the FOSSIL LAW.

---

## Step 1 — Fix the spawn bug and land the outdoor lot *(blocking; nothing else matters until this is true)*

The first map's ground plane was 70x34, exactly the compound footprint, and spawn
points are pushed 3.5 m OUTSIDE the perimeter. **All fourteen sat off the floor,
off the navmesh, in the void.** Nothing could ever spawn — which is precisely what
he saw.

- Point `vc_zombies.gd` at `ZombieMapLot`; **delete `zombie_map_depot.gd`** (fossil law).
- `ZombieMapLot` already carries the fix: 150x120 ground with an 18 m apron
  outside the wire, so every spawn stands on real, baked navmesh.
- **Acceptance:** round 1 puts bodies through the fence. Verify by count, not by
  vibe — `wave_count_changed` should report `alive` climbing above zero.

**A permanent guard, because this class of bug is invisible:** a spawn point with
no navmesh under it fails silently. Add a boot assertion that every
`zombie_spawns` node has a nav-reachable position, and push a warning naming any
that do not. A silent dud spawn reads to the player as "the game is broken" and to
me as "the director stopped".

---

## Step 2 — Fix the interaction key *(his note 4; two-line change)*

`interact` is bound to **F** (`project.godot:253`, physical keycode 70), while my
prompts all read `[E]`. Worse, **`lean_right` is bound to E**, so pressing the key
the HUD tells you to press makes you lean.

- Add `allow_lean` to `player.gd`, defaulting **true**, and set it false from the
  zombie mode — exactly the pattern the arena already uses for
  `allow_photo_mode` (`ai_stress_arena.gd:1282`).
- Read **E** directly in `vc_zombies.gd` so key and prompt agree.

Do not repoint the global `interact` action. `InputMap` is global and persists back
into the campaign.

---

## Step 3 — Replace the box-primitive shell with the real firebase kit

Right now the perimeter is grey `BoxMesh` walls. The repo already ships the
compound kit the mode is pretending to be:

| Use | Asset |
|---|---|
| The gate he asked for | `fb_gate_assembly` |
| Perimeter | `fb_sandbag_heavy`, `fb_sandbag_light`, `barbed_wire`, `barbwire_tangle`, `fence_run_01` |
| Hard corners | `fb_bunker_mg`, `fb_bunker_fighting`, `mg_nest_sandbag` |
| Fighting positions | `fb_FoxholeSandbags`, `artillery_pit` |
| Vehicle cover | `tank_revetment`, `aircraft_revetment`, `tank_trap` |

Keep the box walls as the **collision** and hide them; hang the kit meshes on top.
That preserves the nav-gap trick exactly (collision unchanged) while making the lot
look built rather than blocked out.

---

## Step 4 — Make the buildings real buildings

The airfield set is a ready-made industrial compound and a far better fit than
primitives:

`control_tower` · `hangar` · `radar_dome` · `radar_network` · `runway_section` ·
`psp_helipad` · `fuel_depot` · `helipad`

Plus `barracks`, `barracks_bunker`, `operations_building`, `hq_building`,
`fire_station`, `market_hall`.

**Zone identity comes from the building, not from a wall colour.** Lot → Motor pool
→ Hangar → Tower. A player who can say "I'm in the hangar" can plan a route; a
player in "grey room 3" cannot.

---

## Step 5 — The dead come UP, not just in *(the single best idea the library gives us)*

The repo ships `tunnel_entrance_hidden`, `spider_hole`, `underground_hospital`,
`punji_pit` and `bomb_crater`.

Put spawn points on tunnel mouths and spider holes **inside** the wire. Now the
horde does not only come through the fence — it comes up out of the ground behind
you. It is thematically perfect for the setting, it breaks the "watch the four
windows" solved-state that kills round-based maps around round 15, and it costs
nothing but placement.

`underground_hospital` becomes the late map's dread zone: expensive door, tight
corridors, the rotted tier weighted heavily. It also finally explains the hospital
patients and staff in his reference sheet.

---

## Step 6 — Give the barricade system more than one kind of thing to board

Today every breach is an identical 6-plank rectangle. The kit supports real
variety, and variety is what stops the rebuild loop going numb:

- **Windows** — 6 boards, fast to rebuild (`ruin_house_shell`, `wall_straight_door`)
- **Fence sections** — 4 boards, wide, two zombies at once (`fence_run_01`, `barbed_wire`)
- **Sandbag gaps** — 8 boards, slow, the strongest hold (`fb_sandbag_heavy`)
- **Tunnel mouths** — cannot be boarded at all; only a bought door seals them

Differentiate `board_count`, rebuild time and how many attackers an opening admits
at once. That last one is the real lever: a wide breach that lets three through is
a different tactical problem from a window that admits one.

---

## Step 7 — Debris and clutter as the pathing skeleton

145 PSX props plus `rubble_*`, `brick_pile`, `wall_remnant`, `ruins_corner`,
`ruinset_*` and `bomb_crater`.

Place them to **shape the horde**, not to decorate. Training a horde is the skill
ceiling of this genre, and a train needs a loop with pinch points. Use containers
and jersey barriers to build one deliberate circuit per zone, with two chokes and
one escape lane. Then dress the leftovers.

Cap what carries a collider — every prop is currently given a box collider, and at
150+ props that is real physics cost for scenery nobody touches.

---

## Step 8 — Light it, and take the light away

Currently one directional light. The mode has no night, and darkness is most of the
genre's tension.

- `IllumFlare` already exists and already works (`ai_stress_arena.gd:419`).
- `MissionWeather.TIMES["NIGHT"]` is the shared night preset the arena reads.
- Campfires and oil-drum fires exist in `_add_bench_campfire`.

**Make the map get darker as rounds climb.** Buyable/earned illum flares as a
power-up. A lit compound is a stage; the gap between flares is where the dread
lives — the siege system already says exactly this
(`siege_director.gd:86`, on why the illum interval is deliberately longer than the burn).

---

## Step 9 — Audio: use what ships, and it is more than expected

333 files. **Nothing horror**, but the war library repurposes remarkably well:

| Moment | Existing asset |
|---|---|
| Round start | `sfx/alarm/siren_spinup.wav` |
| Round cleared | `sfx/alarm/siren_allclear.wav` + `siren_spindown.wav` |
| Horde inbound / round 10+ | `sfx/alarm/siren_alert_loop.wav` |
| Base ambience | `sfx/night_insects_loop.wav`, `wind_loop.wav`, `ambience/jungle_day.mp3` |
| Low health | `sfx/player/breath_hold.wav`, `breath_break.wav` |
| RPG / explosives | `sfx/explosions/*` (20 files) |
| Guns | `sfx/weapons/*` (100 files) — all five wall guns already covered |

**The best free idea in the whole plan:** `assets/audio/Radio Vietnam/` holds 14
traditional music tracks and 5 real 1969 AFVN broadcasts (Apollo landing, Nixon's
inauguration, a baseball report). Put a **practical radio in the lot** playing them
while the dead come through the fence. A cheerful 1969 DJ over a horde is free
atmosphere, it is unmistakably this project's voice rather than a Treyarch tribute,
and the asset is already on disk and already licensed (`audio/CREDITS.txt`).

Use the radio diegetically: it plays until the power/round state changes, then cuts
to static. Cutting it is worth more than adding anything.

**THE ONE REAL GAP — name it rather than pretend:** there are **no zombie vocals**
(moans, screams, the horde bed) and no wet flesh impacts. Mixamo supplies motion,
never audio. These must be sourced (CC0 — freesound/OpenGameArt) or recorded.
Roughly 12 files: 4 idle moans, 3 aggro screams, 3 attack grunts, 2 death rattles,
plus a layered crowd bed. **Until they exist the horde is silent, and a silent horde
is the single largest hole in the mode** — bigger than anything else on this list.

---

## Step 10 — The round-15 problem

Every step above improves the first ten rounds. This one is about whether the mode
has legs.

Once the player knows the map, a fixed layout with fixed spawns becomes solved and
the mode stops being interesting. Three cheap answers from existing assets:

- **The box already moves** — extend that principle. Rotate which tunnel mouths are
  live per round so the pressure pattern shifts.
- **Weight the mix by zone.** Rotted heavies in the underground hospital, runners in
  the open lot. Geography becomes a decision instead of a backdrop.
- **A wave that changes the rules,** not just the numbers: one round where every
  breach opens at once, or a crawler-only round using `wounded_crawl` +
  `zombie_crawl` and the spider holes.

**Do this last.** It only matters if rounds 1–10 are fun, and that is his call to
make, not mine.

---

## Order of work

**Blocking:** 1, 2 — the mode is not honestly playable until spawns work and the
prompt names the right key.
**Highest value per hour:** 5, 9, 3 — tunnels change the game, audio changes the
feel, the kit changes the look.
**Then:** 4, 6, 7, 8.
**Only if it earns it:** 10.

**Not in this plan, deliberately:** anything requiring new models, new animation,
or a second map. The parked plan's kill criteria still bind
(`ZOMBIE_MODE_PLAN.md` §9) — if something is being modelled in Blender for this
mode, the mode should be cancelled instead.
