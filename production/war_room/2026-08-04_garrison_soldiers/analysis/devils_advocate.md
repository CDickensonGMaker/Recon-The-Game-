# Devil's Advocate — Garrison men are soldiers (2026-08-04)

Independent read. Code only. The ruling (soldier-class on every side) is DECIDED; every HOW below
is stress-tested. No free lunches — each section names what the option sacrifices.

---

## 1. The premise, stress-tested: what does the class NAME actually break?

Almost nothing. Walk the defect list honestly:

- **They already fight.** `GarrisonDefender.promote()` (`scripts/allies/garrison_defender.gd:26-89`)
  tears the Civilian down synchronously and stands an `AllyBase` at his post, MG/mortar manning
  included. `_garrison_stand_down` (`scripts/missions/field_director.gd:1492-1500`) reverses it at
  dawn. The fighting man IS soldier-class today. The class diagram is only "wrong" during peacetime.
- **The real defect #1 — the reaction trigger, verified.** `_garrison_stand_to` fires from exactly
  three places: siege start (`field_director.gd:1442`), the 0.5s threat poll requiring
  **≥ 2 live enemies within 90m of fsb_center** (`field_director.gd:971-972, 1348-1361`), and a
  heli delivery *only if already stood-to* (`scripts/vehicles/heli_lift.gd:249-250`). Meanwhile
  every garrison man is DEAF: `civilian.gd:250-251` hard-returns `if is_garrison` in `_on_noise`.
  Consequence: a **lone** VC inside the wire (1 < FSB_THREAT_MEN 2), or any fire from **beyond
  90m** (a marksman at 150m, mortars at 300m), and the garrison sweeps floors while taking hits.
  This is a *trigger-coverage* bug. Renaming the class fixes zero bytes of it.
- **The real defect #2 — W-9 count 2, verified.** `SeatSystem.board_squad`
  (`scripts/vehicles/seat_system.gd:332-334`) does `body as AllyBase` → null for a Civilian → no
  MOVE_TO order is ever issued; `_board_one` (`seat_system.gd:341-351`) then glue-teleports him on
  the stagger timer. The new `board_heli` clip (`heli_lift.gd:45`) plays on a man who never walked.
  This is a *missing move verb* bug. Renaming the class fixes zero bytes of it either.

**Verdict on the premise:** the ruling is about legibility and reaction, not taxonomy. Any option
whose diff is mostly `class_name` churn is cost with no on-screen truth. The demo player cannot see
a class name; he CAN see a firebase ignoring gunfire and a man teleporting into a Huey.

---

## 2. Option (a) — migrate garrison to AllyBase / GarrisonSoldier subclass, full-time

The clean-diagram option. It is also the one that detonates the most shipped systems:

1. **Perf, and it is not hand-waving.** Bodies are ~94% of AI cost (cited in-code at
   `heli_lift.gd:23-24`; PERF_LEDGER: hitzone sync alone ~10ms/pf at line 297, and `:1057` states
   true hitzone cost is HIGHER — render-frame sync counted nowhere). Civilian deliberately builds
   **static hitzone bands** because "11 bone-synced convex hulls each is ~6.4ms/frame of hitzone
   sync" at 16-40 civilians (`civilian.gd:214-218`). AllyBase builds **bone-synced** zones
   (`scripts/allies/ally_base.gd:548`, synced per frame at `:563`). AllyBase is also pinned
   body-HOT ("allies get pinned HOT", `ally_base.gd:42-44`) where Civilian carries a 3-tier LOD
   with a hard return at 300m (`civilian.gd:284-287`). 40 full-time AllyBase heads at the firebase
   is precisely the load the ledger says the project cannot afford, spent on men who spend 90% of
   the day carrying trays.
