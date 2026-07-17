# LEAD PROGRAMMER — the random grunt spawner, the kill list, and the x1bs in the new art

Read from source, 2026-07-13. Every claim below is cited to a line I opened.

---

## 0. THE HEADLINE (read this if you read nothing else)

I dumped the glTF node tables of all six new GLBs. Three things are true that no document says:

1. **All six ship a `Base_Human` mesh — 402 tris, 320 verts, SKINNED — *in addition to*
   `us_grunt_joined` (434 tris).** Two bodies. Nothing in `ModelActor` hides it. This is a
   NEW x1bs, and it is worse than the helmet one, because it is a whole man.
2. **All six ship `prc25_pack` + `prc25_antenna` + `prc25_handset`.** Every grunt — rifleman,
   marksman, pointman — walks the AO wearing a PRC-25.
3. **NONE of the six ships a `head_frag_*` mesh.** The old rigs shipped seven. `GibSystem`
   `dismember_head_burst()` returns `false` on an empty frag list (`gib_system.gd:203-204`).
   **The exploding-head gore is silently dead on 100% of the new art**, and the test that guards
   it (`tests/test_head_burst.gd:26`) points at `us_grunt_v2`, so **the suite stays green while
   the feature is gone.**

The brief's claim that `_apply_gib_rig_contract()` "hides ONLY by prefix" is **stale**.
`model_actor.gd:298-315` already builds a `gib_gear` set from `GibSystem.REGIONS` and hides
`helmet_camo_shell` / `helmet_bugjuice`. That fix has landed. The gear-donor x1bs the brief
names is **already closed**. The two above are not.

---

## 1. MODEL RESOLUTION (as-built)

A squadmate goes from an MOS string to a rendered `.glb` through **four** hops. No registry, no
`.tres` — bare strings all the way down.

```
SquadSystem.setup()                      squad_system.gd:27-53
  └ SquadRoster.ensure_roster(seed)      squad_roster.gd:88   -> Array[Dictionary]; m.mos
  └ AllyBase.spawn_ally(world, pos)      -> _ready() -> _setup_visual()
        uses AllyBase.sprite_unit,       ally_base.gd:155     DEFAULT = "us_grunt_v3"
  └ MOS_BODY.get(mos)                    squad_system.gd:60-65  {unit, weapon}
  └ ally.set_sprite(body.unit, ...)      ally_base.gd:212-224  frees the actor, rebuilds it
        └ _setup_visual()                ally_base.gd:176-185
              └ ModelActor.model_exists(sprite_unit)   model_actor.gd:84
              └ ModelActor.setup(sprite_unit)          model_actor.gd:89
                    └ model_path(unit_id)              model_actor.gd:22-29
                         searches MODEL_DIRS in order, returns dir + unit_id + ".glb"
```

`model_path()` is a **filesystem probe**: `assets/us/characters/` then `nva_vc/` then
`civilians/`, first `ResourceLoader.exists()` wins (`model_actor.gd:13-17, 22-29`). `all_units()`
`DirAccess`-scans the same three folders (`:34-43`). **There is no manifest.** A `unit_id` is a
filename, and the only things that name one are: `squad_system.MOS_BODY`, `ally_base.sprite_unit`,
`gore_dummy.unit_id`, `insertion_ride.crew_models`, `data/enemies/*.tres` (`sprite_unit` /
`sprite_unit_fallback` — **all `vc_*`, none `us_*`**), and the test/tool probes.

Height is `ModelActor.target_height()` → `UNIT_HEIGHT_M.get(unit_id, 1.7132)` (`:51-66`), then
`_normalize_height()` rules by **skeleton rest span**, not AABB (`:113-148`). The six new GLBs are
already authored to 1.7132 by the exporter (`export_us_squad.py:26, 106-119`), so ADR-002 needs
**no new entry** and k lands ≈1.0.

### What must change

