# Bible 05 · Campaign & Roster

**Obeys Pillars:** 4 (squad is the RPG), 5 (fail forward). **Source:** `DESIGN.md §2, §4.5, M8` + braindump 2026-07-08.
**Beads:** epic `RECONgame-4i60` (campaign loop overhaul) + children (roster/bios, HQ tent, faction types, visual variety).

---

## Operation Style — the campaign front door (NEW)

The **first choice of a campaign**, before any mission. Picks the identity you play the whole campaign as.
It is not cosmetic — it reshapes offers, kit, roster, and models.

| Style | Feel | Squad size / MOS lean | Kit | Mission-offer weighting | Models needed |
|-------|------|----------------------|-----|-------------------------|---------------|
| **Special Forces (MACV-SOG)** | small, deniable, deep | 2–4, heavy on Point/RTO/Demo | CAR-15, suppressed, sterile | recon, snatch, cross-border, sabotage | SF: boonie/beret, tiger-stripe, light rig |
| **Regular Army** | line infantry, supported | 4, standard fireteam | M16, M60, M79 | search-and-destroy, firebase defense, convoy escort | Army: M1 helmet, OG-107, ALICE-ish |
| **Marines** | aggressive, up north (I Corps) | 4, assault lean | M16, heavier organic firepower | clear-and-hold, hill fights, ville sweeps | USMC: own helmet cover, cammo |

**Decision status:** ⚠️ this changes the loop structure and commits us to ≥3 faction model sets.
**Run a War Room before building it** (Arbiter + game-designer + systems-designer + devils_advocate).
Named per `ROADMAP.md` as the gate before M8-campaign work.

---

## HQ Tent (firebase hub)

The between-missions home screen. Data + UI only, no 3D sim (DESIGN §3 layer 1). Panels:
- **Mission board** — generated offers weighted by war state + forced events (firebase defense when a zone goes hot). Uses existing `mission_select.roll_offers()` (now deterministic + one-seed-per-op).
- **Roster** — the squad; view/assign/heal/bench; read bios; see wounds & XP.
- **Loadout** — by MOS + requisition (style-gated).
- **XP spend** — RECON team pool → skills/attributes.
- **War map** — province state, zone control, calendar.

## Persistent Roster (XCOM-level)

`CampaignState` autoload (already exists) owns the roster and survives missions (MissionScope deliberately
does NOT reset it). A soldier record:

```
{ id, name, nickname, style, mos, portrait_keys{helmet,torso,arms,face},
  St, Ag, Al, skills{}, xp, wounds[], status: green|active|wounded|rotating|KIA|MIA,
  missions_run, kills, join_date, bio_id }
```

**Rules (DESIGN §4.5, §2):**
- **Permadeath** — KIA is gone; body drag + tags is a *beat*, not a save. MIA feeds the CAPTURE epic (`RECONgame-iyuh`).
- Wounded heal on the calendar (~2 St/day); near-cap veterans rotate stateside; green replacements arrive.
- `portrait_keys` drive appearance from the modular model kit (see Bible 09) so a bio has a face on screen.
- Minimal stats (St/Ag/Al + MOS + skills). **Maximal attachment** comes from names, bios, history — not stat depth.

## 100 Bios

Pure content/data — **no asset dependency, authorable now.** A bio: `{ id, name, nickname, hometown,
draft-or-volunteer, pre-war job, 1-line quirk, voice/temperament tag, style-affinity }`. Feed the roster's
`bio_id`; nickname surfaces in barks. Author as a data file (`data/roster/bios.gd` or `.json`), lint for
uniqueness. Split across styles (SF volunteers skew different from drafted line infantry). **Bead:** child of `4i60`.

**Build note:** design the roster schema FIRST (this doc), then bios can be batch-authored (good subagent-fanout job).