2. **AllyBase has NO life brain.** Verified: no occupation, no schedule, no working point, no BT,
   no chow, no sleep anywhere in `ally_base.gd` — its verbs are FOLLOW/HOLD/MOVE_TO/RESCUE
   (`ally_base.gd:160`). Everything that makes the base read lived-in is Civilian-side:
   `_bt_settle` and the twelve actions (`civilian.gd:867-909`), `_play_garrison`'s
   occupation-aware chains (`civilian.gd:438-501`), `place_for_current_hour`
   (`civilian.gd:777-788`), household group-walk (`civilian.gd:684-722`). Porting that into
   AllyBase is not a rename — it is **rebuilding the Civilian inside AllyBase**, i.e. the 15th
   man-system wearing a soldier's shirt, days before the demo. The chow-hall loop (built 8/3,
   unwired) lands on this exact machinery.
3. **Shipped consumers break, enumerated:**
   - `spare_garrison` satchel decree (`scripts/autoload/combat_manager.gd:114, 161-167`) walks
     `AgentRegistry.civilians` and checks `is_garrison` — an AllyBase garrison silently exits the
     decree, and its stated rationale ("men who cannot react are not deleted", Pillar 5) INVERTS:
     they now can react, so the decree must be deleted, not orphaned (`placed_satchel.gd:59` names
     it). Nobody has ruled that the sapper breach may now delete the aid-station staff.
   - Litter team: the puppet latch is a **Civilian field** (`civilian.gd:110-113`, honored at
     `:289-291` and in `_animate`). AllyBase has no puppet concept; the three bearers and the
     scripted carry (`mission_generator.gd:929-948`) die with the migration.
   - `heli_lift.gd` is typed Civilian end-to-end: `_pax: Array[Civilian]` (`:58`), `_load_pax`
     spawns Civilians (`:191`), `_extract` filters `n as Civilian` (`:272`), `_on_took_off` casts
     Civilian (`:304`). All of it rewrites, and the 2026-07-30 ruling it cites (`:178-181`) is
     revoked wholesale — see §4.
   - Determinism: Civilian faces/dress are seeded by position (`civilian.gd:186-190, 228-231`,
     ADR-010); `AllyBase.spawn_ally` + `SquadRoster.generate_member` are only seeded on the
     promote path (`garrison_defender.gd:56, 129-132`). A naive migration churns the garrison's
     faces every boot.
   - `GarrisonDefender` itself must DIE in the same change (fossil law) — promote/demote, the
     MG/mortar manning consumers (`garrison_defender.gd:63-76, 139-167`), and both group names in
     `garrison_strength()` (`heli_lift.gd:113-118`).
4. **The boot race.** The 8/4 audit found demo boot ordering already fragile. Swapping the garrison
   population class the same week is how a second boot race is minted.

**Sacrifice (a) refuses to name:** the demo. This is a multi-day structural rebuild plus a re-tune
of the perf budget, purchased to fix two bugs that have one-file fixes.

## 2b. Option (b) — shared "person" base

The 15th man-system, formally. Civilian (910 lines) and AllyBase (~1600 lines) share
`CharacterBody3D` and nothing else: different hitzone strategies (static vs bone-synced, §2.1),
different LOD schemes, different nav idioms, different animation dispatch. A common base extracted
under deadline pressure will hold the ~50 lines they genuinely share (a move-toward and a noise
hook) and leave BOTH old paths alive — the exact fossil pattern ADR-023 exists to kill, except now
there are three places to look instead of two. The divergent-systems blindspot memo says this
project already did this ~14 times. Refactor blast radius: every caller of both classes, every
`as Civilian` / `as AllyBase` cast repo-wide, days before demo, with no headless suite to catch it
while coding. **Sacrifice:** everything, for an abstraction whose two clients disagree about
physics, damage, LOD and brains. Reject without ceremony.

## 2c. Option (c) — minimal bridge: real MOVE_TO verb + reaction hooks on Civilian

Two honest observations, one for and one against:

- **Against:** a general `set_order(MOVE_TO)` on Civilian is a THIRD order system
  (AllyBase `OrderMode` at `ally_base.gd:160`, EnemyBase has its own goal set) — ADR-023 by the
  letter. And "rename/retype later" is a check this project has bounced before; the drift law says
  later never comes. If (c) ships with a rename IOU, the IOU is the deliverable that dies.
