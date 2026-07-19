# SYSTEMS DESIGNER — Playtest Polish Pass (F1 / F2 / F6 + the surprise list)

Lens: system coherence, collision-layer contracts, damage-grammar integrity (ADR-003: ONE damage
grammar), and what breaks downstream. Everything below was read in the code, not the plan.

---

## 0. THE BLOCKER THE BRIEFING MISSED — civilian `take_damage` has the WRONG ARITY

This outranks all three of my forks. **No layer choice fixes it, and every layer choice trips it.**

- `scripts/world/civilian.gd:234` — `func take_damage(amount: int, _t: Enums.DamageType = ..., _a: Node = null) -> int` — **THREE parameters.**
- `scripts/combat/bullet_system.gd:147` — `target.take_damage(dmg, wd.damage_type, shooter, zone)` — **FOUR arguments.**
- `scripts/player/weapon_holder.gd:634` and `:638` (shotgun bucket resolve) — also **four**.

The guard at `bullet_system.gd:133` is `target.has_method("take_damage")`. `has_method()` checks the
NAME, not the signature. The moment a civilian hitzone enters the bullet mask, the first round to
land calls a 3-param function with 4 args and throws a runtime error inside `_impact()` — mid-loop,
inside `_physics_process`, on the shared arrival resolver **every shooter in the game uses**.

That is not "civilians don't die". That is the one damage path in the game erroring on a villager.

**Every damageable entity in the codebase already carries the 4-param zone signature:**

| File:line | Signature |
|---|---|
| `scripts/enemies/enemy_base.gd:2097` | `(amount, _damage_type, attacker, zone)` |
| `scripts/allies/ally_base.gd:974` | `(amount, _damage_type, _attacker, _zone)` |
| `scripts/player/player.gd:817` | `(amount, damage_type, attacker, _zone)` |
| `scripts/levels/gore_dummy.gd:141` | `(amount, _damage_type, attacker, zone)` |
| **`scripts/world/civilian.gd:234`** | **3 params — the ONLY entity out of contract** |

**RULING (prerequisite to F1, not optional):** widen `civilian.gd:234` to
`take_damage(amount: int, _t := Enums.DamageType.PHYSICAL, _a: Node = null, zone: String = "BODY") -> int`
BEFORE any layer edit. ADR-003's surviving clause is "one damage grammar" — a fourth entity that
speaks three-quarters of it is a grammar fracture, and it has been invisible only because the
civilian was unreachable. This is the actual root cause chain: layer 2 hid an arity bug.

Take the `zone` parameter even though nothing consumes it yet — it is the argument the caller
already passes. Discarding it in the signature is free; being unable to accept it is a crash.

---

## F1 — HOW CIVILIANS BECOME SHOOTABLE

### First: the briefing's framing of (a)-vs-(b) is wrong in one load-bearing way

The briefing argues (b) is honest "but AI stray rounds then kill villagers, which touches
who-gets-shot", implying (a) avoids that. **It does not.** All three shooters fire with mask
`1 | 32 | 64` (`weapon_holder.gd:479`, `enemy_base.gd:2022`, `ally_base.gd:944`). Put a civilian
hitzone on **64** and every VC and every ally round already collides with it — layer 64 IS in their
mask. Option (a) delivers AI-kills-villagers *by default and silently*; option (b) delivers it
*only if you choose to add the bit to their masks*. **(b) is the option with the safety valve.**

### The three options, judged on their real blast radius

**(c) Layer 32 — REJECTED, and it is the worst of the three.** Layer 32 is not just "the player
hurtbox"; it is a *cover-query* layer:

```
enemy_base.gd:1789-1793   PhysicsRayQueryParameters3D.create(candidate+UP*1.3, threat+UP*1.0, 1 | 32)
                          if space_state.intersect_ray(query): candidates.append(candidate)
ally_base.gd:815-819      identical
```

A HIT means "LOS blocked → this is cover." Put civilians on 32 and **the AI starts taking cover
behind villagers.** Both sides. Every cover evaluation in the game. That is a Pillar-2 atmosphere
disaster played straight, and it also silently loads the blessed AI wave (mwfi→qpfr) with a bug it
did not create. Also: `weapon_holder.gd:550,596` (buckshot) masks `1 | 64` only — on 32, **a
villager would be immune to the shotgun and vulnerable to the rifle.** Two damage grammars by
weapon class. ADR-003 forbids exactly this.

