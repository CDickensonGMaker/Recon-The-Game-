# AI ARCHITECT — Question H: Ally AI to the *Vietcong* bar

**Date banner:** every claim below is `file:line` against the tree as of 2026-08-03. No claim here is
carried from a doc.

---

## 0. THE ARBITER'S ALREADY-VERIFIED POINTERS — RE-CONFIRMED, NOT RE-DERIVED

All five hold:

- Cover-first personality gate — `scripts/allies/ally_base.gd:106-109` (`wants_cover_first`), with the
  coward's anchor at `:114-117` (`may_close_distance`) and the go-getter's skip at `:1046-1053`.
  Courage is rolled per man per playthrough at `:296` (`courage = randf()`).
- Prone latch identical to the enemy's through the shared authority — `:389-391`, `:395-413`, calling
  `scripts/ai/combat_posture.gd:35-71`. Confirmed byte-identical rule: `wants_prone` / `must_rise` are
  static and both factions call them.
- Suppression — `ally_base.gd:216-217`, decay `:577-578`, heavy-pin gate `:748-756`, freeze
  `:1153-1164`.
- Cover-fail counting — `:1217` increments, `:106-108` reads it.
- Squad break on the same authority — `scripts/squad/squad_system.gd:388-409` calls
  `EnemySquad.break_state`, written onto each man at `:404-406`, read at `ally_base.gd:109` and `:117`.

**But see §4.1 — the break flag reaches only two hand-written gates and is NEVER fed to the shared
scorer, where the enemy does feed it. That is a real, cheap, pointered defect.**

---

## 1. QUESTION 1 — DOES AN ALLY UNDER FIRE SEEK THE MEDIC?

**NO. There is no wounded ally. There is no downed ally. There is no ally casualty at all.**

End-to-end trace:

1. `AllyBase.take_damage` — `ally_base.gd:1467-1489`. At `:1485-1487`: `if current_hp <= 0: _die()`.
   There is no downed branch, no bleed clock, no revive window. An ally is at full function or he is
   a corpse.
2. `AllyBase._die` — `:1496-1549`. Ragdoll/gib, `AgentRegistry.unregister`, `died.emit`,
   `add_to_group("ally_corpses")`, `queue_free` in 45s.
3. `SquadSystem._on_member_died` — `squad_system.gd:558-567`. Sets `m["alive"] = false`, writes
   `squad_kia`, toasts the KIA line, saves the campaign. **Nothing routes the medic anywhere.**
4. The medic's ONLY revive path is the player: `squad_system.gd:99-102` binds
   `_health.revive_handler = self` off `world.player`'s `HealthSystem`; `begin_revive` `:292-305`,
   `_process_revive` `:313-348` all read `world.player`. `HealthSystem.is_downed` /
   `DOWNED_BLEED_SECONDS` live at `scripts/player/health_system.gd:249-286` — **player-only fields.**
5. `AllyBase` itself acknowledges this in a docstring at `:41-42`: *"Allies have no alert tier or
   downed state."* Echoed at `scripts/autoload/campaign_state.gd:260`.

**The asymmetry is exactly backwards from Pillar 4.** The ENEMY has the full casualty system the
squad lacks: `is_downed` (`scripts/enemies/enemy_base.gd:2489`), `downed_pool` (`:2497`), a combat
medic that scans 45m for downed men and hauls them out (`:2494-2570`, gated by
`enemy_data.gd:30-33`). **The VC drag their wounded out of the fight; your own squad does not have a
wounded state to be in.**

What an ally under fire DOES do, per the shared scorer:
- SEEK_COVER (`ally_base.gd:770-774`, `1185-1236`)
- RETREAT when hurt — `combat_goals.gd:121-132`, gated by `ally_base.gd:800-801`
  (`retreats_when_hurt = true`, `retreat_hp_frac = 0.35`). Execution at `ally_base.gd:868-878`: he
  backs off 12m along the threat axis, face to the enemy, still firing.

So a hurt ally breaks contact. He never asks for aid, and there is no aid to ask for.

