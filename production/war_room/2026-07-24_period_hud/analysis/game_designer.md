# Game-Designer / Atmosphere — The Period HUD

**Convened:** 2026-07-24 · **Lens:** the five pillars (`bible/BIBLE.md:84-95`), ADR-029, ADR-022, ADR-012.
**Read:** handoff `README.md` (full), `RECON UI.dc.html` turn 3 target (via README spec), the code
(`scripts/ui/mission_hud.gd`, `radio_menu.gd`), the three ADRs. Skill: `hud-system/SKILL.md` loaded —
note its whole vocabulary (tweened bars, eased counters, `create_tween`) is exactly the *modern tell*
this handoff bans; it is the counter-example, not the guide, for this HUD.

## Verdict up front

**The doctrine SERVES the pillars — conditionally.** The 640×480 diegetic-first HUD is the single most
on-pillar-2 UI decision the project has made; it is `VISION_READOUT`'s "UI is diegetic-first" made
literal. Four of the five open items fit their ADRs cleanly. **One is a live contradiction** the Summoner
must rule on, and **one "deliberate artefact" is a combat-critical lie** that should not ship as written.

---

## 1 · The deliberate artefacts

### 63px name truncation — "SCHOENBER" — STAYS.
This is the cheapest, strongest Pillar-2 cue in the whole handoff. A real acetate-covered printed roster
form clips a long surname; the truncation reads as *the form was too narrow*, which is believable, not
broken. It costs nothing and it is exactly the kind of "authored by a person, not a grid" texture the
handoff (`README:114-117`) is buying. **Keep it.**

