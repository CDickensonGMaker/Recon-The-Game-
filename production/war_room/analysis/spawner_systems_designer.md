# SYSTEMS DESIGNER — The Random Grunt Spawner
**Session:** 2026-07-13 · **Charge:** reconcile the six new GLBs with the MOS code, design the migration, spec the spawner.
**Binding ruling from the Summoner:** *"change the code to fix the model names and not the other way around."* **ART IS TRUTH.**

---

## 0 · THE MEASUREMENT THAT DECIDES EVERYTHING

I dumped the mesh node names out of all six new GLBs. **They are the same man, six times, with one mesh swapped.**

| GLB (19:28 today) | mesh count | the ONLY difference |
|---|---|---|
| `us_grunt_rifleman` | 29 | `m16a1_world` |
| `us_grunt_rto` | 29 | `m16a1_world` |
| `us_grunt_pointman` | 29 | `ithaca37_shotgun_world` |
| `us_grunt_mg` | 29 | `m60_mg_world` |
| `us_grunt_grenadier` | 29 | `m79_launcher_world` |
| `us_grunt_marksman` | 29 | `m70sniper_world` |

The other 28 meshes are **byte-for-byte the same list** on every one of them:

```
Base_Human, us_grunt_joined, grunt_{head,torso,uparm_l,uparm_r,forearm_l,forearm_r,leg_l,leg_r},
cap_{head,torso,uparm_l,uparm_r,forearm_l,forearm_r,leg_l,leg_r},
helmet_shell_worn, helmet_camo_shell, helmet_bugjuice,
prc25_pack, prc25_antenna, prc25_handset,
ruck_pack_worn, webbing_worn, pouch_belt_worn, canteen_worn
```

`us_grunt_rto.glb` (11,414,236 B) and `us_grunt_rifleman.glb` (11,414,248 B) are **the same file, twelve bytes apart.**

**Three consequences, and they drive the whole design:**

1. **The art's notion of "role" is exactly one thing: the gun in his hands.** Nothing else distinguishes the six. So the spawner cannot *read* variety out of these files — it must **author** variety on top of them.
2. **Every man is wearing a PRC-25.** All six carry `prc25_pack` + `prc25_antenna` + `prc25_handset`. ADR-011's law is *"the radio is a man."* Ship this as exported and **the radio is a uniform** — the RTO becomes a lookup table entry, not a silhouette. This is the single most damaging line in the batch and §3 fixes it first.
3. **The tool to fix all of it is already written and wired to nothing.**

### `scripts/visuals/grunt_dresser.gd` — 179 lines, fully built, ZERO callers

Grep it: the only two hits for `GruntDresser` outside its own file are **two comments in `gib_system.gd`**. Nothing calls `dress()`.

It already does *precisely* what the Summoner asked for tonight:

- **70 faces** — head + hands share one material (`grunt_face_skin`) inside a 10×7 atlas; one `uv1_offset` slides face **and** skin tone together, and they can never mismatch because they are the same pixels.
- **15 helmets** — all 15 GLBs confirmed on disk at `assets/us/props/helmets/`: `m1_plain, m1_barepot, m1_barepot_fta, m1_cig, m1_bugjuice, m1_cig_bug, m1_ace, m1_ace_cig, m1_rounds, m1_foliage, m1_foliage_graf, m1_erdl_short, m1_war_is_hell, m1_born_to_kill, m1_veteran`.
- **Gear toggles** — `GEAR_TOGGLES` already names `ruck → ruck_pack_worn`, `radio → prc25_pack`, `radio_antenna → prc25_antenna`, `radio_handset → prc25_handset`. **The exact three knobs needed to strip the radio off the five men who should not have one.** Somebody built this for this problem and never plugged it in.
- It takes an `RandomNumberGenerator` in and returns the chosen look out as a Dictionary. It was designed to be seeded and recorded.
- `GibSystem.HELMET_SOCKET` already knows to blow the *dressed* helmet off instead of the stock donor.