---

## 2. QUESTION 2 — DOES A MAN CARRYING A CAPABILITY WEIGHT SELF-PRESERVATION HIGHER?

**NO. MOS is read NOWHERE in the ally AI. Proven, not inferred.**

`grep -n '\bmos\b' scripts/allies/ scripts/ai/` returns exactly ONE hit repo-side in the AI layer:
`ally_base.gd:166` — and it is a COMMENT (`## roster entry (name/mos/stats)`). The AI reads `member`
only twice, and neither is a role:
- `ally_base.gd:1390` — `SquadRoster.skill_level(member, "small_arms")` for spread.
- `ally_base.gd:175` — `SquadRoster.call_name(member)` for a promotion bark.

Where MOS *is* read, and what it buys — all of it cosmetic or offensive, none of it survival:
- Weapon + body — `squad_system.gd:78-88`, `:108-145`.
- MG fire-rate 1.6× — `:80-81`.
- RTO radio rig — `:91`, `:152-156`.
- Point slot 12m ahead — `:88` → `ally_base.gd:956-957`.
- Point scan, thumper, revive, boxes — `:427-453`, `:456-488`, `:224-348`, `:251-276`.

**Consequences, in order of severity:**

1. **The RTO does not hang back — he rolls the same `randf()` every rifleman rolls**
   (`ally_base.gd:296`). ~25% of playthroughs give him nerve ≥ 0.75, which makes
   `wants_cover_first` return **false** (`:109`): the man carrying the fire-support verb **skips the
   cover trip and pushes with the player.**
2. **The verb he carries is the hardest-gated in the game.** `_radio_check`
   (`field_director.gd:654-663`) requires a **living RTO within `RTO_RADIO_RANGE = 10.0`**
   (`:323`), and `:257-268` kicks the player off the net the same frame the RTO dies. So a
   coward-rolled RTO who anchors 30m back silently disables all three fire missions, and a
   go-getter-rolled RTO gets shot and disables them permanently.
   **→ This also ANSWERS the briefing's open extension (§0 item 8): if the RTO man goes down, the
   calls STOP, hard, today, in shipped code.** That needs a ruling — it is a much bigger swing than
   the one Caleb already refused.
3. **The point man is deliberately the MOST exposed man in the squad** — 12m ahead
   (`ally_base.gd:956-957`) — and he carries the ambush/trap-detection verb
   (`squad_system.gd:427-453`). That is correct doctrine and correct drama, but it means the squad's
   eyes die first and nothing compensates.

---

## 3. QUESTION 3 — DO ALLIES USE CONCEALMENT, OR ONLY COVER?

**COVER ONLY. Concealment can NEVER be a chosen AI position. This is the single largest gap between
this squad and *Vietcong*'s.**

The cover-point query — `ally_base.gd:1286-1310`:
```
var query := PhysicsRayQueryParameters3D.create(
    candidate + Vector3.UP * 1.3, threat_pos + Vector3.UP * 1.0, 1 | 32)   # :1298-1299
...
if space_state.intersect_ray(query):
    candidates.append(candidate)                                           # :1302-1303
```
A candidate qualifies **if and only if a physics ray is BLOCKED** on layer 1 (world) or 32. Twelve
offsets, ±3/±6m, `enemy_base.gd:124-128`. Sorted by distance + crowding (`:1304-1306`), claimed
through the shared broker (`:1308`).

Now the vegetation contract — `terrain/vegetation/tree_cover_layer.gd:17-19`:

> *"Cover-givers ONLY: a solid a bullet stops and a body hides behind. ... Everything NOT listed
> (grass, fern, vine, moss, rice, bush, sapling, liana) is CONCEALMENT — it cuts sight via the veg
> grid, never a collider."*

`COVER_TRUNK` (`:20-28`) is broadleaf / banana / bamboo / palm / logs / stumps. **Elephant grass,
tall grass, ferns, bushes, rice — the entire GRASSLAND species pool
(`vegetation_manager.gd:49`) — have no collider and therefore can never satisfy the raycast.**

