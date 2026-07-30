# SYSTEMS ARCHITECT — the occupiable, destructible firebase

**Convened** 2026-07-30. Scope: the Summoner's items (a) bunkers along the sandbag walls you can
occupy and shoot out of, (b) bunkers destructible, (c) watchtowers blown up and collapsed, "same
with all our buildings". Read as ONE system: a **claimable post attached to a breakable structure**.

Every claim below carries a `file:line`. Where the briefing and the code disagree, the code wins and
I say so. Godot was not launched; Blender was not opened.

---

## 0. FIVE THINGS THE CODE SAYS THAT THE BRIEFING DOES NOT

1. **`MortarPit`'s occupancy API HAS NO CALLERS.** The briefing (`briefing.md:83`) offers
   `MortarPit.claim/release` as the existing mechanism. It exists (`scripts/world/mortar_pit.gd:49,58`)
   and **nothing in the repo calls it.** Repo-wide, the only hits for `MortarPit` outside its own file
   are `mission_generator.gd:796` (`MortarPit.create`). `claim`, `release`, `is_free`,
   `free_stations`, `station_position` — **zero external callers.** Under ADR-023 triage that is
   **UNFINISHED, not live**: built ahead of its wiring. It must be wired or cut, and it is the natural
   thing for the new contract to eat.
2. **`Destructible.is_destroyed()` also has no callers.** `scripts/world/destructible.gd:52`, added
   2026-07-30, is read by nothing (`grep is_destroyed(` → the definition only). Its own doc-comment
   says "nothing outside this class could otherwise ask" — correct, and nothing asks. It is the exact
   accessor the occupant problem needs, so it goes live in this change or it is a fresh fossil.
3. **DESTRUCTION IS INVISIBLE TO EVERY EXISTING SELF-HEAL.** `_do_destroy` does **not free the node**
   — it hides meshes and disables shapes (`destructible.gd:70-74`). But every occupancy self-heal in
   the game tests `is_instance_valid()`:
   - `MGEmplacement._physics_process` (`mg_emplacement.gd:83-90`)
   - `Player._tick_mg_manning` (`player.gd:1126`)

   A destroyed structure stays `is_instance_valid() == true` forever, so **both checks pass and
   nobody is ever released or ejected.** This is the occupant bug in one sentence, and it is already
   latent: the moment an MG post rides the blast bus, the player is glued to a dead gun with his own
   `CollisionShape3D` disabled (`player.gd:1080-1082`) — a hard soft-lock, no collider, no ground.
4. **`MGEmplacement` is currently INDESTRUCTIBLE and cannot be blown up at all.** It has no
   `take_damage`, and nothing registers it: `mg_emplacement.gd:47-51` sets `collision_layer = 1` and
   joins `mg_emplacements` / `nav_source`, with **no `AgentRegistry.register`**. The only things on
   the props blast bus in the shipped world are the 80 parapet segments
   (`site_planner.gd:1308`) and the claymores. So "bunkers need to be destructible" is not a tuning
   change — the geometry is not on the bus yet.
5. **`FellableTree` is a SECOND destructible authority.** It carries its own `take_damage` and its own
   HP (`scripts/world/fellable_tree.gd:64-70`) beside `Destructible.take_damage`
   (`destructible.gd:28`), while ADR-031 §6 says "the general `Destructible` is the ONE destructible
   component". It also already implements the exact hinge-fall-then-swap that item (c) asks for
   (`fellable_tree.gd:95-137`). Two authorities, one of which owns the feature the other needs: that
   is the fossil law's failure mode, and it is the lever for collision 2 below.

---

## COLLISION 1 — SHOOTING OUT OF A BUNKER vs COLLISION

### What is already true

The generator is **already correct at source, and the shipped GLB is not.**

- `tools/gen_firebase_v3.py:844-856` lists `fb_bunker_mg`, `fb_bunker_fighting`,
  `fb_sleeping_bunker`, `fb_tower`, `fb_gun_pit`, `fb_mortar_pit`, `fb_sbg_seg_` on `COL_TRIMESH`.
  `make_collision()` (`:871-873`) gives those a `-colonly` twin **sharing the visual mesh data**;
  everything else gets an axis-aligned box (`:874-891`) that "fills every opening in the mesh it
  wraps — it would seal the bunkers shut and brick up every firing slit" (`:832-835`, the generator's
  own words).
