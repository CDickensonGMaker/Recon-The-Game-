# TECHNICAL DIRECTOR / LEAD PROGRAMMER — Implementation Plan

Buildable-today, reuse-only. Every hook lands on an **existing call site** that already
holds the attribution ("soldier X did action Y"). No new systems, no duplicate progression.

**Load-bearing fact that makes this cheap:** `AllyBase.member` is assigned by reference —
`squad_system.gd:32-33` does `var m: Dictionary = roster[i]; ally.member = m`. GDScript
dicts are references, so `ally.member` **IS** `CampaignState.roster[i]`. Mutating a member
dict in-mission mutates the persistent roster (already proven at `squad_system.gd:257`,
which sets `ally.member["alive"]=false` then saves). So learn-by-doing = mutate `member`
in place; persistence is free.

---

## PART 1 — LIVING SQUAD XP

### 1.1 New member fields + starting-skill roll
**File:** `scripts/squad/squad_roster.gd` — `generate_member()` (lines 22-31, the return dict).

Add two fields and a role-skill roll. Reuse `SkillCatalog.MOS_SKILL`:

```gdscript
# after building attributes, before/inside the return dict:
"xp": 0,                 # per-soldier lifetime XP (separate from CampaignState.team_xp)
"skill_uses": {},        # skill_id -> accumulated use progress
# ...existing keys...
```

Then after the dict literal (new lines ~32+), roll the starting skill:

```gdscript
var role_skill: String = str(SkillCatalog.MOS_SKILL.get(mos, ""))
if role_skill != "" and SkillCatalog.SKILLS.has(role_skill):
    var start: int = rng.randi_range(0, 2)   # rookie..competent, weighted low
    if start > 0:
        (member["skills"] as Dictionary)[role_skill] = start
# everyone gets a small chance at baseline small_arms so no recruit is fully blank
if rng.randf() < 0.5 and role_skill != "small_arms":
    (member["skills"] as Dictionary)["small_arms"] = 1
```

(Refactor `generate_member` to build `var member := {...}` then mutate + `return member`,
since we now touch `member["skills"]` after construction.)

**Strict-typing gotchas:** `MOS_SKILL.get(mos,"")` returns Variant → wrap `str(...)`.
`member["skills"]` access returns Variant → cast `as Dictionary` before index-assign.
`rng.randi_range`/`randf` are typed fine.

### 1.2 The choke-point API (avoid scattering)
**File:** `scripts/squad/squad_roster.gd` — add static funcs next to `skill_level()` (line 61).

```gdscript
## Learn-by-doing: credit `n` uses of `skill` to `member`, level up on threshold.
## Returns the NEW level if it leveled this call, else -1 (callers with a toast use it).
static func credit_use(member: Dictionary, skill: String, n: int = 1) -> int:
    if member.is_empty() or skill == "" or not SkillCatalog.SKILLS.has(skill):
        return -1
    var uses: Dictionary = member.get("skill_uses", {})
    var total: int = int(uses.get(skill, 0)) + n
    uses[skill] = total
    member["skill_uses"] = uses
    member["xp"] = int(member.get("xp", 0)) + n
    var lvl: int = int((member.get("skills", {}) as Dictionary).get(skill, 0))
    var cap: int = int((SkillCatalog.SKILLS[skill] as Dictionary).max)
    if lvl >= cap:
        CampaignState.save_campaign()   # deferred mid-mission (see 1.4) - no disk hit
        return -1
    if total >= SkillCatalog.uses_for_level(lvl + 1):
        var skills: Dictionary = member.get("skills", {})
        skills[skill] = lvl + 1
        member["skills"] = skills
        CampaignState.save_campaign()
        return lvl + 1
    CampaignState.save_campaign()
    return -1
```

**File:** `scripts/squad/skill_catalog.gd` — co-locate the growth curve with the cost table
(add after `MOS_SKILL`, ~line 32):

```gdscript
## Cumulative uses needed to REACH `level`. Quadratic: 6, 24, 54, 96, ... (level^2*6).
static func uses_for_level(level: int) -> int:
    return level * level * 6
```

This **reuses** `SKILLS[skill].max` for the cap and lives beside `buy_skill`, so the two
growth paths (spend vs. do) share one source of truth.

### 1.3 The four learn-by-doing HOOKS (exact sites)

**HOOK A — ally kill → `small_arms`.** *Attribution is present but the DEATH signal throws
it away — thread it at the killing blow instead of re-plumbing the signal.*
`scripts/enemies/enemy_base.gd:1510-1512` (the `if current_hp <= 0:` block in `take_damage`;
`attacker` is the killer, and `AllyBase._fire_at_target` passes `self` — `ally_base.gd:532`).

