# ADR-023 — THE FOSSIL LAW

**Status:** ACCEPTED — direct Summoner decree, 2026-07-13
**Supersedes:** nothing. **Amends:** the working agreements (Charter §7), process law (Charter §8).
**Enforced by:** `tests/test_fossils.tscn` (in the suite; `run_all_tests.ps1` auto-discovers it).

---

## The decree

> *"lets clean up old and outdated code and make that a key part of the workflow — when we improve or
> fix a system we always need to clean up the old system so we don't have multiple things that could
> accidentally be interpreted by you as the same thing when coding."* — the Summoner, 2026-07-13

**THE LAW: a system's replacement is not shipped until its predecessor is deleted.**
You may not fix a system and leave the corpse standing.

---

## What a fossil is

A **fossil** is a symbol that is *declared and never read*. A const nobody reads. A signal nobody
connects. A function nobody calls.

A fossil is **not a bug.** The game runs perfectly with it. It is worse than a bug:

> **A fossil is a lie in the map.** It reads as load-bearing. It survives every grep. And the next
> reader — human *or* AI — cannot tell it from live code.

That last clause is the whole reason for this ADR. The Summoner's exact words: *"so we don't have
multiple things that could accidentally be interpreted by you as the same thing when coding."* An
agent reading `ALERT_RANGE` next to `enemy_data.alert_range` has no way to know one is a corpse. It
will use the wrong one. **The fossil layer is an AI-drift generator**, and this project has already
paid for that twice.

## The evidence that produced this law (2026-07-13, one session)

The disease, five times, in five unrelated systems — and **the game worked the whole time:**

| Fossil | The truth |
|---|---|
| `ALERT_RANGE` / `AGGRO_RANGE` (`enemy_base.gd:234-5`) | superseded by `enemy_data.alert_range`. The replacement's own comment says so. Never deleted. |
| `MAX_THINK_TIME` (`enemy_base.gd:236`) | a Quake-3 pattern that was never wired. `last_think_time` never even assigned. |
| `CombatManager.apply_bullet_damage` (`:76`) | **an entire damage router the bullet system routes around.** Its 2 signals fire inside it; nothing connects to them anyway. |
| `.gitignore` rules naming `art_source/**` | a tree the restructure deleted. **The rule did not fail — it stopped matching**, and swallowed 1.66 GB. |
| the GATE bead (`97u3`) | `k77e` was never `bd dep add`-ed to it. **A gate that blocks nothing.** ~95 commits shipped over it. |

**None of these broke anything. Every one of them was a lie about what the code means.** The Summoner
found this the hard way — he opened `satchel_m3.blend`, saw an empty window, and deleted a fully-built
aid bag, because the generator wrote objects into the file with **no scene** and Blender had nothing
to draw. Real art, invisible to the only view a human ever looks at. Same disease, different layer.

**The project's problem is not fractures. It is fossils.**

---

## The mechanism — and why it is not a document

Every guardrail this project has ever written was a document a diligent reader had to *choose* to
obey, and **not one of them was a machine that said NO.** That is precisely how `.gitignore` and the
GATE were walked out from under. A fossil law written only in Markdown would be the sixth fossil.

So the law is a **ratchet**, and it lives in the test suite:

- `tests/test_fossils.gd` scans every declaration in `scripts/` and every reference in `scripts/`,
  `terrain/`, `scenes/`, `data/`, `tests/`, `tools/`.
- The fossils are grandfathered in `tests/fossil_baseline.json` — **19/19** of record (`:3-4`, as of
  2026-07-24; this ADR was authored at 79).
- **A NEW fossil fails the build.** You changed a system and left the old one standing → red.
- **The register only shrinks.** Bury a fossil, and the probe tells you to shrink it.
- Regenerating the baseline to *silence* a failure is **the one forbidden move.** It is a debt
  register, not a snooze button.

**Verified, not claimed** (ADR-015): baseline stable (19/19 of record, `tests/fossil_baseline.json:3-4`,
as of 2026-07-24) → PASS/exit 0. A planted fossil → FAIL/exit 1, named by file and line. Removed → green.
The gate bites.

### Two rules the probe had to learn, and they are the law in miniature

1. **A comment is a tombstone, not a caller.** `# was a hardcoded ALERT_RANGE*2` was counted as a
   reference — *the very sentence recording the const's death was keeping it off the death list.*
   Comments are now stripped before the tally. That one fix revealed 10 more fossils (69 → 79).
2. **The death register is not a caller.** `fossil_baseline.json` names all 79 fossils; tallying it
   resurrected every one (79 → 35). **The fossil detector was defeated by its own record** — the
   disease, committed by the cure. The register is now excluded.

---

## What the fossils are (triage, not a delete list)

The probe finds *dead symbols*. It cannot tell you **why** they are dead. Three kinds, and only the
first is a true fossil:

1. **FOSSIL** — superseded by a newer system. *Delete.* (`ALERT_RANGE`, `apply_bullet_damage`, `MAX_THINK_TIME`)
2. **UNFINISHED** — built ahead of its wiring. *Wire it or cut it.* (`radio_handset` take/cord — bead `mywr`)
3. **MISSING FEATURE** — documented and never built. *Build it.* (`world_config`'s FPS-fallback ladder:
   `VEGETATION_DENSITY_MULT` + `BILLBOARD_DISTANCE_MULT` are documented as the perf escape hatch and
   **read by nothing** — while perf is the project's top systemic risk.)

Category 2 is also an **r4bk Law** violation: grenade cook-off emits `grenade_cooking` and exposes
`get_cook_progress`, and **the HUD connects none of it.** A feature with no affordance does not exist.

**Triage is a War Room job, not a sweep.** The 2026-07-13 structure audit proved the cost of the
opposite error: 913 of 1,291 assets have zero grep hits, and deleting on that number would have
erased the entire cast — `ModelActor` resolves them from bare `unit_id` strings.

---

## Consequences (what this costs — no free lunches)

- **Every fix gets longer.** You now pay for the deletion at the same time as the improvement. That is
  the point, and it is a real cost.
- **The suite goes red on work that used to pass.** Leaving a corpse is now a build failure, not a
  shrug.
- **The fossils are a debt.** They are grandfathered, not forgiven. Shipping with them is allowed; *growing*
  them is not.
- **The probe is conservative and will miss fossils.** A symbol mentioned anywhere in a string, a
  scene, or a resource is spared. We would rather miss a fossil than delete something live.