**(a) Layer 64 (enemy_hurtbox) — REJECTED on semantics, but note it is CHEAP and it works.** It
costs zero mask edits, it makes buckshot work, and `Hitzone._setup_groups()` (`hitzone.gd:46-55`)
leaves a civilian-owned zone's layer alone because it only branches on `player`/`enemies`. What it
buys in convenience it pays for in truth: layer 64 is named `enemy_hurtbox` in `CLAUDE.md`'s layer
table and is read as "the enemy" by four systems (see the surprise list — `projectile_base.gd:97-98`
is the sharp one: **every rocket, LAW, RPG and M79 round would arm and detonate on a villager
because `hits_enemies` sets `4 | 64`**). A layer whose name lies is precisely the fossil failure
mode ADR-023 exists to prevent: *"it reads as load-bearing and it survives every grep."*

**(b) A NEW civilian layer — RULED. Layer 8 is taken (`player_hitbox`, read at `hitzone.gd:55`).
Use layer 10 = bit 512.** Layer 9 (256) is projectiles (`grenade.gd:37`, `projectile_base.gd:49`).
512 is unused across the whole `scripts/` tree.

The wiring, and NOTHING more this session:

1. `civilian.gd` build call: `HitzoneBuilder.build(self, actor, 512, 0, ["civilian_hurtbox", "hitzone"], true)`
   — mask 0, because nothing melees civilians. Groups: **`civilian_hurtbox`, never `enemy_hurtbox`.**
2. Add `| 512` to the **player's** two fire masks ONLY: `weapon_holder.gd:479` (rifle) and
   `:550`/`:596` (buckshot, both rays — miss one and the shotgun becomes the one gun that cannot
   kill a villager).
3. **Do NOT add 512 to `enemy_base.gd:2022` or `ally_base.gd:944` this session.** The player can
   kill civilians; AI stray rounds pass through them.

### The Pillar consequence, named (Law 2 — no free lunches)

Holding 512 out of the AI masks buys a clean, ownable act: **when a villager dies, the player killed
her.** No ambiguity, no "the ally did it", and — critically — no interaction with the blessed AI
wave that is mid-flight. It costs realism: a firefight in a village leaves villagers untouched by
everything except the player's muzzle, which is a lie the player *can* notice (Pillar 2). I accept
that cost for exactly one session, on the grounds that the alternative is shipping AI-caused
civilian casualties with **no consequence system to receive them** and no probe on the AI's
target-selection while another council owns that code. Adding `| 512` to the two AI masks later is a
two-line change gated behind the ROE hook actually being wired — that is the correct sequencing.

Aim-ray note: `weapon_holder.gd:413-420` (the convergence ray, `1 | 32 | 64`) does NOT need 512.
Leaving it out means a shot at a villager converges on the terrain behind her — a sub-centimetre
error at village range. Adding it is harmless. Prefer adding it for coherence; it is not a defect
either way.

### Sync obligation the layer choice creates

`hitzone_builder.gd:10-12` is explicit: callers **MUST** call `sync()` every physics tick, and
**BEFORE any DEAD early-return.** `civilian.gd:124-132` early-returns twice — `state == GONE`
(line 125) and `lod_tier == LOD_FAR` (line 131) — and `_update_lod()` calls
`set_physics_process(false)` at FAR (`:361`). Consequences, in order of severity:

- **GONE corpses:** zones freeze at the death pose. Acceptable (the body tips over via
  `rotation_degrees.x = 90` and frees after 30s), but the zones will not follow the tip. Cosmetic.
- **LOD_FAR (>300m):** physics off, zones frozen at last position while the *model* may still be
  moved by the SimClock hour listener. A frozen hitzone 300m from its body is a floating invisible
  target. Fix: hoist `HitzoneBuilder.sync(actor, _hz_sync)` to the TOP of `_physics_process`, above
  both returns, exactly as the builder's header orders — and accept that FAR-tier civilians simply
  do not update zones (they are outside every weapon's practical range anyway; the freeze is only a
  problem if the body moves, which at FAR it does not).

---

## F2 — THE PLAYER'S DOUBLE HITZONE SET

**Confirmed live, both sets, same frame.** `player.gd:446` builds 7 static bands
(`HitzoneBuilder._build_static(self, 32, 16, ["player_hurtbox","hitzone"], true)` — HEAD, BODY, GUT,
ARM_L/R, LEG_L/R), then `:456 _setup_hitzones()` builds 7 more by hand (`:880-894`) on the same
layer 32, the same two groups, `hitzones.append()` into the same array (`:449` and `:924`).