So the sim already REWARDS being in the grass, and the AI is structurally blind to it:
- `SightCap.at` (`scripts/ai/sight_cap.gd:32-39`) lerps the sight ceiling from open range down to
  jungle range on `max(veg(observer), veg(target))` — the grid lookup is `get_vegetation`,
  `terrain/core/gameplay_grid.gd:349-351`, an **O(1) array read**.
- `GameplayGrid.has_line_of_sight` (`:377-421`) gives HEAVY_JUNGLE cells a deterministic **30%
  per-cell block** (`:406-411`).
- `_find_target` applies the cap at `ally_base.gd:692-697`; `_update_line_of_sight` applies the
  terrain LOS at `:717-719`.

**A man standing in elephant grass is measurably harder to see, and no ally will ever choose to
stand there.** One O(1) grid read is the whole distance between the current AI and the Vietcong bar.

**Second, worse finding — trunk cover only exists near the PLAYER.** Trunk collision bodies are a
pooled ring keyed to `GameManager.player`, radius 70m (`tree_cover_layer.gd:34-43`, `:69-71`;
`_park_body` at `:280-284` sets `collision_layer = 0`). Beyond 70m from the player there are **no
tree colliders at all**, so an ambient friendly patrol, a garrison defender, or any ally the player
has walked away from finds **zero** cover in open jungle, burns `_cover_fail_count` to 2
(`ally_base.gd:1217`), and `wants_cover_first` permanently returns false (`:107-108`) — he fights
standing in the open until the fight ends. The demo's squad usually stays inside the ring; the
hunter-patrol / ambient-cell proposals in question G do not.

---

## 4. DEFECTS FOUND WHILE READING (not asked for, cheap, pointered)

### 4.1 The squad-break flag never reaches the shared scorer — ALLY ONLY
`ally_base.gd:782-801` builds the `CombatGoals.Context` and sets 18 fields. It does **not** set
`c.squad_broken` or `c.force_ratio`. The enemy does: `enemy_base.gd:1408-1409`.

`combat_goals.gd:121-132` gives `+0.7` retreat for `squad_broken` and scales the whole retreat score
by `numbers = f(force_ratio)`. With the defaults (`combat_goals.gd:50-52`: `squad_broken = false`,
`force_ratio = 1.0`) **a broken ally squad never gets the retreat bonus and is never treated as
outnumbered.** `SquadSystem` computes the break correctly, toasts *"SQUAD COMBAT INEFFECTIVE —
BREAKING CONTACT"* (`squad_system.gd:408`), and the men do not break contact through the scorer —
only through the two hand-written gates at `ally_base.gd:109` and `:117`. **The toast is currently
writing a cheque the AI does not cash.** Two lines.

### 4.2 MARKSMAN is a verb that has never once been in the field
`MOS_WEAPON` has him with an m70 (`squad_system.gd:114`), `WEAPON_BODY_POOLS` has his body
(`:122`) — but `SquadRoster.MOS_ORDER` is `["POINTMAN","RTO","MEDIC","MG","GRENADIER"]`
(`squad_roster.gd:64`), and `ensure_roster` fills every remaining slot with `RIFLEMAN`
(`:68`, `:174-185`). **No marksman is ever generated.** Data + art + a docstring calling him "a valid
MOS", zero instances. FOSSIL-LAW triage: **UNFINISHED — wire or cut.**

### 4.3 The briefing says "the demo's 5-man squad." It is EIGHT.
`SquadSystem.SQUAD_SIZE = 8` (`squad_system.gd:19`) and `SquadRoster.SQUAD_SIZE = 8`
(`squad_roster.gd:67`): 5 specialists + 3 riflemen. The "five" in the briefing is `MOS_ORDER`'s
length. Correct the scope doc — eight men is a different perf and legibility problem from five.

---

## 5. THE VIETCONG INSIGHT — WHICH VERBS DOES THE SQUAD OWN?

**OWNED, in code:**

