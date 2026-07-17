# THE TECHNICAL ARTIST — PROJECT DRIFT
**Domain:** the art pipeline, Blender → glTF → Godot.
**Method:** every number below was measured. I parsed the shipped `.glb` binaries directly
(glTF node graph, accessors, skins) and I opened `us_base_v3.blend` **read-only** in Blender 5.0
headless. Nothing here is inferred from a document. Where I could not measure, I say so.

---

## 0 · THE HEADLINE, BEFORE ANYTHING ELSE

> ### `us_grunt_v2.blend` — the file `.gitignore` and `make_base_v3.py` both call THE TRUTH SOURCE — **does not exist.**
>
> It is not on disk (`find` → nothing). It is not in `HEAD` (`git ls-tree` → 0 hits).
> It was deleted by commit **`53c903d`** *("cleanup: remove dead sprite_frames + stale US lineage blends")*
> from `art_source/characters/base_psx/us_grunt_v2.blend`.
> It survives as exactly **one thing**: git blob **`4ac7b7c`**, 94,079,010 bytes, reachable only
> through the 4.8 GB `.git` history.

Read that against the `.gitignore` comment, which is still live at lines 31–35:

```
# us_base_v3.blend is a pure function of us_grunt_v2.blend + tools/make_base_v3.py.
```

**The function has no input.** `tools/make_base_v3.py:37` opens
`assets\us\characters\us_grunt_v2.blend`, a path that has never existed and now never can.
Run it today and it dies on line 145 before it does anything.

So the sentence the repo uses to justify *deleting* `us_base_v3.blend` is **false**, and the
cheapest fix for the P0 push-blocker — *"the .git is 4.8 GB, run BFG / filter-repo, drop the big
blobs"* — is precisely the operation that **destroys blob `4ac7b7c` forever.**

That is the unforgivable loss, and the repo is currently *inviting* it.

---

## 1 · MEASURED STATE OF THE US GRUNT

Seven US character `.glb` files ship under `assets/us/characters/`. All seven, measured:

| unit | tris | rig | rest-span (skeleton) | body mesh | worn gear | back payload | gun (tris) |
|---|---|---|---|---|---|---|---|
| `us_grunt_v2` | **5,376** | 41 joints | 1.6858 m | `us_grunt_joined` **842** (gear WELDED IN) | — none — | — | m16 **2,400** |
| `us_grunt_v3` | **5,376** | 41 joints | 1.6858 m | `us_grunt_joined` **434** (gear cut out) | helmet 300 · bando 48 · ruck 48 · pouch 12 | ruck_pack_worn | m16 **2,400** |
| `us_grunt_m60` | 3,988 | 41 | 1.6858 | 842 (welded) | — | — | m60 1,012 |
| `us_grunt_m79` | 3,308 | 41 | 1.6858 | 842 (welded) | — | — | m79 332 |
| `us_grunt_m14` | ~5.3k | 41 | 1.6858 | 842 (welded) | — | — | m14 |
| `us_rto` | **5,720** | 41 | 1.6858 | 434 | helmet 300 · bando 48 · pouch 12 | **prc25** 392 (no ruck) | m16 **2,400** |
| `us_medic` | **5,644** | 41 | 1.6858 | 434 | helmet 300 · bando 48 · ruck 48 | **satchel** 268 | m16 **2,400** |

**v2 → v3 is an exact, verifiable cut.** `842 − 434 = 408`, and
`helmet_shell_worn 300 + bandolier_worn 48 + ruck_pack_worn 48 + pouch_belt_worn 12 = 408`.
`make_base_v3.py` did exactly what it says. That much of the doc is true.

### Height vs the 1.7132 m contract (ADR-002)

| model | skeleton rest-span | mesh AABB (what `_aabb_of` sees) | predicted `gib_scale` |
|---|---|---|---|
| `us_grunt_v2` / `v3` / `m60` / `m79` | 1.6858 m | **3.4082 m** | **0.495** |
| `us_rto` | 1.6858 m | **4.0175 m** | **0.420** |
| `us_medic` | 1.6858 m | **1.8812 m** | **0.896** |

