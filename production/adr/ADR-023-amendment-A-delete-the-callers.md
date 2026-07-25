# ADR-023 — AMENDMENT A
## "Delete the old system" is not finished until the callers are gone

**Status:** RATIFIED 2026-07-20 by the Summoner. Binding.
**Amends:** ADR-023 (THE FOSSIL LAW)
**Evidence:** measured incident, this repo, this night. See §2.

> Binding law. Deleting a system is not finished until every caller is gone with it.

---

## 1. The proposed clause

ADR-023 today says, in substance: **delete the old system when you replace it; don't bury it.**

**Add:**

> **A dead symbol and a live call to a dead symbol are the same fossil, and the second one is worse.**
> Deleting a system is not complete until **every call site is deleted or retargeted** — *including call
> sites in `tests/`, `tools/`, benches, and dev scenes.*
>
> A caller left pointing at a corpse is not "a stale test". In GDScript it is a **runtime SCRIPT ERROR
> in whatever function reaches it first**. If that function is a coroutine (`await`), the error
> **aborts the coroutine silently** — nothing after it runs, including `get_tree().quit()`. The process
> then **never exits**. A test that never exits does not fail; **it reports nothing at all.**

**Corollary (the reason this is a law and not a style note):** the fossil law's existing direction —
*declared but never called* — is the **cheap** half. This half — *called but no longer declared* — is
the **expensive** one, because the first is a dead weight and the second is an **active silencer**.

---

## 2. The worked example — measured 2026-07-16/17, not hypothetical

| commit | what it did |
|---|---|
| `ba3f941b` COMBAT FEEL PASS 2 | Created `EnemyBase._exposure_spread_mult()` **and** created `tests/test_ai_fairness.gd` to guard it. Its own commit message: *"Probes: test_ai_fairness NEW (exposure/attention/cover-first/broker all assert green); **suite 32 PASS / 0 FAIL**"*. |
| `f7464629` **Track C** — "unify AI accuracy into one symmetric model" | Replaced the accuracy model and **deleted `_exposure_spread_mult()`**. Correct under ADR-023 as written: it did not bury the old system. **It left the caller.** |

**What that one deleted function did, measured:**

```
SCRIPT ERROR: Invalid call. Nonexistent function '_exposure_spread_mult'
              in base 'CharacterBody3D (EnemyBase)'.
   at: _ready (res://tests/test_ai_fairness.gd:34)
```

1. `_ready()` is `async` (it `await`s). The SCRIPT ERROR **aborted the coroutine at line 34**.
2. `get_tree().quit()` lives at line 126. **It was never reached.**
3. The process ran forever. `run_all_tests.ps1` had **no timeout** and waited on it **synchronously**.
4. → **The entire 64-test suite hung on that one call and could never produce a verdict.**
5. → So nobody ran the suite. `8vtl`'s "10 reds" is dated **2026-07-13** and was never rechecked;
   `ida9` sat unrun for **95 commits**.
6. → And nobody saw that **ADR-005's Fairness Law — Pillar 1 — had no working guard at all.**

**One deleted function silently disabled this project's entire test suite and left a pillar unguarded.**
It cost nothing to introduce and it was invisible for weeks, because the failure mode of a dead caller
is *silence*, not *red*.

**Also found the same night, same shape** (so this is a class, not an anecdote):
`test_vehicle_kill` — `SCRIPT ERROR: Invalid access to property or key 'village_target' on a base
object of type 'Dictionary'` → same abort → same infinite hang. **2 of 64 tests, both silent.**

---

## 3. Can a machine enforce this? — **honest answer: PARTLY, and the gap is named**

*(t6z9's thesis: "a rule nobody enforces is not a rule". So this section is the point of the
amendment, not an appendix. Every claim below was tested tonight.)*

### 3.1 What does NOT catch it — measured, so the draft cannot pretend otherwise

- **Static typing does not catch it.** `EnemyBase.spawn_enemy()` is declared `-> EnemyBase`, so
  `var nva := EnemyBase.spawn_enemy(...)` **is** statically typed. Godot 4.7 **still did not reject
  `nva._exposure_spread_mult()` at parse time** — the probe spawned both enemies and printed its
  `[MODEL]` logs *before* erroring at line 34. **The failure is a runtime error, not a parse error.**
  A direct check (`var e: EnemyBase = null; e._nonexistent()`) also compiled and failed only at runtime.
