# DEMO SHIP BACKLOG — everything between here and a shippable demo

**Opened 2026-07-29** out of the day's playtests. Ordered by the Summoner's ruling:
**allies first, then the air spectacle, then everything else.**

The ship gate, his words: *"More Hueys and jets flying around. At least a few Huey landings
with troops disembarking or unloading supplies. The base attack has parts of the base blow up.
The VC attempt to overrun the firebase."* The demo's job is **scope and spectacle immediately**.

Legend: **[C]** code, I can do it · **[B]** Blender, needs him · **[?]** needs measurement first

---

## A. ALLIES AND THE GARRISON — first

**A1. [C] Ally path failures at 5-8m.** *(fix applied 7/29, unverified)*
`NavRouter` refused to clamp a target further than **4m** off the navmesh and handed the raw
unreachable point to the query - a guaranteed no-path. A garrison post inside a hootch
footprint sits further than that. Clamp limit raised to 12m with a named guard.
**Verify: the `[NAV] ally ... no path` count per boot. It was 8.**

**A2. [?] Whatever survives A1.** If failures persist they are navmesh ISLANDS, not clamping -
the compound fragmenting into disconnected patches. Diagnose with region connectivity, not by
raising numbers.

**A3. [C] Garrison work is invisible at demo open.** Schedules rewritten 7/29 so the night
shift is the busy one (sentry_night on the wire 18:00-05:30, gun crew on the guns, radioman on
the net, quartermaster moving ammo after dark). **Needs his eyes to confirm it reads as a
working base.**

**A4. [C] Off-duty men need somewhere to BE.** `off_duty` currently sits and talks. With the
work markers already in the GLB (191 of them) they could be cleaning weapons, filling sandbags,
queueing at the mess. Cheap life, big return on "the base is alive".

**A5. [?] Squad members stacking.** The 2-man post overlap is fixed (stations spread by index).
If he still sees two men in one skin it is the follow-slot convergence, not spawn.

---

## B. THE AIR SPECTACLE — the ship gate's biggest item

**B1. [C] AirTraffic schedules ONE transit per sim-hour** off a random kind list
(`_seed_default_schedule`). That is ambient weather, not an opening. Needs a demo-facing
cadence: several airframes up at once, continuous movement on the horizon.

**B2. [C] Huey landings with troops.** `lz_cycle` exists as a profile. He has just built the
landing + load/unload animations, so this becomes: fly in, flare, touch down, men out, lift.
**Ask him for the clip names before building - do not guess them.**

**B3. [C] Jet formations.** `CASAirplane` flies single. A pair or a vic crossing high is pure
silhouette work and cheap.

**B4. [C] Air must not fly through the firebase.** Same class as the convoy (D1): routes are
not aware of the compound.

**B5. [?] Perf ceiling for all of it.** PERF_LEDGER says this project is call-bound. Every
airframe is draw calls. Measure before committing to a count.

---

## C. THE BASE ATTACK — ship gate items 3 and 4

**C1. [?] Nobody has ever seen the sapper detonate.** His ask: a sterile stress room - just
him, three sappers, some wire and sandbags to blow. Answers reach, detonation and destruction
in one test. Parts exist: `ai_stress_arena` pattern, `SapperCharge`, `Destructible`,
`AgentRegistry.props`.

**C2. [C] Parts of the base must blow up.** ADR-031 destruction doctrine and the 80 authored
parapet segments with HP already exist; the wiring to the blast bus is the gap.

**C3. [C] The VC must attempt to OVERRUN, not probe.** Half-unblocked already: the assault
element no longer runs at a point forever (`assault_driven` split, 7/29). Needs a real assault
behaviour past the wire.

**C4. [C] Siege is on a 600s/720s arc** - too slow to test. A debug trigger exists on `[J]` but
only in debug builds.

---

## D. WORLD AND VEHICLES

**D1. [C] Convoys drive through buildings.** `Convoy._physics_process` assigns
`global_position` directly - no `move_and_slide`, no navmesh, no collision. Fix is ROUTING
(road + gate), not making trucks collide.

**D2. [C] Spooky keep-out.** Done 7/29 - ambient gunship orbit pushed 420m off `fsb_center`
after it strafed the player's own compound. Verify it never recurs.

**D3. [C] Ambient war audio.** One one-shot per event; a distant engagement should be a volley.
His note: *"the fire rate should either be faster or a less occurring event."*

---

## E. ART AND MATERIALS — his side

**E1. [B] Ten materials on default white, no texture.** Named by the boot probe:
`Walnut`, `Walnut.001`, `.003`, `.004` (Ithaca 37 furniture, M79 stock, M70 sniper stock),
`MitchellCamo` + `Webbing` (helmet shell, EVERY body), `bandolier_tex`.
**The `.00N` duplicates are separate slots - fixing "Walnut" alone misses the sniper and shotgun.**

**E2. [B] Firebase re-export** picks up four already-fixed generator changes: mound plate
collision off, parapet to trimesh, five merged veg objects to trimesh, mound manifest.
See `production/blender/FIREBASE_BLENDER_HANDOFF.md`.

**E3. [B] Fire slits + bunker embrasures.** Handoff §2.

**E4. [B] The fighting step.** Parapet top is 2.39m against a 1.6m eye, and the berm crest is a
knife edge with the wall on it. Spec with numbers in handoff §2b. **This is the "stuck in the
dirt mounds" report.**

**E5. [B] `Base_Human` out of the US body export** (or renamed `grunt_base_human`). Patched in
code; the special case deletes itself once the export lands. Handoff §5.

**E6. [C] Skin/face mismatch.** Fixed 7/29 - the dresser now slides every surface that samples
the face atlas, matched by TEXTURE not by material name, so face and body can never diverge.
Warns loudly if a body carries skin that is not on the atlas. **Needs his eyes.**

---

## F. THE MAP

**F1. [C] M opened nothing.** Fixed - the control's rect was 0x0 so the bottom-right-anchored
sheet drew off-screen. Boot now warns if the rect is ever too small for the sheet.

**F2. [C] Only right-click places marks.** His report. Left-click is bound to the order circle;
the two verbs need separating or rebinding.

**F3. [?] The note verb is not intuitive.** His ask: **research how Arma does its map** and
learn from it before redesigning. Not started.

**F4. [?] Held-object map in the player's hand.** His design question - a flat plane in the
hand with the live sheet on it, versus the current screen-space corner draw. Deferred by him.

---

## THE INSTRUMENTS BUILT TODAY — keep them, they earn their keep

Each of these turned a playtest complaint into a named line in the log:

- `[FSB] one ground` - terrain vs the authored mound, warns past 0.6m
- `[FSB] N collider(s) floating >3m` - caught the four invisible veg slabs
- `[MODEL] renders N body-sized meshes` - caught `Base_Human` inside every soldier
- `[MODEL] N surface(s) left on DEFAULT WHITE` - named all ten white materials
- `[DRESSER]` stranded-skin and missing-stock-helmet warnings
- `[TOPO]` rect-too-small warning
- `[FSB] stand to: promoted N` - the garrison question, answered every boot