The **height contract is honoured** — `ModelActor._normalize_height()` rules off the *skeleton*
(`mixamorig_HeadTop_End` → `LeftToeBase`), and that span is **1.6858 m on all seven**, dead uniform.
`k = 1.7132 / 1.6858 = 1.016`. Every US soldier stands correct. ADR-002 is not violated.
(`MODEL_SESSION_HANDOFF.md`'s "2.69–2.73 m" was measuring the whole-scene AABB, not the man.)

**But `gib_scale` is broken, and it is broken by the same root cause as x1bs.** `gib_scale` divides the
rest-span by `_aabb_of()`, and `_aabb_of()` merges **every** MeshInstance3D — including junk:

- `head_frag_01..07` sit at world **Y = −1.60 m** (a metre and a half *below the floor*),
- `helmet_camo_shell` reaches **Y = +1.787 m** (above the 1.713 helmet top),
- `prc25_antenna` is a 1.07 m whip.

So the "man" measures 3.41 m (grunt), 4.02 m (RTO), 1.88 m (medic).
**Gibs popped off an RTO spawn 2.1× smaller than gibs popped off a medic.** Same rig. Same body.

> ⚠ **Measured in the glTF file, not at runtime.** Godot is not installed on this box — I could not
> execute `_aabb_of()` to confirm the runtime numbers. The *inputs* to the bug (junk node positions)
> are hard-measured; the *output* needs `tools/probe_rig_compare.gd` or a headless run to close.
> I am not claiming it as verified. **It needs a probe.**

---

## 2 · THE DONOR CONTRACT

### 2a · What is actually double-rendering — measured, per mesh

`ModelActor._apply_gib_rig_contract()` (model_actor.gd:296) hides by name prefix:
`grunt_*`, `head_frag_*`, `cap_*`. Everything else renders. Here is what "everything else" contains,
with world-space bbox centres out of `us_grunt_v3.glb`:

| live worn piece | centre (x,y,z) | **the copy sitting on top of it** | centre (x,y,z) | **gap** |
|---|---|---|---|---|
| `helmet_shell_worn` (300 t) | (0.002, **1.648**, 0.070) | `helmet_camo_shell` (276 t) | (−0.009, **1.628**, 0.061) | **20 mm** |
| `ruck_pack_worn` (48 t) | (0.000, **1.320**, −0.133) | `ruck_bag` (108 t) + rails/crossbar (36 t) | (0.000, **1.306**, −0.133) | **14 mm** |
| `bandolier_worn` (48 t) | (0.000, **1.166**, **0.133**) | `bandolier` (108 t) | (0.000, **1.166**, **0.127**) | **6 mm** |

Two helmets. Two rucks. Two bandoliers — **6 mm apart, identical Y centre.** At 100 m in a PSX
depth buffer that is not "close", that is *the same surface*, and it shimmers. **x1bs is real and
this is its arithmetic.**

**Total dead geometry rendering on every US grunt:**
`helmet_camo_shell 276 + helmet_bugjuice 24 + bandolier 108 + bando_mag0..2 324 + ruck_bag 108 + ruck_rail_l/r 24 + ruck_crossbar 12` = **876 triangles**.
Rendered tris after ModelActor hides the prefixed donors = 4,658.
**876 / 4,658 = 18.8 % of every US soldier the player sees is a duplicate z-fighting with the real thing.**

### 2b · Two things the briefing got wrong, and they change the answer

**(i) The bug is older than v3.** `us_grunt_v2.glb` ships `helmet_camo_shell`, `ruck_bag`,
`ruck_rail_l/r`, `ruck_crossbar`, `bandolier`, `bando_mag0..2` **visible**, on top of a body
(`us_grunt_joined`, 842 t) that has the gear **welded into it**. v2 double-renders too. Every US
grunt has worn two helmets since the day v2 shipped.

**(ii) Most of these aren't donors at all.** `GibSystem.REGIONS` (gib_system.gd:22–53) consumes
exactly these mesh names:

```
meshes: grunt_head, grunt_forearm_l/r, grunt_leg_l/r
gear:   helmet_camo_shell, helmet_bugjuice        <- HEAD only. That is the entire gear list.
caps:   cap_head, cap_forearm_l/r, cap_leg_l/r
```

`bandolier`, `ruck_bag`, `ruck_rail_l`, `ruck_rail_r`, `ruck_crossbar` are **named in no region,
spawned by nothing, and hidden by nothing.** They are not gib donors. They are **orphans** — 264
triangles of pure z-fight garbage with no consumer anywhere in the codebase.
(`grunt_torso`, `grunt_uparm_l/r`, `cap_torso`, `cap_uparm_l/r` are likewise unconsumed — but they
*are* prefixed, so they hide. Harmless dead weight, 176 t.)

### 2c · THE SIGNAL ALREADY EXISTS, AND OUR OWN EXPORTER DELETES IT

This is the finding that decides the contract. I read every hide flag on all 74 base-rig objects in
`us_base_v3.blend`. **The eye icon (`hide_get()`) separates donor from live with 100 % accuracy,
zero exceptions:**

| `hide_get()` | objects |
|---|---|
| **True — hidden** | `grunt_*` (8) · `cap_*` (8) · `splay_*` (8) · `helmet_camo_shell` · `helmet_bugjuice` · `ruck_bag` · `ruck_crossbar` · `ruck_rail_l/r` · `Base_Human` · `canteen_l.001` · all `_GUN_TEMPLATES` · all `_BAG_TEMPLATES` |
| **False — visible** | `us_grunt_joined` · `helmet_shell_worn` · `m16_world` · `pouch_belt_worn` · `canteen_l.002‥006` · all 16 `web_*` |

**Caleb has already told us, correctly, on every single object, which pieces are not supposed to
render.** He did it with the eye icon, which is what an artist uses.

And `tools/export_us_grunt_v2.py`, lines **248–250**:

```python
print("=== 5. normalize height ===")
for o in bpy.data.objects:
    o.hide_viewport = False
    o.hide_set(False)          # <-- THE BUG. One line. It erases the artist's intent.
```

The received wisdom — *"Blender viewport-hide does not survive glTF export"* — is true as a
statement about the glTF **format**, and it is a **red herring as a statement about this bug.**
The signal never reaches glTF because **we destroy it three steps earlier, on purpose, in our own
exporter.** (`hide_viewport` is `False` on everything — the flag we've been blaming was never even
set. It is the *eye*, and we wipe the eye.)

The unhide is not gratuitous, either — the glTF exporter needs objects selectable and evaluable.
The unhide is **fine**. Failing to *record what it erased* is the bug.

### 2d · THE PICK: `gib_` prefix, stamped BY THE EXPORTER, driven by the eye icon

**Contract:** *A mesh renders on the live body **iff** it is eye-visible in Blender. The exporter
reads the eye BEFORE it unhides, prefixes every hidden mesh `gib_`, and Godot hides every `gib_*`.
The name and the hide are then **the same fact**, and they cannot disagree.*

**Caleb's burden in Blender: ZERO.** He keeps pressing `H`. He types no prefix, remembers no
collection, sets no custom property, moves nothing. He is already doing 100 % of this, correctly,
today. **The one workflow change is that there is no workflow change** — which is the only kind an
artist actually keeps.

#### Why the alternatives lose

| option | why it loses |
|---|---|
| **(a) mandatory `gib_` prefix Caleb types by hand** | Right *shape*, wrong *author*. It relies on the artist remembering a build-engineering convention on every new object forever. He will forget once, and once is all it takes — that is a naming *convention*, not a *contract*. **Stamping it from the eye icon gives the same guarantee with none of the memory.** |
| **(b) Blender custom property → glTF `extras`** | Tempting: `export_extras=True` is **already on** (export_us_grunt_v2.py:342) and `make_gear_armory.py` **already writes** `obj["attach_bone"]` (I measured them on `prc25_*` and `ruck_*` in the blend). But **I could not verify that Godot 4.7 surfaces glTF node `extras` as node metadata** — Godot is not installed here and I will not guess about engine behaviour (that is the law). Betting the fix on an unverified importer path is how we got here. **Rejected until probed** — and if a probe *does* confirm it, it is a fine *second* channel, not the primary. |
| **(c) a Blender collection excluded at export** | Two fatal flaws. (1) Excluded at export = **the donor is not in the .glb**, so `GibSystem` has nothing to spawn — the whole gore system dies. (2) It adds a step Caleb must remember (drag each new donor into the collection) *on top of* the eye icon he already presses. Strictly worse than (d2c). |
| **(d) donors to a separate .glb** | Cannot work for the *skinned* donors. `grunt_head`/`grunt_forearm_*` are skinned to **this man's skeleton** and `GibSystem.dismember()` spawns them at `skel.get_bone_global_pose(bone) * rest⁻¹` — the current **animated** pose. A donor in a different file has no access to that skeleton. It also doubles the load and re-introduces the exact "which file holds the gear" ambiguity `MODEL_SESSION_HANDOFF.md` §3 names as the root disease. **Rejected.** |

#### Exactly what changes

**`tools/export_us_grunt_v2.py`** — insert *before* the existing unhide at line 248:

```python
# THE DONOR CONTRACT. The eye icon is the artist's word on what renders.
# Capture it BEFORE the unhide below erases it, and burn it into the NAME -
# the only channel glTF is guaranteed to carry (measured).
DONORS = {o.name for o in bpy.data.objects
          if o.type == 'MESH' and (o.hide_get() or o.hide_viewport)}
for o in bpy.data.objects:
    o.hide_viewport = False
    o.hide_set(False)          # still needed: glTF export needs them evaluable
for name in DONORS:
    o = bpy.data.objects.get(name)
    if o and not o.name.startswith("gib_"):
        o.name = "gib_" + o.name

# THE GATE (ADR-015): a donor that renders is a shipped bug. Refuse to write one.
live = [o for o in exportables if o.type == 'MESH' and not o.name.startswith("gib_")]
for i, a in enumerate(live):
    for b in live[i+1:]:
        if _bbox_overlap_frac(a, b) > 0.5:
            raise SystemExit(
                f"REFUSING TO EXPORT: '{a.name}' and '{b.name}' are two visible meshes "
                f"occupying the same volume. One of them is a donor you forgot to hide, "
                f"or a duplicate. Hide it with the eye icon and re-run.")
```

That gate is the "impossible, not fixed once" clause. **The exporter will not produce a .glb with
two solids in the same place, ever again.** x1bs cannot come back, and it cannot be introduced by a
new soldier, a new bag, or a new faction.

**`scripts/visuals/model_actor.gd`** — `_apply_gib_rig_contract()` collapses to one rule:

```gdscript
if String(mi.name).begins_with("gib_"):
    mi.visible = false
```
Delete the `grunt_` / `head_frag_` / `cap_` heuristic and the whole `has_body`/`has_donors`
trigger dance (model_actor.gd:302–316). It stops guessing.

**`scripts/combat/gib_system.gd`** — `REGIONS` keys gain the prefix (`gib_grunt_head`,
`gib_helmet_camo_shell`, `gib_cap_head`, …). ~20 strings. Mechanical, one commit.
`dismember_head_burst()`'s `begins_with("head_frag_")` → `begins_with("gib_head_frag_")`.

**`scripts/combat/hitzone_builder.gd`** — already skips hidden meshes (line 281) and gear by name
hint. Add `gib_` to the skip. Belt and braces.

**NEW `tools/probe_donor_contract.gd`** — the ADR-015 instrument. For **every** character `.glb`:
1. no non-`gib_` mesh overlaps another non-`gib_` mesh by >50 % of the smaller AABB;
2. every name in `GibSystem.REGIONS` resolves in the rig that claims the contract;
3. `_aabb_of()` computed over **`gib_`-excluded, visible meshes only** lands in `k ∈ [0.8, 1.0]`.
**Fails the build.** That also fixes `gib_scale` for free — exclude `gib_*` from `_aabb_of()` and the
RTO's antenna and the sub-floor head frags stop poisoning the measurement.

---

## 3 · THE ONE-TIME REMAKE PLAN

### 3a · What Caleb has ALREADY built today (measured in `us_base_v3.blend`, read-only)

**He is not remaking the grunt. He has built the modular squad, and it is most of the way there.**
`us_base_v3.blend` now holds **361 meshes**, **7 armatures**, and **4 collections**:

| collection | contents |
|---|---|
| `Collection` | the v3 base grunt (74 meshes) — body, the **new 16-piece `web_*` M1956 webbing**, helmet, 5 canteens, m16 |
| `_BAG_TEMPLATES` | **the swappable back payloads.** A brand-new 10-piece `ruck_*` (body/flap/pocket_0‥2/frame_l/r/frame_bar/buckle_l/r) and the 3-piece `prc25_*`. **Every one carries `obj["attach_bone"] = "mixamorig:Spine2"`.** |
| `_GUN_TEMPLATES` | `Ithaca37_Shotgun`, `M60_MG`, `M70sniper`, `M79_Launcher` |
| `SQUAD` | **six complete soldiers, each on its own rig** — `PSXRig_rifleman`, `_pointman`, `_marksman`, `_mg`, `_grenadier`, `_rto` |

| MOS | meshes | gun | back payload |
|---|---|---|---|
| rifleman | 54 | `m16_world` | **ruck** |
| marksman | 54 | `m70sniper_world` | **ruck** |
| rto | 47 | `m16_world` | **prc25** |
| pointman | 44 | `ithaca37_world` | *(none — travels light)* |
| mg | 44 | `m60_world` | *(none — carries ammo)* |
| grenadier | 44 | `m79_world` | *(none)* |

**The `MOUNT_back` swappable-payload system the brief asks me to design ALREADY EXISTS.**
It is `_BAG_TEMPLATES` + `attach_bone` + a per-MOS rig. He built it by hand, today, and it is *good*
— the doctrine is even right (the pointman and the pig don't hump a ruck).

**A recommendation that costs him this is a recommendation that gets rejected. So: don't.**
The plan is to **land what he is already building**, not to replace it.

### 3b · The gaps in it, measured

1. **NO MEDIC.** Six MOS rigs; `ART_GAPS` says the medic is the one with no body. `_BAG_TEMPLATES`
   has a ruck and a radio and **no aid bag** — and `satchel_m3.blend` is **deleted in the working
   tree**. The aid bag currently exists in exactly two places: `us_medic.glb` (baked, 268 t) and
   git blob for `satchel_m3.blend` (71 MB, in `HEAD`, about to be deleted). **See §4.**
2. **The shipped GLBs are already stale.** `us_grunt_v3.glb` ships `bandolier_worn` and
   `ruck_pack_worn`. **Neither exists in the blend any more** — Caleb replaced them with
   `web_bandolier` and the `_BAG_TEMPLATES` ruck. Nothing on disk reflects what he has made.
3. **The orphan donors are still in the base** — `ruck_bag`, `ruck_rail_l/r`, `ruck_crossbar` are
   still parented to `PSXRig(Spine2)`, eye-hidden, and now donors *for a ruck that no longer exists*.
4. **The tool chain is dead.** **22 of 44 `tools/*.py` still resolve `art_source/`**, which the
   restructure deleted. `make_base_v3.py` can't find its source; `make_rto.py` can't find
   `gear_library.blend`; `make_medic.py` points at `assets/models/characters/` (gone).
   **Not one character tool runs today.**

### 3c · ⚠ THE BEVEL: 49 % OF EVERY US SOLDIER IS A MODIFIER

`export_apply=True` (export_us_grunt_v2.py:330) bakes modifiers. I measured raw vs evaluated tris:

| mesh | raw tris | after BEVEL | multiplier |
|---|---|---|---|
| **`m16_world`** | **336** | **2,400** | **×7.1** |
| `M70sniper` | 344 | 2,456 | ×7.1 |
| `Ithaca37_Shotgun` | 260 | 1,668 | ×6.4 |
| `canteen_l.002‥006` (×5) | 12 each | **108 each** | ×9 |
| `ruck_bag` | 12 | 108 | ×9 |

**The M16 alone is 2,400 of the grunt's 5,376 triangles — 45 % of the man is his rifle**, and 2,064
of those 2,400 are a bevel. Across the live model the BEVEL adds **≈ 2,640 tris to a ≈ 2,736-tri
soldier.** We are shipping every US grunt at **roughly double** his necessary cost, in a game
currently running at **19–25 FPS**, for edge highlights a PSX-filtered texture at 40 m cannot resolve.

**I am not deleting his bevels behind his back.** This is a *look* decision and Caleb is the one who
looks. The action is: render an A/B of one grunt at 5 m / 40 m / 100 m with `render_levels=0`, put
it in front of him, and let him call it. If he keeps it, we keep it and we say so out loud.
If he drops it, **the US roster gets ~45 % cheaper for zero art loss** — which is the largest
single perf win visible anywhere in this asset tree.

### 3d · The tri budget — name the number

`GAME_SCALE_STANDARD.md` says "~3–6k tris". That band is too loose to police anything; it is how a
5,376-tri man with 876 tris of duplicate gear and a 2,400-tri rifle passed inspection.

**Proposed contract — the soldier is budgeted in parts:**

| part | budget | measured now |
|---|---|---|
| body (`us_grunt_joined`) | **≤ 500** | 434 ✓ |
| worn gear (helmet + webbing + canteens + pouches) | **≤ 700** | ~1,000 (bevelled canteens) |
| back payload (ruck / prc25 / aid bag) | **≤ 400** | ruck 168 ✓ · prc25 392 ✓ · satchel 268 ✓ |
| **world gun** | **≤ 400** | **m16 = 2,400 ✗✗** |
| **LIVE SOLDIER TOTAL** | **≤ 2,000** | **4,658** |
| gib donors (`gib_*`, never rendered) | ≤ 800 | 718 ✓ |
| **FILE TOTAL** | **≤ 2,800** | **5,376** |

2,000 rendered tris is a *generous* PSX soldier (a PS1 character was 300–900). It is met the moment
the bevel comes off the gun and the 876 duplicate tris die. **Both of those are free.** No hand-work
is lost to hit this budget — that is the entire point of naming it now.

### 3e · LODs

**Do not build LODs.** Godot 4 generates them automatically on import, and at a 2,000-tri budget the
soldier is not the bottleneck — 19–25 FPS is not being caused by a 2 k-tri man. Building an LOD chain
by hand costs Caleb a day and buys a number we have not measured. **Measure first. Refuse the work.**

### 3f · THE PLAN — by hand vs by script

| # | who | what | why |
|---|---|---|---|
| **0** | **CLAUDE — DO THIS FIRST, BEFORE ANY BLENDER WORK** | `git cat-file -p 4ac7b7c > _truth/us_grunt_v2.blend` and **verify the md5**. Restore `satchel_m3.blend` + `helmet_v3_fitted.blend` from `HEAD` to a path outside the repo. | The ancestor and the aid bag exist only inside a 4.8 GB `.git` that the P0 is about to attack. **Nothing else in this plan matters if this is not done.** |
| **1** | **CLAUDE** | Repoint all 22 dead `art_source/` paths. **One constants module, `tools/paths.py`** — every tool imports it. The next re-org edits one file, not twenty-two. | The re-org broke the pipeline silently, and it will happen again. |
| **2** | **CLAUDE** | The donor contract, §2d: exporter eye→`gib_` stamp + the **overlap gate**; `model_actor.gd` one-rule hide; `gib_system.gd` REGIONS rename; `probe_donor_contract.gd`. | **x1bs dies, and its whole class dies with it.** This is the one moment the art can absorb it free. |
| **3** | **CALEB (hand)** | Delete the four orphans from the base: `ruck_bag`, `ruck_rail_l`, `ruck_rail_r`, `ruck_crossbar`. Nothing spawns them; the ruck they donated for is gone. | 10 seconds. He is already in the file. |
| **4** | **CALEB (hand)** | **Append the M3 aid bag into `_BAG_TEMPLATES`** (from the restored `satchel_m3.blend`), fit it, and build **`PSXRig_medic`** — the 7th MOS. Drag the sling's last ribbon segment into the bag by eye (`MODEL_SESSION_HANDOFF.md` §4: `fit_webbing`'s gate measures 284 mm and correctly refuses to skin it). | **Hand-work. Ten seconds with a mouse; I could not do it blind and I am not going to pretend otherwise.** This closes the last MOS gap in `ART_GAPS`. |
| **5** | **CLAUDE** | `tools/export_squad.py` — iterate the `SQUAD` collection, export one mesh-only `.glb` per `PSXRig_<mos>` (`export_animations=False`; the 91 clips live once in `anim_library.glb`), each through the §2d gate. **One script replaces `export_us_grunt_v2.py` + `make_rto.py` + `make_medic.py`.** | The lineup **is** the manifest. Adding an 8th MOS = adding a rig to `SQUAD`. **No new tool, ever again.** |
| **6** | **CALEB** | Look at the bevel A/B (§3c) and rule. | It is a look decision. He looks. |
| **7** | **CLAUDE** | `bd close cn68` **with the measured numbers** (ADR-015: no "likely"). Its description points at `art_source/` paths that do not exist — the bead is lying and must be re-scoped or closed. | Truth law. |

**One `.blend`. One export script. One probe. Seven soldiers out.**

---

## 4 · DERIVED VS SOURCE — the per-file adjudication

The rule, stated once: **a file is DERIVED only if a script that RUNS TODAY can rebuild it byte-for-byte
from inputs that EXIST TODAY. Everything else is SOURCE, and deleting SOURCE destroys work.**

By that rule, `.gitignore`'s claim is not merely stale — **it is unsatisfiable**, because the input is gone.

| file | status in tree | the claim | **VERDICT** |
|---|---|---|---|
| **`us_base_v3.blend`** (122 MB) | **MODIFIED** by hand | ".gitignore: a pure function of us_grunt_v2.blend + make_base_v3.py" | **🔴 SOURCE. THE CLAIM IS FALSE TWICE OVER.** (1) `us_grunt_v2.blend` **does not exist** — the generator cannot run. (2) Even if it could, `make_base_v3.py` produces **one rig and ~40 objects**; this file now holds **7 rigs, 361 meshes, `SQUAD`, `_BAG_TEMPLATES`, `_GUN_TEMPLATES`, and a 16-piece M1956 webbing** — none of which that script knows how to make. **Deleting this file destroys the entire US squad. It is the single most valuable art file in the project. TRACK IT. NEVER `.gitignore` IT.** |
| **`gear_armory.blend`** (53 MB) | **MODIFIED** by hand | "rack/pack the locker" | **🔴 SOURCE.** `make_gear_armory.py`'s own docstring says `pack` folds **Caleb's hand edits** back in. A file whose script exists to *ingest hand-work* is by definition not derived. Hand-modified, 12.5 MB smaller than `HEAD`. **Keep.** |
| **`us_v3_soldier_lineup.blend`** (50 MB) | **NEW, untracked** | — | **🟡 SOURCE, but check.** Newest file on disk (15:54). `tools/make_soldier_lineup.py` exists but points at dead `art_source/`. **Ask Caleb: is this a review scene, or the squad's real home?** If the squad lives in `us_base_v3.blend` (it does, measured), this is a *review* artifact → **`.gitignore` it**. **Do not assume. Ask him.** |
| **`assets/us/props/gear_armory.blend`** (53 MB) | **NEW, untracked** | — | **🟢 DELETE — a byte-identical duplicate.** md5 `88fbcf33…` == `assets/us/characters/gear_armory.blend`, exactly. **This is a SIXTH locker**, and `MODEL_SESSION_HANDOFF.md` §3 names *"five lockers claim to hold the gear"* as **the root disease**. **The drift is regenerating itself, right now, in the untracked tree.** Delete the copy, keep one locker. Zero work lost — it is the same bytes. |
| **`satchel_m3.blend`** (71 MB) | **DELETED** | — | **🔴 DO NOT COMMIT THIS DELETION YET.** It holds the **only editable M3 aid bag**, and `_BAG_TEMPLATES` **has no replacement in it** (measured: ruck + prc25 only). The medic is the last MOS gap in `ART_GAPS`. **Restore it, append the bag into `_BAG_TEMPLATES` (plan step 4), *then* the .blend is genuinely dead and may go.** Deleting it first strands the aid bag in a baked `.glb`. |
| **`helmet_v3_fitted.blend`** (13 MB) | **DELETED** | — | **🟢 SAFE TO DELETE.** Verified: `helmet_shell_worn` (167 v / 131 f) is present, eye-**visible**, bone-parented to `PSXRig(Head)` inside `us_base_v3.blend`. The fitted result is in the base. This was scaffolding. **Let it go.** |
| **`us_grunt_v2.blend`** | **GONE — disk and `HEAD`** | "THE DECLARED TRUTH SOURCE" | **🔴🔴 THE ONE UNFORGIVABLE LOSS, AND IT IS ONE `git gc` AWAY.** Survives only as blob **`4ac7b7c`** (94,079,010 B) in a 4.8 GB `.git` that the P0 push-blocker is *begging* someone to rewrite. **`git cat-file -p 4ac7b7c > _truth/us_grunt_v2.blend` — TODAY, BEFORE ANYTHING TOUCHES HISTORY.** It is the ancestor of every US soldier and of both pilots. |
| `us_base_v3.blend1` / `gear_armory.blend1` | untracked | Blender autosave | **🟢 DERIVED.** `.gitignore` `*.blend1`. |
| `_archive/us_base_v3_DUPLICATE_from_us_troops.blend` (94 MB) | tracked | — | **🟢 DELETE from `HEAD`** once `4ac7b7c` is rescued. Its own filename says `DUPLICATE`. 94 MB of the push-blocker, for nothing. |

**The general repair.** `.gitignore` lines 31–35 must be rewritten, because they encode a rule that
is now actively dangerous:

```diff
-# Derived character blends - regenerated from the tracked truth source, ~90 MB each.
-# us_base_v3.blend is a pure function of us_grunt_v2.blend + tools/make_base_v3.py.
-art_source/characters/base_psx/us_base_v3.blend
-art_source/characters/lineup_review.blend
+# LAW (War Room, drift council): a .blend is DERIVED - and therefore ignorable -
+# ONLY if a tool that RUNS TODAY rebuilds it from inputs that EXIST TODAY.
+# us_base_v3.blend was called derived. Its generator's input (us_grunt_v2.blend)
+# had already been deleted, and Caleb hand-built a 6-man SQUAD inside it.
+# It is SOURCE. It is TRACKED. Deleting it would have destroyed the US army.
+#
+# Ignore only true scratch:
+*.blend1
+assets/**/review/
+assets/**/_backups/
```

And the 100 MB push-blocker is then solved the **honest** way — `git rm --cached` the two 217 MB
`_backups/` blends and the 94 MB `_archive/` duplicate, `.gitignore` them, keep them on disk — rather
than the tempting way, which eats `4ac7b7c` and the US grunt's ancestor with it.

---

## 5 · WHAT I AM SACRIFICING

No decree is free. Mine costs:

1. **The bevel decision is not mine and I am leaving it open.** I measured a ~45 % tri win sitting in
   a modifier and I am *refusing to take it*, because it is a look, and Caleb is the one who looks.
   That means the largest perf win in the asset tree stays on the table until a human eyeballs an
   A/B render. **I am trading a day of latency for not silently flattening his art.** I'll take that
   trade every time — but it is a real cost and I am naming it.

2. **The `gib_` rename touches ~20 strings in `gib_system.gd` and every character rig, not just the
   US.** VC, NVA, civilians, pilots all ride `_apply_gib_rig_contract()`. Do it half-way and the VC
   go back to the "floating gib pieces" bug (bead i3b0). **This is one atomic commit across the whole
   roster, or it is a regression.** It also invalidates every shipped character `.glb` — all ~25 must
   be re-exported. That is machine time, not hand time, but it is not nothing.

3. **The export-overlap gate WILL false-positive**, and it will do it to Caleb, in the middle of his
   work. A bandolier legitimately intersects a webbing yoke. The 50 % threshold is a guess I have not
   tuned against the real roster, and a gate that cries wolf is a gate an artist learns to bypass.
   **It must be tuned against all 25 characters before it is armed, or it will be the most annoying
   thing in the pipeline.**

4. **I am telling him to keep working in a 122 MB tracked binary.** That is genuinely bad for git —
   every save is a new 122 MB blob and `.git` grows without bound. I am accepting it anyway, because
   the alternative on offer (call it derived, ignore it, delete it) is what nearly cost us the army.
   **Correctness over repo hygiene. But the repo will keep getting fatter, and one day that bill
   comes due** — probably as Git LFS, which is its own tax.

5. **I did not run Godot.** It is not installed on this box. Every glTF number here is hard-measured
   from the binary; every claim about what `_aabb_of()` and `ModelActor` *do at runtime* is read from
   the source and is therefore **inference, not verification.** The `gib_scale` spread (0.42 → 0.90)
   is my strongest un-probed claim. Under ADR-015 it does not close a bead until
   `probe_donor_contract.gd` runs green. **I am flagging my own weakest link rather than letting it
   pass as measurement.**

6. **I am spending Caleb's hand-time on the medic (plan step 4) rather than on the NVA**, which
   `ART_GAPS` ranks #1 by felt value. I do it because he is *already in this file, today*, with the
   squad open — and the medic is a 20-minute append while the NVA is a new silhouette from scratch.
   **The NVA is the higher prize and I am deferring it.** That is a real sacrifice and the Arbiter
   should weigh it: my plan optimizes for *landing the thing in flight* over *starting the thing that
   matters most.*