| Verb | Man | Pointer | Player-invoked? |
|---|---|---|---|
| Detect ambush / spot punji traps | POINTMAN | `squad_system.gd:427-453` | **no — automatic** |
| Call for fire (arty/napalm/CBU/Spooky) | RTO | `field_director.gd:269-522`, gate `:654-663` | **YES** |
| Revive the PLAYER; bandage bag; medical box; resupply crate | MEDIC | `squad_system.gd:224-348`, `:251-260`, `:543-553` | **no — automatic** |
| Sustained fire (1.6× rate, M60) | MG | `squad_system.gd:80-81` | **no — passive** |
| Indirect fire on a 3+ cluster; ammo box | GRENADIER | `squad_system.gd:456-488`, `:266-276` | **no — automatic (box is on HOLD)** |

Player-issued squad verbs: FOLLOW / HOLD / MOVE / WEAPONS-TIGHT — `squad_system.gd:175-190`, keys
dual-bound per `ADR-012:51-54`. Plus the auto-go-loud on the player's first shot (`:358-360`).

**Every capability dies correctly with its man** — `member_by_mos` skips the dead
(`squad_system.gd:166-170`), so the point scan (`:428-430`), the thumper (`:459-461`), the revive
(`:224-226`) and the radio (`field_director.gd:658-663`) all go silent. **The wiring is right.**

**MISSING — and this, not the AI, is the real Vietcong gap:**

1. **Four of the five verbs are AUTOMATIC.** Losing the grenadier removes background noise you never
   asked for. In *Vietcong* you ORDERED the specialist, so his death took a button off your hand.
   Here it takes an ambient event out of the world. **A verb the player never spends is a verb he
   cannot miss.** Pillar 4 says you suggest and call — right now you suggest and call exactly once
   (the radio), and that one is the only verb whose loss the player will actually feel.
2. **No ally casualty verb** (§1) — you cannot save a man, so you cannot fail to save one.
3. **MARKSMAN** — a verb in the data that never reaches the field (§4.2).

---

## 6. MINIMUM CHANGE SET TO REACH THE BAR IN A 30-MINUTE DEMO — RANKED BY COST

**ALREADY SHIPPED — do not build, do not put in the backlog (verified this session):**
cover-first + courage gating · prone latch · suppression + heavy-pin freeze · the 9-verb shared
scorer including FLANK/ADVANCE/RETREAT · squad break math · cover claim broker (no two men on one
rock) · muzzle discipline (`ally_base.gd:1415-1422`) · verb-dies-with-the-man wiring for all five
MOS · the RTO-death radio kick · vegetation sight cap + jungle LOS occlusion · per-man aim settle,
spread from skill, and the file/formation layer.