```gdscript
if current_hp <= 0:
    current_hp = 0
    if attacker is AllyBase:
        var am: Dictionary = (attacker as AllyBase).member
        SquadRoster.credit_use(am, "small_arms", 3)
        am["kills"] = int(am.get("kills", 0)) + 1   # member["kills"] was never incremented
    _die()
```

> **Why not the `died` signal?** `_die()` (`:1543`) emits `died.emit(self)` with no killer;
> `mission_director._on_enemy_died` (`:47`) never learns who fired. Adding a killer arg means
> touching `spawn_tracked_enemy`'s `.bind()` and every connect. Crediting inside `take_damage`,
> where `attacker` is still in scope, is the minimal, correct thread. **This is the one place
> attribution had to be recovered.**

**HOOK B — medic revive → `medic`.** Attribution present (`medic` local is the AllyBase).
`scripts/squad/squad_system.gd:157-161`, inside `if _revive_timer >= channel:` after `_health.revive(heal)`:

```gdscript
var got: int = SquadRoster.credit_use(medic.member, "medic", 5)
if got > 0:
    director.toast.emit("%s: STEADIER HANDS NOW (MEDIC %d)" % [str(medic.member.nick), got])
```

**HOOK C — point warning → `detect_ambush`.** Attribution present (`point` local).
`scripts/squad/squad_system.gd:193-194`, right after `_point_warned[...] = true`:

```gdscript
SquadRoster.credit_use(point.member, "detect_ambush", 1)
```

**HOOK D — RTO call-for-fire → `fo_fac`.** Attribution present; `_rto` already fetched.
`scripts/missions/mission_director.gd:218-219` (inside `request_fire_support`, AFTER all the
early-return guards at 201/204/207/211 so only SUCCESSFUL calls credit):

```gdscript
var _rto := squad_system.member_by_mos("RTO") if squad_system != null else null
if _rto != null:
    SquadRoster.credit_use(_rto.member, "fo_fac", 4)
var _fo: int = SquadRoster.skill_level(_rto.member, "fo_fac") if _rto != null else 0
```

(Credit BEFORE reading `_fo` so the cooldown reflects the freshly-earned level — minor, nice.)

**Optional HOOK E — grenadier → `demolitions`** at `squad_system.gd:218` (`_grenadier_tick`,
when `_thumper_cooldown = 14.0` fires). One line, same pattern. Flag as nice-to-have.

**Strict-typing:** `attacker is AllyBase` then `(attacker as AllyBase).member`. All `.member`
locals are already typed `AllyBase`. `credit_use` returns `int` (level or -1).

### 1.4 Save / migration / perf
- **No SAVE_VERSION bump needed.** New keys (`xp`, `skill_uses`) are additive and every read
  is `.get(key, default)`. Existing `user://campaign.cfg` roster dicts (which have `skills:{}`
  but no `xp`) load unchanged: `xp`→0, `skill_uses`→{}. Starting-skill rolls only affect
  **newly generated** recruits (`generate_member`), so veterans keep bought skills.
  Recommend a one-line note in `campaign_state.gd:_migrate` comment (`:195`) documenting the
  additive shape so the NEXT change knows the field set.
- **Perf: zero mid-mission disk cost.** `credit_use` calls `CampaignState.save_campaign()`,
  but `_defer_saves` is `true` during a mission (`campaign_state.gd:144-147`) so it only sets
  `_dirty`; the real write happens once at debrief via `on_mission_end` (`:126`). Safe to call
  per event. **Credit on KILL, not per-shot** — do NOT hook `_fire_at_target`, that would fire
  ~10x/sec per ally.
- **Barracks shared-XP: KEEP as accelerator (hybrid).** `buy_skill` (`skill_catalog.gd:35`)
  writes the same `member["skills"][id]` that `credit_use` does — they compose with zero
  conflict. No code change to keep it; both paths converge on one field. (Systems-designer owns
  the final call; from the implementation lens coexistence is free.)
- **Level-up feedback:** `credit_use` returns the new level; callers holding a `director`
  (Hooks B/C/D) can toast. Hook A (in `take_damage`) has no director — leave it silent or
  route through an existing bus later; don't add a new autoload just for a toast.

---

## PART 2 — RADIO FIRE SUPPORT (expose CBU, wire fo_fac)

The CBU is fully built (`cas_airplane.gd:10` enum, `:163` `_drop_cluster`, `_launch_flyby`
already exists at `mission_director.gd:251`). It just isn't reachable. Four small edits.

### 2.1 Dispatch — `scripts/missions/mission_director.gd`
- **Default budget dict (`:195`)** — add the key so the generator merge and the
  "NO AIR SUPPORT" zeroing loop (`mission_generator.gd:272`) both see it:
  ```gdscript
  var fire_support: Dictionary = {"bombs": 0, "napalm": 0, "cbu": 0, "arty": 0, "mortar": 2, "spooky": 0}
  ```