- **For:** Civilian already HAS a move target — `_wander_target`, consumed by `_step_toward` every
  frame (`civilian.gd:28, 504-517, 671`). And it already has the exact suppression pattern needed:
  the **puppet latch** (`civilian.gd:110-113`), which stands down the BT, the schedule and
  `_animate` while a driver owns the body. A `board_target` latch that pins `_wander_target` to
  the staging point and releases on seat is not a new order system — it is the second consumer of
  a shipped pattern, ~30 lines in `civilian.gd` + a 5-line `else` branch in
  `seat_system.board_squad` (`seat_system.gd:332-335`).
- **The devil's caveat on the latch:** two latches (puppet, board) is the start of a latch
  collection. Name a rule now — one latch field, one owner at a time — or in three months there
  are five booleans fighting over `_wander_target`.
- The reaction half of (c) must NOT be a combat brain: react = call
  `director._garrison_stand_to()` (the one path, precedent already set by `heli_lift.gd:249-250`).

**Sacrifice (c) refuses to name:** the class stays named `Civilian` while holding armed US
soldiers, which is the exact lie-in-the-map the Summoner just tripped over. If (c) is chosen, the
rename is not "later" — it is a mechanical `class_name` + group-string sweep that must land inside
the same decree window or be declared dead.

## 2d. Option (d) — promote-on-boarding (promote to AllyBase just to walk to the bird)

Superficially cute — reuse the one promote path for W-9. It is the worst of the four:

1. `promote()` moves the man `firebase_garrison` → `garrison_promoted`
   (`garrison_defender.gd:42, 84`). `garrison_strength()` counts both groups
   (`heli_lift.gd:113-118`) so the count survives — but `_on_took_off` only strips
   `firebase_garrison` from a **Civilian** cast (`heli_lift.gd:303-306`). A promoted AllyBase
   flies away still in `garrison_promoted` → **the departed man is counted forever** → strength
   is permanently inflated → every future sortie reads EXTRACT → the demo's "nobody disembarked"
   bug is reborn by its own fix.
2. `_extract` selects `n as Civilian` from `firebase_garrison` (`heli_lift.gd:271-272`) — so
   promotion must happen mid-boarding, meaning a class swap (queue_free + spawn,
   `garrison_defender.gd:48-51`) **between** `board_squad`'s order and `_board_one`'s seat check
   (`seat_system.gd:346` `seat_of(body)`) on a freed node. Timer-bound callbacks holding a
   reference to a body that promote() just destroyed.
3. Promotion is loud: nameplate member generation (`garrison_defender.gd:53-56`), MG/mortar
   station claiming (`:63-76`) — a man boarding a heli could claim the nearest free M60 on his
   way to the pad. Stand-down at dawn (`field_director.gd:1496-1500`) would try to demote a man
   seated inside a despawning airframe.
4. It quietly violates the 2026-07-30 ruling (`heli_lift.gd:178-181`) for exactly the case that
   ruling was written about — heli pax — without the Summoner ever being asked.

**Sacrifice:** correctness, for the illusion of reuse. Reject.

---

## 3. The trap NOBODY has named: widening the reaction trigger has no exit path

Whichever option wins, the council will want to fix defect #1 by letting garrison noise/threat
trigger stand-to. Two live landmines inside that fix:

1. **`_garrison_stand_down` is only called from `_on_siege_ended`**
   (`field_director.gd:1477-1486`). A stand-to triggered by a noise event or a lone infiltrator is
   NOT a siege — `siege_ended` never fires for it — so the base stands to **forever**: camp life
   dead for the rest of the operation, chow hall empty, the 8/3 living-world work invisible, and
   40 bone-synced always-hot AllyBase heads on the frame until dawn-never-comes. Any widened
   trigger MUST ship its own all-clear (e.g. reuse the `FSB_CLEAR_POLLS` sustained-quiet machinery,
   `field_director.gd:994, 1380-1386`) **in the same change**, or the fix is worse than the bug.
