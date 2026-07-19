# DECREE — Playtest bundle (7 items), 2026-07-19

Council: game/UX designer · systems designer · technical director/lead programmer · devil's advocate.
Arbiter: the Overseer. Five parallel code-reading recons preceded the council; **three of the
briefed premises collapsed against the code.** That is the headline finding of this session.

---

## 0. THE THREE COLLAPSED PREMISES

**Item 1 — the RTO/PRC-25 theory was wrong.** The fire-support chain is wired end to end. The RTO
always draws the `us_grunt_rto` body (`squad_system.gd:93-94`), which is in `CARRIES_RADIO`
(`model_actor.gd:319`), and `_apply_optional_gear` returns EARLY for that unit (`:329-330`) — the
PRC-25 is baked in and cannot fail to appear. Bead `f0kv` concerns the **cosmetic 35% radio roll**
on rifleman/pointman flavour spawns, not the RTO role. **Fire support was never art-blocked.**

Proved by running it (`tools/diag_fire_mission.gd`, this session):
```
member_by_mos('RTO') = PRINCE CRAWFORD      RTO distance = 3.29m (leash 10.0m)
_radio_check() = ''                          _cas_ground_target() = (640.0, 165.9992, 240.0)
director.fire_support = {bombs:0, napalm:0, arty:0, mortar:2, spooky:0, cbu:0}
verbs that will answer NONE AVAILABLE: 5 of 6
mortar budget 2 -> 1 (DISPATCHED)
```
**THE ACTUAL DEFECT:** `director.fire_support` was never assigned from anything —
`grep -rn "\.fire_support\s*=" scripts/` returned ZERO hits. `mission_generator.gd:437` was dead
data. The live budget was forever the hardcoded default at `field_director.gd:194`.

**Item 3 — activity-tiering was not the cause.** `_execute()` runs every physics frame
unconditionally (`enemy_base.gd:500`); ADR-026 hot-set tiering only touches units already in COMBAT
(`:584-590`, whose own comment reads "Non-combat units are never tiered"). Distance never stops
movement.

**Item 3's REPLACEMENT diagnosis was also wrong** — caught by the Devil's Advocate, verified by the
Arbiter. `_attach_camp_directors` iterates `director._live_enemies` at world-build time
(`mission_generator.gd:205`), but village defenders are `"lazy": villages[vi] != nearest` (`:539`)
and **every** camp garrison is `"lazy": true` (`:542`). Those men spawn from a `LazyGroup` on player
proximity, long after. **Nothing re-attached a CampDirector.** So exactly ONE village in the AO had
a schedule, work stations and a patrol route; every other village and every camp stood in a spawn
ring forever. The briefing's implied one-line `work_pos` fix would have been a **no-op on the very
units the owner was complaining about** — it would have shipped, passed a probe on the nearest
village, and changed nothing he saw.

Free second defect found alongside it: `LazyGroup` never received `group.spread` — the non-lazy
branch used it (`:665`) but the lazy branch set only count/tag/setup/position, so every authored
20m village ring and 14m camp ring silently became the 12m `@export` default. Villages huddled.

---

## 1. RULINGS

**R1 — Fire support: grant at the outward wire crossing.** `_poll_wire_gate()` is already the patrol
boundary and already resets state via `_bank_patrol()`. One `_grant_fire_support()` on the outbound
edge. Table at `fo_fac` 0: **mortar 3 · arty 1 · bombs 1 · napalm 0 · cbu 0 · spooky 0**, with
`fo_fac >= 6` buying a 4th tube. Rejected per-day (invisible boundary) and a firebase shop (ADR-029
§4/§7 condemns the operations layer). Air stays thin because ADR-006 pays ground and unseen
contacts, never kills — fire support must not become the optimal opener.

**R1b — the menu must list only what you have.** The panel rendered all six rows always, dimmed.
Injecting budgets alone would have turned five dead rows into four. Fixed at `mission_hud.gd`.

