# DEVIL'S ADVOCATE — Tet / Hue / Operations (2026-08-18)

*Independent sight. No cross-talk. Sources: briefing.md · GAME_GUIDE.md · ADR-028 · ADR-029 ·
7/28 operations decree (memory: recon-operations-decree) · DEMO_TIGHT_40_2026-08-14.md ·
DEMO_SHIP_BACKLOG.md · CLAUDE.md session-gate section. Velocity assumption throughout: the
Summoner ships ~1 animation sequence OR 1–2 models per working day (stated in this council's
own charter; consistent with ART_Track_Log cadence).*

**Posture:** I am not here to kill Tet. Tet is the correct emotional target — the one moment
the whole war walked into the firebase, which is literally our demo's shape already. I am here
to price it, because the four names he invoked are four studios' combined output, and the last
time this project bought a vibe without pricing it we got 30 documents of undischarged R4.

---

## 1 · SCOPE — what each reference game silently imports

### Steelman
The blend is coherent as a *feel* target: COD intensity at the set-piece peak, Battlefield
combined-arms noise around you, Men of Valor's Vietnam squad intimacy, HLL's lethal weight.
The siege already delivers a low-rent version of all four for 30 minutes. Operations are "more
sieges, away from home." That is genuinely cheap in kind.

### Puncture — the hidden bill of materials, per name