### RULING: DELETE `_setup_hitzones()` + `_create_hitzone()` NOW. Do not bead it.

Fossil law is not the strongest argument here — *damage determinism* is. ADR-010 is the determinism
contract; two overlapping zone sets mean **the zone that resolves is whichever the ray reaches
first**, which depends on physics-server shape ordering, i.e. on child-node order and rebuild order.
The same round, the same aim, the same pose can resolve TORSO ×2.5 or GUT ×2.25 across builds. That
is a live variance channel ADR-016's flat grammar was written to eliminate. Beading it is beading a
nondeterminism.

Delete the hand-built set, not the builder set, for three reasons:
1. `_build_static` sets `hz.set_meta("region", ...)` (`hitzone_builder.gd:576`). `_create_hitzone`
   sets **no region meta** — so `bullet_system.gd:152`'s `get_meta("region","")` hands `""` to the
   gore channel. Deleting the builder set would blind player gore.
2. `_build_static` is the shared authority every rigless unit uses; `_create_hitzone` is a private
   duplicate of it. Fossil law: delete the *predecessor*, keep the one authority.
3. `_create_hitzone` also mirrors the arms backwards vs the builder (left arm at `-0.35` at
   `player.gd:888` vs `+0.35` at `hitzone_builder.gd:562`). Both are LIMB so nothing breaks today —
   but it means the two sets are not even in agreement about where the player's body is.

### What deleting it could actually break — the honest list

- **Coverage shrinks, measurably.** The two sets are NOT identical volumes. Builder BODY: capsule
  r0.3 **h0.6** at y1.3 (`hitzone_builder.gd:568`). Hand-built TORSO: r0.3 **h0.35** at y1.3
  (`player.gd:884`). Builder GUT: r0.28 **h0.6** at y**0.85** (`:569`); hand-built GUT: r0.28
  **h0.3** at y**0.9** (`player.gd:886`). Today the union of both is what the player is. After the
  delete, the survivor is the *taller* builder set — so coverage does not shrink, it **grows
  slightly** at the chest/gut seam. Net: the player becomes marginally EASIER to hit and a hair more
  likely to eat GUT (2.25 + bleed) instead of a miss. **Player TTK moves. It must be probed, not
  assumed** (ADR-015).
- **`hitzones` array halves (14 → 7).** Its only consumer is `weapon_holder.gd:507-514`
  `_self_exclusions()`, which excludes the player's own zones from his aim ray and his own rounds
  (`:424`, `:479`, `:552`, `:598`). Excluding 7 instead of 14 is correct *provided* the 7 that
  remain are the ones actually in the world. They are — `:447-449` appends every `Hitzone` child
  after the builder call. **Verify the delete does not reorder `_ready()`:** `_build_static` at :446
  must stay BEFORE the `for c in get_children()` loop at :447, or `_self_exclusions()` returns an
  empty list and **every trigger pull becomes a self-headshot** (the exact failure
  `weapon_holder.gd:504-506` documents).
- **Nothing else touches them.** `player.gd` has `apply_wound` (:412) and `is_dead` (:875) but **no
  `on_zone_hit`** — so the gore channel at `bullet_system.gd:151` no-ops on the player either way.
  Deleting changes nothing there.

**Required probe (ADR-015):** headless — spawn the player, assert `get_children()` yields **exactly
7** `Hitzone` nodes, one per region name {HEAD, BODY, GUT, ARM_L, ARM_R, LEG_L, LEG_R}, **each
region exactly once**, all on layer 32, and `hitzones.size() == 7`. That last assertion is the one
that would have caught this on the day it shipped, and it ratchets: it fails if anyone ever adds a
third set.

---

## F6 — TRAP DESTRUCTIBILITY

`punji_trap.gd` is a bare `Node3D` (`:6-7`): no `Area3D`, no `CollisionObject3D`, no `health`, no
`take_damage`. Its header (`:3`) states the layer-free polling is deliberate, mirroring Claymore.
Detection is a 5Hz distance poll at 1.4m (`:42-57`) against `GameManager.player` and the `allies`
group.

### RULING: DEFER. Bead it. Do not build it this session.

Destructibility is not a tweak; it is a **new collision citizen**, and every new collision citizen
in this codebase has to answer the five questions the layer contract asks:

