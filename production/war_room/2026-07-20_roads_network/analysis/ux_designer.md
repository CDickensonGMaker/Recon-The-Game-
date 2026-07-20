# UX DESIGNER — Q4: does a road print on the topo sheet, or appear when walked?

**Council:** 2026-07-20 ROADS NETWORK · **Lens:** ux-designer · **Laws binding me:** r4bk (no HUD
affordance = no feature), ADR-022 (the grease-pencil law), Pillar 3 (no rails), Pillar 2 (atmosphere).

---

## THE FINDING THAT DECIDES THE QUESTION

The briefing framed roads as possibly needing a *third layer* that would violate ADR-022's two-layer
law. **It does not, and the code already proves it.**

`scripts/ui/topo_map.gd:33-75` (`_render_base_map`) renders, at `setup()` time, before the player has
taken one step:

- contour bands sampled from the **real heightmap** across the whole AO (`:38-42`, `get_height_at`)
- **water in blue** via `world.gameplay_grid.is_water()` (`:54`) — every river in the AO, printed
- a 100m grid (`:69-73`)
- the sheet's own header: `"AO TACTICAL MAP - 1:25,000 // GRID 100M // CONTOUR 12M"` (`:89`)

There is **no fog of war, no reveal, no decay** on any of it. The player is handed a fully surveyed
1:25,000 sheet of the whole AO at boot. **Rivers he has never seen are already printed on his map
today, and nobody has ever called that a quest log.**

That is the precedent, and it settles Q4.

### RULING 1 — roads live on the BASE SHEET. No ADR-022 amendment required.

ADR-022's "two layers" was never a claim that the sheet has only two things drawn on it. It is a law
about **MARKS** — the game's hand vs. the player's hand. The paper the marks sit on is not a third
hand. Contours, water and the grid are Layer 0 and always have been.

The taxonomy, stated once so no future agent re-litigates it:

| Layer | Whose hand | Content | Decays? | Corrected? |
|---|---|---|---|---|
| **0 · BASE SHEET** | the *cartographer's*, 1968 | surveyed terrain: contours, water, grid, **roads** | never | never (see Ruling 6) |
| **1 · OBSERVED** | the game's | what you personally witnessed | **yes** | n/a |
| **2 · ANNOTATED** | the player's | what he thinks | never | **never** (grease-pencil law) |

**Recommended (not an amendment, a clarification):** add one sentence to ADR-022 naming the base sheet
explicitly. ADR-022 is quoted as law by every architect who touches the map; its "two layers on one
topo sheet" phrasing already sent this council chasing a phantom third-layer conflict. Under the
POINTER LAW, cite `topo_map.gd:33-75` as the existing implementation. **Cost of not doing this: this
exact question gets asked again.**

---

## RULING 2 — print the whole surveyed network, not the walked parts. But the world holds more than the sheet does.

Printing only walked road is **fog of war**, which is precisely the minimap ADR-022 forbids, and it is
cartographically absurd — a survey sheet does not half-print. It also punishes the player for the one
thing the map is supposed to reward: planning before you walk.

But there is a split here that is worth more than the road system itself:

> **A ROAD is surveyed cartography. A TRAIL is not.**

- **Roads** (the vehicle network, what a convoy drives) → **BASE SHEET, printed in full, from t=0.**
- **Footpaths / VC trails / the patrol circuits of ADR-021** → **NEVER on the base sheet.** They enter
  the map only as **OBSERVED**, when he walks one or reads sign on one, and they **decay** like all
  observed intel.

This gives the map the only asymmetry that matters: **the sheet under-reports the world, and never
over-reports it.** Everything printed is true; not everything true is printed. A player who learns to
distrust the blank areas is playing exactly the game ADR-021 wants him to play. And it hands the
ambush economy (Q3) its real substrate for free — the trails he *earned* are the ones nobody printed.

---

## RULING 3 — a printed road is not a waypoint, IF it stays furniture

A road becomes a rail the instant it reads as *instruction*. Four hard constraints keep it as terrain:

1. **Draw it in the base sheet's own ink.** Roads render in the `CONTOUR` family
   (`topo_map.gd:13`, `Color(0.45,0.36,0.22)`) using period cartographic convention — a double thin
   line for a graded road, a single dashed line for a cart track. **NEVER a new saturated colour.** A
   bright new colour on a beige 1968 sheet reads as UI highlight, and UI highlight reads as "go here."
   The one already-saturated thing on that sheet is the CO's pencil (`:114`, dark red) — that
   saturation is *reserved* for the grease-pencil layer and roads must not borrow it.