**One binding constraint — a content rule, not a code fix:** the truncation must never render two live
squad members identically. If a squad ever fields `SCHOENBERGER` and `SCHOENBERG`, both clip to
`SCHOENBER` and the player can no longer tell WHICH man is CRIT — that *does* strike Pillar 4 ("you must
know your men's state"). Mitigation: author the callsign/surname table so every name in a possible squad
is unique within its first 9 glyphs. A naming constraint on the roster generator, asserted by a probe.
With that guard, the artefact is pure upside.

### 2-digit MAGS showing "00" at 100 — the field STAYS, the "leave it at 00" clause is a BRIDGE TOO FAR.
Separate the two claims. **Two-digit zero-pad (`MAGS 07`) is period-correct and clean — keep it.** The
defended behaviour — "at 100 magazines it shows `00`, leave it" (`README:132-133`) — is the problem, on
two grounds:

- **It designs for a state that cannot occur.** A grunt does not carry 100 magazines; a realistic M16
  load is ~7-20. The game will never reach 100 mags in honest play, so "leave 00 at 100" is bravado
  defending an impossible state — there is nothing to defend.
- **If it ever DID occur (debug, cheat, future MG belt count), `00` is not a charming artefact — it is a
  combat-critical lie.** `00` reads as *empty*, the single most dangerous false readout in a firefight
  (Pillar 1 believable firefights, Pillar 4 know your state). A truncated *name* that reads slightly
  wrong is atmosphere; an ammo count that reads *empty when you are full* is a bug a playtester will file
  and be right to file. Authenticity artefacts are free on decorative fields and dangerous on state
  fields the player must act on. This one is on a state field.

**Ruling:** keep 2-digit zero-pad; drop the "00 at 100 is deliberate" clause. Clamp display at `99` so a
wraparound can never present as `00`/empty. The truncation is the good artefact; the mag-wrap is the one
that crossed the line.

---

## 2 · SPARSE and NONE density modes

### SPARSE ("read your men by voice, your mag by weight") — SERVES freedom/immersion, CONDITIONAL on the audio layer.
As an **opt-in** this is Pillar 3 (freedom — the player chooses his own austerity) and Pillar 2/4 in its
purest form. "Read your men by voice" is *literally* Pillar 4: the squad IS the RPG, and a squad you read
by barks — "I'm hit," "reloading," ammo-low calls — is more the-squad-is-the-RPG than a text readout ever
is. Hiding the roster does not strip Pillar 4 **if the voice layer actually carries the state.** That is
the load-bearing dependency, and today it is not met: the roster currently carries live state as text —
`"scanning 51m"` (`mission_hud.gd:262`) and `"ON THE NET - [T]"` (`:272`). SPARSE hides those, so unless
that state has first moved into audible barks, SPARSE doesn't create immersion, it creates *blindness*.

**Ruling:** SPARSE ships as a legitimate opt-in mode, but it MUST NOT be default until the squad
voice/wound-bark layer demonstrably carries wound/reload/contact state. Until then it is an expert toggle
for players who already know the language, not the out-of-box experience.

### NONE (reticle only) — a REAL supported mode, not a gimmick — with one guard against the r4bk law.
NONE serves a real fantasy (total-immersion / navigate-by-the-land / screenshot runs) and it is fully in
the spirit of ADR-022 (the map is your memory — so is the land). It is not a gimmick. **But it collides
head-on with the r4bk LAW: "a feature without a visible HUD affordance does not exist."** If NONE also
suppresses the *transient* affordances — the radio/fire menu when opened, the report-verb confirmation,
squad-order feedback — then squad orders and fire missions become invisible and the discovery law breaks.

**Resolution:** NONE hides only PERSISTENT furniture (compass, roster, ammo, reticle). TRANSIENT
affordances summoned on demand — the keyed radio menu, the fire-mission net, an order confirmation flash —
still surface even under NONE, then vanish. Hide the wallpaper, never the doorbell. With that split, NONE
is a real mode; without it, it is the gimmick the pillar law forbids.

---

## 3 · The five open items — FIT judgments (not build)

**(1) Real 1969 identifiers** (III Corps sheets, PRC-25 freqs, battalion designators): pure Pillar-2 win,
lowest-risk place in the whole handoff to spend authenticity — see §4. GREEN.

**(2) Keyed radio submenus (numbered/spoken, NO radial) vs ADR-012 + existing menus: GREEN — this is
already the game's established pattern, not a new invention.** The fire-support net is *already* a numbered
keyed menu: `"PRESS NUMBER TO SIGHT IT - LMB SENDS, RMB BACKS OUT. [T] OFF NET"` (`mission_hud.gd:117`),
and `radio_menu.gd:2-5` already carries per-man orders (FOLLOW ME / HOLD HERE) + the handset grab. ADR-012
keeps orders on the F1-F4 / C-H-X-N keys and the ambush mark separate; a **radial wheel would be the
anachronism AND would fight the game's keyed identity.** The handoff is describing what exists and asking
to extend it period-correctly. No conflict.

**(3) Overloaded report verb (aim + press = call over net + mark map) vs Pillar 4 + ADR-022: GREEN with a
hard layer constraint.** The "call over the net" half is exactly Pillar 4 — "you suggest and call"
(`BIBLE.md:88`); a grunt reporting a contact he sees is the fantasy. The "mark the map" half is legal
**only if it stamps the OBSERVED layer** (ADR-022 §1: "THE GAME MARKS WHAT YOU SAW… stamped
automatically" — a contact you called IS something you saw). It **MUST NOT** write to the ANNOTATED
grease-pencil layer, which the grease-pencil law reserves for the player's hand alone: *"He never marks
the map for you. The pencil is yours"* (`ADR-022:57`). So: report verb → OBSERVED (printed, decays),
never ANNOTATED. That single constraint keeps it canon.

**(4) "Map as an object with a cost" vs ADR-022 topo_map.gd (M-toggle): GREEN — it DEEPENS ADR-022.**
"Time passes, the treeline is unwatched, marks in grease pencil" is a near-quote of ADR-022's
decay-on-OBSERVED + grease-pencil-ANNOTATED design. The new idea is the *cost* — reading the map means you
are not watching the treeline — which is a strong Pillar-1/Pillar-2 diegetic move: it turns the map from a
free pause overlay into a real object you are exposed while using. Only friction: ADR-012's M-toggle is
instant/free today, so adding an exposure/time cost is a genuine interaction change that needs a Summoner
nod — but it pulls WITH the pillars, not against them. GREEN, pending his ruling on the cost mechanic.

**(5) Pre-patrol planning screen vs ADR-029 "no briefing UI": THE CONTRADICTION. FLAG FOR SUMMONER.**
This is the one item the council cannot resolve on its own. ADR-029 is emphatic and near-verbatim from the
Summoner: *"Remove the whole briefing part of the game… an open simulator with no mission tracking… The
briefing/offer/select/exfil-bird chain is deleted under ADR-023"* (`ADR-029:9-13, :37-38`); north star
*"i just wanna leave the camp and go find problems"* (`:16`). A screen labelled "pre-patrol planning" is,
on its face, the briefing screen ADR-029 condemned and ADR-023 deleted — and resurrecting a buried system
is a Fossil-Law violation.

BUT the label hides a real distinction the Summoner must rule on:
- **BRIEFING** (the game hands you objectives / offers / a destination) — CONDEMNED, do not build.
- **PLANNING** (the player looks at his own topo sheet, picks which way he'll walk, checks his load,
  marks his own grease-pencil ambush) — this is **ADR-022 + Pillar 3** ("plan your own war on paper"),
  in a pre-patrol context, assigning *nothing*. That is legal and on-pillar.

The screen is fine **if and only if** it surfaces the map + squad + kit and issues zero objectives. If it
presents a task, an offer, or a pointer, it is the deleted briefing loop wearing a period font. **The
Summoner must rule on the CONTENT, not the label.** This is the sharpest tension in the handoff.

---

## 4 · Authenticity vs playability — "keep the real ones even where they scan worse"

The principle is **correct on decorative fields and dangerous on state fields** — and the handoff applies
it to both without drawing the line.

- **Decorative identifiers** (grid `XT 4471`, `46.55 MHz`, sheet `6331 IV`, `2ND SQD, B/1-16`): the player
  never has to *act* on these — they are flavour the eye reads and the hand never uses. "Scans worse"
  costs zero playability here. This is the **safest possible place to spend authenticity**, and it buys
  hard Pillar-2 texture. Keep the real ones, unreservedly.
- **State fields** (mag count, man status): the same "keep it even if it scans worse" instinct produced
  the `MAGS 00` lie in §1. Here authenticity-over-playability actually bites, because the player must act
  on the number, and a wrong number gets men killed.

**The rule to hand the Summoner:** authenticity artefacts are free on DECORATIVE fields and forbidden from
corrupting COMBAT-CRITICAL readouts. Spend all the awkward-scanning realism you want on names, freqs,
grids and sheet numbers; never let an artefact make a state field lie.

---

## Sacrificed (no free lunch)

- **The truncation will draw "is this a bug?" reports** even when working as designed (same class of
  complaint ADR-022 accepts for the wrong-map). We keep it anyway; it is the design working.
- **SPARSE/NONE split the QA surface three ways** and put load on an audio-state layer that isn't proven
  yet. If we ship SPARSE as default before the barks carry state, we ship blindness dressed as immersion.
- **The report verb and the map-cost quietly expand ADR-022's interaction contract** — more of the map's
  behaviour becomes load-bearing, and ADR-022 already warns the two-layer map "is a real UI problem, not a
  small one" (`ADR-022:73`). Every verb we hang on it raises that stakes.
- **The planning screen, if mis-scoped, reopens the exact briefing loop the project spent an ADR and a
  Fossil-Law deletion to kill.** That is the one that can cost real rework, and it is why it goes to the
  Summoner, not to us.