1. **What layer?** If layer 1 (world), the trap becomes bullet-stopping cover, and — worse —
   `enemy_base.gd:1790` / `ally_base.gd:816` cover queries include layer 1, so **a punji pit becomes
   a cover position the AI walks to**, which is the funniest and most immersion-fatal outcome
   available. If a new layer, it needs adding to the player's fire mask, which is the same edit F1
   is already making — two new layers in one session, in the file the whole game's lethality runs
   through.
2. **Health path?** A trap with HP needs `take_damage` with the 4-param zone signature (see §0), a
   death path, and a decision about zone multipliers on an object with no anatomy — HEAD is
   `is_fatal_zone()` (`hitzone.gd:93-96`) and a trap has no head. That means either a bare
   `Hurtbox` (a class that exists, is not used here, and would be a fourth damage-receiver pattern)
   or a hitzone with `fatal_override = 0` and `damage_mult_override`. **Either way it is new damage
   grammar surface**, in the same session as F1's new layer and F2's zone deletion.
3. **Grenades?** `CombatManager.apply_explosion_damage` (`:138-208`) iterates the player, then
   `AgentRegistry.allies`, then `AgentRegistry.enemies` — **three hardcoded registry lists, no
   generic "damageables"**. A destructible trap is invisible to every explosive in the game unless a
   fourth loop is added to the explosion authority. Blowing a trail with a frag and having the
   punji pits survive is worse than not being able to clear them at all.
4. **Who clears them, and is that fun?** Shooting a spike pit is not the Vietnam verb. The verb is
   *spot it and mark it* — and that verb already half-exists: `punji_trap.gd:20` puts every trap in
   group `punji_traps` for the point man's `detect_ambush` scan.
5. **What probe closes it?** Nothing in `tests/` covers trap lifecycle today.

Three of those five answers land in files another council owns (`combat_manager.gd` explosion
authority) or that F1 is already editing (`weapon_holder.gd` masks). **Two structural changes to the
lethality path in one session is one too many.** Defer, and bead it with the five questions attached
so the next council starts from the contract instead of from "add a health bar".

Cheap, honest alternative if the owner wants *something* on traps today: nothing in the damage path
at all — the trap is already in `punji_traps`, so a marking/spotting verb costs zero collision
surface. That is a game-design call, not mine; I only note that it is the option with no systemic
blast radius.

---

## THE SURPRISE LIST — what queries these layers / the `hitzone` group

Ordered by how badly it bites. **Cited, all verified in code this session.**