**R1c — DEVIL'S ADVOCATE VETO, ACCEPTED: no budget ships while the danger-close confirm cannot see
the player.** `_danger_close_to_squad` (`field_director.gd:320-328`) iterated squadmates only —
granting napalm and arty while the confirm is blind to the player himself ships a way to kill him
with no warning. This is also ADR-011's own **REQUIRED AMENDMENT**, open since 2026-07-10. Shipped
with the budget, not after it.

**R2 — Completion verb: SPLIT, and the epic half STOPS.** ADR-029 §4 is unambiguous ("No
player-facing mission tracking, ever… Objective tracking dies"). The decree as written ordered
wiring into `MissionState.register_objective` — **that is a canon violation and the Arbiter refuses
it.** The legal reading is narrow and mechanical: an AAR/`flags` line is fine, `register_objective`
is not; `objective_titles` must stay empty in a patrol world.

But the council also found that **~80% of the owner's felt problem was not the missing charge at
all.** `player.gd:207-251` has ALWAYS handled the tunnel at 3.0m — enter, loot the cache, exit. He
was standing on a live interaction and **the game never told him it was there.** That is a flat
r4bk violation and it is cheap. **SHIPPED:** a proximity prompt naming the verb under his feet,
with ranges read from the same numbers the interact uses so the prompt can never promise a verb
that will not fire.

**DEFERRED with the reason named:** the satchel/collapse verb. `GAME_GUIDE.md:262` does bless it
("Tunnel MOUTHS you mark and **satchel are IN SCOPE TODAY**"), so it is legitimate scope — but the
Devil's Advocate costed it at five to seven systems (no charge item; the slot slider is hardcoded to
`range(4)` at `mission_hud.gd:128-134`; an F-key collision with "enter tunnel" at the same
position; `TunnelRoom.get_or_create` would resurrect a collapsed tunnel) and it needs an ADR-029
amendment **in writing before the code lands**. Per the decree's own instruction — *if an item turns
out bigger than scoped, STOP that item and report* — it is beaded, not built.

**R3 — Camp life: fix the attach, do NOT raise `activation_range`.** Unanimous. Measured cost is
~0.57ms per live unit and **BODY is 95-97% of AI cost vs BRAIN ~3%** (`PERF_LEDGER.md:265-284`), so
raising the range is the most expensive lever in the bundle and it solves a complaint the owner did
not make — at 200m there is nothing rendered to describe. `CampDirector.attach()` extracted as the
single factory both paths call; the build-time duplicate deleted (ADR-023). A moving man re-opens
the body gate on the next frame (`enemy_base.gd:528`), so this fix costs **no perf concession at
all** on units that already exist.

**NAMED SACRIFICE / OPEN RISK:** the Devil's Advocate is right that nothing ever despawns a
LazyGroup (`_spawned` never resets), so motion is *permanent* once woken. Making garrisons move
converts idle bodies into moving bodies for the rest of the patrol. This is the one item in the
bundle with a real frame cost and **it has not been measured** — the GPU bench needs a windowed run
and this session is headless-only by decree. Beaded.

**R4 — Flinch: ship the procedural half only.** `sprite_state_map.gd:138` maps `"flinch"` →
`rifle_aiming_idle` and **nothing ever emits the intent** — a survived hit produced a 0.1s red flash
and a 0.25s trigger stall, which is why the owner said they "just kinda stood around". Shipped a
`SkeletonModifier3D` spine punch: lazy, spine-only, `MAX_CONCURRENT_FLINCH = 8`, gated on
`CombatManager.perceivable()` and explicitly **not** on `_body_gate_open()` — that returns true for
anyone in COMBAT (`:524`), i.e. always true for a man who was just shot, so gating on it would be a
guard that guards nothing while reading as a perf guard. **Death theater NOT shipped:** it needs
`death_from_the_left`, which does not exist as an asset (`ANIM_WISHLIST.md:12`). Any decree ordering
"death theater" is ordering art that has not been authored.

