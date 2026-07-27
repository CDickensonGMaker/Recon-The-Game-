# ARCHITECTURE / COUPLING READ — 2026-07-26

**Scope:** "are there too many load-bearing pieces, and is there a refactor that makes the code make
more sense." Desk read built from the three PRIOR audits plus fresh measurement today. **No full
re-investigation was run.** Every claim below carries a pointer or a measured number (POINTER LAW).

---

## 1. WHAT THE PRIOR AUDITS ALREADY ANSWER (don't re-run these)

The project has audited **two** of the three failure axes. The third — coupling — has never been done.

| Axis | Audit | Status |
|---|---|---|
| **DEAD code** (declared, never read) | Fossil law ADR-023 + `GHOST_CODE_AUDIT_2026-07-25.md` (six passes) | **COVERED and CLEANED.** Runtime load graph clean (240/240 res:// targets exist), zero unattached scripts, zero dead signals, zero orphan .tres. Wave shipped 7/25. |
| **DIVERGENT parallel LIVE systems** (same job, several implementations) | War Room `2026-07-17_worldbuild_unification/synthesis.md` → ADR-028 | **DIAGNOSED, PARTIALLY FIXED.** Phase 1 shipped. Phases 2–3 were beaded — and beads were retired 7/22, so they are orphaned (see §3.1). |
| **COUPLING / load-bearing surface** (how many things does one change break) | — | **NEVER AUDITED.** This document is the first read. |

The 7/17 memo already named why a fossil audit can't answer this question: *"the fossil probe catches
DEAD code, NOT divergent parallel LIVE systems doing the same job."* The same blind spot applies to
coupling — a maximally-coupled codebase has **zero** fossils and passes every probe in the suite.

---

## 2. FRESH MEASUREMENT (2026-07-26)

**Codebase:** 344 `.gd` files, 14 autoloads.

### 2.1 Global fan-in — how many distinct files touch each autoload

| Autoload | Files referencing | Read |
|---|---:|---|
| `GameManager` | 32 | ~9% of the codebase |
| `CampaignState` | 32 | ~9% |
| `CombatManager` | 31 | ~9% |
| `NoiseBus` | 25 | |
| `SimClock` | 21 | |
| `AgentRegistry` | 17 | |
| `DamageSystem` | 17 | |
| `GameSettings` | 9 | |
| `SaveManager` | 7 | |
| `VOManager` | 3 | squad_system, enemy_base, field_director only |
| `ClearingSystem` | 3 | |
| `WorldSim` | 2 | `mission_generator.gd:207,211` + `test_world_alive.gd` |
| `AudioManager` | 1 | |
| `TerrainEngine` | **0 direct** | reached only by string: `terrain/core/terrain_manager.gd:55` `get_node_or_null("/root/TerrainEngine")` |

> **THIS TABLE'S METRIC IS BAD — corrected below on 2026-07-26, same day. Do not act on the
> "files referencing" column.** Counting *distinct files* undercounts a global that is used heavily
> from few files, and scores zero for a global fetched by string into a variable. Re-measured by
> **production call sites**:

| Autoload | Prod call sites | Verdict |
|---|---:|---|
| `CampaignState` | 70 | load-bearing |
| `CombatManager` | 63 | load-bearing |
| `GameManager` | 60 | load-bearing |
| `NoiseBus` | 41 | load-bearing |
| `AgentRegistry` | 39 | load-bearing |
| `SimClock` | 37 (+2 string-fetch) | load-bearing |
| `GameSettings` | 26 | healthy |
| `DamageSystem` | 23 | healthy |
| `VOManager` | 17 | healthy |
| `SaveManager` | 15 | healthy |
| `ClearingSystem` | 7 | modest, real |
| `AudioManager` | 5 | modest, real |
| `TerrainEngine` | 0 direct, **1 string-fetch** | **load-bearing** |
| `WorldSim` | 2 | thin — deliberately (below) |

**Verdict, corrected: there is no autoload problem at all. Nothing here should be trimmed.**

Two claims in the original read were simply wrong, and both were wrong the same way — the instrument
could not see the usage:

- **`TerrainEngine` is not near-empty; it generates the world's heightmap.** It is fetched once by
  string into `terrain_generator` (`terrain/core/terrain_manager.gd:39,55`) and driven at `:95-109`
  (`set_preset`, `target_relief`, `generate`, `heightmap_data`). A fan-in count of `TerrainEngine.`
  scores it zero. Demoting it would have broken terrain generation outright.
- **`WorldSim` is thin because a ruling made it thin.** `production/PERF_LEDGER.md:1048` records it as
  "now **34 lines**, a flat id-to-dict registry", and `production/bible/03_AI_DETECTION.md:44` carries
  the ruling *"tick-list wins; WorldSim tiers die"*. The surviving registry is the deliberate remnant
  of a killed system, not neglect. **Do not delete it as a fossil.**

**The lesson, and it is the same one twice in one session:** grep-shaped metrics lie about
stringly-typed and indirectly-held references — first on groups set through a builder array (§2.3),
then on an autoload held in a variable. In this codebase, **measure by running, not by matching.**

### 2.2 God objects

| File | Lines |
|---|---:|
| `scripts/enemies/enemy_base.gd` | 2236 |
| `scripts/levels/ai_stress_arena.gd` | 1858 |
| `scripts/player/player.gd` | 1316 |
| `scripts/allies/ally_base.gd` | 1147 |
| `scripts/missions/field_director.gd` | 1096 |
| `scripts/world/site_planner.gd` | 930 |
| `scripts/player/weapon_holder.gd` | 874 |

`enemy_base` + `ally_base` = **3,383 lines**. Confirmed today: `class_name AICombatant` has **zero hits
repo-wide** — the Part B merge decided 7/23 is still unbuilt. **They are NOT "two halves of a duplicated
combatant"** — that reading is measured and refuted in §2.6.

### 2.3 The invisible coupling surface — stringly-typed dispatch

- **219** group-string couplings (`add_to_group` / `is_in_group` / `get_nodes_in_group`) across the tree.
- Dynamic dispatch (`has_method` / `.call` / `call_deferred` / `get_node_or_null`), top files:
  `player.gd` **42**, `enemy_base.gd` **22**, `scripted_sequence.gd` **15**, `seat_system.gd` **10**.

This is the real answer to "too many load-bearing codes." **Neither the type system nor a grep can
prove any of these links.** The 7/25 audit's two live bugs were both exactly this failure mode: a
group read with no writer (`temple_shrines`, `player.gd:454,602`) and a cleanup loop with no
registrants (`wave_runners`, `mission_scope.gd:29`), plus eight groups written-but-never-read.

**MEASURED, and it corrects the alarm above.** A probe now exists — `tests/test_group_contract.gd`,
run headless in Godot 4.7 — and the group landscape is **healthy**: 44 written, 35 read, and after the
7/25 wave only ONE production violation survives (§2.4). The projected "defect rate of 219 unchecked
links" did not hold. The group axis is in good shape; what remains uncovered is the `has_method`
dispatch surface, which no probe reads.

**A false positive worth recording, because it is the trap this whole class sets.** An ad-hoc grep of
group writers flagged `civilian_hurtbox` as read-but-never-written — a live bug, apparently. It is
not: `civilian.gd:154-155` writes it, by passing the name inside an **array argument** to
`HitzoneBuilder._build_static`, where no `add_to_group("…")` literal appears. Any scan looking for the
literal call misses every group set through the builder — 6 call sites (`ally_base.gd:436`,
`enemy_base.gd:447`, `gore_dummy.gd:113`, `player.gd:866`, `hitzone_editor.gd:146`,
`civilian.gd:154`). The probe handles both forms; a grep cannot. **Do not audit groups by grep.**

`player.gd` with 42 dynamic dispatches is the single most load-bearing file in the project: every
interaction verb added since the open-sim pivot (radio take, shrine search, SECURE, binoculars, cook
ring, downed clock) bolted another `has_method` onto it.

### 2.4 Two live findings the new probe surfaced (2026-07-26, verified in 4.7 headless)

**(a) `ally_hurtbox` is an inert group.** Written at `scripts/allies/ally_base.gd:436` (production),
read by **nothing** — not one production consumer, not even a test. Damage does not route by group at
all: it routes by collision layer (`scripts/combat/hitzone.gd:49-54`). The enemy twin `enemy_hurtbox`
is equally unread in production and survives only on a test reader, i.e. it is test-only-live debt
already owned by the sibling probe. ADR-023 says delete the ally string; **left in place deliberately**
because the Part B `AICombatant` merge (§3.2) wants the enemy/ally naming symmetric, and deleting one
half of a pair right before merging them trades a small lie for a bigger one. Decide it *with* Part B.

**(b) Two systems write the same collision mask, and the call site loses.**
`enemy_base.gd:447` builds enemy hitzones with `HitzoneBuilder.build(self, ma, 64, 16, …)` — signature
`build(body, model, layer, mask, groups, with_gut)` (`hitzone_builder.gd:78-79`), so **mask = 16**.
Then `hitzone.gd:43` `call_deferred("_setup_groups")` fires and `:54` sets **mask = 8** for any zone
whose owner is in group `enemies`. The deferred write lands last and wins.

**The `16` at the enemy call site is dead input.** It reads as the configuration of record and
configures nothing — a fossil that no fossil probe can see, because the symbol *is* read; it is just
overwritten. This is the divergent-parallel-LIVE-systems class from 7/17 in miniature: two places own
one field, and which one wins is decided by frame timing rather than by design. Same shape applies to
the player branch (`:48-50`). **Fix: one owner.** Either the builder args are authoritative and
`_setup_groups` stops touching layer/mask, or `_setup_groups` is authoritative and the args go.
**FIXED 2026-07-27.** `_setup_groups` and its `call_deferred` are deleted; layer/mask is authored only
at the builder call site (`enemy_base` 64/**8**, `gore_dummy` 64/**8**, `ally_base` 32/16,
`player.gd:866` 32/16). Every value written is the one that was *already in effect*, so this is a
zero-behaviour-change refactor: both `enemy_base` and `gore_dummy` join group `enemies` on the first
line of `_ready()` (`enemy_base.gd:257`, `gore_dummy.gd:41`), before the deferred call could fire, so
they always resolved to 8. Verified green: `test_flat_damage`, `test_hitzones`, `test_hitzone_rebuild`,
`test_bullet_flight`, `test_downed_enemy`, `test_head_burst`, `test_actor_damage_contract` (76 checks).

**It also closes a hazard this project's own council flagged and never fixed.** The 2026-07-19 review
rated the deferred rewrite *"Fragile by design"* and named the trap precisely
(`war_room/2026-07-19_playtest_polish/analysis/systems_designer.md:246`, item S9):

> *"if anyone ever adds `civilians` to the `enemies` group, every civilian zone silently jumps to
> layer 64."*

With the deferred rewrite gone, group membership can no longer reach collision layers at all. The trap
is not documented-and-avoided; it is structurally unreachable.

### 2.5 THE HEADLINE FINDING — a law with an owner that the live path never consults

ADR-016 Amendment D: **HEAD = fatal (bypass)**. The codebase has a designated owner for that rule —
`Hitzone.is_fatal_zone()` (`scripts/combat/hitzone.gd:76-79`), whose entire job is to answer "does this
zone kill outright."

**No damage code calls it.** Its only callers are the hitzone editor tool
(`scripts/tools/hitzone_editor.gd:384,550`) and two tests (`test_flat_damage.gd:85`,
`test_hitzones.gd:205,219`). The live bullet path never asks.

Instead the rule is **reimplemented inline, in one actor out of three**:

| Actor | Zone param | HEAD bypass | Effect |
|---|---|---|---|
| `enemy_base.gd` | `zone` — used | **yes** — `amount = current_hp + 999` | headshot always kills |
| `ally_base.gd` | `_zone` — **ignored** | no | survives on raw damage |
| `player.gd:1411,1422` | `_zone` — **ignored**, dropped before `health_system.take_damage` | no | survives on raw damage |

The 4.0 HEAD multiplier still applies to all three upstream (`bullet_system.gd:122,146-147`), so this
is not "allies are headshot-proof" — it is a **range-dependent asymmetry**, and it is computable:

- Ally `max_hp = 80` (`ally_base.gd:7`). M16A1 base 27 (ADR-016), HEAD ×4.0, `min_damage_mult = 0.65`
  (`data/weapons/m16a1.tres:23`).
- Point blank: 27 × 4.0 = **108 > 80** → the ally dies.
- At max range: 27 × 4.0 × 0.65 = **70 < 80** → **the ally survives a headshot.** An enemy in the same
  round never does. With the M1911 (`min_damage_mult = 0.3`) a long headshot deals **32** to an 80 HP ally.

`bullet_system.gd:13` states the law as universal — *"a lucky head hit at distance still kills
(ADR-016; HEAD stays fatal)"*. That header is true only for enemies. Meanwhile `hitzone.gd:7` scopes it
in a comment — *"fatal **on enemies**"* — so the code disagrees with both the ADR and its own sibling
file about how wide the law is.

**Not changed — this is a lethality ruling, not a cleanup.** Making headshots fatal on the player and
his squad is a real difficulty and feel decision (Pillar 5, "death matters, but this is not a sadism
simulator") and it collides with the 2026-07-22 ruling that *"both factions use the SAME systems."*
Three coherent outcomes, and the Summoner picks:
1. **Universal bypass** — allies and player die to headshots too. Honours ADR-016 as written and the
   same-systems ruling. Hardest, most lethal, most consistent.
2. **Enemy-only, made explicit** — amend ADR-016 to say the bypass is an enemy rule, and correct
   `bullet_system.gd:13`. Zero gameplay change; ends the drift.
3. **Fatal-zone via the owner** — route all three actors through `Hitzone.is_fatal_zone()` so the rule
   has one implementation, then choose (1) or (2) as a flag on it.

Whichever wins, **the structural defect is the same and should be fixed regardless**: a rule that owns
a function, is not read from it, and is retyped by hand in one caller is the fossil disease with the
polarity reversed — not dead code that reads as live, but **live law that reads as dead**.

### 2.5b A self-defeating idiom, found while running the suite (2026-07-27)

Three files carry a lambda that cannot do the job it was written for:

```gdscript
_explosion_nodes = _explosion_nodes.filter(func(n: Node) -> bool: return is_instance_valid(n))
```

- `scripts/combat/gun_fx.gd:123` (`_explosion_nodes`)
- `scripts/levels/gore_lab.gd:577-578` (`_enemies`, `_allies`)

**The parameter type is checked before the body runs.** A freed object cannot be converted to `Node`,
so the array element the filter exists to *remove* is the one that throws — Godot reports
`Error calling method from 'filter': Cannot convert argument 1 from Object to Object`, which is the
exact error `test_ai_stress_arena` fails with. The guard is defeated by its own signature.

Fix is one word per site: type the parameter `Variant` (or leave it untyped) so `is_instance_valid`
can actually judge it. `camp_director.gd:138-139` uses the same idiom but over `Dictionary` elements,
which are never freed — it is fine and should not be "fixed".

**Pre-existing, not introduced by this session's changes** — none of these three files were touched
(verified by stash-and-rerun, §5).

### 2.6 Part B is not a de-duplication — measured

The 7/23 note describes Part B as pruning "~2,500 lines of dup". **Measured function-by-function
(2026-07-26), that framing is wrong and would mislead whoever picks it up:**

- `enemy_base` declares **85** funcs; `ally_base` **52**. They share **33 names**.
- Of those 33, exactly **7 are byte-identical** — `_exit_tree`, `_is_low_posture`, `_near_cover`,
  `apply_suppression`, `get_muzzle_position`, `get_muzzle_visual`, `on_zone_hit` — totalling **58 lines**.
- The other **26 shared names have genuinely diverged**: `take_damage` 139 vs 30 lines, `_evaluate_goals`
  137 vs 68, `_move_toward` 52 vs 9, `_think` 34 vs 7, `_execute_idle` 19 vs 52.
- **52 funcs are enemy-only; 19 are ally-only.**

**These are not two copies of one class. They are two different implementations sharing a vocabulary.**
A mechanical lift harvests 58 lines and leaves 26 functions each needing a behavioural ruling on
whether an ally should now act like an enemy — §2.5 is one such ruling, discovered exactly this way.

**So Part B is a design exercise wearing a refactor's clothes.** That is why it felt unsafe to do blind,
and the instinct to defer it was right. Sequence it as: rule on the divergences first (each is a small,
answerable question like §2.5), then the merge becomes mechanical.

---

## 3. THE THREE REFACTORS, RANKED

### 3.1 — ~~Finish ADR-028: kill the arena's parallel world~~ — **CUT by Summoner's ruling, 2026-07-26**

> *"i chose to keep the ai stress test as a more sterile enviorment to target things while debugging.
> work on the other problems tho."*

**ADR-028 Phase 3 (arena-as-slice) is CUT, not deferred. Do not re-propose it.** The arena stays a
hand-wired sterile bench on purpose — isolation is the feature, and the 1,858 lines plus
`TerrainManagerStub` (`ai_stress_arena.gd:11,277-280`) stay.

The dead-bead pointer this created has been repaired: `tests/test_placement_paths.gd:5-8,18` now cites
the ruling instead of `qjf0`, so the carve-out is permanent **by decision** rather than by an orphaned
tracker reference. **Standing consequence, and it is the price of the ruling:** the arena is not a
slice of the shipping path, so anything tuned there — AI accuracy dial, cover behaviour, break-contact
— must be re-confirmed in the real world build before it counts as shipped.

The original analysis is preserved below for the record only.

#### (superseded) original recommendation

The 7/17 decree ratified **"One world-build path. The arena is a slice of it, never a parallel copy."**
Phase 1 shipped. The structural probe exists and works — `tests/test_placement_paths.gd` — but read
its own header:

> `## The arena's hand-wired build is the ONE recorded exception until qjf0 lands.`
> `const KNOWN_EXCEPTIONS := ["res://scripts/levels/ai_stress_arena.gd"]` (`:19-21`)

**`qjf0` is a bead. Beads were retired 2026-07-22.** The exception's expiry pointer now points at
nothing, so a temporary carve-out has silently become permanent law — and the 1,858-line arena still
hand-wires its world (`TerrainManagerStub` at `:11`, `:277-280`; its own clutter root at `:409`).

This is the exact shape the 7/17 memo warned about: *"'it works in the arena' measured the wrong
thing."* The arena is the tuning ground for the shipping firefight (`recongame-project`, 7/15
direction), so every hour tuned in a parallel world is an hour that may not transfer.

**Work:** wrap the arena so it calls the real builder with a fixed seed and a small AO; delete
`TerrainManagerStub` and the hand-wired clutter in the same change (fossil law); remove the entry from
`KNOWN_EXCEPTIONS` so the probe locks it shut. **Sacrifice:** arena boot gets slower (it now builds a
real AO), and arena-tuned numbers shift once under the real generator — a one-time retune.

### 3.2 — Part B: the `AICombatant` merge *(highest line-count win, highest risk)*

Already blessed as the intended end-state on 7/23 and deferred for a real reason: *"big reparent; needs
cheap iterative verification (each headless cycle is minutes) — not safe blind overnight."*

That reason still stands, and the 7/25 audit made the case stronger, not weaker: the ally half was
found missing 5 of 9 AIStates and missing a default match arm, so allies closed at the crouch cap
forever. **That bug class is a direct product of the divergence** — the fix went into one
implementation and not the other for two days. It has since been patched (`combat_posture.gd` is now
shared), but the divergence that produced it is untouched.

**Sacrifice:** this is the change most likely to break a working game, and it cannot be verified
overnight. It wants a windowed session with him on the controls.

**NOT ATTEMPTED on the 7/26 overnight run, deliberately.** The Summoner's 7/23 deferral — *"not safe
blind overnight"* — described exactly the conditions of that run, and he lifted the hold on the arena
only. What was done instead is the measurement that makes this cheap and safe when he IS at the
controls: **§2.6**, which shows the job is 26 behavioural rulings, not a reparent. Rule on those first
and the merge becomes mechanical. §2.5 is the first such ruling, and it was found by doing exactly this.

### 3.3 — Type the coupling: retire group-strings and `has_method` where a contract exists *(cheapest, incremental)*

Not a big-bang refactor — a standing rule plus a probe, applied file by file:
- A **group registry** (`const` names in one file) so a typo can't create a silent third group, and so
  a write-with-no-read is machine-detectable. The 7/25 audit found 8 such groups and 2 live bugs by
  hand; a probe finds them for free, forever.
- Replace `has_method("x")` with a typed interface or a `class_name` check wherever the receiver is a
  project class (most of `player.gd`'s 42 are). Keep it where the receiver genuinely varies.

**Sacrifice:** touches many files for no visible gameplay change, and it competes with feature work
for the same hours.

**SUPERSEDED IN PART by measurement.** Both probes now exist and both came back clean, so the
file-by-file rewrite this section proposed is **not worth doing**: converting 129 already-resolving
`has_method` calls to typed checks would touch dozens of files to prevent a defect class the probes now
catch for free. **Keep the probes, skip the rewrite.** The group-name `const` registry is still worth
having someday, but it is now a legibility nicety, not a defect fix.

**STATUS 2026-07-26 — the dispatch half is BUILT too.** `tests/test_dispatch_contract.gd` +
`.tscn` resolve every `has_method` / `call` / `call_deferred` / `callv` string target against all
2,018 project `func` definitions and all 12,178 engine methods. **Result: 129 string-named targets,
every one resolves — zero unresolved.** The `has_method` surface is healthy; the alarm in §2.3 was
raised on volume, and volume turned out not to be defect.

The probe carries a self-test and was proved by negative control: injecting
`has_method("zzz_no_such_method_anywhere")` into `mission_scope.gd` made it fail as intended, and the
file was restored byte-identical (`git diff --numstat` empty). **A probe that has never been seen to
fail is not evidence.**

**STATUS 2026-07-26 — the group half is BUILT.** `tests/test_group_contract.gd` +
`tests/test_group_contract.tscn` ship, auto-discovered by `run_all_tests.ps1`. It diffs group writers
against readers, understands both the `add_to_group("…")` literal and the builder-array form, and
scopes both sides to production so probe scaffolding cannot mask a real defect. Registers
(`ALLOWED_WRITE_ONLY`, `ALLOWED_READ_ONLY`) ratchet down like the fossil baseline.

**It exits 0.** It briefly failed on the inert `ally_hurtbox` group; that was fixed at the source
(§2.4a) rather than allow-listed, so **no entry was added to either register** — the forbidden move was
available and declined.

The probe failed its own first run by counting its `GROUP_BUILDER_CALLS` declaration as six writers —
the fossil law's second rule ("the death register is not a caller") reproduced exactly, in a new probe
written by someone who had just read that law. Guard is at `:56-58`.

---

## 4. HONEST BOTTOM LINE

**There is no load-bearing-code problem in RECONgame.** That is the answer to the question asked, and
the measurements are in §2. The dead-code and divergent-system axes were already audited and cleaned;
the coupling axis, audited here for the first time, came back healthy on every metric that was actually
measured rather than estimated:

| Claim in the first pass | After measurement |
|---|---|
| 219 group-strings ≈ high defect rate | **44 written / 35 read, one defect, now fixed** |
| `has_method` is the big uncovered risk | **129 targets, all resolve, zero unresolved** |
| 6 autoloads are near-empty and trimmable | **Metric was wrong. Trim nothing** — `TerrainEngine` is load-bearing, `WorldSim` is thin by ruling |
| `enemy_base`+`ally_base` = 3,383 dup lines | **7 identical funcs / 58 lines.** Two implementations, not two copies |

**Three of my own four opening claims did not survive contact with measurement.** Every one failed the
same way: a grep-shaped metric cannot see stringly-typed links, indirectly-held references, or genuine
divergence behind shared names. In this codebase, **estimate nothing — run the probe.**

### What is actually true

1. **Two real defects existed and are fixed** — the double-owned collision mask (§2.4b), where a
   deferred write made a call-site argument dead input, and the inert `ally_hurtbox`/`enemy_hurtbox`
   groups (§2.4a). Both are the *same* disease as the fossil law, in shapes the fossil probe cannot
   see: not dead code that reads as live, but **live code whose stated configuration is a lie**.
2. **One finding needs the Summoner and nobody else** — §2.5, the HEAD-fatal bypass implemented in one
   of three actors while its designated owner `Hitzone.is_fatal_zone()` is called by no damage code at
   all. This is a lethality ruling; it was deliberately not made on his behalf.
3. **Part B is a design exercise, not a refactor** (§2.6) — 26 behavioural rulings, 58 mechanical lines.
   Sequencing it as "rule, then merge" turns the scariest item on the list into a safe one.
4. **The bead retirement silently un-scheduled decreed work.** `test_placement_paths.gd` gated a
   carve-out on `qjf0`, a bead that no longer exists, so a temporary exception had become permanent by
   accident. Repaired, and the tree swept — ~30 bead references remain in `.gd`, but only that one was a
   live gate; the rest are provenance narration (comment-discipline debt, not holes).

### Coverage this leaves behind

Three ratcheting probes now guard the coupling axis where none existed: `test_group_contract`
(groups), `test_dispatch_contract` (string-named methods), and the `_zone_layers_have_one_owner`
section of `test_actor_damage_contract` (layer/mask single ownership). Each carries a self-test or a
demonstrated failure, because **a probe that has never been seen to fail is not evidence.**