| # | Site | What it does | Bites which option |
|---|---|---|---|
| **S1** | `civilian.gd:234` vs `bullet_system.gd:147`, `weapon_holder.gd:634,638` | 3-param `take_damage` called with 4 args. **Runtime error on the first round that lands, inside the shared arrival resolver.** | **ALL THREE.** Prerequisite. |
| **S2** | `projectile_base.gd:96-98` | `if data.hits_enemies: mask \|= 4 \| 64`. Rockets/LAW/RPG/M79 arm on **layer 64**. On (a), **every warhead detonates on a villager it flies past.** | (a) |
| **S3** | `enemy_base.gd:1789-1793`, `ally_base.gd:815-819` | Cover search rays mask `1 \| 32`; a HIT = "this is cover". On (c), **both AIs take cover behind civilians.** | (c) |
| **S4** | `weapon_holder.gd:550` and `:596` | Buckshot rays mask `1 \| 64` — **32 is NOT in it.** On (c), villagers are rifle-vulnerable and shotgun-immune (two grammars, ADR-003 violation). On (b), **both lines need `\| 512` or the same split appears.** | (c) fatally; (b) if you miss line 596 |
| **S5** | `combat_manager.gd:138-208` | Explosion authority iterates player + `AgentRegistry.allies` + `AgentRegistry.enemies`. **Civilians are in `AgentRegistry.civilians` and are damaged by NO explosive in the game** — a frag in a hut kills nobody. Layer choice does not touch this; it is registry-driven. | ALL (unfixed by any option) |
| **S6** | `enemy_base.gd:1997-2002` | Muzzle discipline resolves `lane_owner` from the hit (Hitzone → `owner_entity`) and holds fire only if `lane_owner.is_in_group("enemies")`. A civilian is not in that group, so **the AI never holds fire for a villager in the lane** — and on (a) the villager's zone still *terminates the lane ray*, which suppresses `_suppress_player_if_near` (`:2006`) behind her. Villagers become suppression shadows. | (a); (b) only if 512 is added to AI masks |
| **S7** | `ally_base.gd:924-931` | Ally muzzle discipline checks `is_in_group("player") or "allies"` — same shape, same gap. An ally will happily fire through a villager at a VC. | (a); (b)+AI masks |
| **S8** | `fire_hazard.gd:22-23,53-55` | `mask = 2 \| 4`, `get_overlapping_bodies()`, **no group check**, calls `take_damage(int, FIRE, null)` — 3 args. **Civilians are on body layer 2, so fire hazards already kill villagers TODAY**, and it works precisely because it uses the old 3-arg form. Widening the signature (§0) keeps this working (defaults); *narrowing* or renaming params would break it. | Pre-existing. Constrains §0. |
| **S9** | `hitzone.gd:46-55` `_setup_groups()` | `call_deferred`, branches only on `player`/`enemies`. A civilian-owned zone keeps its build layer — **this is the mechanism (b) depends on**, and it means (b) needs no edit here. But it also means: **if anyone ever adds `civilians` to the `enemies` group, every civilian zone silently jumps to layer 64.** Fragile by design. | Enables (b); latent for all |
| **S10** | `probe_bullet_damage.gd:32`, `gun_range.gd:267`, `gore_lab.gd:476` | Iterate `get_nodes_in_group("hitzone")` and count/inspect. Adding civilian zones to that group (correct, for the bench overlay) **changes every count these three take.** `gun_range`/`gore_lab` are labs (no civilians spawn) — safe. `probe_bullet_damage` prints a zone count — cosmetic. Check before assuming a probe regression is real. | (b), (a), (c) |
| **S11** | `player.gd:446-449` ordering | `_self_exclusions()` (`weapon_holder.gd:507-514`) reads `controller.hitzones`, populated by the `for c in get_children()` loop at `:447`. **If the F2 delete disturbs that ordering, every player shot is a self-headshot.** | F2 |
| **S12** | `hitzone_builder.gd:10-12` sync contract vs `civilian.gd:125,131,361` | Civilians early-return on GONE and LOD_FAR and call `set_physics_process(false)`. Zones freeze. Builder header explicitly forbids syncing after a dead early-return. | (b), (a), (c) |
| **S13** | `tests/test_fossils.gd:224-237` | A `signal` nothing `connect`s = fossil = **build fails**. A `func` with `freq <= 1` (appears nowhere but its own declaration) = fossil = **build fails**. | The ROE hook. See below. |

**Non-surprises I checked and am clearing, so nobody re-derives them:**
`mission_trigger.gd:58-60` masks `2 | 4` and civilians are on layer 2 — but `:124` and `:130` gate
on `is_in_group("player"/"allies")`, so a wandering villager cannot trip a mission trigger. Safe.
`combat_manager.has_line_of_sight` (`:276-288`) and `_can_damage_multipoint` (`:213-244`) are
**layer-1-only** — civilians never occlude AI LOS under any option. Safe.
`squad_nameplate.gd:95` is layer 1 only. Safe. `player.gd:138` masks `1 | 4` and type-checks
`is EnemyBase`. Safe.

---

## THE ROE HOOK — shape it so it cannot become a fossil

**The constraint nobody has stated yet:** `tests/test_fossils.gd` will **fail the build** on the
obvious implementations.

- A `signal civilian_killed(...)` that nothing connects → `test_fossils.gd:227-229` records it as
  *"emitted into the void - nothing connects"* → **build red.** A signal is the wrong shape.
- A `func on_roe_violation()` that nothing calls → `_judge()` at `:241-243` sees `freq <= 1` →
  **build red.** An unwired function is the wrong shape.
- Adding either to `fossil_baseline.json` is *"the one forbidden move"* (CLAUDE.md, ADR-023).

The only shape that survives is **a function that IS called, whose body is intentionally inert.**

Second constraint: there is already a proto-consequence in the code, and the owner has ruled against
it. `civilian.gd:242-243` writes `director.state.flags["civ_casualties"]` and toasts
*"CIVILIAN DOWN. THAT FOLLOWS YOU HOME."* **`civ_casualties` is read by NOTHING** — grep across
`scripts/` returns exactly one hit, the write itself. That flag is a fossil already; the toast is a
promise the game cannot keep. Fossil law says the hook does not get *added alongside* it — the hook
**replaces** it, in the same change.