2. **Same visual weight as rivers.** If the road is thicker or brighter than the river beside it, the
   player's eye reads a hierarchy that does not exist.
3. **Nothing is ever marked ON the road.** No convoy icons. No "traffic" indicator. No suggested
   ambush points. The sheet says a road **exists**; it never says anything is on it. Waypoint-ness
   comes from a mark that means *go*, and the game has exactly one go-mark: the CO's sweep circle
   (`topo_map.gd:112-118`), already correctly scoped as pencil.
4. **No legend entry, no roads toggle, no filter.** A layer control implies the layer is a *feature*.
   It's ground.

**And the honest inversion:** a printed road is *anti*-rail. It is the single strongest legible-choice
generator in the game — fast + exposed vs. slow + concealed — and the player can only weigh that
choice **if he can see it on paper before he walks.** Hiding roads until walked doesn't remove a rail;
it removes a decision and replaces it with a surprise. Pillar 3 wants the choice, not the ignorance.

**The one live risk:** `FieldDirector.raise_crisis` (`field_director.gd:605-621`) drops the sweep
circle at a crisis position, and an `ambushed_convoy` crisis position is **by definition on a road**.
If circles keep landing on the road, the player learns "the road is where the game sends me" and the
road becomes a quest line by statistics rather than by design. **Mitigation: the crisis circle never
snaps to, aligns with, or draws along road geometry — it stays the fat scrawled arc it is today
(`:115-116`), which is deliberately imprecise. Never draw a crisis as a road segment.**

---

## RULING 4 — convoys: the affordance is 80% BUILT, and the missing 20% is sensory, not UI

Verified against code — the crisis path is real and diegetic:

- `DynamicMissionFactory._on_convoy_ambushed` (`dynamic_mission_factory.gd:52-57`) → `emit_location`
  (`:38-48`) → `FieldDirector.raise_crisis` (`field_director.gd:605`)
- `CRISIS_CALL["ambushed_convoy"] = "SIX: CONVOY AMBUSHED"` (`field_director.gd:504`) — **already
  written, waiting for a road to make it fire**
- toast is emitted with **bearing + range**, not a screen pin (`:618-620`), and routes through
  `MissionHUD.show_toast` (`mission_hud.gd:23, 248`)
- **it is radio-gated**: `if _radio_check() != "": return` (`:612`) — off the net, the word never
  reaches him and the sweep does not move. The header at `:600-604` states the Fairness Law
  explicitly: *"No marker ever appears from nothing."*

This is already the right answer to "how does he learn diegetically" — it is a **radio call from
higher, by bearing and distance, over a man with a 10m tether** (`mission_hud.gd:230-246`). I would
not replace it and I would not add a second channel.

**What is genuinely missing, ranked, with what I'd cut:**

1. **BUILD — a convoy must be encounterable with no event at all.** If the only way a convoy exists is
   by being ambushed, it is a cutscene trigger, not a world object. Minimum: **engine noise on an
   `AudioStreamPlayer3D` audible well beyond visual range, plus a dust plume.** A road is a *sound*
   before it is a sight, and hearing a truck you never see is the single cheapest thing that makes the
   whole network feel inhabited. This is the highest atmosphere-per-byte item in the entire roads
   decree.
2. **BUILD — the wreck persists.** If an ambushed convoy despawns, the radio call becomes a lie and
   the player walks 800m to an empty road. **That is the worst possible r4bk outcome: a feature that
   announces itself and then isn't there.** Arriving late must show burned trucks and bodies. If
   persistence cannot be afforded, **do not raise the crisis at all** — better silent than lying.
3. **BUILD IF CHEAP — a smoke column at the ambush position, visible at range.** This is the only cue
   that survives being **off the net**, which is the one state where the radio path deliberately gives
   him nothing. It is also the most Vietnam image in the list. Cut it first if perf says no; the
   feature still works without it.
4. **CUT — any map icon for the convoy.** No truck symbol, no route line, no wreck marker. If he
   walked up and looked at it, that is an **OBSERVED** mark like any other and it **decays**. If he
   only heard it on the radio, he gets the CO's pencil circle and nothing else. Hearsay is pencil;
   eyes are print. Hold that line or the sheet becomes a live tracker.
5. **CUT — convoy schedules/timetables on the map.** "Convoy passes here at 1400" is a quest log with
   a clock. If he learns a pattern, he writes it himself in the ANNOTATED layer. That is the entire
   point of ADR-022.