| Site | Today | Must become |
|---|---|---|
| `ally_base.gd:155` | `sprite_unit = "us_grunt_v3"` | `"us_grunt_rifleman"` |
| `squad_system.gd:60-65` `MOS_BODY` | PIGMAN→`us_grunt_m60`, GRENADIER→`us_grunt_m79`, RTO→`us_rto`, MEDIC→`us_medic`; **POINT absent** | **DELETED.** Replaced by `GruntDresser.MOS_KIT` (§3) |
| `gore_dummy.gd:15` | `unit_id = "us_grunt_v3"` | `"us_grunt_rifleman"` |
| `model_actor.gd:59` | `"us_rto": 1.7132,` | **DELETED** — it equals `TARGET_HEIGHT_M`, so it is a no-op entry; the const's own comment says a combatant "needs no entry here" (`:46-50`). Same is true of `us_pilot_white/black` at `:58`. |

The Summoner's ruling holds cleanly: **the code moves to the art.** The six exported names are
canonical and nothing needs renaming on disk.

---

## 2. THE KILL LIST + THE KEEP LIST

**The warning in my brief was correct and it saved this section.** A grep-only sweep says the old
GLBs are orphans. They are not — **five are load-bearing test fixtures**, and `all_units()`
`DirAccess`-scans the folder, so deleting a file changes what the *editor tools* enumerate.

### KEEP — DO NOT DELETE (proof, per file)

| GLB | Held alive by | Verdict |
|---|---|---|
| **`us_grunt_v2.glb`** | `tests/test_hitzones.gd:49,71,162,183,193` · `tests/test_head_burst.gd:26` · `tests/test_gore_rig.gd:26` · `tests/test_anim_library.gd:37,54` · `tests/test_seat_system.gd:67` · `scripts/tools/hitzone_editor.gd:40` | **THE REFERENCE RIG.** Five suite tests `setup("us_grunt_v2")`. It is the ONLY unit with a `head_frag_*` set that `test_head_burst` asserts ≥6 of. **Deleting it turns five tests red.** It is not a fossil — it is the fixture. |
| **`us_grunt_m14.glb`** | `tests/test_hitzones.gd:49,253` | The `_default`-tuning **inheritance case**: the test needs a unit with *no* `data/hitzones/<unit>.tres` to prove fallback (`hitzone_builder.gd:88-92`). Delete it and `test_hitzones` loses its negative case. |
| **`us_medic.glb`** | `squad_system.gd:64` (live) | **The six contain no medic.** Doc stays on his own body. Keep. |
| **`us_pilot_white/black.glb`** | `insertion_ride.gd:54` (live) | Aircrew. Untouched by this work. |
| `vc_guerilla*.glb` (6) | `data/enemies/*.tres` `sprite_unit` (live) | Enemy cast. Untouched. |
| `civ_*.glb` (10) | `ModelActor.UNIT_HEIGHT_M:52-55` + `civilian.gd` | Untouched. |

### KILL — safe to delete, **but only in the same change that lands the repoint**

