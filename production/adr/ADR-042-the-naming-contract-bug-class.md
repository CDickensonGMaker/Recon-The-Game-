# ADR-042: A name is not a contract — the prefix-match bug class

**Date:** 2026-09-09 · **Status:** ACCEPTED as law; the audit clause is binding immediately,
the migration clause is POST-DEMO ·
**Depends on:** ADR-015 (verification and gate law), ADR-023 (the fossil law) ·
**Binds:** every system that decides behaviour by matching a node, mesh or resource NAME ·
**Origin:** the Summoner, 2026-09-09, after finding the same defect shape twice in one night

---

## Context

Two defects surfaced in a single session. They look unrelated and they are the same bug.

**One.** Every US grunt has been wearing two helmets. `ModelActor` hides gear meshes by matching
name prefixes (`grunt_`, `cap_`). The model ships three helmet variants and the dresser picks one;
the other two do not carry those prefixes, so nothing hides them. The code confesses it in its own
comment: *"helmet_camo_shell / helmet_bugjuice do not begin with grunt_ or cap_, so they slipped
this net and every grunt shipped wearing TWO helmets."* Two stacked helmets z-fight, which is the
black speckling on helmets the Summoner has been asking about "since day one almost."

**Two.** The firebase decides bullet penetration by matching `FSB_SOFT_PREFIXES` against collider
names. Anything matching nothing becomes `hard_surface` — **bulletproof**. 589 soft against 1,847
hard, and no test in the project exercises that function. The Summoner asked the question that
found it: *"did we ever prove in game that you can shoot thru certian building types? i know in the
shooting range we had but how does that translate to the buildings int the world."*

The village path IS proven — `probe_structure_ballistics` places a real hut and a real bunker,
spawns a man in each, and verifies the shot axis crosses a tagged wall before firing. The firebase
uses a different function that nothing tests.

### The same shape appears elsewhere in this project

- `_SOFT_NAME_HINTS` in the collision table — "hooch", "hootch", "hut", "thatch", "bamboo"…
- `_GEAR_NAME_HINTS` in the hitzone builder — "hat", "helmet", "boonie", "pith"…
- `NAV_IGNORE_PREFIXES` / `REMESH_COLLIDER_PREFIXES` in the site planner
- the destructible export contract, whose own skill states the consequence plainly: **a mesh that
  misses a prefix silently ships INVULNERABLE and BULLETPROOF, with no error**

---

## The bug class, stated

**A name-prefix match is an OPEN set pretending to be a closed one.**

1. It fails **silently**. An unmatched name does not error; it takes the default branch.
2. It fails **toward the wrong default**. Unmatched means bulletproof, means visible, means
   un-hidden — always the option the author was not thinking about.
3. It fails **later**. It is correct the day it is written and breaks when someone adds a mesh,
   renames one, or re-exports an asset — none of which touch the matching code.
4. It fails **invisibly to tests**. A ceiling test passes: the system works on the meshes the author
   remembered. The meshes nobody remembered are exactly the untested ones.

This is a named instance of the standing law that **a green validator can pass empty work**.

### The canonical illustration: one underscore, eleven pieces of a man's own webbing

`hitzone_builder._GEAR_NAME_HINTS` excludes gear from a man's hurtbox by SUBSTRING. It carries
the word `"webbing"`. The meshes are named `web_buckle`, `web_snap_l`, `web_susp_r` and so on.

`"webbing"` has never matched anything. So every US grunt in this game has been carrying eleven
suspender clips, snaps and buckles as HURTBOX VOLUME — **you could shoot a man's web snap and
hurt him** — and the list's own comment warned about exactly this outcome ("you could shoot his
ANTENNA and hurt him") while failing to deliver it. Measured 2026-09-09 by making the harvester
name every skinned mesh it takes; the VC, whose bodies export as one joined mesh, were clean.

All four properties of the bug class in one line of source: it failed silently, toward the
dangerous default (harvested, not excluded), later than it was written, and invisibly to tests.

### The second worked example: the name the CODE reads is not the name the ARTIST wrote

The webbing case is a list that missed a name. This one is worse, because the name the contract
needs **does not exist on the node the contract inspects.**

`_tag_fsb_ballistics` reads the ballistic family off the **CollisionObject3D**. But Godot's glTF
importer **MINTS** a `StaticBody3D` for every `-colonly` node it converts, and names it
`StaticBody3D` or `@StaticBody3D@20876` — a name carrying no information whatsoever. 132 of the
firebase's colliders are born that way. All 132 matched no prefix and took the dangerous
default.