2. **`_on_noise` carries `_team` and ignores it** (`civilian.gd:247`). The PLAYER firing a test
   round inside his own wire is a GUNSHOT within 90m of fsb_center. A naive un-gating of
   `civilian.gd:250-251` means the player standing his own base to (and paying landmine #1) by
   touching the trigger once. Filter on team, or on the threat poll's enemy census — never on raw
   noise.

Also for the record: the threat poll reads `_live_enemies` — verify a LazyGroup-spawned camp party
that wanders to the wire is registered in that array before trusting the poll as the sole trigger.

## 4. The 2026-07-30 vs 2026-08-04 ruling tension — say it out loud

`heli_lift.gd:178-181` encodes his 07-30 ruling: pax are Civilians BECAUSE AllyBase has no
schedule brain and promote/demote is the one path (ADR-023). That reasoning is still TRUE in the
code today (§2.2). The 08-04 ruling does not refute the reasoning — it renames the conclusion.
Options (a), (b) and (d) all silently revoke 07-30; only the Arbiter may do that, explicitly, in
the decree. The consistent synthesis of both rulings is: **the promote/demote architecture IS the
soldier-ness** (they are soldiers who hold jobs, and the fight-shape is AllyBase whenever there is
a fight) plus honest naming (a class not called `Civilian` for men in uniform). Any option should
be scored against BOTH rulings, not just the newer one.

## 5. VC audit — independent, and the side is CLEAN

Checked every `Civilian.spawn` caller (grep, 5 hits): `garrison_defender.gd:122` (US stand-down),
`mission_generator.gd:936, 966` (US firebase garrison + litter), `mission_generator.gd:1021` (true
villagers), `heli_lift.gd:191` (US pax). **Zero VC spawns.** VC camp life runs on the soldier
class end-to-end: `camp_director.gd:29` (`garrison: Array ## Array[EnemyBase]`), roles applied to
EnemyBase (`camp_director.gd:120-132`), camp-role clips ON EnemyBase (`enemy_base.gd:584-596`,
explicitly mirroring `Civilian._play_garrison`). The informer edge case: `_transform_to_vc`
(`civilian.gd:582-593`) swaps the MODEL but the body goes GONE + invisible + physics-off in the
same call chain (`civilian.gd:307-314`) and the armed response is spawned as EnemyBase by
`field_director.on_informer_escaped` (`field_director.gd:642+`). No armed VC ever runs as a
Civilian. **The extension ruling is already satisfied by shipped code. Any "fix" on the VC side is
a fix for a non-bug — that is drift, and I formally object to a single line landing there.** The
only defensible VC deliverable is one sentence in the decree recording this audit.

## 6. Timing — smallest change that makes the ruling TRUE on screen

W-9 count is 2 and the demo ships soon. On-screen truth vs class-diagram truth:

| Change | Files | On-screen effect |
|---|---|---|
| Board latch (W-9): Civilian walks to staging, then seats | `civilian.gd` (+~30), `seat_system.gd:332-335` (+~5) | Men visibly walk to the Huey |
| Threat-poll fix: drop hard-return `civilian.gd:250-251` → route qualifying HOSTILE noise/threat into `director._garrison_stand_to()`, WITH an all-clear re-arm (§3) | `civilian.gd`, `field_director.gd` | Firebase answers off-siege contact |
| Rename/retype (`GarrisonMan` or garrison flag made honest) | mechanical sweep | Invisible to the player |

The first two rows are the ruling as the player will ever experience it, shippable in ~a day. The
rename is legibility debt for future agents — real, but it is the ONLY part of options (a)/(b)
the player cannot see, and it is the part that costs days.

**The sacrifice the council will not want to name:** if the demo-safe slice ships, the codebase
still contains a class named `Civilian` full of armed American soldiers, and every future agent
reads that lie until the retype lands. If the full migration ships instead, the demo eats the
schedule and the perf ledger eats 40 hot bone-synced bodies. There is no option that pays neither.
Pick which debt, on purpose, and write it in the decree.