- The embrasure geometry itself already exists in the kit: `tools/gen_firebase.py:292-314` builds the
  MG bunker **sunk 0.9 m so the firing slit sits at grade**, with `slit_w=2.5, slit_z=0.42`, a timber
  lintel over it, and two baked markers — `mg_fire_point` and `bunker_los_point`. The fighting bunker
  is the same at `slit_w=1.6, slit_z=0.45` (`:324-328`). `gen_firebase_v3.py:724` re-emits
  `mg_fire_point_001` into world space. **The slit was authored, with a LOS marker, from the start.**

### The live defect

`site_planner._repair_glb_colliders` only repairs two prefixes:
`REMESH_COLLIDER_PREFIXES = ["fb_veg_", "fb_sbg_seg_"]` (`site_planner.gd:1103`). **`fb_bunker_*` and
`fb_tower` are NOT in that list.** The runtime repair exists precisely because the shipped GLB
predates the `COL_TRIMESH` additions (`:1098-1102`: "gen_firebase_v3.py now lists fb_sbg_seg_ as
trimesh, but that only lands on a re-export"). Therefore, **as the game boots today, every bunker and
every tower is a box hull — sealed slits, and a tower is a solid 6 m block you cannot get inside.**
The briefing frames the box hull as a hazard to avoid; the code says it is the current state.

### RULING 1

**No new collision mechanism. Three exact acts, in this order:**

**1a. Add the two prefixes to the existing repair list — today, no re-export needed.**
`REMESH_COLLIDER_PREFIXES` becomes `["fb_veg_", "fb_sbg_seg_", "fb_bunker_", "fb_tower"]`.
`_remesh_collider` (`site_planner.gd:1160-1169`) already strips the export ordinal and calls
`mi.create_trimesh_collision()`, which is exactly the shape the `-colonly` twin would have been. This
un-bricks every slit in the shipped GLB in a one-line change, and the file's own comment at `:1101-1102`
already promises these counts go to 0 and the block deletes when the re-export lands — **so honour
that: the day the re-export ships, this whole `_repair_glb_colliders` branch is deleted (ADR-023).**

**1b. On the re-export, author a low-poly `-colonly` PROXY per bunker, not the render mesh.**
`make_collision()` currently *shares the visual mesh datablock* for trimesh entries
(`gen_firebase_v3.py:872`). For 9-course sandbag geometry that is thousands of collision triangles
per bunker, and the generator already names the mitigation: "the answer is NOT to go back to boxes;
it is to author a low-poly `-colonly` PROXY per segment with the slit cut into it" (`:841-843`). The
proxy is 5 boxes welded — floor, two cheeks, lintel, rear — with the aperture as an actual hole. It
must be a **separate object whose name ends `-colonly`**, and `make_collision()` needs one extra
branch: if a hand-authored `<base>-colproxy` object exists, emit *that* as the twin instead of the
render mesh. Mind the naming trap already documented at `:807-810`: number BEFORE the suffix.

**1c. The occupant's eye must be pinned AT the aperture, not merely inside the room.**
This is the part that would otherwise ship broken. Bullets and AI sight are both **plain world-layer
rays** — `bullet_system.gd:110` steps `intersect_ray` with the round's mask, and enemy target
resolution fires `1|2|4|32|64` (`enemy_base.gd:1990-1994`) while cover search uses `1|32`
(`enemy_base.gd:1791-1792,1814-1815`). So geometry alone is symmetric and **no layer trickery is
needed or wanted**: cut the hole and the player's rounds leave, enemy rounds come in, and enemy LOS
sees through it — all three for free. **But** those AI rays go eye→chest from wherever the man
happens to stand. A garrison rifleman parked 1.5 m behind a 1.6 m-wide slit has no LOS to anything
and will never acquire; he will read as an idiot standing in a dark box. The fix is the existing
`MGEmplacement` pattern: pin him to an authored station whose eye sits **in** the aperture, with
`post_anchor` + a short `post_leash` (`mg_emplacement.gd:157-162`). `bunker_los_point`
(`gen_firebase.py:314`) is already that marker and is currently consumed by nothing.

### Physics layers involved (`project.godot:293-300`; CLAUDE.md:168-179)

| Layer | bit | Role in this feature |
|---|---|---|
| 1 `world` | 1 | The bunker's trimesh. THE ONLY layer that stops a round. `MGEmplacement` sets exactly this (`mg_emplacement.gd:47`), and so must every bunker/tower Destructible (`site_planner.gd:1289-1290` sets `collision_layer = 1, collision_mask = 0` on the parapet segments — copy it verbatim). |
| 2 `player` | 2 | Player **and allies and civilians**: `ally_base.gd:1458`, `civilian.gd:166` both set `collision_layer = 2`. |
| 3 `enemies` | 4 | `enemy_base.gd:2581`. |
| 6/7 hurtboxes | 32/64 | `Hitzone` areas. A `Destructible` has **no Hitzone** (`destructible.gd:27`) — by design: rifle fire is *blocked*, only explosions damage it. Keep that. |
| 9 `projectiles` | 256 | Not used by the bunker. |

**Nothing new goes on layer 9, and no bullet gets a special mask.** The single hardest thing to
resist here is a "shoot-through window volume" — an Area3D that lets rounds pass. It is not needed
(the hole is real), it would need to be one-way to be interesting, and one-way ballistics is a lie the
physics tells, which is the same bug class `collision_table.gd:184-200` was written to kill.

### SACRIFICE (1)
Trimesh collision on ~4 bunkers + 4 towers + 80 parapet segments on a **call-bound** project
(`PERF_LEDGER.md`) — collision triangles are physics-server memory and broadphase cost, not draw
calls, so the frame should not move, but the *load-time* `create_trimesh_collision()` at boot is a
main-thread cost paid per boot until the re-export lands. Second sacrifice: a real aperture means the
player can be **shot through it**, which is correct (Pillar 1) but removes the bunker as a safe box.
Third: the man on the gun is pinned to a station, so occupying a bunker is not free movement inside
it — you take a post, you do not roam.

---

## COLLISION 2 — "COLLAPSED" vs ADR-031

ADR-031:12 is unambiguous: state-based, never a physics fracture. ADR-001 forbids fracture. A
watchtower is ~6 m (`collision_table.gd:42` gives `observation_tower` a 3×8×3 hull) and its
silhouette against the sky is most of its value.

### RULING 2 — "collapsed" means a SCRIPTED HINGE ON THE MESH THAT IS ALREADY THERE, and the code that does it already exists

**This is not a new capability. `FellableTree` already does exactly this**
(`fellable_tree.gd:95-107`): hinge the visual at the node origin, ease-in to ~90° over
`FALL_TIME = 2.0`, then `_settle()` swaps in the permanent log and its capsule
(`:109-137`). ADR-031's build state calls it "scripted hinge, permanent log". A tower topple is the
same operation with a different mesh and a shorter time.

So the ruling is a **fold, not a build (ADR-023):** the hinge moves INTO `Destructible` as an
optional topple, and `FellableTree`'s duplicate `take_damage`/HP is deleted, leaving it as a
`Destructible` configured with `topple_time` and a `destroyed_mesh`. That resolves finding §0.5 in the
same change instead of adding a third faller.

**Is a two-stage (leaning → down) swap affordable? YES, and it costs no draw calls.**
The intact mesh already exists as a `MeshInstance3D` child. Rotating it is a transform write per
frame on an object that is already being drawn — **zero new draw calls, zero new material, zero new
instance**, which is the only budget that matters here (tri budgets are style, not perf — measured).
The throttle is untouched: `WorldConfig.STRUCTURE_LEVELS_PER_FRAME = 2`
(`scripts/levels/world_config.gd:47`), drained by `Destructible.drain()` from
`DamageSystem._process` (`terrain/systems/damage_system.gd:179`).

**Exact cost accounting.** A topple must NOT consume two queue slots. `drain()` pops the node and
calls `_do_destroy()` once (`destructible.gd:41-47`); the topple then runs on the popped node's own
`_physics_process` for ~1.2 s and is *off* the queue while it leans. So a napalm run over four towers
still costs **2 swaps/frame → 2 frames to start all four**, exactly as today, plus at most N
concurrent transform tweens. At `STRUCTURE_LEVELS_PER_FRAME = 2`, the whole 80-segment parapet takes
40 frames (~0.67 s at 60 fps, ~2 s on the Intel-UHD floor at 20 fps) to level — that is the existing,
already-accepted cost and the topple does not change it. **Do not raise the throttle for towers.**

**What sells a collapse without simulating one** (ordered by value per unit of cost):
1. **The silhouette leaves the skyline.** Nothing else reads at 200 m. The hinge is the whole trick.
2. **The occluding burst, already built**: `GunFX.play_explosion_3d` is already called by
   `_do_destroy` (`destructible.gd:84`) — fire it BEFORE the hinge starts, at the tower's *base*, not
   at `global_position`, so the dust column hides the pivot cheat.
3. **A dust cloud at the impact line as it lands** — reuse the same explosion visual, no new FX.
4. **Sound**: `NoiseBus.emit_noise(EXPLOSION)` already fires (`destructible.gd:85`); a timber-crash
   one-shot at settle. Audio does the structural work the geometry is not doing.
5. **Permanence** (ADR-031 §4): the authored rubble stays. A collapsed tower is a map landmark for the
   rest of the operation, and this is where the atmosphere pillar actually gets paid.
6. **Screen shake, distance-scaled** — ADR-031:16 already names it.

**The stages, precisely.** Two states, not three: `intact --(hinge 1.2s)--> down`. A separate
"leaning/damaged" *resting* state is a third authored mesh per structure and a third silhouette to
model, for a state the player sees for one second. **Cut it.** The lean is the *transition*, not a
state. `Destructible.hp` stays a single threshold; a damaged tier is deferred and named as such.

### SACRIFICE (2)
The hinge is a lie that reads from outside and not from underneath: a man standing next to the base
will see the tower's legs rotate through the dirt. Mitigation is the dust column, not geometry. We
also lose per-hit damage tiers (no scarred-but-standing tower) and we accept that a toppling tower's
**collider is gone the instant the hinge starts** — it cannot be leaned on, walked through, or
crushed-under, because the mesh doing the leaning is decoupled from physics. And an authored rubble
mesh per structure family is real Blender time the Summoner has to pay (towers, MG bunker, fighting
bunker, sleeping bunker, hootch, tent = 6 rubble meshes minimum), or they all fall back to the shared
box-rubble MultiMesh (`destructible.gd:104-122`), which will read as generic.

---

## COLLISION 3 — THE OCCUPANT PROBLEM

### Verified

- `grep -i "occupant\|claim\|release" scripts/world/destructible.gd` → **zero hits.** Confirmed.
- `_do_destroy` hides meshes and disables shapes and **does not free the node**
  (`destructible.gd:69-74`). See §0.3: every existing self-heal tests `is_instance_valid` and so
  cannot see destruction.

### The four questions, answered

**(i) The man inside.** He dies. Not ejected — *killed*. A 250-damage RPG-7 or a 150 M79 HE
(CLAUDE.md:188-192) into a 3 m timber-and-earth box kills everyone in it, and "ejected unharmed from
a structure that was just destroyed" is a fail-state cheat the fail-forward pillar does not ask for.
Exception: **a man is ejected, not killed, if he was merely STANDING ON the structure** (tower deck) —
he falls, and the fall does what falls do. Two outcomes, one rule: *inside/on-station → dead; on-top →
dropped.*

**(ii) The station.** Released in the same call, before the mesh hides. Non-negotiable: a claimed post
held by a corpse is invisible — `_nearest_free_emplacement` (`garrison_defender.gd:126-139`) skips
occupied posts silently, so the next stand-to just quietly produces one fewer gunner and nothing logs.

**(iii) The player.** This is the worst case and it is already live-adjacent. On the gun the player's
`CollisionShape3D` is **disabled** (`player.gd:1080-1082`) and his position is *written every frame*
to a cached `_mg_stand_pos` (`player.gd:1130`). `_tick_mg_manning`'s eject test is
`_mg_emplacement == null or not is_instance_valid(...)` (`:1126`) — which destruction never trips.
Result today, if an MG post were on the blast bus: **the player is frozen at a dead gun with no
collider, forever, with no input that frees him except [F]** (which does work — `:1132` — so it is
a soft-lock only in the sense that the world is destroyed around him and he is unharmed and pinned).
That is unshippable, and the fix must be in the *eviction* path, not in `player.gd`, because
`dismount_mg` already does the right thing correctly (`:1103-1119`: unmount gun, re-enable collider,
move to `dismount_position()`, release the post).

**(iv) The man standing on a tower.** He falls. `_do_destroy` disables the shapes
(`destructible.gd:74`), so the deck vanishes under him. For the **player** this is fine and even good
— fall damage from 6 m. For an **AI**, it is not fine: `AllyBase`/`EnemyBase` have
`collision_mask = 1` (`ally_base.gd:1459`, `enemy_base.gd:2582`), so they will fall to the ground and
land, but they are NavigationAgent-driven and their `post_anchor` still points at a station 6 m in the
air (`ally_base.gd`'s post leash) — the man will spend the rest of the mission trying to walk back up
to a deck that no longer exists. **The post_anchor must be cleared by the same eviction.**

### THE CONTRACT — ONE class, ONE hook, and TWO deletions

```gdscript
class_name Post
extends Node3D

## ONE claimable station on ONE structure. The single occupancy authority for
## bunkers, towers, MG mounts and mortar pits. A Post is a CHILD of the thing it
## belongs to, so destroying the parent finds every Post under it by descent -
## there is no registry to keep in sync.

enum Kind { FIRE, CREW, WATCH, REST }
enum Evict { DESTROYED, DISMOUNT, DEATH }

signal claimed(body: Node3D)
signal vacated(body: Node3D, cause: Evict)

@export var kind: Post.Kind = Post.Kind.FIRE
@export var face_local: Vector3 = Vector3.FORWARD   ## downrange in Post-local space
@export var lethal_on_destroy: bool = true          ## false for a rooftop/deck post

var occupant: Node3D = null

static func build_from_markers(root: Node3D, prefix: String, kind: Post.Kind) -> int
static func find_free(near: Vector3, kind: Post.Kind, max_dist: float, tree: SceneTree) -> Post
static func evict_all_under(host: Node, cause: Post.Evict) -> int

func is_free() -> bool
func claim(body: Node3D) -> bool
func vacate(cause: Post.Evict) -> void
func eye_position() -> Vector3
func face_dir() -> Vector3
func is_alive() -> bool          ## occupant valid, not dead, and the host not destroyed
```

`Destructible` gains **exactly one line** in `_do_destroy`, placed before the meshes hide:

```gdscript
func _do_destroy() -> void:
	if _dead:
		return
	_dead = true
	Post.evict_all_under(self, Post.Evict.DESTROYED)
	...
```

`Post.evict_all_under` descends the host, calls `vacate(DESTROYED)` on each Post, and `vacate`
does the three things nobody is doing today:

```gdscript
func vacate(cause: Post.Evict) -> void:
	var body: Node3D = occupant
	occupant = null
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("dismount_mg"):
		body.call("dismount_mg")            # the player's own restore path, unchanged
	if "post_anchor" in body:
		body.set("post_anchor", Vector3.ZERO)
	if cause == Post.Evict.DESTROYED and lethal_on_destroy and body.has_method("take_damage"):
		body.call("take_damage", 999, 0, null, "TORSO")
	vacated.emit(body, cause)
```

Note the ordering: **`dismount_mg()` FIRST, then the kill.** The dismount restores his collider and
weapon (`player.gd:1109-1113`); killing a man whose collider is disabled is how you get a corpse with
no physics. And `999` with zone `"TORSO"` rather than `"HEAD"` because the headshot law
(`zone_name_is_fatal`) is a separate authority and this is a blast, not a shot.

The **deck** case (iv) is the same call with `lethal_on_destroy = false`: he is released, his anchor
cleared, and gravity handles the rest. For a man **not** on a Post but merely standing on the deck,
the collider disappearing already drops him — that is correct behaviour and needs no code. What it
needs is that his `post_anchor` is cleared, which is why tower deck posts must be real Posts.

**And the missing accessor goes live.** `Post.is_alive()` calls
`Destructible.is_destroyed()` (`destructible.gd:52`) on the host, which is what turns that
zero-caller function from a fresh fossil into the load-bearing check that
`MGEmplacement._physics_process` and `Player._tick_mg_manning` should have been making all along.
Both of those self-heals become `if not _post.is_alive(): vacate(...)`.

### WHAT THIS DELETES (ADR-023 — the price of admission)

| Deleted | Why |
|---|---|
| `MortarPit._occupants`, `claim`, `release`, `is_free`, `free_stations`, `station_position` (`mortar_pit.gd:16-68`) | Second occupancy implementation, **zero callers** (§0.1). The pit's three `STATIONS` become three `Post` children of the `mortar_pit.tscn`, `kind = CREW`. `MortarPit` keeps only geometry + `create()`. |
| `MGEmplacement.occupant`, `_occupant_is_ai`, `_clear_occupant`, `is_occupied`, `_physics_process` (`mg_emplacement.gd:29-31,81-96,171-173`) | Third occupancy implementation with its own self-heal that cannot see destruction. The `GunnerStand` marker becomes a `Post`, `kind = FIRE`. `man_by_player` / `man_by_ai` stay — they are the *mount* behaviour, not the occupancy bookkeeping — but they gate on `_post.is_free()`. |
| `FellableTree.take_damage` + its private `hp` (`fellable_tree.gd:64-70`) | Second damage authority, against ADR-031 §6. The hinge (`:95-107`) moves into `Destructible` as `topple_time`; the tree becomes a configured `Destructible`. |
| `site_planner.REMESH_COLLIDER_PREFIXES` + `_repair_glb_colliders`' remesh branch + `_remesh_collider` (`site_planner.gd:1101-1103,1131-1142,1160-1169`) | **On the day the re-export lands**, not before. The file already promises this at `:1101-1102`; honour it or it becomes the fossil that hides the fact that the GLB is finally correct. |

**Net: one occupancy concept replacing three, and one destruction authority replacing two.** The
symbol count goes DOWN, which is the only honest test of an ADR-023-compliant change.

### SACRIFICE (3)
Touching `MGEmplacement` and `MortarPit` in the same change as bunker destruction means the MG mount —
the top deferred feature per the 2026-07-29 memory — gets refactored under it, and its probe
(`ai_stress_arena.gd:1459-1473`, the `[MG-PROBE]`) must be re-verified by the Summoner because
`is_occupied()` disappears from the public surface. Second: occupancy becomes a **node** rather than a
dictionary, so 4 bunkers × 2 posts + 4 towers + 1 mortar pit × 3 + N MG mounts ≈ 20 extra Node3Ds in
the firebase — negligible, but they are `_physics_process`-free by construction and must **stay** that
way; if anyone gives `Post` a per-frame tick, this becomes 20 ticks for nothing. Third: `lethal_on_destroy`
means a garrison man in a bunker that eats an RPG is simply *gone* — no wounded, no drag-out, so the
enemy-medic ruling and the medic RESCUE order never fire for bunker casualties. That is a real loss of
drama and it is the price of not simulating a collapse.

---

## SEQUENCE (smallest first slice that visibly pays off)

1. **`REMESH_COLLIDER_PREFIXES += ["fb_bunker_", "fb_tower"]`** — one line, code-only, un-bricks
   every slit and hollows the towers in the shipped GLB. **This is the slice.** He can walk into a
   bunker and shoot out of it the same session, with no Blender time and no new system.
2. **`Post`** + the one line in `_do_destroy` + fold the three occupancy impls. Code-only.
3. **Wire bunkers and towers onto the blast bus** by copying `_wire_parapet_destructibles`
   (`site_planner.gd:1269-1314`) — it already adopts a GLB mesh, steals its collider, registers on
   `AgentRegistry.props` and groups it. Extend `firebase_v3_destructibles.json` (today: 80 segments,
   all `kind: sandbag_wall`, `hp: 140` — verified by reading the file) with bunker and tower entries.
   **Reuse the loop; do not write a second one.**
4. **The topple**, folding `FellableTree`'s hinge into `Destructible`.
5. **HIS Blender time, and only here:** the low-poly `-colonly` proxies with the aperture cut
   (E3), the fighting step for the 2.39 m parapet against a 1.6 m eye (E4), and the authored rubble
   meshes. Everything above 1–4 ships without him.

## THE BIGGEST RISK

Not perf. It is that **destruction is not a validity change**, and the entire codebase's convention
for "is my thing still there" is `is_instance_valid()`. There are at least two such checks today
(`mg_emplacement.gd:83-90`, `player.gd:1126`) and `siren_tower.gd:149` already had to work around it
by testing `.visible` instead — an audio node reading a *mesh's visibility* to infer that its tower
was destroyed. That workaround is a warning shot: as more systems attach to structures, each one will
invent its own way to guess. `Destructible.is_destroyed()` exists and is called by nothing; if this
change does not make it THE answer and delete the guesses, the next three features will each ship
their own.