- **`tests/test_fossils.gd` cannot catch it.** It scans *declarations* and asks "who calls this?" A
  symbol that no longer exists **has no declaration to scan**. The probe is structurally blind to this
  direction. *(`SCAN_DIRS` already covers `terrain/`; widening it further would not help — different axis.)*
- **The headless boot check cannot catch it.** `--headless --quit-after 300` never loads `tests/`.
  The fairness probe is only reachable by running it.
- **`--check-only` cannot be trusted here** (known: false-positives on autoloads; see bd memory).

### 3.2 What DOES catch it — already shipped tonight, and it is a backstop, not a preventer

**The suite timeout** (`run_all_tests.ps1`, `-TimeoutSec`, default 420s). It does not prevent the dead
call; it **converts an invisible infinite hang into a loud, named line on the board**. That is the
difference between "the suite mysteriously never finishes" and "`test_ai_fairness` exceeded the box —
go look". **That conversion is the whole reason the incident was findable at all.**

> ⚠ **The timeout is a BOX, not a hang detector — do not let it become the next lying instrument.**
> Measured the same night: `test_hub_loop` legitimately runs **167s** and my first 120s box reported it
> as `HUNG`. **Slow is not hung.** The box is 420s and its message now says *"exceeded the box: hung, or
> slower than the box. Check before calling it hung."*

### 3.3 The honest gap, stated plainly

**There is no static enforcement of this clause today, and this draft does not invent one.**
The realistic options, none free:

1. **Deletion-time grep (discipline, not a machine).** Whoever deletes symbol `X` greps `X` across
   `scripts/ tests/ tools/ terrain/ scenes/` and proves zero hits. Cheap, effective, and **exactly the
   kind of rule that "reads perfectly and matches nothing"** — the disease `t6z9` names. **Weak.**
2. **A call-site probe (a real machine, real cost).** Extend `test_fossils.gd` with a second pass:
   collect `<ident>.<method>(` call sites whose base type is resolvable, and fail when the method is
   absent from that type. This is a small type-inference engine in GDScript. It would have caught this
   incident. It is a **genuine build**, it will have false positives on `Variant`/duck-typed bases, and
   it should be **its own bead with its own probe** — not smuggled in under an amendment.
3. **Godot's analyzer.** The natural home, and it did not fire. Worth a minimal repro before
   concluding anything about upstream.

**Recommendation:** ratify the clause **and** file (2) as a bead. Ratifying the clause with only (1)
behind it is honest but weak; it is still strictly better than today, where **the law is silent on the
direction that actually hurt us.**

---

## 4. What ratifying this would change, concretely

- `f7464629` (Track C) would have been **incomplete** under the amended law — correct deletion, missing
  caller cleanup.
- The fossil law would cover **both directions**: dead declarations *and* dead calls.
- The deletion checklist gains one line: **"grep the symbol; prove zero call sites, `tests/` included."**
- **Nothing else changes.** No existing fossil is reclassified. The baseline register — `ceiling 19 /
  count 19` of record (`tests/fossil_baseline.json:3-4`, as of 2026-07-24) — is untouched.

## 5. What this draft does NOT ask for

- It does **not** ask to change `tests/fossil_baseline.json`. The register does not stand where this
  draft was written: it now reads `ceiling 19 / count 19` (`tests/fossil_baseline.json:3-4`, as of
  2026-07-24), and it passed through **146** en route — the probe's own source records that growth as the
  defect it was built to make visible (*"Nothing checked them, which is how 77 became 146."* —
  `tests/test_fossils.gd:332`). `grandfather_log` is still `[]` (`tests/fossil_baseline.json:26`) despite
  that growth, so the register
  carries no provenance for it. **That is a live discrepancy against ADR-023's one forbidden move, and
  it is out of this draft's scope — it needs its own ruling.**
- It does **not** resolve `j3ke`'s 19 built-ahead-of-wiring symbols. Those are a **roadmap** decision.
- It does **not** touch `zpw2`'s `terrain/` blind spot — **that hole is closed**: `terrain/` is now
  scanned (`tests/test_fossils.gd:8`, `SCAN_DIRS = ["res://scripts", "res://terrain"]`), and the
  register carries `terrain/` entries (`tests/fossil_baseline.json:29-32`).
- It does **not** claim the incident is fixed by the timeout. `test_vehicle_kill` still hangs.

---

**DRAFT. Awaiting the Summoner. The Director proposes law; he ratifies it.**