### The shape

In `civilian.gd`, at the death branch of the widened `take_damage`:

```gdscript
func take_damage(amount: int, _t: Enums.DamageType = Enums.DamageType.PHYSICAL,
		attacker: Node = null, _zone: String = "BODY") -> int:
	_hp -= amount
	if _hp <= 0 and state != CivState.GONE:
		state = CivState.GONE
		AgentRegistry.unregister(self)
		set_physics_process(false)
		rotation_degrees.x = 90
		_record_noncombatant_death(attacker)
		get_tree().create_timer(30.0).timeout.connect(queue_free)
	return amount


## ROE ledger entry. INTENTIONALLY INERT: ADR-019 hearts-and-minds is not built,
## and the owner's decree is that killing civilians costs nothing at this stage.
## The call site is the contract - a future scoring pass fills the body and
## touches nothing else. Do not delete: this is the single seam where a
## noncombatant death is known, and there is no other.
func _record_noncombatant_death(_killer: Node) -> void:
	pass
```

Why this shape holds:

- **It is called** (one call site, `freq >= 2`) → `test_fossils.gd` is satisfied, honestly, with no
  baseline edit.
- **It is one function, one seam, one name.** ADR-019 (hearts-and-minds) has a body to fill and one
  place to look.
- **It carries `attacker`**, which the widened signature now receives. Without it, a future ROE pass
  cannot tell a player kill from a fire-hazard death (`fire_hazard.gd:55` passes `null`) and would
  have to re-plumb the signature — the exact rework the hook exists to prevent.
- **The comment states a constraint the code cannot show** ("intentionally inert, this is the only
  seam") — which is the one thing comment discipline permits. It narrates no history and names no
  bead.
- **It deletes the `civ_casualties` flag and the toast in the same change** (fossil law: bury the
  corpse in the same commit). The toast is a consequence system with no system behind it; the flag
  is read by nothing.

Naming: **`_record_noncombatant_death`, not `_on_war_crime` or `_apply_roe_penalty`.** It records; it
does not judge and it does not penalise. A name that promises scoring is a lie until scoring exists,
and a lying name is how the next agent "fixes" it into a system nobody asked for.

**Probe that keeps it honest (ADR-015):** the F1 probe should assert that a civilian who takes lethal
damage reaches `CivState.GONE` **and that mission/debrief state is unchanged** — i.e. the hook is
provably inert. That single assertion is what stops a future session from quietly wiring
consequences in without a decree.

---

## RULING SUMMARY

- **§0 (prerequisite):** widen `civilian.gd:234` to the 4-param zone signature. Nothing in F1 is
  safe until this lands.
- **F1:** option **(b)**, new layer **512**, groups `["civilian_hurtbox", "hitzone"]`, added to the
  **player's three fire masks only** (`weapon_holder.gd:479`, `:550`, `:596`). AI masks untouched
  this session. Sacrificed: AI rounds do not harm villagers, which is unrealistic and visible.
- **F2:** **delete now.** Remove `_setup_hitzones()` and `_create_hitzone()` from `player.gd`
  (`:456`, `:880-924`); keep `_build_static` at `:446` and the append loop at `:447-449` in that
  order. Probe: exactly 7 zones, one per region, `hitzones.size() == 7`. Player TTK shifts slightly
  — measure it, do not assume it.
- **F6:** **defer and bead**, with the five contract questions attached. Two structural edits to the
  lethality path in one session is one too many.
- **Hook:** `_record_noncombatant_death(_killer)`, called, inert, replacing the `civ_casualties`
  flag and the toast.

## THE THING THIS COUNCIL IS MOST LIKELY TO GET WRONG

Treating F1 as a **layer question**. It is an **arity question wearing a layer costume**. Every
option on the briefing's table — (a), (b) and (c) alike — routes the first civilian hit into
`bullet_system.gd:147`, which passes four arguments to a three-parameter function. A council that
debates 32-vs-64-vs-new, picks one, ships it, and closes on "civilians are now shootable" will
produce a build where **shooting a villager throws a runtime error inside the one damage resolver
every shooter in the game shares** — and the symptom will present as a villager who *still* will not
die, sending the next session back to re-litigate the layer choice that was never the problem.

The second-most-likely error is smaller and cheaper: adding `| 512` to `weapon_holder.gd:479` and
forgetting `:550` and `:596`, shipping a game where the M16 kills villagers and the shotgun cannot.