| # | Change | Cost | Why it reaches the bar |
|---|---|---|---|
| **1** | Feed `c.squad_broken` and `c.force_ratio` into the ally Context at `ally_base.gd:782-801`, mirroring `enemy_base.gd:1408-1409`. | **~2 lines.** Zero perf. | The squad already computes its break and already toasts it; this makes the men actually break contact through the same scorer the enemy breaks on. Highest ratio of pillar to keystroke in this whole document. |
| **2** | MOS-weight `courage` at `ally_base.gd:296`: RTO and MEDIC roll in a low band (they carry a verb, not a rifle), POINTMAN and MG in a high one. | **~6 lines.** Zero perf. | The Vietcong insight made literal: a man IS his capability, so he values his own life in proportion to it. The RTO hangs back because the radio is worth more than his marksmanship. |
| **3** | **CONCEALMENT.** In `_find_cover_point` (`ally_base.gd:1286-1310`), accept a candidate whose `grid.get_vegetation(candidate)` clears a threshold even when the ray does not block, and add a vegetation term to the sort at `:1304-1306`. | **~12 lines + a LOOK-CHECK.** Perf: 12 × O(1) array reads per man per **second** (`_cover_search_timer = 1.0`, `:1209`) — free next to the 12 raycasts already there. | *This is the Vietcong bar.* The grass already conceals (`sight_cap.gd:32-39`, `gameplay_grid.gd:406-411`); this is the only change that makes the AI *know* it. Caleb's jungle ruling, pointed at the AI, exactly as the briefing frames it. |
| **4** | **Make ONE automatic verb player-spendable.** Cheapest with no new key and no HUD (ADR-012 / r4bk): when weapons are free and the GRENADIER is alive, `squad_move`'s existing ground-point aim (`squad_system.gd:183-186`, `_aim_ground_point` `:208-219`) also puts a thumper round there, bypassing the cluster search. | **~15 lines**, reuses a bound key and an existing affordance. | Turns the grenadier from ambience into a button. Now his death costs a VERB the player was USING — the whole point of the insight, and unreachable by any amount of AI tuning. |
| **5** | Wire MARKSMAN into `MOS_ORDER` or cut him (§4.2). | ~1 line either way; wiring costs one more body in the AO. | Fossil Law. A ruling, not a build. |
| **6** | **DOWNED ALLIES.** Give `AllyBase` an `is_downed` latch mirroring `enemy_base.gd:2489-2660`, and let `_process_revive` (`squad_system.gd:313-348`) target squadmates, not only `world.player`. | **Days. New state across take_damage / _die / _update_sprite / the bleed clock / the ledger / the LIVE_CAP accounting.** | The strongest version of the pillar — and **CUT FROM THE DEMO.** Named here so it is a decision, not an oversight. |
| **7** | Extend `TreeCoverLayer`'s 70m player-keyed collision ring to AI (§3, `tree_cover_layer.gd:34-43`). | Medium build, **real perf risk** (`POOL_MAX 1280`, `:40). | Only matters once ambient cells fight away from the player (question G). Not required if the demo's fights all happen near him — which the current beat sheet says they do. **Defer, but the G proposal must not assume otherwise.** |

**RECOMMENDED DEMO SCOPE: 1 + 2 + 3 + 4.** Roughly a day of work plus one look-check, and it moves
every one of the three unanswered questions. 5 is a ruling. 6 and 7 are cut, on the record.

---

## 7. LAW 2 — WHAT IS SACRIFICED

- **#1 (break → scorer).** An 8-man squad that loses 3 will now genuinely fall back — during the
  night attack, at the demo's climax, the player may watch his squad leave him on the wire. That is
  correct soldiering and it will read as abandonment to a first-time player. **Pillar 1 buys it,
  Pillar 4 pays.** No mitigation short of a bark, and there is a toast slot already
  (`squad_system.gd:408`).
- **#2 (MOS courage).** A cautious RTO plus a 10m radio leash (`field_director.gd:323`) means the
  player must walk BACKWARD to make a call. The fire-mission verb gets physically harder exactly
  when the fight is hottest. **This is a direct Pillar 4 vs Pillar 1 trade and the reason to ship it
  with the leash re-examined, not alone.**
- **#3 (concealment).** Cuts both ways by construction — `SightCap` is symmetric. Men who take grass
  become hard for **the player** to see, and Pillar 4 says you are IN the squad, not above it. A
  squad that melts into the elephant grass at 20m reads as a squad that left. `squad_nameplate.gd`
  exists and is the mitigation; it must be checked at the same look-check, or #3 buys realism with
  legibility.
- **#4 (spendable thumper).** Overloads an already dual-bound key with a second meaning and no HUD
  hint — the exact r4bk failure mode (ADR-012:26-30, 51-54). Sacrifice: discoverability. It needs
  one diegetic bark on the first successful call or it does not exist.
- **#6 (cut).** The demo ships with a squad whose men die instantly and finally. The casualty ledger
  stays the scoreboard, but the player never gets to SAVE anyone — the fantasy Caleb described as
  *"keeping them alive"* is, in the demo, only *"not getting them killed."* That is a smaller
  fantasy, and it is the price of 30 minutes.
- **#7 (cut).** Any fight the demo stages more than 70m from the player is fought by men with no tree
  cover. Question G's ambient cell must be scoped to fight near the player or accept dumb-looking
  allies. **Flagging this to the Arbiter as a cross-question dependency.**
