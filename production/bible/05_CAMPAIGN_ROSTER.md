# Bible 05 · Campaign & Roster

**Obeys Pillars:** 4 (squad is the RPG), 5 (fail forward). **Source:** braindump 2026-07-08.
*(The old `DESIGN.md §2, §4.5, M8` pointer is dead — `DESIGN.md` has no numbered sections and no M-series
roadmap.)*
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

The between-missions home screen. Data + UI only, no 3D sim. *(The `DESIGN §3 layer 1` pointer is dead.)* Panels:
- **Mission board** — ⛔ **DELETED BY ADR-029.** There is no offer chain: the open patrol simulator has no
  briefing UI and no mission board, and the generator emits one type, `"PATROL"`
  (`scripts/missions/mission_generator.gd:540`). This bullet used to read *"Uses existing
  `mission_select.roll_offers()`"* — **there is no such function.** `roll_offers` has zero hits in
  `scripts/`; only the tombstone `scripts/ui/screens/mission_select.gd.uid` remains, the script itself is
  gone. *("Uses existing X" is the most dangerous phrase in a spec: it tells the reader not to check.)*
- **Roster** — the squad; view/assign/heal/bench; read bios; see wounds & XP.
- **Loadout** — by MOS + requisition (style-gated).
- **XP spend** — RECON team pool → skills/attributes.
- **War map** — province state, zone control, calendar.

## Persistent Roster (XCOM-level)

> **⛔ UNBUILT SPEC (banner added 2026-08-07).** The soldier record below, the wounds/status/rotation
> rules, and the 100 Bios section were never built. The shipped roster record is
> `scripts/squad/squad_roster.gd:95-111` — name / mos / nick / st / ag / al / skills / skill_uses /
> xp / kills / missions / alive / face / helmet, and nothing else: no `wounds[]`, no `status`, no
> `bio_id`, no `portrait_keys`, and `data/roster/` does not exist. Read everything from here to the
> end of the file as spec awaiting the post-launch open-patrol world (EA scope ruling 2026-08-06).

`CampaignState` autoload (already exists) owns the roster and survives missions (MissionScope deliberately
does NOT reset it). A soldier record:

```
{ id, name, nickname, style, mos, portrait_keys{helmet,torso,arms,face},
  St, Ag, Al, skills{}, xp, wounds[], status: green|active|wounded|rotating|KIA|MIA,
  missions_run, kills, join_date, bio_id }
```

**Rules** *(the `DESIGN §4.5, §2` pointer is dead)***:**
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