---

## RULING 5 — a road at PSX fidelity does NOT read as a road from a ground texture alone

This is the failure mode I am most confident about. At eye level, in jungle, at PSX texture density, a
strip of different-coloured ground reads as a **terrain artifact** — the same read as a paddy edge or
a shader seam. Playtest complaint predicted verbatim: *"is that a road or is the ground broken?"*

Cheapest legibility, ranked by signal per triangle:

1. **THE CANOPY GAP.** A road is a **corridor of sky**. This is the strongest ground-level cue by a
   wide margin, you feel it before you look down, and it falls out of the vegetation clearing the road
   build has to do anyway. **Effectively free. Non-negotiable — ship this or don't ship roads.**
2. **CUT AND CROWN.** A shallow height profile (crowned centre, shoulder drop) via the existing
   `modify_terrain` call the road already makes. Near-free, and it makes the road readable *underfoot*
   and from a slope above. **Ship.**
3. **TELEGRAPH / TELEPHONE POLES at 60–100m intervals.** One trivial mesh, huge period. Highest
   signal-per-tri item available: gives vertical rhythm, reads as *man* from a ridgeline half a klick
   off, and turns a road from a texture into infrastructure. **Ship.** It is also the only road cue
   that is visible above the canopy.
4. **Culverts / bridges at river crossings.** Scope-dependent (Q5, hydrology). **Cut unless rivers
   force a crossing**; if a road must cross water, a ford reads fine and costs nothing.
5. **Signage.** **CUT.** Text at PSX resolution is illegible, and it is a localisation surface for no
   gameplay return.

---

## RULING 6 — the base sheet may be WRONG, and the game still never corrects it

The grease-pencil law's spirit extends cleanly to Layer 0 and costs nothing to honour: **the printed
sheet is 1968 survey truth, and the war has moved on since it was printed.** If a road is cratered,
washed out, cut, or interdicted, **the sheet does not update.** The road stays printed. He finds out
by walking, and if he wants it noted, *he* writes it in grease pencil.

This is free thematic gold and it inoculates the base sheet against ever drifting into live-state
tracking. Write it into the clarification alongside Ruling 1.

---

## CROSS-QUESTION NOTE — UX VOTES CANDIDATE A ON Q1

Not my question, but the map has a stake in it and I have the pointer.

`topo_map.gd:54` draws water by asking **`world.gameplay_grid.is_water(...)`** — the map is already a
**consumer of the gameplay grid**, not of the hydrology solve.

- **Candidate A** (`TerrainType.ROAD` inside `_seat_cell`, the one writer): the topo map gets roads for
  ~free by the identical code path as water — one query, one colour, **one authority**.
- **Candidate C** (height-only / shader mask, no grid semantics): the map has **no road source**, and I
  would have to query road splines directly. That is a **second road authority whose only client is
  the UI** — precisely the parallel-systems failure the briefing names as this project's worst
  recurring disease.

**The map is a reason to put roads inside the grid, not beside it.**

---

## SUMMARY OF SACRIFICES (no free lunches)

- **Printing the whole network gives away AO structure at t=0.** The player knows where the arteries
  are before he walks. Accepted deliberately — that knowledge is the *choice*, and the trails he
  actually needs are still unprinted.
- **Roads make some navigation trivially easy.** Following a road is the lazy route, and lazy players
  will take it. Accepted: it is also the exposed route. The road *is* the risk/reward, provided
  Q3 makes travelling it genuinely more dangerous. **If roads are not more dangerous than the bush,
  the road is a free fast-travel lane and Q4's answer becomes wrong retroactively.** Flagging that as
  a dependency on the systems-designer's ruling.
- **Base-sheet ink is now crowded.** Contours + water + grid + roads on one 512px beige texture at
  `CONTOUR_INTERVAL 12.0`. Road linework in contour ink is at real risk of being lost in dense contour
  bands. **This needs to be eyeballed, not reasoned about** — and per ADR-022's own listed sacrifice,
  *"if observed and annotated are not instantly distinguishable at a glance, the whole law collapses
  into mush."* Same risk, one layer down.
- **The convoy sensory work (engine audio, dust, smoke, persistent wreck) is real cost** and it is
  *not* optional garnish — without it the convoy sim is invisible and r4bk says it does not exist.
  That cost belongs in the roads scope estimate (Q5), not treated as polish to do later.
