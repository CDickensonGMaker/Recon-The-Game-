# BRIEFING — INTERIOR-FIRST BUILDINGS, AND A FIREBASE WORTH OCCUPYING

**Convened 2026-07-30** on the Summoner's brief. He is declaring a WORKFLOW, not asking a
question — the workflow itself is a ruling and is not up for a vote. What the council is asked
is how to fit it to the pipeline that already exists, and what it costs.

**HIS WORDS (the ruling):**
> *"i want to build the insides of rooms with everything itll need than we build the walls
> around it. not the other way around."*

**Canon binds:** `production/GAME_GUIDE.md`, `production/adr/`, `CLAUDE.md`. Pillars:
believable firefights · **atmosphere** · freedom · the squad is the RPG · fail forward.
Rule #1: it must be FUN to walk and it must FEEL like Vietnam, judged BY HIS EYES.

---

## THE BRIEF, ITEMISED

**1. INTERIOR-FIRST as the standing build order.** Contents first, walls last, for every
building.

**2. THE MEDICAL TENT.**
- 8–12 stretchers, and **the number of OCCUPIED beds rotates over time** so it reads as a
  living world rather than a diorama.
- Doctors/nurses walking the rows, checking on people.
- **Stretcher-bearer choreography, exactly as specified:** when bearers take a casualty to a
  heli they **form up OUTSIDE the tent first**, then come out carrying the stretcher. The
  forming-up does not happen inside.

**3. THE HQ TENT.**
- A few officers and radiomen working, and studying maps *(his phrasing was "studying tents" —
  read as map/table study inside the tent; if that reading is wrong the whole HQ interior
  changes, so flag it rather than build on it)*.
- **A steady stream of 1–2 NPCs in and out every few minutes.** Traffic is the point.

**4. THE BARRACKS — period accuracy.** Design them properly rather than as a shell.

**5. "ADD WAY MORE TO THE FIREBASE."**

**6. BETTER MUD.**

**7. PLACE ALL THE NEW GUN PITS AND MORTAR PITS.**

**8. BUNKERS ALONG THE SANDBAG WALLS — occupiable, and you can SHOOT OUT of one.**

**9. BUNKERS DESTRUCTIBLE. WATCHTOWERS BLOWN UP AND COLLAPSED. "same with all our buildings."**

---

## THREE COLLISIONS WITH STANDING LAW — resolve these, do not discover them later

**A. "Shoot out of a bunker" versus the collision convention.** MEASURED and on the books:
a **box collision hull SEALS the fire slits** — the fix is `COL_TRIMESH` or a dedicated
`-colonly` proxy. So an occupiable bunker with a working embrasure is a COLLISION-AUTHORING
problem before it is a gameplay problem, and the generator's collision choice per part is the
load-bearing decision. Also open on his Blender queue as E3 (fire slits + bunker embrasures)
and E4 (the fighting step, because the parapet top is 2.39 m against a 1.6 m eye).

**B. "Collapsed" versus ADR-031.** `ADR-031:12-15` — destruction is CHEAP and STATE-BASED,
**never a physics fracture** (ADR-001 forbids fracture): intact → damaged → rubble, with the
swap hidden under an occluding particle burst. So a watchtower "collapsing" must be AUTHORED
collapsed geometry, not simulated. The council must say what that means for a 6 m tower whose
silhouette is half its value, and whether a two-stage (leaning → down) swap is affordable.

**C. Destroying a building nobody thought would be OCCUPIED.** `Destructible._do_destroy`
hides the intact mesh and DISABLES its colliders, and it has **no concept of an occupant**
(zero hits for occupant/claim/release in `scripts/world/destructible.gd`). Meanwhile
`MortarPit` already has `claim(station, body)` / `release(station)` (`:49,:58`) and
`MGEmplacement` exists. So: what happens to the man in the tower when it goes? He must die or
be ejected, and the station must be released, or the pit is claimed forever by a corpse.

---

## WHAT ALREADY EXISTS — reuse it, do not rebuild it (ADR-023)

- **The station architecture decree (2026-07-29):** per-role clips + the EXISTING
  `camp_director`, with stations attaching as CHUNKS at `fsb_main_v3` markers. That is the
  mechanism for gun pits and mortar pits — it is already ruled.
- **The firebase chunk kit:** 19 marker-GLB chunks. `barbwire_card` is the ONLY wire.
- **21 US interior props exist and are UNEXPORTED.** `work_` / `prop_` marker conventions,
  `fb_` lowercase, 160 px/m. `sandbag_heavy` is **BANNED** (broken and dated).
- **`MortarPit`** (`scripts/world/mortar_pit.gd`, claim/release, group `mortar_pits`), placed
  one per firebase by `mission_generator`. **`MGEmplacement`** exists; a mannable MG
  emplacement is the top DEFERRED feature.
- **`Destructible`** (`scripts/world/destructible.gd`) — one class, rides
  `AgentRegistry.props`, throttled by `WorldConfig.STRUCTURE_LEVELS_PER_FRAME`. 80 parapet
  segments and 16 claymores are already on the bus. Now also has `is_destroyed()` and an
  `fsb_parapet` group (2026-07-30).
- **NPC life is a Behaviour Tree over WORK MARKERS**: `civilian.gd` + `civilian_schedules.gd`
  + `working_point_resolver.gd`, 191 markers in the GLB, `bb["target_pos"]` resolved per sim
  hour. **`_bt_work` was only fixed to actually WALK to a post on 2026-07-30** — before that
  every scheduled action froze in place. The HQ traffic and the nurse rounds are schedule +
  marker work, NOT a new system.
- **The one-ground law:** terrain is sculpted to the mound manifest; never hardcode a mound
  height. The GLB IS the ground.
- **`scenes/world/firebase_main.tscn`** is an inherited scene wrapping the GLB, and exists so
  hand-authored siblings SURVIVE a re-export. Anything placed by hand belongs there.

---

## WHAT THE COUNCIL IS ASKED

1. **How does interior-first actually work against a GENERATED firebase?**
   `tools/gen_firebase_v3.py` emits the base and the model is the ground. Interiors authored by
   hand live in the .tscn. Chunks carry markers. Give the concrete authoring order and say
   which artefact owns what, so an interior is never destroyed by a re-export and never
   duplicated between the GLB and the scene.
2. **Is "rotating occupancy" random, or is it the CASUALTY LEDGER?** A medical tent whose
   occupancy is a random number is a diorama with a timer. Occupancy driven by real casualties
   from patrols and sieges is the living world he asked for. Say which, name the cost, and name
   what breaks if the ledger is empty on a fresh boot.
3. **The stretcher-bearer form-up-outside rule** — is that a nav constraint (tent interiors too
   tight for group formation), a spectacle choice, or both? Whatever the reason, it is his
   instruction; say how to implement it with the existing group-walk/formation code.
4. **Sequence the whole thing.** Which items are HIS Blender time, which are mine, which are
   code-only, and what is the smallest first slice that visibly pays off. Perf: the project is
   CALL-BOUND (`production/PERF_LEDGER.md`) — draw calls, not triangles. Tri budgets are STYLE,
   not perf, measured.
5. **Every ruling names what it SACRIFICES.**

**READ THE CODE, NEVER THIS BRIEF.** Where they disagree, the code wins and say so with a
`file:line`. **Do not open Blender and do not launch the game** — he drives testing, and he is
live in Blender on the weapons right now.
