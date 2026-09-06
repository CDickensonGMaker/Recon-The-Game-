# ADR-007 — AMENDMENT A: Save anywhere is POST-DEMO, and here is the bill

**Date:** 2026-09-06 · **Status:** ACCEPTED as canon; **POST-DEMO — BUILD NOTHING** (Summoner decree,
THE RPG PIVOT, under his own scope wall *"but the demo scope is still the overall goal"*) ·
**Amends:** ADR-007 (save tiers), and forces a future amendment to ADR-010 (see WS6) ·
**War Room:** `production/war_room/2026-09-06_rpg_pivot/`

---

## Context

The Summoner asked for **save anywhere**, and named it correctly as the big technical bill. He is right,
and the bill is larger than the decree assumed: measured against the code this session, **save-anywhere
is the single largest item in the 2026-09-06 decree — larger than the 2km map and the zone system
combined.**

It is recorded here, in full, for one reason: **so that it stops competing with shipping.** Nothing below
is authorised.

## The correction that comes first

**Both save defects standing on the ship list are CLOSED. Strike them.** `GAME_GUIDE` §8.1 item 2
("STOP THE BLEEDING") still lists atomic writes and future-version reject as open. Measured this session:

- **Atomic write-and-swap is live** — `save_manager.gd:100-131`: temp file → flush → verify → `.bak`
  rotate → rename.
- **Future-version saves are rejected** — `save_manager.gd:193-199` returns null rather than falling
  through to `from_dict`.

Both were prerequisites for save-anywhere anyway, and they are already paid.

## Why it is expensive: it breaks ADR-010's central economy

ADR-010 and ADR-007 make saves tiny by a single trick: **the world is not saved, it is REGENERATED from
a seed.** A save is a seed plus a ledger.

**That assumption dies the instant the world has been MUTATED** — and this game mutates its world
constantly and on purpose: terrain deformed by ordnance, ADR-031 destruction, felled trees, the dead
where they fell, AI that has moved, villages burned under ADR-019. A seed describes the world at t=0. A
save-anywhere file must describe it at t=now.

Today only four sections persist (`save_manager.gd:134-142`): campaign ledgers, hub seed and name, meta,
and player pockets — and player **position** is restored **only in the hub** (`:233`).

## The bill — six workstreams

| | Workstream | Note |
|---|---|---|
| **WS1** | **Terrain mutation.** Either a ~1.0 MB heightmap delta or a replay log of deformations. | Turns a **4 KB save into a megabyte-class one** — a file-format problem, not a feature |
| **WS2** | **ADR-031 destruction state + the felled-tree registry.** | Every state-swapped structure and every downed trunk |
| **WS3** | **The living population** — every man, where he is, what he knows, what he is doing. | **This *is* ADR-025 Phase 2's bit-exact capture/apply, which has not started. It is a hard prerequisite and it belongs to that ADR, not this one.** |
| **WS4** | **Clock, weather, air traffic, fires.** | Every `get_ticks_msec()`-relative timestamp in the codebase becomes a reload defect the day this ships |
| **WS5** | **Format + the tier repeal.** ADR-007's checkpoint economy is *about* restricting when you may save; save-anywhere repeals its reason to exist | The design half |
| **WS6** | **The ADR-010 amendment** — *a seed describes the world at t=0 only.* | **Cheap, and it must come FIRST**, because every other workstream is illegal until the determinism contract admits mutation |

## The ruling

1. **BUILD NOTHING.** Recording it as post-demo canon is exactly right; anything more competes directly
   with shipping.
2. **WS6 is the only cheap piece and it is the gate.** No other workstream may start before the ADR-010
   contract admits world mutation.
3. **WS3 is not this ADR's to schedule.** It is ADR-025 Phase 2 and it is un-started.
4. **OFFER HIM THE CHEAP INTERMEDIATE BEFORE ANYONE PRICES THE FULL BILL.** Extend the existing save to
   cover the **hub-side world** — garrison roster, ward, depot, marks, most of which `CampaignState`
   already carries — and keep field saves at the wire. That is **"save when you get back to base"**, it
   costs almost nothing, it is essentially what HARD and IRONMAN already do
   (`save_manager.gd:88-96`), and it gets most of the *feel* he is asking for.
   **This is the Summoner's call to make, and he has not yet been asked it.**

## FROZEN FILES (the scope wall's enforcement surface)

**Nothing here is authorised except WS6's text.** FROZEN:

- `scripts/autoload/save_manager.gd` and `scripts/autoload/save_data.gd` — **except** the two items
  still genuinely open (the demo save-dir leak on abnormal exit, export hygiene), which are bug fixes
- `scripts/autoload/campaign_state.gd` — no new persisted sections
- anything under `terrain/` reached in the name of saving a mutated heightmap

**The named leak risk, and it is the fastest one in the decree:** save-anywhere work will ride in on the
back of the already-ordered save hardening, because both live in the same file and the hardening is
GATE-exempt. **Hardening the save is exempt. Widening what it stores is not.**

## Consequences

**Bought (by recording rather than building).** The largest item in the decree stops being a vague
ambition competing for attention and becomes a costed, sequenced, deferred plan with a named prerequisite
and a named cheap alternative.

**Sacrificed — no free lunches.**

- **Save-anywhere is further away than it sounded**, and it is gated behind an un-started ADR-025 phase.
- **The cheap intermediate is not what he asked for.** "Save at base" is not "save anywhere", and if he
  takes it, dying 300m out still costs the walk. It buys most of the feel, not all of it.
- **ADR-007's whole checkpoint economy is designed to be repealed by this**, so the tier system becomes
  vestigial the day it ships — a deliberate future deletion (fossil law) that must not be forgotten.
- **A megabyte-class save changes the autosave story**: the 30-second autosave rewrite that atomic
  writes made safe is a different proposition at 1 MB.

## Evidence

- Summoner decree 2026-09-06; council record `production/war_room/2026-09-06_rpg_pivot/`, costing in
  `analysis/technical_director.md` §4.
- `scripts/autoload/save_manager.gd:88-96, 100-131, 134-142, 193-199, 233` (all verified this session).
- `production/adr/ADR-010-determinism-contract.md` — the seed economy WS6 must amend.
- `production/adr/ADR-025-lod-tier-simulation.md` — Phase 2, WS3's owner, un-started.

## Related

- **ADR-039 §7** — the same ruling in the zones record.
- **ADR-040** — the down state; save-anywhere is the largest part of the answer to his durability ask.
- **ADR-031** — destruction, WS2's subject.
- **Pillars served:** 5 (Fail forward — a save that remembers what you broke).
