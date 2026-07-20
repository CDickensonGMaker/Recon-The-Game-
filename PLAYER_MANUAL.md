# RECON — FIELD MANUAL (FM 69-1, PROVISIONAL)
*RESTRICTED // MACV-SOG // FOR TRAINING USE ONLY*

> **MANUAL STATUS, 2026-07-19.** Sections 1, 6 and parts of 7 describe the **offer → briefing → Huey →
> exfil** loop that ADR-029 deleted; they have not been rewritten yet and are marked ⛔ inline. The
> keybind table in §2 was re-checked against `project.godot` today and is correct **except** the ABORT
> row, corrected below. §§3–5 are current.

## 1. GENERAL ⛔ (loop text superseded by ADR-029)
You lead a **five-man** recon team (§3) in an open procedural campaign.

> ⛔ **This no longer describes the game.** There is no op to pick, no fly-in and no bird to reach:
> ADR-029 replaced all of it with the **open patrol simulator** — you boot seated at the firebase, walk
> out the wire gate, and come back. The generator produces one mission type, `"PATROL"`
> (`scripts/missions/mission_generator.gd:540`). Old text: *"Every operation is generated: pick your op,
> fly in, do the work, get to the bird."*

Stealth is never required and never punished by mission failure — only by consequence. The AO
remembers what you do (intel, your roster).

## 2. CONTROLS
| Input | Action |
|---|---|
| WASD / Shift / Ctrl / Z / Space | Move / sprint / crouch / **prone** / jump |
| Q / E | Lean (E doubles as context interact at prompts) |
| Mouse 1 / Mouse 2 / R | Fire / aim / reload |
| 1–4 | Rifle / pistol / grenade / medkit |
| **5 / 6 / 7 / 8** | Smoke / claymore / pop flare / call resupply |
| **F** | Interact (plant, loot, capture, tunnel, board, **armorer's bench**) |
| **9 / 0** (hold) | Eat a ration / **field-strip the rifle** (12s, +25% condition, costs a kit) |
| **B** (hold) | Binoculars — glass a man for 2s to mark him |
| **M** | Topographic map |
| **T / Y** | Call CAS strike / mortar fire mission (needs the RTO alive) |
| **F1–F4** *or* **C / H / X / N** | Squad: on me / hold / move there / weapons tight-free (dual-bound, `project.godot:211-231`) |

*Removed 2026-07-19: this table listed **G (hold 2s) — ABORT, emergency exfil**. There is no `abort`
action in `project.godot` and no exfil step to abort (ADR-029). Nothing was ever bound to it.*

## 3. THE TEAM
Five men, persistent across missions, each an MOS:
- **POINTMAN ("EYES")** — spots ambushes and trap wires ahead.
- **RTO ("RADIO")** — carries the net. He dies, you lose CAS, mortars, resupply.
- **MEDIC ("DOC")** — when you drop, he runs to you. 2 revives per mission. Protect him.
- **MG ("PIG")** — sustained fire. **GRENADIER ("THUMPER")** — auto-lobs M79 at clusters.
- **MARKSMAN ("DEADEYE")** — an alternate; he takes the long shots.

**You do not have stats, and neither do they.** There is nothing to buy and no levels to
grind. Your aim on mission one is your aim on mission one hundred (ADR-018).

**Your men get better by doing the job, and they never tell you.** Doc gets to you faster
because he has pulled you out before. The pointman learns the trip wire by walking point.
The RTO's fire missions land quicker because he has called them before. You will not see a
number — you are meant to *feel* it, and to feel it when a veteran dies and a green kid
takes his slot. KIA are gone for good. The **BARRACKS** shows the man, not a character
sheet: GREEN → BREAKING IN → STEADY → SEASONED → SALTY.

**Look at a man from within 5m** and his rank, name and role surface. That is how you find
your RTO in a firefight — and he is the one you cannot afford to lose.

## 3b. YOUR RIFLE IS YOUR JOB
Every shot fouls it, and rain fouls it faster. A dirty weapon **jams** — it never does less
damage. Condition **carries between missions**; nothing cleans it for free.
- **Field-strip [0]** (hold 12s): +25%. A stopgap, and twelve seconds you may not have.
- **The armorer's bench** at the firebase (hold **F**, 20s): back to 100%. The only real fix.

## 4. THE ENEMY
Local Force (SKS, breaks under pressure — some will *Chieu Hoi*, capture them for
intel [F]) and NVA regulars (AK-47, they don't break). They have eyes (vision cones,
jungle-capped ~45m, worse in rain/night) and ears (gunshots 55m, your sprint 16m,
crouch-walk almost nothing). They investigate NOISE, not you. They throw grenades —
when you hear "LUU DAN!", move. Final-wave sappers sprint the wire with satchels.

## 5. THE AO
- **Jungle is concealment, not cover.** Rounds go through leaves.
- **Weather is rolled per op** (the "shown on the offer card" part is dead — ADR-029 deleted the offer
  card; you read the sky): monsoon halves everyone's
  hearing — move loud when the sky is loud. Night crushes sight lines; flares [7] undo it locally.
- **Villages**: civilians flee and cower. One may be an informer — 25 seconds after
  he sees you, everyone knows. Chickens scatter loudly. Campfires mark camps at night.
- **Tunnels**: hidden entrances drop into cache chambers [F]. Bring a pistol mindset.
- **Everything craters.** Grenades, mortars, bombs, satchels reshape the ground for real.

## 6. THREAT & INTEL (the campaign) ⛔ (superseded by ADR-029)

> ⛔ **The AA-threat and briefing-intel economy below is written against the deleted Huey/offer loop.**
> There are no LZs to defend, no ride in, and no briefing for intel to sharpen. What the intel loop
> becomes in the open patrol is **ADR-021's ground/sign economy**, which this manual has never covered.
> Retained verbatim only so old references make sense.

- Loud missions raise **AA THREAT**; clean work and ANTI-AA sweeps lower it for
  the next few ops. High threat = live AA near your LZs and a rougher ride in.
- The bird can be waved off or **shot down**. The fallback LZ is final.
- Loot documents [F], photograph targets, capture prisoners → **intel points**
  sharpen your next briefing (enemy counts stop lying to you).

## 7. GOING DOWN
HP 0 = DOWNED, not dead — if Doc lives and can reach you (30s clock, 2 revives).
After that: fail-forward. KIA ends the patrol, not the campaign — unless you
checked **IRON MAN** in the barracks. Then it was nice knowing you.

*"WHEN IN DOUBT, TRUST YOUR ALERTNESS." — RECON, 1982*