Measured 2026-09-09 by `tools/probe_unnamed_colliders.gd`, which was written specifically to
avoid guessing what they were: 80 are parapet segments, where hard is right by accident — and
**three are `fb_gp_tent_i` and one is `fb_mess_i`. A GP tent and the mess hall, both on the soft
list for years, were bulletproof because their collider was born anonymous.** The identity was
on the PARENT the whole time. The tagger falls back to it now.

**The lesson a reader of the webbing case alone would not take away:** when a name is a contract,
ask *which node* carries the name, and whether the engine invented it. An importer, an exporter
or a `.duplicate()` can hand you a node whose name was never authored by anybody.

**And the fourth property had teeth.** `test_hitzone_rebuild` needs two units with different
hulls or it proves nothing, and its discriminating pair — `us_grunt_rifleman` vs
`us_pilot_white` — only differed BECAUSE of the web gear. Fixing the gear made the two identical
and turned the probe red. **The probe had been discriminating on the defect**, and would have
gone quiet the instant anyone got it right, with nothing to say why. See the broken-instrument
register.

---

## Decision

### 1. AUDIT CLAUSE — binding immediately

**Every name-matching decision must be able to enumerate what it did NOT match.**

A system that classifies by name must, on load, report the distinct name families that matched no
rule and therefore took the default. Families, not every instance. A defect must be visible by
reading one line of the boot log rather than by playing until something behaves wrongly.

Where the default is dangerous — bulletproof, invulnerable, visible, invincible — the unmatched
list is a **ratcheting gate**: the build fails if it grows.

The firebase penetration probe ordered on 2026-09-09 is the reference implementation.

### 2. THE DANGEROUS DEFAULT MUST BE THE SAFE ONE

Where it can be inverted without changing the design, unmatched should fail toward the *harmless*
option: penetrable rather than bulletproof, hidden rather than visible. A mesh nobody classified
should not become cover the player trusts with their life.

Where it cannot be inverted, clause 1 applies with a ratcheting gate. No exceptions.

### 3. MIGRATION CLAUSE — POST-DEMO, build nothing now

A name is not a contract. The right contract is one of:
- an explicit manifest listing every member of the set, or
- a property authored in the asset itself (a glTF extra, a custom node property), or
- an exporter that refuses to emit a mesh carrying no classification

Migrating the existing prefix systems is post-demo work. **This ADR does not authorise it.** What is
authorised now is clause 1 and, where free, clause 2.

### 4. THE TEST MUST BE A PRESENCE TEST

`probe_structure_ballistics` is the model, and specifically its refusal to fire until it has
confirmed a tagged wall is on the line — *"a doorway would let the round through untested."*
A test that proves the mechanism works on hand-picked cases proves nothing about the world.
Test the shipped asset, through the real load path, and assert on what was NOT covered.

---

## Consequences

**Accepted cost.** Clause 1 adds a boot-log line and a gate to every name-matching system, and some
of those lists will be long the first time they are printed. That is the point: the length IS the
finding. Clause 2 may flip meshes to penetrable that were quietly bulletproof, which will change how
some fights play. That is a correction, not a regression.

**What this does not do.** It does not fix the two originating defects — those are separate work
items. It does not authorise a migration. It does not apply to name matching used for logging,
debugging or tooling, where a miss is harmless.

**The tell, for future readers.** If a system asks "does this name start with…" and cannot answer
"and what didn't?", it is this bug, and it is already wrong somewhere you have not looked yet.

---

## Related

- Helmet stacking: **CLOSED on the asset side** — all three variants are caught, because the gib
  contract reads names off `GibSystem.REGIONS` instead of re-listing prefixes. (This line said
  "diagnosed, unfixed" until 2026-09-09.)
- `hitzone_builder._GEAR_NAME_HINTS` — FIXED 2026-09-09, and now this ADR's worked example above
- Firebase penetration: `_tag_fsb_ballistics` / `FSB_SOFT_PREFIXES` — probe BUILT and ratcheting
  2026-09-09 (`tools/probe_firebase_penetration.gd`, `--pen-probe`). It found 242 bulletproof
  hooch walls, 262 bodies reading as hard cover, a dead prefix matching nothing, and a hanging
  light bulb that stopped rifle rounds
- `PERF_LEDGER.md` 2026-09-09 — the broken-instrument register, which is the same disease in the
  measurement layer: three retracted conclusions in one night, each from a mislabelled column