**R5 — Traps: one Hitzone, not a hitzone SET, and not a bare body.** This is provable rather than a
preference: `bullet_system.gd:112-133` resolves damage only through `col is Hitzone` or group
membership in enemies/player/allies, so **a trap with a body and hp would have been silently
unshootable.** One TORSO zone on layer 512 — which `weapon_holder.gd:421` already carries in the
player's fire mask, so it costs nothing to wire and gives "VC fire cannot clear VC traps" for free.
HP 30: two rifle rounds, one buckshot pattern, any blast that reaches it. Blast gets a fifth loop in
the existing router — **a fifth client, not a second router**; ADR-003's one-grammar law governs
computation, not roster count. Rejected reusing the civilian path: it would put a spike pit in
`AgentRegistry.civilians`, where ROE and the ADR-019 ledger would read it as a person.

**RECORDED HONESTLY:** this morning's council deferred traps unanimously (F6) as "a feature, not
polish", and **that deferral was correct on the merits.** It was overturned by Summoner preference,
not by new evidence. That is Law 3 and entirely legitimate — but the record should say which it was.

**R6 — Informer: LOS, a direct call, and ALERT not COMBAT.** The clock now starts only on
`CombatManager.has_line_of_sight` (the one canonical helper — never a camera-look fake). The
`state.flags` mailbox is deleted: `Civilian` already holds `director` and used it one line earlier,
so passing a message through a write-only dictionary to a poller that reads the object you already
reference is indirection with no payer. Direct `director.on_informer_escaped()`, one-shot latched.
The lying comment died with the mailbox (TRUTH LAW). Response spawns 4 men at 90-140m on the side
away from the player at tier ALERT with `witnessed=false` — they arrive **searching**, and normal
perception decides whether they find you, so the beacon stays earned (ADR-005). Also deleted the
fake 120m GUNSHOT the informer emitted — there was no gunshot; it laundered detection past ADR-005.

**R7 — Nameplate: a category error, not a missing line.** `set_anchors_preset(PRESET_CENTER)` on a
never-sized Control preserved its default `(0,0,0,0)` rect, pinning it to the corner while
`_process` never computed a screen position at all. The plate belongs to the `_marker_box` family
(full-rect root + per-frame `unproject_position` behind an `is_position_behind` guard), not the
anchored-panel family; a static offset would have made it wrong in a new place. Head anchor reads
`ModelActor.target_height()` — **never a hardcoded 1.7132 in the HUD**, which would fork the ADR-002
contract. `LOOK_RANGE = 5.0` and `LOOK_CONE_DEG = 12.0` untouched per Summoner lock; ALLIES ONLY
holds. The other CanvasLayer children are genuinely safe — every sibling re-stamps `.position` after
its preset; the nameplate was the only one trusting the preset alone. **Honest discrepancy on the
record:** the TD reads the engine semantics as predicting screen-centre rather than upper-left; the
fix is identical either way, and the disagreement was converted into a measurement rather than an
argument.

---

## 2. WHAT IS SACRIFICED
- The satchel verb does not ship. The owner can now SEE the tunnel verb and go down the hole, but he
  still cannot collapse the mouth. That is the honest state and it is beaded.
- Napalm, CBU and Spooky remain at zero. CBU cannot be a live verb while `cbu_strike` and
  `place_claymore` both bind physical keycode 54.
- Garrison motion is permanent once a LazyGroup wakes, and its frame cost is UNMEASURED.
- Flinch reads as theater to a probe, not to an eye. Nobody has looked at it.
- Traps pay zero score, by design (ADR-006 pays contacts, not scenery) — and shooting one emits a
  150m GUNSHOT, so clearing traps loudly is how a stealth player gets found. A silent hold-to-clear
  was NOT built; that is a real gap in the trap's counterplay and it is beaded.

## 3. NOT VERIFIED — reported, not claimed
- That any of this **feels** right. Every probe here is headless by decree.
- The frame cost of moving garrisons.
- Which sentence the owner actually saw when fire support failed him. The budget defect is measured
  and real, but it explains a bad menu, not "never" — he still had 2 mortar rounds on key 4. The
  r4bk gap (no fire-support pixel on screen until the first T press) is the strongest remaining
  hypothesis and is now partly addressed by the wire-crossing toast naming the RTO and the key.