| Reference | The vibe he means | The system it silently imports | Do we have it? |
|---|---|---|---|
| **COD** | staged set-piece intensity | scripted event choreography, mo-capped ally beats, one-off hero assets, *rails* | NO — and Pillar 3 says "Nothing is on rails. Ever." COD intensity IS rails. Our substitute is director-driven emergence (SiegeDirector), which peaks lower but never breaks the pillar. Buying real COD moments means buying a cutscene/staging discipline we've explicitly kept out of gameplay (cutscenes are standalone by decree). |
| **Battlefield** | scale, vehicles, combined arms | respawn/ticket economy, drivable vehicle physics, 64-actor density | NO tickets (death matters — persistent squad ruled 7/28), NO drivable vehicles (aircraft are choreography with facing conventions, not physics), and the **hot cap is 50** with the gating FPS number STILL UNSET (TIGHT-40 #18, "the charter's #1 named systemic risk, unset since July"). Battlefield scale in a city is a perf claim nobody has measured. |
| **Men of Valor** | Vietnam squad narrative grounding | authored dialogue, VO, written character beats per squadmate | PARTIAL at best — one radio-voice consistency pass (TIGHT-40 #27) is not a narrative layer. Every hour of "squad narrative" is writing + VO + staging days that come out of the same body that makes 1–2 models a day. |
| **Hell Let Loose** | one man in a big fight, milsim weight | fronts/sector logic AND — the big one — **allied AI that fights competently INSIDE BUILDINGS at scale**. HLL gets this free from 99 humans. We must code it. | NO. Indoor combat AI + indoor navmesh is the single largest unbuilt system in this whole conversation. The 7/28 decree already admitted it ("the real cost is AI/navmesh in enclosed spaces, not art") — and note we can't even hold OUTDOOR navmesh honest yet: the firebase bake had a missing wall (FIX 0), 4 revet posts still block capsules (TIGHT-40 #4). |

**Minimum honest version of "operations + Tet" that still delivers the fantasy:**
ride a helicopter OUT of your AO → land in a fight already in progress → the siege machinery
runs forward (assault) or backward (hold) → you are one rifleman in it → fly home, ledger
remembers. That is: Huey (done) + NPC dropoff pipeline (done) + SiegeDirector/MarchingCell
(proven) + a destination. It needs ZERO of the four imports above. Everything beyond it —
tickets, drivables, scripted beats, indoor squad AI — should be priced separately and mostly
refused.

**Dissolves if:** the decree explicitly translates each reference name into an existing-system
delivery (COD→siege peaks, Battlefield→ambient air/arty ladder already built, MoV→radio voice
register, HLL→fear doctrine + lethality already standing) and bans the imported systems by name.

---

## 2 · HANDCRAFTED MAPS — what random bought, what handcrafting costs

### Steelman
Handcrafted op maps are the industry-correct answer for set-pieces: authored sightlines,
paced approaches, a shared map players can talk about ("the canal crossing on Op Jasmine").
Random maps cannot author a canal crossing. The Summoner's split (seeded home AO / consistent
op maps) is exactly how Arma's campaigns sit on Arma's sandbox. It is not a naive ask.

### Puncture A — what the 7/28 random-map ruling BOUGHT, now being sold
1. **Zero art-days per map, forever.** Every op map was free after the first op *type*.
2. **Replayability of the op layer itself** — same op type, new ground, new story. Handcrafted
   maps are consumed once per player; after two runs the ambush corner is memorized, which is
   the exact reload-and-memorize loop Pillar 5 forbids.
3. **The seeded-tour premise.** "Your tour, your province, your war" is the identity that
   separates RECON from every shooter he named. A shared, consistent Hue map is *someone
   else's level* inside *your* war — the first non-seeded ground in the game.
4. **ADR-028 compliance for free.** Generated op maps ride the one WorldBuilder. A handcrafted
   .tscn map is structurally a **parallel world path** — the exact bug class ADR-028 exists to
   kill and the briefing itself says is off the table ("ops maps are generated worlds, a
   parallel world system is off the table"). A hand-built scene that bypasses WorldBuilder
   is the arena mistake, and the Catacombs collapse, again.

### Puncture B — the price at his velocity (numeric, assumptions stated)
Assume ONE Hue-adjacent city op map, ~400–600m playable urban core, PSX fidelity, reusing the
proven modular building kit (village + temple sets exist):

| Line item | Assumption | Art-days |
|---|---|---|
| New landmark models: citadel/compound wall kit + gate, colonial 2-story ×3–4 variants, church, bridge, tower | ~10–14 models @ 1–2/day | 6–10 |
| Pre-rubbled/battle-damage dressing variants (Hue's LOOK is a half-destroyed city; runtime destruction doesn't give you the *arrival* state) | ~6–8 damaged variants | 4–6 |
| Street furniture + civilian vehicles (cyclo, sedan, cart, poles, signage sheet) | ~6–8 small models | 3–5 |
| Hero-house interiors (3–4 enterable, per 7/28's own scope) | interiors + cabinets are ALREADY a demo backlog line (TIGHT-40 #35) he hasn't cleared | 3–5 |
| Layout/blockout + iteration passes in-engine | 3 passes minimum | 4–6 |
| **Total, ONE map** | | **~20–32 art-days ≈ 4–6 working weeks** |

That is a month-plus of the only art hands the project has, for one consumable map — while the
demo backlog still holds his bench items (LAW viewmodel, ladder meshes, interiors, renames).
Multiply by "some real operations" (plural) and handcrafted ops are the entire post-launch art
budget for a quarter. Also unpriced: indoor navmesh QA per map, and the perf pass — dense
urban geometry is the worst case for a renderer whose gating FPS number does not exist yet.

### The hybrid that keeps both purses
**Authored LAYOUT, seeded DRESSING, one build path.** The op map is *data*: a hand-authored
site graph (streets, wall line, landmark placements, nav hints) stamped through the SAME
WorldBuilder that stamps villages today — vegetation, clutter, garrison, weather still seeded.
Players share the geography worth talking about; the world stays generated; ADR-028 survives;
art cost collapses to the new landmark models only (~8–12 days, amortized across every op that
reuses the urban kit). This is also the only version that doesn't require amending a LOCKED
foundation. **If the decree takes handcrafting, it must take THIS shape or explicitly amend
ADR-028 — silence is not an option.**

**Dissolves if:** ops maps are authored-layout-as-data through WorldBuilder (then my objection
reduces to the landmark-kit bill, which is honest and payable), OR the Summoner knowingly
rules one flagship handcrafted map as a marketing centerpiece and prices it as such.

---

## 3 · HISTORY — what "real Tet, real Hue, 1968" reopens

### Steelman
Tet is the single most legible Vietnam event to a buyer. "Firebase near Hue, January 1968"
sells itself on a Steam capsule in a way "fictional province" never will. And 1968 flavor
(weapons, music-less dread, the countrywide eruption) costs nothing — the game is already set
there.

### Puncture — the 7/28 decree already litigated this and won, three weeks ago
The same decree that created operations ruled: **"fictional unit, not historical re-enactment
— the Hue *character* without the real dates, units or dead — protects the seeded-tour
premise."** Today's ask reopens it. Name what walks back in through that door:

1. **The wrong-army problem.** Hue was fought by the US Marines and ARVN (with 1st Cav on the
   approaches). Our locked launch faction is **the US Army line grunt** (GAME_GUIDE §1, one
   faction, Marines are post-launch DLC). A real-Hue op either ships ahistorical (the exact
   pedantry a "historical" tag invites) or forces the Marine fork forward on the roadmap.
2. **The real-dead / atrocity problem.** Real Hue includes the Hue Massacre — thousands of
   civilians executed. We have an atrocity hook ruled UNFINISHED, not fossil, and a fear
   doctrine — but putting the player at *the actual event* with real dates converts a tonal
   system into a claim about real victims. The 7/28 ruling dodged this deliberately.
3. **The comparison tax.** Naming Hue invites review-side comparison to big-budget treatments
   of the same battle at PSX fidelity with AI squadmates. "Inspired by Tet" is judged as
   ours; "Hue City, Feb 2 1968" is judged against everyone's.
4. **The research burden.** Real geography (Citadel, Perfume River, MACV compound) becomes a
   correctness obligation the moment the real name is used — days of reference work that a
   fictional provincial capital simply doesn't owe.
5. **The seed premise contradiction.** "Your randomly seeded province" and "the real city of
   Hue" cannot both be true of the same campaign without the fiction visibly cracking.

**The honest dial position:** *Tet as EVENT, Hue as CHARACTER.* The Offensive hits the living
campaign as a date-shaped storm — every AO in the province erupts, the ops tempo spikes, a
fictional provincial capital (walled citadel, river, colonial quarter — everyone will know
what it means) becomes reachable ground. 1968 is the year on the ledger. No real units, no
real dead, no real street map. This gets ~90% of the fantasy for ~10% of the burden and zero
canon amendments.

**Dissolves if:** the Summoner explicitly rules he WANTS the historical-marketing bet, accepts
the Marine-faction and taste consequences on the record, and budgets the research. That is his
Law-3 right — but the 7/28 ruling must be formally overturned, not eroded.

---

## 4 · CANON DRIFT — the line where RECON becomes the briefing-screen game again

### Steelman
Operations were already ruled IN (7/28) with diegetic guards: radio/RTO assignment, never a
briefing screen, man-not-hero. The open-sim pivot and operations can coexist the way Arma's
patrol sandbox coexists with its showcase scenarios.

### Puncture — drift arrives as defaults, not decisions
The 7/17 north star is "i just wanna leave the camp and go find problems" — NO mission
tracking, ADR-029's `"PATROL"` as the only generator output. Watch the ratchet:

- Handcrafted consistent maps → they cost a month each → sunk cost demands players SEE them
  → ops get surfaced, promoted, sequenced → an op *selector* appears ("just a board in the
  TOC") → the board is the briefing screen with set dressing. Each step is locally reasonable.
- **The tell-tale list** (any ONE of these appearing means we crossed the line): an objective
  marker or tracker during an op · a success/fail result screen distinct from the AAR/ledger ·
  ops as a menu/list the player browses · the patrol AO reduced to a lobby you wait in between
  ops · "op progression" gating (finish Op 2 to unlock Op 3).
- **The guard that actually holds:** an operation is a PLACE-IN-TIME, not a quest. The RTO
  hands you a ride and a grid square; you can miss it, walk away mid-fight, or never go; the
  ONLY scoreboard is the casualty ledger (standing decree); the op ends because the battle
  ends, not because objectives ticked. If an op cannot be ignored without a fail state, it is
  a mission, and ADR-029's spirit is dead no matter what the amendment says.
- **Budget as canon metric:** the day the roadmap spends more art-days on op maps than on AO
  life (villages, ambient ecology, patrol content), the open sim has quietly become the menu
  game. Put that ratio in the decree.

**Dissolves if:** the ADR-029 amendment (already flagged as mandatory on 7/28) writes the
tell-tale list above INTO the ADR as prohibitions, and ops remain radio-encountered, missable,
and ledger-scored only.

---

## 5 · SEQUENCING — preconditions and the cheapest honest probe

### What must be TRUE before one art-day is spent here
1. **The demo ships.** EA ruling 8/6: nothing pulls effort from the ship list (briefing §6,
   binding). TIGHT-40 #40 — his verified end-to-end playthrough — is the gate, undischared.
2. **The siege replay checklist runs** (TIGHT-40 #1) — every op design reuses SiegeDirector;
   we have not yet watched the siege pass its own checklist.
3. **PLAYTEST R4 discharges.** The open-patrol loop has NEVER been verified end-to-end, in 30
   documents. Operations are the SECOND floor of a house whose first floor is unwalked.
   Building set-pieces on top of an unverified patrol loop repeats the exact pattern that
   forced the EA scope retreat on 8/6.
4. **The gating FPS number exists** (TIGHT-40 #18) — before anyone designs a dense city fight
   for a renderer with no measured floor, on a hot cap of 50.

### The cheapest probe (code-only, zero new art, post-demo week one)
**"The Ride-Out":** RTO traffic breaks into a patrol day → a Huey lands at fsb_main → it
flies the player + squad to a SEEDED enemy camp 1.5–2km out in the EXISTING AO → SiegeDirector
runs the assault with the player as one rifleman → extraction or walk home → ledger banks it.
Every component exists: Huey (complete), NPC dropoff pipeline, siege machinery, seeded camps,
casualty ledger. Claude-code days, zero Summoner art-days, zero canon amendments beyond the
ADR-029 op amendment already owed.

**What it tests, before any map is built:** is riding to someone else's fight and being small
inside it FUN (Rule One) on random ground? If YES on a random map — handcrafting is polish,
buy the landmark kit. If NO on a random map — no month of Hue art will fix it, and we just
saved the quarter. The probe is the referee between the 7/28 random ruling and today's
handcrafted ask; run it before ruling.

---

## SACRIFICES ANY DECREE MUST NAME (Law 2)

- **Choosing handcrafted ops maps sacrifices:** zero-art-cost map generation, op-layer
  replayability, ~20–32 Summoner art-days per city map, and (unless shaped as
  authored-layout-through-WorldBuilder) ADR-028's one-build-path guarantee.
- **Choosing real Tet/Hue sacrifices:** the fictional-unit protection ruled 7/28, the
  US-Army-only launch faction's coherence (Hue was a Marine fight), taste insulation around
  real dead, and freedom from big-budget comparison.
- **Choosing the four-game vibe uncritically sacrifices:** Pillar 3 (COD rails), the
  death-matters ruling (Battlefield tickets), the art/writing budget (MoV narrative), and
  honesty about indoor AI (HLL) — the one system in this whole ask that is genuinely unbuilt
  and genuinely hard.
- **Choosing to design ops NOW sacrifices:** nothing, IF it stays talk — but every day of
  roadmap design before demo-gate #40 discharges is a day the ship list didn't move, and the
  EA date is already only 19 days out.
