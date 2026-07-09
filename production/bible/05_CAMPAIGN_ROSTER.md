# Bible 05 · Campaign & Roster

**Obeys Pillars:** 4 (squad is the RPG), 5 (fail forward). **Source:** `DESIGN.md §2, §4.5, M8` + braindump 2026-07-08.
**Beads:** epic `RECONgame-4i60` (campaign loop overhaul) + children (roster/bios, HQ tent, faction types, visual variety).

---

## The core experience — US Army grunt (base game)

**Decision 2026-07-08:** the base game IS the **Regular Army grunt** experience — one faction, no
operation-style front-door at launch. You play a draftee/volunteer line grunt: standard 4-man fireteam,
M16 / M60 / M79 kit, search-and-destroy / firebase-defense / convoy-escort / ville-sweep offers.

**Tonal north star (grunt-infantry canon):** **Platoon · Hamburger Hill · Apocalypse Now** — attrition,
dread, moral weight, the boredom-then-terror rhythm, the squad as your only anchor. Worn, muddy,
unglamorous. NOT the SF/recon glamour fantasy. Reinforces Pillars 2 (atmosphere), 4 (attachment), 5 (fail forward).

### Operation Styles → POST-LAUNCH DLC (deferred)
Special Forces (MACV-SOG) and Marines were considered as a campaign front-door; **deferred to DLC.**
They remain in the design as future forks, not launch scope — this keeps launch to **ONE model set** and
removes the loop-structure risk.

| Style | Ships | Feel | Kit | Models |
|-------|-------|------|-----|--------|
| **Regular Army (grunt)** | **BASE** | line infantry, attrition | M16 / M60 / M79 | Army grunt — the one base set |
| Special Forces (SOG) | DLC | small, deniable, deep | CAR-15, suppressed, sterile | SF kit (later) |
| Marines | DLC | aggressive, I Corps hill fights | heavier organic | USMC kit (later) |

**No War Room gate for launch** (single-faction grunt = no loop-structure change). A War Room convenes only
if/when the DLC styles are greenlit — those DO fork the loop.

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