- **`request_fire_support` match (`:221-237`)** — add a branch after `"napalm"` (reuses
  `_launch_flyby` + the existing `Ordnance.CBU`):
  ```gdscript
  "cbu":
      _launch_flyby(target, CASAirplane.Ordnance.CBU)
      toast.emit("FAST MOVER - CBU CLUSTER INBOUND - DANGER CLOSE (%d left)" % fire_support[kind])
  ```
- **Input (`_process`, `:167-181`)** — add a 6th slot inside the `if fire_menu_open` block:
  ```gdscript
  elif Input.is_action_just_pressed("slot_6"):
      request_fire_support("cbu")
  ```

### 2.2 HUD row — `scripts/ui/mission_hud.gd:107-113`
Add to the `rows` array (CAS family, so group it with the fast-movers):
```gdscript
["6", "CAS - CBU CLUSTER", "cbu"],
```
The existing loop (`:114-117`) renders count/color automatically — no other HUD change.

### 2.3 InputMap — the ONE project.godot edit required
`slot_1..slot_5` exist; `slot_6` likely does not. Add action `slot_6` bound to key **6** in
`project.godot`'s `[input]` section (mirror the `slot_5` entry). **This is the only edit
outside GDScript.** If a `slot_6` already exists (verify in-editor), skip.

### 2.4 Budget in the generator — `scripts/missions/mission_generator.gd`
Give CBU a supply on the big-raid profile so it's reachable:
- `:248` (the max-support profile): add `"cbu": 1` →
  `{"bombs": 2, "napalm": 1, "cbu": 1, "arty": 2, "mortar": 3, "spooky": 1}`
- Optionally `:236` gets `"cbu": 1` too. Leave `:132` (light patrol) without it — escalation,
  not entitlement (Pillar 3). The merge loop (`:262-263`) sets only listed keys; unlisted
  missions leave `cbu` at its default 0 = unavailable, correctly greyed in the HUD.

### 2.5 Plumbing already correct (verified, no work)
- **fo_fac growth on every call:** Hook D (1.3) lives in `request_fire_support`, which ALL
  kinds route through — CBU credits `fo_fac` for free.
- **Cooldown:** `_cas_cooldown = maxf(10.0, 25.0 - 2.0*fo)` (`:220`) is set for every kind;
  CBU inherits the fo_fac-reduced turnaround with no extra code.
- **Guards:** RTO-dead (`:201`), no-budget (`:204`), net-busy (`:207`), no-target (`:211`)
  all pre-branch — CBU is covered by every gate automatically.
- **"NO AIR SUPPORT" complication** (`mission_generator.gd:271-274`) zeros everything but
  mortar; since `cbu` is now in the default dict, it's zeroed correctly.

---

## RISK / SEQUENCING
1. **`SkillCatalog` ↔ `SquadRoster` dependency:** both are `RefCounted` with `class_name`;
   `SquadRoster.credit_use` calls `SkillCatalog.uses_for_level`/`SKILLS`. No cycle at runtime
   (static calls), but ensure both `class_name` are registered (they are).
2. **`take_damage` edit is hot-path-adjacent** but only runs on the killing frame — negligible.
   Guard the cast (`attacker is AllyBase`) so a null/enemy attacker (arty, `null`) is skipped.
3. **Balance (Devil's Advocate handoff):** CBU at budget 1 on raids only; per-soldier growth is
   slow (quadratic curve, `36` uses ≈ level 3 in `small_arms` ≈ dozens of kills) so it enhances
   attachment without trivializing gunplay (Pillar 1).
4. **Test suite:** `test_squad` / `test_xp_spend` exist. Add assertions that (a) a fresh
   `generate_member` may carry a role skill, (b) `credit_use` levels at the threshold and caps
   at `SKILLS[skill].max`, (c) roster round-trips `xp`/`skill_uses` through save/load.

## FILES TOUCHED (summary)
| File | Edit |
|------|------|
| `scripts/squad/squad_roster.gd` | new `xp`/`skill_uses` fields + starting-skill roll in `generate_member`; new `credit_use()` |
| `scripts/squad/skill_catalog.gd` | new `uses_for_level()` growth curve |
| `scripts/enemies/enemy_base.gd:1510` | Hook A: credit killer's `small_arms` + `kills` in `take_damage` |
| `scripts/squad/squad_system.gd:159,193` | Hooks B & C: medic revive, point warning |
| `scripts/missions/mission_director.gd:195,221,167,218` | CBU budget key + match branch + slot_6 input + Hook D fo_fac |
| `scripts/ui/mission_hud.gd:109` | CBU menu row |
| `scripts/missions/mission_generator.gd:248` | CBU budget on raid profile |
| `project.godot` `[input]` | `slot_6` → key 6 (only non-GDScript edit) |