Per the FOSSIL LAW's own triage this is **UNFINISHED**, not FOSSIL: built ahead of its wiring → **wire it.** The spawner is not a new system. It is a two-line call site and a data contract.

---

## 1 · THE ROLE SET — MY RULING

### The finding that unlocks it: **the player is already the sixth man, and he is already the RIFLEMAN.**

- `campaign_state.gd:31` — `player_data = {"mos": "RIFLEMAN", ...}`
- `skill_catalog.gd:45` — `"RIFLEMAN": "small_arms"` (the only MOS in `MOS_SKILL` that is **not** in `MOS_ORDER`)
- `squad_system.gd:31` — spawns `mini(5, roster.size())` allies. The player is **not** in the roster.

**The fireteam that walks the AO is six guns: the player (RIFLEMAN, invisible — he's the camera) + five AI.** That is not a proposal; that is what the code does today. So the art's six bodies and the code's six men were never in conflict. They were only mis-*named*.

### THE RULING

> **The AI fireteam stays 5-man (GAME_GUIDE §4.4 unamended). The MOS pool is 6. Four slots are FIXED VERBS. The fifth is THE LONG GUN, and it rotates between MG and MARKSMAN.**

| Slot | MOS | Why it cannot be cut |
|---|---|---|
| 1 | **POINTMAN** | `_point_scan()` — trap + ambush warnings (`squad_system.gd:214`); `plant_charge.gd:31` overwatch |
| 2 | **RTO** | ADR-011 — gates *every* fire-support verb (`mission_director.gd:266,327,338`) |
| 3 | **MEDIC** | revive chain, 2/mission, 30s clock (`squad_system.gd:136-187`); own VO bank (`vo_manager.gd:62`) |
| 4 | **GRENADIER** | `_grenadier_tick()` M79 on clusters (`:246`); `demolitions` sets charge-plant speed (`mission_generator.gd:385`) |
| 5 | **MG *or* MARKSMAN** | **the rotating slot** — the squad's long gun |

**Plus the player: RIFLEMAN.** Unchanged. Already true.

### Why the fifth slot rotates, and why that is the *right* answer rather than a dodge

Four of the five MOS **own a mechanic whose absence deletes a system**. Kill the RTO and the sky goes silent. Kill Doc and you bleed out. Those four are load-bearing and must always be on the roster.

The fifth is not. Look at what the code actually gives the PIGMAN: **`fire_rate_mult = 1.6`** (`squad_system.gd:42`) and the `small_arms` skill. That is it. He is *"the guy with the big gun."* A MARKSMAN is also *"the guy with the big gun"* — pointed differently. **In the fiction and in the code they are genuinely interchangeable**, which is exactly the property a rotating slot needs and the other four lack.

**And the marksman's skill already exists, orphaned.** `skill_catalog.gd:13` defines `"sniping": {"name": "SNIPING", "desc": "Long-range accuracy bonus", "max": 8}`. It has **no MOS owner**. Its only home is `PLAYER_SKILLS` (`:37`) — and **ADR-018 killed that**: *"No player progression may touch accuracy, recoil, sway, handling, health, or stamina. Ever."* A long-range accuracy bonus on the player is precisely what ADR-018 forbids. So `sniping` is a skill with a dead owner, and the marksman is a body with no skill. **They are the two halves of the same key.** ADR-018 §2 keeps squad XP *alive* (silent, behavioral) — so `sniping` is fully legal on a squadmate and illegal on the player.

`MOS_SKILL` gains exactly one line: `"MARKSMAN": "sniping"`. No new skill, no new curve, no new XP economy.

### When the slot is decided (and this is the Pillar-4 payoff)

**The slot's MOS is chosen when the slot is EMPTY** — at campaign start, and again whenever that man is KIA. Not per mission. `SquadRoster.ensure_roster()` already fills missing MOS slots with rookies (`:101-108`); the rotating slot just asks *"MG or MARKSMAN?"* on the way in, and the answer is written into the roster.

Which means: **your pig man dies, and the Army might not send you another pig man.** You bury Pig and a kid with a scoped Model 70 gets off the resupply bird, and your squad *is a different squad now* — quieter, longer-ranged, and no longer able to hose a treeline. That is Pillar 4 (loss changes who you are) and Pillar 5 (failure mutates) delivered **for free**, out of a rename.

### What each option cost, and why they lost

| Option | Verdict |
|---|---|
| **6-man AI squad** | Rejected. Changes squad size → formation, perf (last measured **19–25 FPS**), AI budget, `mini(5, ...)`, `ensure_roster`'s `< 5` loops, and the "5-man fireteam" identity in GAME_GUIDE §4.4. Buys one body. The SLICE (§6.0) forbids paying that. |
| **MARKSMAN replaces MEDIC or RTO** | Rejected outright. Deletes revive or deletes fire support. Not a trade, a demolition. |
| **MARKSMAN is scenery only** (firebase/enemy body, never a MOS) | Rejected. The Summoner asked for roles. The art declares a role. Wasting it is answering a different question. |
| **MEDIC dropped because he's not in this batch** | Rejected on measurement. `us_medic.glb` exists (13 MB, 11:35 **today**) and is current. He was not in the 19:28 batch because **he was already done**, not because he was cut. Canon requires him; the art has him. No conflict exists. |

**No pillar is violated. No system is deleted. One new MOS, reusing an orphaned skill. The squad stays five. Every one of the six new bodies gets used, plus the medic.**

---

## 2 · THE RENAME + THE SAVE MIGRATION

### The renames

| Code today | Code after | Art file |
|---|---|---|
| `POINT` | **`POINTMAN`** | `us_grunt_pointman.glb` |
| `PIGMAN` | **`MG`** | `us_grunt_mg.glb` |
| — | **`MARKSMAN`** *(new)* | `us_grunt_marksman.glb` |
| `RTO` | `RTO` | `us_grunt_rto.glb` *(replaces `us_rto.glb`)* |
| `MEDIC` | `MEDIC` | `us_medic.glb` |
| `GRENADIER` | `GRENADIER` | `us_grunt_grenadier.glb` *(replaces `us_grunt_m79.glb`)* |
| `RIFLEMAN` | `RIFLEMAN` *(player)* | `us_grunt_rifleman.glb` |

### THE LUCKY FACT THAT MAKES THIS MIGRATION CHEAP AND SAFE

I checked whether the rename destroys skill data. **It does not, and this is not luck I would have bet on:**

- `POINT → detect_ambush` and `POINTMAN → detect_ambush` — **same skill key.**
- `PIGMAN → small_arms` and `MG → small_arms` — **same skill key.**

The `skills` and `skill_uses` dicts on a roster member are keyed by **skill id, never by MOS.** So the rename touches **exactly two fields**: `member["mos"]` (a string) and `member["nick"]` (a derived string). Names, attributes, skills, XP, kills, missions-survived, alive-flag: **all untouched.**

**An existing campaign survives intact. Nobody dies, nobody resets, no veteran loses a level.** That is what makes this a string swap rather than a campaign wipe, and it is the reason I can recommend doing it now rather than deferring it.

### The migration — and z90e is the forcing function it asked to be

`campaign_state.gd:8` — `SAVE_VERSION = 1`. `:197` — `_migrate()`'s **entire body is a `push_warning`.** Bead **z90e** (P1, OPEN) says it in the imperative:

> *"Old saves 'migrate' by doing nothing; new fields silently keep defaults. **Write it BEFORE the next save-format change, not after.**"*

**This is that change.** z90e gets paid here or it never gets paid.

**Bump `SAVE_VERSION` to 2.** The v1→v2 body:

1. For each roster member: `mos = RENAME.get(mos, mos)` · re-derive `nick` from the new `NICKNAMES` table.
2. Back-fill `member["look"]` (§3) for every man who lacks one — **one deterministic roll per man, then it is his forever.**
3. Back-fill `player_data["look"]`.

Two ordering defects in the current path that MUST be fixed or the migration silently does nothing:

- **`_migrate()` is called at `:178`, BEFORE the fields are read from the ConfigFile at `:179-187`.** It is handed the `ConfigFile` (as `_cfg` — *underscore-prefixed, i.e. declared unused*). A migration that mutates in-memory `roster` from there would be **overwritten one line later by the load.** Fix: run the roster/player fixups **after** the reads, on the in-memory arrays. The existing re-save at `:190-191` then commits them, and the warning stops firing every boot.

- **`from_dict()` (`:217-228`) has NO migration path at all.** `SaveManager` slot files (`.sav`) carry campaign state through `to_dict`/`from_dict` under **SaveManager's own schema version**, not CampaignState's. **A slot saved before tonight loads old MOS strings straight into a post-rename build, through a door the migration never watches.** The five-man squad silently loses its point man and its pig — `member_by_mos("POINTMAN")` returns `null`, `_point_scan()` returns early, and the trap warnings just… stop. **A silent capability loss with no error.**
  **Fix:** extract one `_normalize_roster()` and call it from **both** `load_campaign()` and `from_dict()`. One function, both doors, ~10 lines. **This is not optional. It is the difference between a migration and a data-loss bug.**

**Probe (ADR-015 — nothing closes without one):** write a v1 `campaign.cfg` with a `POINT`/`PIGMAN` roster carrying non-zero `detect_ambush` and `small_arms` levels → load → assert MOS strings are `POINTMAN`/`MG`, **skill levels are unchanged**, `look` is populated, and `member_by_mos("POINTMAN")` resolves. Then do it again through `from_dict()`. Two asserts, both doors.

### Nicknames

`NICKNAMES` is the **diegetic** layer; MOS is the **data** layer. They are allowed to disagree, and they should.

| MOS | Nick | Note |
|---|---|---|
| `POINTMAN` | `EYES` | unchanged |
| `RTO` | `RADIO` | unchanged |
| `MEDIC` | `DOC` | unchanged |
| `MG` | **`PIG`** | **keep it.** He is still the pig man. The grunts never called him "the MG." |
| `GRENADIER` | `THUMPER` | unchanged |
| `MARKSMAN` | **`HAWK`** | new |

---

## 3 · THE SPAWNER — THE SPEC

### 3.1 The two-axis contract

> **ROLE is the READ. LOOK is the MAN.**
> Role decides what the player must be able to *identify at 80m through elephant grass*. Look decides who he is.
> **A look may never make two roles ambiguous. That is the one law of this system.**

### FIXED BY ROLE — never randomized, ever

| What | Value | Why it is locked |
|---|---|---|
| **The weapon body-mesh** | baked in the GLB (§0) | it *is* the role, per the art |
| **THE RADIO** | **`prc25_pack` + `prc25_antenna` + `prc25_handset` — ON for the RTO. **OFF FOR ALL FIVE OTHERS.** | see 3.2 |
| **The medic's body** | `us_medic.glb` (aid bag) | Doc must read as Doc |
| **MG's `fire_rate_mult`** | 1.6 | existing role effect |

### VARIES PER MAN — the whole variety budget, all of it already built

| Axis | Range | Source |
|---|---|---|
| **Face + skin tone** | **70** (10×7 atlas, one `uv1_offset`, head+hands move as one) | `GruntDresser._set_face()` |
| **Helmet** | **15** GLBs, all on disk | `GruntDresser._swap_helmet()` |
| **Ruck** | on/off | `GEAR_TOGGLES["ruck"]` |

**70 × 15 × 2 = 2,100 distinct men from six exported bodies, with no new art.** That is the answer to *"different arrangements every time."* It is not a stretch goal; the code to do it is already sitting in the repo, unreferenced.

**Fatigue/wear is NOT in this build.** There is no wear texture and no second UV row. Do not invent one. Ship the three axes that exist.

### 3.2 THE RTO PROBLEM — say it plainly, because this is the one that matters

**Today, as exported, every soldier in the United States Army is wearing a radio.**

ADR-011 is built entirely on the opposite premise:

> *"**The radio is a man.** … Fire support becomes a Pillar-4 statement — the RTO is a man you protect, whose skill you feel in the sheaf, **whose death silences the sky**."*

You cannot protect a man you cannot pick out of a file of five. You cannot feel dread about losing him. And the enemy AI cannot *hunt* him — which is the whole reason the leash exists. **If everyone wears the antenna, ADR-011's Pillar-4 statement is a lie told by a lookup table.**

**THE RULE, and it is not negotiable:**

> **`radio: true` for the RTO. `radio: false` for POINTMAN, MEDIC, MG, GRENADIER, MARKSMAN.
> Exactly one antenna is in the air at any time, and it belongs to the man who calls the sky.**

That whip antenna is a ~1.5m vertical line above a helmet — **the most readable silhouette anywhere in this game at range**, in a jungle where everything else is horizontal. It is already modelled, already rigged, already toggleable by name. It costs **one boolean** to become the best diegetic HUD element in the project — and it costs *nothing at all* to remain the worst kind of noise.

Follow-on (bead it; do **not** build it tonight): **enemy AI target priority on the antenna.** Historically the VC shot the radioman first, and every grunt memoir says so. But the *visual must ship first* — an AI that hunts a fact the player cannot see is not a mechanic, it is an unfair death. Ship the silhouette, playtest it, *then* teach the enemy to look for it.

### 3.3 WHERE THE SEED COMES FROM — the hard question, and the answer is "nowhere"

Pillar 4: *"named persistent teammates who improve, get wounded, rotate home, and die for real."*

**Therefore: a squadmate's face is not rolled. It is REMEMBERED.**

> **A squadmate's look is ROSTER DATA — generated ONCE in `SquadRoster.generate_member()`, written into his member dict, and SAVED. It is not a function of anything. It is a fact about him.**

```
member["look"] = {"face": 0-69, "helmet": "m1_cig", "ruck": true}
```

**Why not derive it from the mission seed (ADR-010):** because ADR-010 says *"ONE seed identifies ONE operation"* — and an operation seed **changes every mission**. Deriving a *persistent man's face* from an *operation seed* is a category error: **it would reroll Doc's face on every single insert.** The determinism contract and the persistence contract are pulling in opposite directions here, and persistence wins, because Pillar 4 is a pillar and determinism is a contract *about generation*. Note the shape of the mistake — the seed is right there, it is convenient, it is deterministic, and it is **exactly wrong.**

**Why not `hash(member.name)` (zero bytes, no migration):** tempting, and it *is* stable. Rejected on two counts. (1) `FIRST_NAMES` × `LAST_NAMES` = 225 combinations against a 5-man roster with replacements over a 40-mission campaign — **name collisions are not hypothetical**, and two men with the same name would be visual twins, which is worse than random. (2) It makes the look **immutable**, forbidding forever the things we will obviously want: a helmet that changes when he makes SGT, a bandage after he's wounded, ADR-018's rank cosmetics. Storing three keys buys all of that. **Store it.**

**And it is free.** The MOS rename *already* forces a save migration (§2). The `look` back-fill rides in the same v1→v2 branch. **One migration, two jobs.** If we do not store the look now, we will need a *second* save-schema bump later to add it — and z90e exists precisely because this project has already learned what happens when you defer a migration.

**For everyone who is NOT a persistent man** — enemies, firebase crowd, ambient grunts:

> Draw from a **dedicated RNG seeded from the mission seed**: `rng.seed = hash(mission_seed) ^ spawn_index`.

ADR-010 explicitly permits *"dedicated RNG objects"* seeded from the mission stream and **forbids** touching the global stream (`randomize()` is legal only for non-persistent cosmetics, and using it here would also make the AO non-reproducible). Same seed → same faces in the same firebase. Deterministic, and no bytes on disk. **Never `randf()` for a face.** (`ally_base.gd:158-166` currently calls raw `randf_range()`/`randf()` for `courage`, `skill`, and the follow-offset — that is a live determinism smell adjacent to this work. Note it; don't fix it in this build.)

**The player's own look** lives in `player_data["look"]`, same shape. But per **ADR-018** the player's helmet is a **rank cosmetic — CHOSEN, not rolled.** The 15 helmets on disk are the unlock surface ADR-018 asked for and did not have. `us_grunt_rifleman.glb` is his body: his corpse, his ragdoll, and him standing in the firebase — ADR-018 says the cosmetics are *"seen in the firebase, and on your own corpse"*, and that body is now sitting on disk waiting.

### 3.4 THE VETERANCY READ — free, and it pays ADR-018's outstanding debt

**The helmet roll is weighted by `member["missions"]`.**

| Tier | Helmets |
|---|---|
| **PVT / PFC** (0–3 missions) | `m1_plain`, `m1_barepot`, `m1_erdl_short` — clean, issued, anonymous |
| **CPL / SGT** (4–11) | `+ m1_cig`, `m1_bugjuice`, `m1_cig_bug`, `m1_rounds`, `m1_foliage` — he's started *personalising* it |
| **SSG** (12+) | `+ m1_veteran`, `m1_war_is_hell`, `m1_born_to_kill`, `m1_ace`, `m1_ace_cig`, `m1_foliage_graf` — **the graffiti is EARNED** |

ADR-018 confessed its own worst weakness:

> *"Silent squad XP is hard to author and impossible to see… **It violates the r4bk law on purpose** — its affordance is the man himself, and if that isn't legible enough to feel, the system has failed."*

**A helmet is an affordance.** Doc goes down, a green kid steps off the resupply bird, and **the kid's pot is clean** — no cigarettes in the band, no ace of spades, no graffiti. You can see he is new. **You can see what you lost, in the first second, without a number, without a UI.** That is Pillar 4's teeth, and it costs one weighted `rng.randi()`.

The look is stored, so it is *stable across missions* — which means it must be **re-rolled on promotion**, not per spawn. Cheapest honest version: when `missions` crosses a tier boundary at `on_mission_end()`, re-roll the helmet from the new tier and write it back. **He earns his graffiti on-screen, between missions.** One `if` in `squad_system.on_mission_end()` (`:314-318`).

### 3.5 THE MODEL TABLE — the new `MOS_BODY`

Replaces `squad_system.gd:60-65`. All five weapon `.tres` the art demands **already exist** (`m16a1`, `m60`, `m79`, `m70`, `shotgun` — verified in `data/weapons/`). **There is no weapon-data gap. Nothing blocks this.**

| MOS | `unit` | `weapon` | radio | ruck | notes |
|---|---|---|---|---|---|
| **POINTMAN** | `us_grunt_pointman` | `shotgun` | **off** | rand | the art hands him an **Ithaca 37**. Correct, period-true, and it *reads* — the man on point carries a scattergun. Today the code gives him an M16 and no body at all. |
| **RTO** | `us_grunt_rto` | `m16a1` | **ON** | **always** | **the only antenna in the squad** |
| **MEDIC** | `us_medic` | `m16a1` | **off** | rand | |
| **MG** | `us_grunt_mg` | `m60` | **off** | rand | `fire_rate_mult = 1.6` |
| **GRENADIER** | `us_grunt_grenadier` | `m79` | **off** | rand | |
| **MARKSMAN** | `us_grunt_marksman` | `m70` | **off** | rand | `sniping` |
| *RIFLEMAN (player)* | `us_grunt_rifleman` | `m16a1` | **off** | — | corpse / firebase / generic fallback |

**`MOS_BODY` stops being a sparse override table and becomes the complete registry.** Today it is missing `POINT` entirely (the comment at `:57-59` claims *"POINT is absent deliberately — the base grunt is correct for him"*). **That comment is now false** and must die with the change — the FOSSIL LAW and the comment-discipline law are the same law, and a stale comment explaining an absence is exactly the fossil that hides the corpse.

### 3.6 Where the call goes

`AllyBase._setup_visual()` (`:176-196`) builds the `ModelActor`. **Dress it there**, not at the `SquadSystem` call site — because `set_sprite()` **tears down and rebuilds the actor** (`:203-210`), and a dresser call bolted onto `SquadSystem.setup()` would be silently undone by any later rebuild. Give `AllyBase` a `look: Dictionary` + `radio: bool`, and have `_setup_visual()` call `GruntDresser.dress()` once the `ModelActor` reports success. **Every path then dresses correctly and the ordering trap cannot be stepped on.** Same hook on `EnemyBase._setup_visual()` when VC/NVA variety comes.

### 3.7 THE FOSSILS THIS CREATES — delete them in the same change (ADR-023)

> *"A system's replacement is not shipped until its predecessor is DELETED."*

| Fossil | Superseded by | Action |
|---|---|---|
| `assets/us/characters/us_rto.glb` (07-12) | `us_grunt_rto.glb` | **delete** (13 MB) |
| `assets/us/characters/us_grunt_m60.glb` (07-12) | `us_grunt_mg.glb` | **delete** (16 MB) |
| `assets/us/characters/us_grunt_m79.glb` (07-12) | `us_grunt_grenadier.glb` | **delete** (16 MB) |
| `model_actor.gd:59` — `UNIT_HEIGHT_M["us_rto"]: 1.7132` | — | **delete.** It names a unit that will not exist, and its value *equals the default anyway* — it was **always a no-op**. A fossil that never did anything is the hardest kind to see. |
| `squad_system.gd:57-59` — *"POINT is absent deliberately"* | §3.5 | **delete the comment with the code it lies about** |
| `ally_base.gd:155` — `sprite_unit = "us_grunt_v3"` | `us_grunt_rifleman` | **retarget** |

**DO NOT DELETE `us_grunt_v2.glb`.** It is the **reference rig for the entire test suite** — `test_hitzones` (×6), `test_gore_rig`, `test_head_burst`, `test_anim_library`, `test_seat_system`, `tools/build_ragdoll_scene.gd`, `hitzone_editor.gd:40`. Removing it turns the suite red. It is not a fossil; it is a fixture. `us_grunt_v3` and `us_grunt_m14` need a separate look once the new bodies are proven in-game — **do not sweep them in this change.**

**Flag, do not fix here:** `skill_catalog.gd:37` `PLAYER_SKILLS = ["small_arms", "sniping", "silent_movement"]`. **ADR-018 killed player ability progression** — `small_arms` ("tighter spread") and `sniping` ("long-range accuracy bonus") are *exactly* what ADR-018 forbids on the player, and `sniping`'s real owner is now the MARKSMAN. This is a canon violation that predates tonight and deserves its own decree; folding it in would smuggle an ADR-018 enforcement action into an art-integration commit.

---

## 4 · WHAT IS SACRIFICED

**No decision is free. Named, per the law:**

1. **Fire support gets genuinely harder, and that is not a side effect — it is the point.** Strip the radio from five men and the RTO becomes *findable* — by the player's eye, and (once the AI follow-on lands) by the enemy's. **The sky will go silent more often.** ADR-011 designed for exactly this and never got it, because the art hid the man. **This must be playtested, not assumed.** If the RTO dies in the first ninety seconds of every firefight, the leash is wrong — but we will finally be *tuning a real system* instead of admiring a lookup table.

2. **The MOS rename is a save-schema change, and there is no way to make it not one.** The migration is genuinely cheap (skill keys are MOS-independent, §2) — but **cheap is not free.** If `from_dict()` is not normalized alongside `load_campaign()`, a pre-rename `.sav` slot loads a roster whose point man and pig man **silently cease to exist**: `member_by_mos()` returns `null`, `_point_scan()` returns early, and the trap warnings just stop. **No error, no crash, no toast — a capability quietly deleted.** Both doors, or don't ship it.

3. **The rotating fifth slot means one of the six new bodies is absent from any given campaign.** Run an MG and you will never see your marksman; run a marksman and you never see the pig. The Summoner exported six men and will, in a single playthrough, field five. **I judge this a feature** (it is what makes a squad *yours*, and what makes losing a man mean something) — but he should hear it said out loud, because it is the direct cost of not expanding to a 6-man squad.

4. **The look becomes save state.** Three keys per man, forever, and every future roster field must now think about `look`. It also means **a bad face roll is permanent** — if the RNG hands the player an ugly or samey-looking Doc, that is his Doc for forty missions. That is the price of persistence, and it is the right price, but it puts real weight on the face atlas being **70 faces that are all worth being**.

5. **`us_grunt_rto.glb` and `us_grunt_rifleman.glb` are the same file** (§0 — twelve bytes apart). We ship 11 MB twice. The RTO is only *visually* an RTO **after** the dresser strips the radio off everyone else — which means the six-file split is, strictly, five files and a duplicate. I am **not** proposing deleting it: the Summoner named it, art is truth, and the name is the honest anchor for `MOS_BODY`. But the Arbiter should know the repo is carrying a redundant 11 MB, and that if `us_grunt_rifleman` ever diverges (a different helmet, a different ruck), **the RTO will silently stop matching the rest of the squad.**

6. **Variety is authored, not exported.** All 2,100 men come from *one* base body. Six identical silhouettes with different faces and hats will read as *"the same guy in different hats"* the moment the player looks closely — because **that is exactly what they are.** The face atlas and the helmets are carrying the entire load. If the base body is "chonky" (GAME_GUIDE §4.10: *"the 'chonky' base fix is the top art debt"*), **every one of the 2,100 is chonky.** The spawner multiplies the base body's virtues and its flaws with equal enthusiasm.

7. **`sniping` inherits an untested curve.** It has an XP curve, a max of 8, and — as far as I can find — **no consumer anywhere in the codebase.** Giving the MARKSMAN `sniping` gives him a skill that *levels up and does nothing* until someone wires it into ally accuracy. **Ship the MOS and the body; bead the effect.** A skill that visibly promotes ("HAWK: SNIPING → 3") and changes no behavior is a **new lie in the map**, and this project has sworn off those.

---

## 5 · BUILD ORDER (cheapest correct path)

1. **`_normalize_roster()`** in `campaign_state.gd` — MOS rename map + nick re-derive + `look` back-fill. Call from **`load_campaign()` AND `from_dict()`**. `SAVE_VERSION` → 2. *(Closes z90e.)*
2. **Rename** `POINT`→`POINTMAN`, `PIGMAN`→`MG` at all 8 call sites: `squad_roster.gd:7,8` · `skill_catalog.gd:40,43` · `squad_system.gd:42,215` · `plant_charge.gd:31` · `tests/test_squad.gd:47`.
3. **Add `MARKSMAN`** — `MOS_SKILL["MARKSMAN"] = "sniping"` · `NICKNAMES["MARKSMAN"] = "HAWK"` · rotating-slot pick in `ensure_roster()`.
4. **New `MOS_BODY`** (§3.5) — complete registry, POINTMAN included, weapons corrected, `radio` flag per role.
5. **`look` in `generate_member()`** + veteran-weighted helmet (§3.4).
6. **Wire `GruntDresser.dress()`** into `AllyBase._setup_visual()`. **The radio comes off five men.**
7. **Delete the fossils** (§3.7) — same commit, per ADR-023.
8. **Probe** (`tests/`): v1 save with `POINT`/`PIGMAN` + skill levels → load → assert MOS renamed, **skills preserved**, `look` populated, `member_by_mos("POINTMAN")` resolves. Same through `from_dict()`. Assert **exactly one** `prc25_antenna` is visible across a spawned 5-man squad.

**Beaded follow-ons (NOT this build):** enemy AI antenna target-priority · `sniping` effect on ally accuracy · `PLAYER_SKILLS` vs ADR-018 (canon violation, needs a decree) · enemy/civilian dresser variety · `ally_base.gd:158-166` raw `randf()` determinism smell · rank-gated player helmet cosmetics (ADR-018's unlock surface, 15 helmets already on disk).