| GLB | Size | Every reference, and what it is |
|---|---|---|
| **`us_grunt_v3.glb`** | 16.5 MB | `ally_base.gd:155` (**LIVE** — default ally body) · `gore_dummy.gd:15` (**LIVE**) · `tools/probe_drift_scale.gd:45`, `probe_hurtbox_size.gd:14`, `probe_worn_gear.gd:10` (dev probes). Both live sites repoint to `us_grunt_rifleman` in §1. |
| **`us_grunt_m60.glb`** | 16.4 MB | `squad_system.gd:61` (**LIVE**) · `tools/probe_anim_audit.gd:13` (dev probe). |
| **`us_grunt_m79.glb`** | 16.3 MB | `squad_system.gd:62` (**LIVE**) · `tools/probe_anim_audit.gd:13` (dev probe). |
| **`us_rto.glb`** | 13.0 MB | `squad_system.gd:63` (**LIVE**) · `model_actor.gd:59` (no-op height entry) · `tools/probe_orphaned_art.gd:15` (a *comment*, not a caller — the FOSSIL LAW's own rule 1). |

**KILL-LIST COUNT: 4 GLBs, ~62 MB.** (Not 6. `us_grunt_v2` and `us_grunt_m14` are test fixtures
and **must survive**.)

**The four are NOT safe to delete today.** They become safe the instant three things are true:
1. `ally_base.gd:155` + `gore_dummy.gd:15` point at `us_grunt_rifleman`;
2. `squad_system.MOS_BODY` is deleted and replaced by `GruntDresser.MOS_KIT`;
3. the five dev probes (`probe_drift_scale`, `probe_hurtbox_size`, `probe_worn_gear`,
   `probe_anim_audit`, `probe_orphaned_art`) are repointed at the six — they live in `tools/`,
   they are **in `test_fossils`' `REF_DIRS`** (`test_fossils.gd:9-11`), and a probe that
   `load()`s a deleted path is a crash, not a warning.

Delete the four `.glb` **and** their `.glb.import` **and** their `.uid` siblings, or the Godot
import cache resurrects a ghost entry in `all_units()`.

### The orphan this creates

`us_grunt_marksman.glb` (M70 sniper) **maps to no MOS.** `MOS_ORDER` is
`POINT, RTO, MEDIC, PIGMAN, GRENADIER` (`squad_roster.gd:7`) — there is no MARKSMAN. If it lands
unwired it is a **new orphan on day one**, which is the art-side of the same disease ADR-023 names.
Two honest doors, and this one is the **Summoner's call, not mine**:

- **(a) Add MARKSMAN as a 6th MOS.** The roster rolls 5 of 6 → genuinely different squads per
  campaign ("different arrangements everytime"). **Cost, named:** `squad_system` hard-assumes
  every MOS is present — `can_revive()` needs MEDIC (`:137`), `_point_scan()` needs POINT (`:215`),
  `_grenadier_tick()` needs GRENADIER (`:249`), `is_rto_alive()` needs RTO (`:86`). A squad that
  rolls no MEDIC **has no revive at all**. That is a systems change, not a spawner change.
- **(b) Keep 5 MOS; `us_grunt_marksman` is the alternate generic body.** `dress()` picks
  `rifleman` or `marksman` for any non-specialist from the man's own seed. Zero systems risk, art
  used, and POINT keeps his shotgun. **Cost:** the M70 is decoration — no squadmate actually
  shoots it.

I recommend **(b) now, (a) as a separate decree.**

---

## 3. THE SPAWNER

### Is the mesh-toggle approach feasible? — Measured, not guessed.

**YES, and it is already half-built.** The six GLBs carry an **identical 28-mesh superset**; the
only difference between any two files is **one weapon mesh**:

```
COMMON TO ALL SIX (28): Base_Human, canteen_worn, cap_*(9), grunt_*(8), helmet_bugjuice,
                        helmet_camo_shell, helmet_shell_worn, pouch_belt_worn,
                        prc25_antenna, prc25_handset, prc25_pack, ruck_pack_worn,
                        us_grunt_joined, webbing_worn
UNIQUE:  rifleman m16a1_world | grenadier m79_launcher_world | mg m60_mg_world
         rto m16a1_world | marksman m70sniper_world | pointman ithaca37_shotgun_world
```

So the answer splits:

- **Variation WITHIN a role = 100% visibility toggles + ONE material offset. No extra loads.**
  `GruntDresser` (`scripts/visuals/grunt_dresser.gd`) already does exactly this: a 10×7 face atlas
  slid by `uv1_offset` on the shared `grunt_face_skin` material (70 faces), 15 helmet variant GLBs
  (~200 KB each, all 15 already on disk at `assets/us/props/helmets/`), and `GEAR_TOGGLES` for
  `ruck` / `radio` / `radio_antenna` / `radio_handset` (`grunt_dresser.gd:20-44`).
  **70 faces × 15 helmets × gear = thousands of distinct men from zero new exports.**
- **Variation ACROSS roles CANNOT be a toggle** — the weapon mesh is baked per-file and the other
  five weapons are not in the file. So: **one GLB per ROLE** (≤5 distinct loads per mission, one
  per squadmate; Godot caches `PackedScene` per path so a second man of the same MOS costs nothing
  extra). That is 5 × ~11 MB, *down* from today's 5 × ~15 MB. **The spawner does not make memory
  worse; it makes it better.**

**`GruntDresser` is written, complete, and CALLED BY NOTHING.** The only hits outside its own file
are two *comments* in `gib_system.gd:50,60`. Under ADR-023 it is not a FOSSIL (nothing superseded
it) — it is **UNFINISHED: built ahead of its wiring.** The law's verdict on UNFINISHED is *wire it
or cut it.* **The spawner IS that wiring.** No new class is justified; a second class next to it
would be precisely the "two things that could be interpreted as the same thing" the Summoner
outlawed.

### Where it lives

**`scripts/visuals/grunt_dresser.gd`** — extend the existing class. **`SquadSystem.MOS_BODY` is
DELETED** (FOSSIL LAW: the replacement is not shipped until the predecessor is buried).

### The concrete API

```gdscript
## MOS -> the exported body and the weapon it was modelled holding. These names are
## the files on disk; a role with no entry wears BASE_UNIT.
const MOS_KIT: Dictionary = {
	"POINT":     {"unit": "us_grunt_pointman",  "weapon": "shotgun"},
	"RTO":       {"unit": "us_grunt_rto",       "weapon": "m16a1"},
	"MEDIC":     {"unit": "us_medic",           "weapon": "m16a1"},
	"PIGMAN":    {"unit": "us_grunt_mg",        "weapon": "m60"},
	"GRENADIER": {"unit": "us_grunt_grenadier", "weapon": "m79"},
}
const BASE_UNIT: String = "us_grunt_rifleman"
const ALT_BASE_UNIT: String = "us_grunt_marksman"

## The body + weapon for a role. Never returns an empty unit.
static func kit_for(mos: String, look_seed: int = 0) -> Dictionary:
	var kit: Dictionary = MOS_KIT.get(mos, {}) as Dictionary
	if kit.is_empty():
		var alt: bool = look_seed != 0 and (look_seed & 1) == 1
		kit = {"unit": ALT_BASE_UNIT if alt else BASE_UNIT, "weapon": "m16a1"}
	if not ModelActor.model_exists(str(kit["unit"])):
		kit = {"unit": BASE_UNIT, "weapon": str(kit["weapon"])}
	return kit


## A squadmate's look is a property of the MAN, not of the mission: it is drawn from his
## own saved seed so he is the same face under the same helmet next operation (Pillar 4).
## Enemies and unnamed spawns take dress_random() and may re-roll every mission.
static func dress_member(actor: ModelActor, member: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed_of(member)
	return dress(actor, rng, _role_opts(str(member.get("mos", ""))))


static func dress_random(actor: ModelActor, rng: RandomNumberGenerator, mos: String = "") -> Dictionary:
	return dress(actor, rng, _role_opts(mos))


## Back-fill is a pure function of the man, NOT of the caller's RNG: ensure_roster() is
## seeded from the MISSION seed, so drawing here would give a veteran a new face per op.
static func look_seed_of(member: Dictionary) -> int:
	var s: int = int(member.get("look_seed", 0))
	if s != 0:
		return s
	return hash(str(member.get("name", "")) + str(member.get("mos", "")))


## Every grunt body ships the PRC-25. Only the RTO carries one.
static func _role_opts(mos: String) -> Dictionary:
	var radio: bool = mos == "RTO"
	return {"radio": radio, "radio_antenna": radio, "radio_handset": radio}
```

**Determinism (ADR-010).** No second seed is introduced. `look_seed` is drawn **once**, at the
man's creation, from the roster RNG that is already seeded off the mission seed — add one line to
`SquadRoster.generate_member()` (`squad_roster.gd:22-33`):

```gdscript
"look_seed": rng.randi(),
```

and one to the back-fill block `ensure_roster()` already runs for exactly this purpose
(`squad_roster.gd:109-116`):

```gdscript
if not m.has("look_seed"):
	m["look_seed"] = GruntDresser.look_seed_of(m)
```

It then **persists** in `CampaignState.roster` → `save_campaign()` (ADR-007's all-or-nothing
commit; the roster dict *is* the save unit). **Stability comes from persistence, not from
re-derivation** — that is what keeps Pillar 4 true and ADR-010 clean at the same time. The province
still rebuilds bit-identical: nothing in the look touches the mission stream.

**ADR-002.** Untouched. `dress()` only sets `visible` and `uv1_offset`, and hangs a helmet variant
on a `BoneAttachment3D` positioned from the *stock* helmet's rendered transform
(`grunt_dresser.gd:122-153`). `_normalize_height()` has already run and is rig-ruled, not
AABB-ruled (`model_actor.gd:113-141`). k stays ≈1.0. Helmet variants ride the head bone, so they
scale with the man.

### Call site (`squad_system.gd:38-45`, replacing the `MOS_BODY` block)

```gdscript
var mos: String = str(m.mos)
var kit: Dictionary = GruntDresser.kit_for(mos, GruntDresser.look_seed_of(m))
ally.set_sprite(str(kit["unit"]), str(kit["weapon"]))
ally.dress_from_member()
if mos == "PIGMAN":
	ally.fire_rate_mult = 1.6
```

and in `AllyBase`:

```gdscript
## Ordering contract: HitzoneBuilder skips invisible meshes (hitzone_builder.gd:243), so
## the man must be dressed BEFORE his hurtbox is harvested or he is shot through his kit.
func dress_from_member() -> void:
	if not _visual_is_model or sprite_actor == null:
		return
	GruntDresser.dress_member(sprite_actor as ModelActor, member)
```

---

## 4. THE x1bs FIX

The brief asked for a gear-donor fix. **That fix has already landed** — `model_actor.gd:298-315`
reads the gear names off `GibSystem.REGIONS` and hides `helmet_camo_shell` + `helmet_bugjuice`.
And it does **not** break the flying-helmet shot: neither `_gear_meshes()`'s fallback branch
(`gib_system.gd:85-88`) nor `dismember_head_burst()`'s gear loop (`:234-239`) checks `visible` —
they `find_child()` by exact name and throw the mesh regardless. The donor stays hidden on the
living man and still flies off the dead one. **Nothing to do there.**

What the new art actually broke is **`Base_Human`** — a second, skinned, 402-tri body that renders
*inside* `us_grunt_joined`. Nothing hides it. Worse, `_apply_gib_rig_contract()`'s body detector
counts it as a body (`model_actor.gd:288-289`: any mesh not `grunt_*`/`head_frag_*`/`cap_*` sets
`has_body = true`), and `HitzoneBuilder` **harvests it into the hurtbox** — it is skinned
(`hitzone_builder.gd:252` skips only unskinned meshes) and its name matches no `_GEAR_NAME_HINTS`
entry (`:43-48`). So today it is a second man inside the first man, *and* it votes on where you
can be shot.

### The exact code, in `ModelActor`

Add the const beside `MODEL_DIRS`:

```gdscript
## The un-clothed base the dressed body was modelled over. It ships in the GLB because the
## rig is skinned to it; the *_joined mesh is the body that renders.
const BASE_BODY_MESH: String = "Base_Human"
```

Then, inside `_apply_gib_rig_contract()`, two surgical edits.

**(a) The base body is not a body.** In the detector loop (`model_actor.gd:279-289`), so a GLB that
ships *only* `Base_Human` and donors cannot fool the trigger:

```gdscript
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var mesh_name := String(mi.name)
		if mesh_name == BASE_BODY_MESH:
			continue
		if mesh_name.ends_with("_joined"):
			has_body = true
		elif mesh_name.begins_with("grunt_") or mesh_name.begins_with("head_frag_"):
			has_donors = true
		elif not mesh_name.begins_with("cap_"):
			has_body = true
```

**(b) Hide it with the donors.** In the hiding loop (`model_actor.gd:307-315`), extend the predicate:

```gdscript
		var is_donor: bool = (nm.begins_with("grunt_") or nm.begins_with("head_frag_")
				or nm.begins_with("cap_")) and not nm.ends_with("_joined")
		if is_donor or nm == BASE_BODY_MESH or gib_gear.has(nm):
			mi.visible = false
			hidden += 1
```

**Safe against GibSystem:** `Base_Human` appears in no `REGIONS.meshes`, no `.gear`, no `.caps`
(`gib_system.gd:17-48`), and is not a `head_frag_*`. Nothing throws it, so hiding it costs the gore
system nothing. **Safe against ADR-002:** `_normalize_height()` is skeleton-ruled and runs
*before* this (`model_actor.gd:101, 104`); visibility does not enter the ruler. **Correct for
hurtboxes:** `hitzone_builder.gd:243` skips invisible meshes, so the silhouette becomes
`us_grunt_joined` alone — which is exactly the mesh `export_us_squad.py:91` measured the man's
height over.

The **radio** is *not* a `ModelActor` concern — it is a role fact, and `GruntDresser.GEAR_TOGGLES`
already has the three switches for it (`grunt_dresser.gd:39-44`). §3's `_role_opts()` throws them.
This is why the repoint and the spawner **must land as ONE change**: repoint alone gives every man
in the squad a PRC-25.

### The regression the new art shipped, and the test that will not catch it

`dismember_head_burst()` needs `head_frag_*` (`gib_system.gd:196-204`). **The six have none.**
`export_us_squad.py:32-33` selects `o.name.endswith("_" + tag)` — the lineup's head-frag meshes
were never given the per-man suffix, so the exporter's own filter dropped all seven, silently.
The head-burst probe points at `us_grunt_v2` (`test_head_burst.gd:26`), which still has them, so
**the suite is green and the feature is gone.** Two things are owed:

1. Blender-side: the frags must ride the per-man copies (Summoner's work, or a fix to the lineup).
2. Code-side: `tests/test_head_burst.gd` must assert against the **live** squad bodies, not the
   retired reference rig. A test aimed at a fixture nobody spawns is the same lie the FOSSIL LAW
   was written about.

### One more, found in passing

`AllyBase.set_sprite()` rebuilds the `ModelActor` (`ally_base.gd:212-224`) but **never rebuilds the
hurtbox** — `_setup_hurtbox()` runs only in `_ready()` (`:170-171`). So every specialist wears the
*default* body's hulls (`HitzoneBuilder` caches hulls per unit, `hitzone_builder.gd:52,268`).
Harmless among the six (they share one body mesh) — **not** harmless for `us_medic`, whose 51-mesh
kit is different. Pre-existing; flagging it, not fixing it here.

---

## 5. SACRIFICES (no free lunches)

- **`us_grunt_v2` and `us_grunt_m14` survive the purge.** 33 MB of retired art stays on disk
  because the test suite is built on it. That is a fossil-shaped thing the FOSSIL LAW *permits* —
  a fixture has a caller — but it is a debt, and the honest close is to re-point the five tests at
  `us_grunt_rifleman` and *then* kill both. That is a bigger change than this one and it should be
  its own bead. **I chose the smaller, safer kill list. Name the debt.**
- **POINT gets a shotgun** (the pointman GLB carries `ithaca37_shotgun_world`; `data/weapons/shotgun.tres`
  exists). ART IS TRUTH — but this is a **balance change smuggled in on an art change**, and I am
  naming it rather than letting it ride. The point man's engagement range drops hard. If the
  Summoner wants POINT on an M16, the kit says `m16a1` and the shotgun in his hands becomes a prop
  he never fires (the weapon mesh is cosmetic; `weapon_data` is what shoots).
- **`us_grunt_marksman` is decoration under recommendation (b).** Real art, no mechanical role.
- **The 15 helmet variants are 15 extra `PackedScene` loads** the moment a squad is dressed
  (~200 KB each, cached). Trivial, but it is not zero, and it is new per-mission allocation.
- **`m16a1_world` is 5,032 tris** — an order of magnitude more than the 434-tri body it is strapped
  to. Not my charge; the perf bead should know.
- **Hiding `Base_Human` will move every US hurtbox slightly** (its hull leaves the union). The
  hulls get *tighter*, and they get *correct* — but any hitzone tuning eyeballed against the
  current build is now measuring a different man. `data/hitzones/` is **empty**, so nothing is
  tuned yet and nothing breaks. It will not be free later.
