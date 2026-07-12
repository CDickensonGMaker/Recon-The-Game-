# ADR-016: Flat base damage × zone — the dice are retired
**Date:** 2026-07-10 · **Status:** Accepted — **SUMMONER-DECREED, verbatim:** *"Pure flat base × zone —
deterministic per hit; all variance from range, zone, and sim. Cleanest for Pillar 1; drops the dice
entirely."* · **Supersedes/Amends:** **ADR-003** (RECON dice as sole grammar — its "one grammar" and
locational-override rules survive; its dice-pool core is replaced) · CLAUDE.md damage law · GAME_GUIDE §4.1

## Context
ADR-003 unified the game on RECON dice pools (M16 5d10, AK 4d10…) — the tabletop's grammar carried into
realtime. The audit that ratified it also exposed the cost: per-shot rolls made time-to-kill *feel*
random at HLL lethality (two torso hits sometimes killed, sometimes didn't), the swing existed on top of
three other variance sources that FPS players actually read (range falloff, hitzone multipliers, the
three-situation asymmetry), and the one catastrophic data bug of the era — the Mosin 1d10+68 one-shot —
was only possible because a dice array could smuggle a flat modifier past review.

The charter (v0.3, Summoner-provided) logged a flat-base candidate as "ADR-016, profiler → War Room."
Before the profiler ran, the Summoner exercised final authority (Law 3) and decreed the direction
directly on 2026-07-10. The council's WHETHER debate is closed; this record captures the decision, the
conversion law, and what was sacrificed.

The tabletop soul is preserved where it belongs: **the flat values ARE the dice averages.** RECON's
numbers still define the game's lethality; only the per-shot randomness is gone. Where a tabletop needs
dice to simulate situation, a realtime sim *has* the situation.

## Decision
**Every weapon deals a flat, deterministic base damage per hit. All variance comes from range falloff,
hitzone multipliers, and the simulation (exposure, suppression, situation asymmetry) — never from rolls.**

- `WeaponData.base_damage` and `ProjectileData.base_damage` are `int` (flat). The dice array
  `[count, sides, modifier]` schema is deleted. `roll_damage()` is renamed `get_damage()` and is pure.
- **Conversion law:** flat = retired dice average, rounded (.5 up). Values of record:
  M16A1/CAR-15/M60 **28** (5d10) · AK-47/SKS/RPD **22** (4d10) · PPSh-41 **17** (3d10) · M1911 **11**
  (2d10) · M79 **44** · M26 **55** · M72 LAW **72** · RPG-2 (+rocket) **62** · RPG-7 **73**.
- **Retuned on conversion (the two legacy HoD outliers had no dice lineage to average):**
  Mosin-Nagant **32** (full-power bolt rifle: above the intermediate 22s, torso ×2.0 = 64 — hits hard,
  cannot one-shot the player) · Thompson **17** (.45 SMG, PPSh class).
- **Retired outright:** MP40 and Kar98k `.tres` deleted (off the Vietnam design's weapon set; their
  shared viewmodel scenes remain for the weapons that reuse them). Mosin and Thompson **stay** — both
  are period-correct in Vietnam and both have live asset/code references (Mosin FP viewmodel; Thompson
  in the lab roster).
- The locational model (ADR-003's second half) is UNCHANGED and now carries the structure dice used to:
  HEAD fatal · TORSO ×2.0 · GUT ×1.75 + bleed · LIMB ×0.75; player 100 HP, enemies 65–85.
- Loadout honesty (decree item 4): vc_rifleman now fires the SKS its description names; nva_regular's
  description now names the PPSh-41 it fires. (NVA→AK-47 archetype upgrade is future enemy work, beaded.)
- **Verification of record:** `tests/test_flat_damage.tscn` asserts determinism, the decreed values,
  the retired grammar's absence, and the lethality guards (rifles ≤2 torso hits vs enemies, ≤3 vs
  player, nothing one-shots the player's torso). Changing a value without amending this ADR turns the
  suite red by design.

## Consequences
**Buys:** learnable, consistent gunfeel (Pillar 1) — a weapon's kill pattern is knowable, so death reads
as *situation* (the pillar's own words), not roll luck. The Mosin one-shot bug class becomes structurally
impossible: no dice array can hide a modifier again. UI can print honest damage numbers. Tuning is one
integer per weapon.

**Costs (named — no free lunches):** per-shot unpredictability is gone — the wounded-not-dead variance
that fed the medic economy now comes only from zone geometry and range, which is coarser than dice were.
RECON fidelity narrows from "we roll their dice" to "we use their averages" — a real identity trade,
accepted by decree. The tabletop's 2d100-class extreme swings (.50, point-blank 12ga) have no analogue;
if those weapons ever ship, their identity must come from the sim (penetration, suppression), not swing.

**Work created:** none blocking — migration shipped with this ADR (schema, 16 resources, 6 call sites,
lab/editor/test rosters, stale comments/labels, CLAUDE.md law). The charter's damage-profiler probe bead
closes as superseded (the decision it was evidence for has been made; its verification role shipped as
`test_flat_damage`). Follow-on beaded: NVA AK-47 archetype upgrade.

## Evidence
- Decree: Summoner message 2026-07-10 (quoted verbatim above); charter §10.2 sequencing honored — probe
  shipped as the regression test, migration done once.
- `scripts/weapons/weapon_data.gd` — `base_damage: int`, `get_damage()`, flat damage string
- `scripts/combat/projectile_data.gd` — same; `data/projectiles/rpg2_rocket.tres` = 62
- Call sites migrated: `weapon_holder.gd`, `ally_base.gd`, `enemy_base.gd`, `projectile_base.gd` (×2)
- `data/weapons/*.tres` — 15 flat values as decreed; mp40/kar98k deleted
- `data/enemies/vc_rifleman.tres` → sks; `nva_regular.tres` description → PPSh-41
- Probe: `tests/test_flat_damage.tscn` — PASS 2026-07-10 (deterministic ×100, values, guards);
  headless boot clean on Godot 4.7
- `tests/test_ballistics.gd` rosters updated; `run_all_tests.ps1` now runs the 4.7 console exe

## Amendment A (2026-07-10, war-room quick): pellet weapons
Shotguns fire `pellet_count` rays per trigger pull with `base_damage` PER PELLET. Pellet spread is
aim-space variance (same class as the existing spread cone), NOT a damage roll — determinism holds
per pellet. Damage aggregates per target+zone into one hit event so locational multipliers and the
GORE_WORKFLOW single-hit thresholds behave. Record: `war_room/quick_2026-07-10_shotgun_pellets.md`.
**Summoner retune (same day, bench-tested):** full damage to **70m**, falloff to ×0.45 at 110m —
"damage a lot higher, drop off after 70m." Range attrition still emergent from the 5.5° cone.
**Summoner devastation decree (final form, same day): the Ithaca fires SLUGS** — `pellet_count = 1`,
flat **100** per round (torso ×2 = 200: one round ends anything to 70m). Matches the tabletop's
2d100 point-blank spirit (~101 avg) as a single freight-train projectile. The pellet-cluster
machinery (Amendment A above) stays in WeaponData for future buckshot variants; the probe's
one-shot-torso guard exempts the shotgun by design — it is the execution weapon.

## Amendment B (2026-07-11, Summoner-directed): per-unit zone override layer
The locational values of record (HEAD fatal · TORSO ×2.0 · GUT ×1.75 · LIMB ×0.75) remain the law and
the defaults. On top of them, a **per-unit override layer** now exists: `data/hitzones/<unit>.tres`
(`HitzoneTuning`) may carry per-zone `damage` (multiplier replacing the default) and `fatal` (bool,
overriding HEAD-fatal — e.g. a future helmeted heavy). Overrides are authored ONLY in the hitzone
bench (`hitzone_editor.bat` — `,`/`.` mult, `F` fatal, Ctrl+S), applied by `HitzoneBuilder._zone()`,
and consumed through the existing `Hitzone.get_damage_multiplier()`/`is_fatal_zone()` seams — no call
site changes. Determinism holds: overrides are static data, not rolls. A unit with no tuning file, or
a tuning entry without damage keys, behaves exactly per the law above; the bench refuses to persist
values equal to the law (no silent no-op files). Probe: `tests/test_hitzones.tscn` roundtrips
radius + damage + fatal and asserts untouched zones keep the values of record. Bead: 5if4.

## Amendment C (2026-07-11, Summoner-decreed): armory truth — arms models define the guns
Decree verbatim intent: *"the existing arm models will be all the guns that truly exist in the
game... that's the core of truth of guns the player can use and pick up. More will be added."*
- **The player-reachable armory = the 11 FP arms exports:** M16A1, M14, M60, AK-47, RPD, PPSh-41,
  Mosin, M70, Ithaca (slug), RPG-2, M1911/Colt45. The lab roster, loadouts, and capture can only
  hand the player these.
- **New values of record (cartridge-class conversion, same law as the original table):**
  **M14 = 28** (7.62 NATO — the M60's cartridge class) · **M70 Winchester = 32** (full-power bolt —
  Mosin class; the Summoner's own 071v suggestion).
- **Retired outright:** `car15.tres` (Thompson stand-in), `thompson.tres` (WW2 holdover),
  `sks.tres` (Kar98k stand-in). **vc_rifleman now fires the Mosin his model visibly carries**
  (loadout honesty — the vc_guerilla_mosin export was already in his hands).
- **NPC-side/future data may exist without arms** (m79 — ally verb; rpg7/m72_law — future) but is
  not player-reachable and carries NO stand-in viewmodel (`m79.tres` model_path cleared).
- **WW2 stand-in assets archived** to `Base Game Assets/RECONgame/ww2_standins/` (kar98/mp40/
  thompson gltf sets + superseded m1911/m16a1 single-gun scenes) — ~43MB out of the project.
- Probe updated: `tests/test_flat_damage.tscn` roster + retired list enforce this amendment.

## Amendment D (2026-07-11, Summoner-decreed): punishing zones — the multipliers rise
Decree verbatim: *"i want to turn up all the damage for all the hitzones. weapons should be more
punishing."* Context: the roster-wide model-scale fix landed the same day (men render true 1.71m and
zones hug them exactly — RECONgame-jkbv), so hits now land where aimed; the Summoner wants each hit
to MATTER more.
- **New locational values of record:** HEAD **fatal** (unchanged; ×4.0 vs the player) ·
  TORSO **×2.5** (was 2.0) · GUT **×2.25** + bleed (was 1.75) · LIMB **×1.0** (was 0.75).
- **Resulting feel:** M16-class 28 → torso 70 (one round drops a 65hp Local Force man, two end
  anyone, player dies in two); Mosin/M70 32 → torso 80 (still no one-shot on the player — the
  Mosin-bug guard holds); limbs now deal full pass-through damage, so wounding fire attrites.
- **Cuts both ways by design:** the player takes the same multipliers — "punishing" is the war,
  not a player buff. Pairs with the numbers-aware morale change (same session): the wave presses
  instead of routing, so lethality is mutual and intensity comes back.
- Guards updated in lockstep: `test_flat_damage` (ZONE_MULTS record + a new drift assertion tying
  `Hitzone.MULTIPLIERS` to this table) and `test_hitzones` (BODY law ×2.5).

## Amendment E (2026-07-11, Summoner-decreed): the Ithaca is buckshot again
Decree: *"we should make the shotgun a pellet spread again like it originally was."* The slug
(Amendment A final form) is retired from the Ithaca; the bench-tested buckshot retune returns as the
values of record: **pellet_count 8 × base_damage 20** per shell, 5.5° cone, full damage to 70m,
×0.45 at 110m. Per-pellet determinism and the per-target aggregation grammar are unchanged
(Amendment A machinery). With Amendment D zones, a full point-blank torso pattern is 8×20×2.5 —
the execution-range devastation survives the slug's retirement, and the cone restores range
attrition the slug never had. Probe updated (EXPECTED 20; the one-shot-player exemption now names
buckshot aggregation instead of the slug).

**Devastator retune (same day, bench-tested by the Summoner):** the first buckshot pass whiffed —
the cone was implemented as a per-axis half-angle (an 11°+ pattern, three shells at 14m) and
uniform-random pellets made it a slot machine (a jackpot one-shot at 30m). Fixes + retune, all of
record: cone semantics corrected (`pellet_spread_deg` = full angle), **deterministic star pattern**
(1 center / 3 at 40% / 4 at the edge, ~0.3° jitter — same aim, same cluster), **base_damage 20 →
35** per pellet, pellets **bucket per region** and feed the gore channel (a leg-full of buck pops
the leg), pellets **penetrate one body** at ×0.65 into the man behind (*"could even kill two
people at the same time and totally gib them apart"* — walls still stop lead), and single
body-zone kills ≥ 90 raw run the blast-butchery doctrine (no rifle chest hit reaches it). Probe
EXPECTED = 35.

**Pattern retune (2026-07-12, Summoner: *"the shotgun should have a larger spread… irl the spread
would grab and hit the opponent"*).** He was right about the symptom and the cure was the opposite of
the instinct: real 00 buck opens about **an inch per yard (~1.6°)**, so at 14m the cloud is ~40cm and
a chest eats most of it. Our 5.5° cone threw a **1.2m** pattern at that range — with only 8 thin rays
sampling it, the pellets flew *past both shoulders* and nothing connected. A colander, not a shotgun.
New values of record: **9 pellets** (real 00 buck count) × 35, **3.0° cone** (double-real, forgiving
but not straddling), star laid 1 centre / 4 at 40% / 4 at the rim. Range re-cut so a tight pattern
does not make it a sniper: **full damage to 25m, ×0.30 at 60m** (was 70m/110m — a slug's envelope).
Measured on a real man (`tools/probe_buckshot.tscn`): 5m **9/9 pellets, 577 applied** (butchery) ·
10–25m **4–5 pellets, ~280-320** (kills) · 30m **102** (kills) · 40m **49** (wounds) · 50m **42**
(wounds). Murderous inside 25m, a wounding cloud past 30 — which is what a 12-gauge is.

## Amendment F (2026-07-12, Summoner-decreed): explosives kill — and rockets outclass grenades
Decree: *"rockets should be more lethal than a grenade… scale grenades to 190 dmg and an RPG should
deal like 250 with splash damage… to demonstrate the effects of shrapnel."* Context: the fuze work
exposed that an armed PG-2 detonating 1.2m from a 70hp man left him **alive** (base 62), and that a
thrown grenade was silently hitting for a hardcoded 130 while its own `.tres` claimed 55 — the data
had been lying for months.

- **New values of record (flat, per ADR-016 grammar — the `.tres` is the single source):**
  M26 frag **190** (was 55/130) · M79 HE **150** (44) · M72 LAW **250** (72) · RPG-2 **250** (62) ·
  RPG-7 **290** (73). `rpg2_rocket.tres` (ProjectileData) matches at **250**, blast radius **8m**.
- **The grenade's hardcoded constants are dead:** `grenade.gd` now reads `m26_grenade.tres`
  (`_grenade_damage()`), so one number rules the weapon. Radius **10m** (real M26 casualty radius is
  ~15m; 10 keeps cover meaningful), rim damage **13%** of centre.
- **Shrapnel shape:** the blast keeps its kill plateau (full damage inside 40% of radius, the
  fireteam-in-the-lap wipe) and tapers to the rim, where fragments **wound rather than kill** —
  M26 rim ≈ 25, PG-2 rim ≈ 38. Cover still blocks it (the 8-point visibility check is unchanged),
  so the counter to shrapnel remains geometry, not hit points.
- **Cuts both ways:** the player has 100 HP. A frag at his feet is death, at the rim a serious
  wound. Ordnance is now the most dangerous thing on the battlefield — for everyone.
- Guards: `test_flat_damage` carries the new record; `tools/probe_grenade.tscn` (fireteam wipe) and
  `tools/probe_fuze.tscn` (drop-safe arming) both stay green.

## Amendment G (2026-07-12, Summoner-decreed): the .45 ACP class, and the Ithaca's magazine
Decree: *"the pistol should be doing 20 dmg a shot… a .45 round ain't no joke. Also the Thompson,
when it's working, is shooting .45 rounds. And the shotgun should have 8 rounds in a magazine, 5 is
too small."*
- **New value of record: M1911 = 20** (was 11). Torso ×2.5 = **50** — two centre hits kill a
  65–85hp man and two kill the player. A heavy, slow, big-bore round: few shots, each one serious.
  The one-shot-player guard still holds (50 < 100).
- **`.45 ACP` is now a CARTRIDGE CLASS, not one gun's number.** Any weapon firing it inherits **20**.
  That names the **Thompson** in advance: it stays retired by Amendment C (no FP arms export exists,
  and Amendment C's law is that the arms models ARE the armory) — but the moment a Thompson arms
  model ships, its value is already decreed at 20 and needs no new amendment. Same rule would give a
  future M3 "Grease Gun" 20.
- **Ithaca 37 magazine 5 → 8.** The trench-gun tube fits it and it is the Summoner's call; the
  weapon's identity is CQB dominance, and reloading after five was clipping that fantasy short.
- Guard: `test_flat_damage` EXPECTED carries M1911 = 20.

## Related
- **Pillars served:** 1 (outstanding gunplay — the decree's own rationale); 5 (honest, learnable death)
- **ADRs:** supersedes ADR-003's dice core (locational model and one-grammar law survive); ADR-015
  (verification law — this ADR shipped WITH its probe); ADR-011 (explosive damage values feed AOE)
- **Beads:** xkn1 (decree item 4 — completed by this migration) · btnm (profiler — superseded by decree)
