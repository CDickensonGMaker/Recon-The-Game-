# TECHNICAL ARTIST — the random grunt spawner

Everything below was measured. Where I could not measure, I say so.

**Method.** Read-only headless Blender (`blender.exe -b -P`, `wm.open_mainfile`, never saved) against
`assets/us/characters/us_v3_soldier_lineup.blend`; direct binary parse of the six shipped GLBs
(JSON chunk: nodes, meshes, accessors, bufferViews, extras). His open session was never touched.

**Headline: he did not make the radio mistake. The exporter did.** And the helmet variants are not
missing — they are a finished, 15-piece, 20-KB-each socketed prop library that the game already
knows how to wear. And the six 10.7 MB GLBs are 96% duplicated texture bytes.

---

## WHERE THE HELMET VARIANTS ARE (measured)

**They are 15 separate GLBs, and they were never supposed to be inside the grunts.**

`assets/us/props/helmets/` — 15 files, **19.6 KB to 60.2 KB each**, 264–452 tris:

    m1_plain  m1_cig  m1_bugjuice  m1_cig_bug  m1_ace  m1_ace_cig  m1_war_is_hell
    m1_born_to_kill  m1_rounds  m1_foliage  m1_foliage_graf  m1_barepot
    m1_barepot_fta  m1_erdl_short  m1_veteran

Source: `assets/us/characters/helmet_variants.blend` (13.4 MB, 19:22 today), collection `HELMETS`,
one sub-collection per variant, each with a `<name>_socket_head` empty.
Exporter: `tools/export_helmets.py`.

Three design decisions in that exporter are load-bearing and correct:

1. **Every helmet exports with its socket at the world origin.** `helmets.json` carries ONE shared
   bone-local offset on `mixamorig:Head`. One offset places any of the 15 — no per-helmet fitting,
   because every variant was cloned off the same shell.
2. **Every mesh is prefixed `helmet_`** so it hits `hitzone_builder._GEAR_NAME_HINTS` (substring
   match on "helmet") and is excluded from the hurtbox. Without the prefix you could kill a man by
   shooting his cigarettes.
3. **Not skinned** (`export_skins=False`) — rigid props, bone-attached.

The variants are **modular**, not monolithic. Parts across the set:
`band, cover, card_ace, cigpack, bugjuice, foliage, gum, rounds`.
`helmet_item_slots.json` holds 15 `item@helmet` local placements (cigpack@m1_cig, bugjuice@m1_veteran…).

And there is a **second variety axis already built**: `tools/make_helmet_decals.py` writes
`helmet_graffiti_atlas.png` — a **4x4 = 16-slogan atlas** (WAR IS HELL / BORN TO KILL / SHORT TIMER /
USMC / GOD COUNTRY / HILL 937 / FTA / 13 MONTHS / A SHAU / THE SMELL OF DEATH / DEATH FROM ABOVE /
1 CAV / SORRY 'BOUT THAT / PEACE / HOME / DEROS), picked by `uv1_offset` on a 2-tri decal quad —
the same trick as the face atlas. Plus `helmet_card_ace.png`, and 15 baked textures in
`assets/us/textures/helmets/`.

**So the answer to "where are the variants": they are exactly where they should be, and the game
already wears them.** `scripts/visuals/grunt_dresser.gd` hides the stock `helmet_shell_worn` welded
into each grunt GLB and hangs a variant off a `HelmetSocket` BoneAttachment3D. Each grunt GLB
carrying exactly one `helmet_shell_worn` is **correct by design** — it is the fit reference, not a
missing variant. `GruntDresser._swap_helmet()` reads the stock helmet's *rendered* AABB centre and
basis to place the variant, which sidesteps every Blender→Godot axis conversion. That is a good
trick and it should not be "fixed".

**Nothing to do here. This system is finished.** The only thing missing is a spawner that calls it.

---

## THE RADIO: CODE BUG OR ART BUG? (measured, with the hide flags)

**CODE BUG. 100%. His art is already correct and the exporter throws it away.**

The PRC-25 exists on all six soldiers in the lineup — `prc25_pack`, `prc25_antenna`, `prc25_handset`,
each bone-parented to `mixamorig:Spine2`, each with a `socket_radio_<tag>` empty alongside. But the
**hide flags are authored per-role, and they are right**:

| soldier    | prc25_pack / _antenna / _handset — eye (`hide_get`) | `hide_render` |
|------------|-----------------------------------------------------|---------------|
| rifleman   | **HIDDEN**                                          | **HIDDEN**    |
| grenadier  | **HIDDEN**                                          | **HIDDEN**    |
| mg         | **HIDDEN**                                          | **HIDDEN**    |
| marksman   | **HIDDEN**                                          | **HIDDEN**    |
| pointman   | **HIDDEN**                                          | **HIDDEN**    |
| **rto**    | **VISIBLE**                                         | **VISIBLE**   |

He hid the radio on five men and left it on the RTO. That is the ADR-011 contract, authored in the
art, by hand, correctly.

**`tools/export_us_squad.py:59-62` destroys it:**

```python
for o in bpy.data.objects:
    o.hide_set(False)
    o.hide_viewport = False
    o.hide_render = False
```

with the comment *"the GAME hides the gib donors at runtime, not us."*

That comment is **true for gib donors and false for the radio.** The runtime hider is
`model_actor.gd:_apply_gib_rig_contract()`, and it hides exactly two categories:

- names beginning `grunt_` / `head_frag_` / `cap_` (and not ending `_joined`)
- every mesh named in `GibSystem.REGIONS[*]["gear"]` — i.e. `helmet_camo_shell`, `helmet_bugjuice`

`prc25_*` is **neither**. It is not a gib donor, so nothing in the game hides it. The exporter unhides
it, the runtime doesn't re-hide it, and **all six grunts ship wearing a radio.**

`grunt_dresser.gd` already has the switch — `GEAR_TOGGLES = {"radio": "prc25_pack", "radio_antenna":
"prc25_antenna", "radio_handset": "prc25_handset"}` — but it only fires `if opts.has(key)`. Nobody
passes the opt, so the radio stays on. **The lever exists and is unpulled.**

### The fix, cheapest first — no art is touched in any of these

**(A) Ship today, zero re-export.** The spawner passes the loadout; the dresser defaults the radio
OFF unless the role is RTO. Two lines. Fixes the tell immediately.

**(B) The right fix — art stays truth.** (A) copies his authoring into a GDScript table, and that
table *will* drift from the .blend (this project has a FOSSIL LAW precisely because of that failure
mode). Better: **stop the exporter stomping his flags**, and have it emit what he authored:

- Skip the unhide for anything that is *not* a gib donor (donors genuinely must be unhidden to reach
  the GLB — that part of the comment is correct).
- Write a `squad_loadout.json` next to the GLBs — per role, the meshes he authored VISIBLE — exactly
  the pattern he already uses in `helmets.json`, `helmet_item_slots.json`, `radioman_loadout.json`.
- The dresser reads it. His hide flags become the single source of truth. A table in code can then
  never disagree with the .blend, because there is no table.

Cost of (B): one exporter script run. **His .blend is opened read-only and never saved; no mesh is
renamed; nothing is re-authored.** That is not an art cost.

I checked whether the flags could ride the GLB directly instead of a sidecar: the exporter already
runs `export_extras=True`, and the shipped GLBs **do** carry extras — measured, the three `prc25_*`
nodes each carry `{"attach_bone": "mixamorig:Spine2"}`. So a `{"live": false}` extra would export.
**But I did not verify that Godot 4.7's glTF importer surfaces node `extras` as node metadata**, and
I will not assert it. The JSON sidecar needs no such assumption and matches his existing pattern.
Recommend the sidecar.

---

## CAN ONE GLB SERVE ALL SIX ROLES?

**Yes — and the payoff is bigger than expected, because the win is textures, not meshes.**

Measured across the six shipped GLBs — **48 unique mesh names**, which decompose as:

**23 meshes present in ALL SIX, identical names:**
`Base_Human, canteen_worn, cap_forearm_l, cap_forearm_r, cap_head, cap_leg_r, cap_torso,
cap_uparm_l, cap_uparm_r, grunt_forearm_l, grunt_forearm_r, grunt_head, grunt_leg_l, grunt_leg_r,
grunt_torso, grunt_uparm_l, grunt_uparm_r, helmet_bugjuice, helmet_camo_shell, prc25_antenna,
prc25_handset, prc25_pack, ruck_pack_worn, us_grunt_joined, webbing_worn`

**18 more that are the SAME THREE MESHES under per-soldier aliases** — `cap_leg_l.001–.006`,
`helmet_shell_worn.001–.006`, `pouch_belt_worn.001–.006`. (Mesh-*data* names only. The glTF **node**
names are clean — see the landmine section below.)

**5 genuinely role-unique meshes — and they are all the weapon:**

| mesh                     | carried by        |
|--------------------------|-------------------|
| `m16a1_world`            | rifleman **and rto** |
| `m79_launcher_world`     | grenadier         |
| `m60_mg_world`           | mg                |
| `m70sniper_world`        | marksman          |
| `ithaca37_shotgun_world` | pointman          |

**The six exported grunts differ by the weapon mesh and nothing else.** (They were *supposed* to also
differ by the radio flags; the exporter erased that difference.)

### The size truth

Per GLB, measured from the bufferViews:

    total 10.75 MB  =  10.31 MB IMAGES  +  0.37 MB mesh + skin

      better textures    8.63 MB
      face_atlas_v3      1.38 MB
      prc25_panel        0.19 MB
      canvas_od          0.06 MB
      gore_tex           0.03 MB
      insectrepl         0.02 MB
      cigs              ~0.00 MB

**Six GLBs on disk: 64.7 MB. Roughly 62 MB of that is six identical copies of the same seven
textures.** The actual geometry of a whole soldier — body, 8 gib donors, 8 gore caps, helmet, radio,
ruck, webbing, canteen, pouches — is **370 KB**.

This is not a disk problem, it is a **VRAM** problem: six GLBs import as six independent texture sets,
so a squad with a rifleman, a grenadier and an MG has three copies of the same 8.63 MB atlas resident.

### The verdict

**One GLB can serve all six roles.** It needs the 23 shared meshes + one texture set + the 5 weapon
meshes, with the role selecting visibility. **~11 MB replaces 64.7 MB — an ~83% cut** — and the
spawner reduces to: load one scene, toggle meshes, socket a helmet.

Better still, the weapons should follow the pattern he **already built for helmets**: separate
socketed prop GLBs. He has the sockets (`socket_head`, `socket_radio`, `socket_ruck` per soldier) and
`gun_placements.json` (17:19 today) already sitting in the characters folder. The helmet library is
the proof that this pipeline works.

**What this costs (naming the sacrifice):**
- One exporter rewrite + one export run. **No .blend edit, no renames, no re-authoring.**
- The exporter's three existing contracts must survive it: rig named `PSXRig` (or the 100-clip
  animation library goes silent), suffix-stripped mesh names (or every gib silently no-ops), and the
  height normalizer that measures body + `*_worn` **excluding** the antenna (that exclusion is why
  radio grunts aren't 34% short — do not touch `HEIGHT_EXCLUDE`).
- **Real blast radius I did NOT fully measure:** `ModelActor` resolves the cast from bare `unit_id`
  strings, and CLAUDE.md warns 913 of 1,291 assets have zero grep hits. Collapsing six files into one
  moves "which role" from the *filename* into the *dress() opts*. I have not traced every `unit_id`
  consumer. **Do not treat the one-GLB migration as a small change until someone has.** The radio fix
  (A/B above) does not depend on it and should not wait for it.

---

## THE x1bs CONTRACT

**The premise is already handled, and it was fixed in the right place.** No art cost, and none needed.

`model_actor.gd:_apply_gib_rig_contract()` (lines ~292-314) hides, on the living man:

- every mesh named `grunt_*` / `head_frag_*` / `cap_*` (not `*_joined`) — the region donors and the
  wound caps; and
- **every mesh listed as `gear` in `GibSystem.REGIONS`** — which is `helmet_camo_shell` and
  `helmet_bugjuice`.

Crucially it derives that gear list **by reading `GibSystem.REGIONS` at runtime rather than
re-listing the names**, so the hide-list and the gib contract cannot drift apart. Its own comment
records that this is exactly the two-helmets-stacked bug, already found and already killed.

`GibSystem._gear_meshes()` closes the other half: if the man is wearing a dressed variant under
`HelmetSocket`, **the variant flies off**, not the donor — and it only throws **visible** meshes, so a
hidden donor is never launched. Gore stays intact while the donor stays invisible.

**So the minimal zero-art-cost contract is the one that already exists**, and it is:

> A mesh is a DONOR if its name starts `grunt_`/`cap_`/`head_frag_`, **or** it is named as `gear` in
> `GibSystem.REGIONS`. Donors are hidden on the living man and revealed/thrown only by the gib. The
> live body is everything else.

**The single gap — and it is the radio.** `prc25_*` satisfies neither clause, so the contract does
not cover it. The radio is not a *donor*; it is **role loadout**. Those are different concepts and
they need different mechanisms. Do not smuggle the radio into `REGIONS.gear` to get it hidden — that
would make the RTO's radio fly off his head when he is decapitated.

**Extend the contract with a second, orthogonal clause:**

> A mesh is LOADOUT if the role does not carry it. Loadout visibility is set at spawn from the role
> (ideally from the exporter's `squad_loadout.json`, i.e. from the flags he authored). Donor-hiding
> and loadout-hiding are independent passes.

That is the whole fix. It is free.

**On the specific 20 mm z-fight claim in the brief: I could not confirm it and I am not going to
assert it either way.** `helmet_shell_worn` is exported **skinned** (bind-space verts) while
`helmet_camo_shell` is a **rigid bone-parented node** (local verts + a node transform chain). Their
accessor bounds are therefore in different spaces and cannot be compared directly. I attempted to
reconstruct world transforms by walking the glTF node graph by hand and the result was visibly wrong
(it produced a 16 mm helmet and a 246 mm M16), so I threw the numbers away rather than report them.
**It does not matter**: whatever their separation, `_apply_gib_rig_contract()` hides
`helmet_camo_shell` on the living man, so nothing z-fights on screen. If anyone wants the true
number, measure it in-engine or in Blender in POSE position — not from the accessor bounds.

---

## THE LANDMINE I FOUND ON THE WAY (not asked for; report anyway)

**The shipped GLBs contain dotted mesh names — the exact failure `export_us_squad.py`'s own 8-line
comment block warns about. It shipped again, in a field the guard doesn't watch.**

Measured, in the shipped GLBs:

| glTF **node** name (Godot uses this) | glTF **mesh-data** name          |
|--------------------------------------|----------------------------------|
| `helmet_shell_worn`  ✅ clean         | `helmet_shell_worn.001` … `.006` |
| `pouch_belt_worn`    ✅ clean         | `pouch_belt_worn.001` … `.006`   |
| `cap_leg_l`          ✅ clean         | `cap_leg_l.001` … `.006`         |

**Mechanism (measured, not guessed).** In the lineup, those three objects' mesh *data* is already
suffixed (`helmet_shell_worn_rifleman` → data `helmet_shell_worn.001`), and the untagged BASE objects
`helmet_shell_worn` / `pouch_belt_worn` / `cap_leg_l` hold data named *exactly* `helmet_shell_worn`
etc. (confirmed: `bpy.data.meshes["helmet_shell_worn"]` exists, users=1, held by object
`helmet_shell_worn`). The exporter deletes the base **object** — but
**`bpy.data.objects.remove()` does not free the mesh datablock's NAME.** It lingers as a zero-user
orphan still holding the string. So `o.data.name = "helmet_shell_worn"` collides, and Blender
re-appends a suffix. Across the six sequential exports in one Blender session the orphans accumulate,
which is exactly why the suffix climbs `.001 → .006` in `TAGS` order.

**The guard is watching the wrong field.** `export_us_squad.py:70-72` aborts on a dotted `o.name` —
the **object** name — which always renames cleanly, because object names *do* free on removal. It
never checks `o.data.name`.

**Is it biting right now? No — and I want to be precise about why.** The glTF **node** names are
clean, and Godot names `MeshInstance3D` from the node name, so `GibSystem`'s exact-name
`find_child("cap_leg_l")` and the dresser's `contains("helmet_shell_worn")` both resolve.
**I did not boot the engine to confirm the importer's naming** — I am inferring it from the node
names being clean and from `model_actor`'s two-helmet fix being described as working. Worth one
in-engine check.

**So: latent, not live.** But it is a lie in the map of exactly the kind ADR-023 is about — the file
*looks* like the thing the abort guard promised to prevent. Fix: have the guard also check
`o.data.name`, and purge orphan mesh datablocks (or rename the data *before* stripping the object
suffix). One line. Zero art cost.

---

## SACRIFICES

Nothing here is free. Named:

1. **The role→loadout table (fix A) duplicates his art authoring in code.** It is two lines and ships
   today, but it is a second source of truth and it *will* drift from the .blend. Take it only as a
   stopgap, with fix B (the exporter emitting `squad_loadout.json`) as the follow-through. If only one
   gets built, build B.
2. **Fix B costs an export run.** No art is touched, but the three exporter contracts (PSXRig name,
   stripped mesh names, antenna-excluded height box) are live landmines and must be re-verified after
   any exporter edit. A bad re-export ships a 34%-short radioman or silently kills every gib, and
   **both failures look fine in the viewport.**
3. **The one-GLB collapse saves ~54 MB and a lot of VRAM, but it moves "which role" out of the
   filename and into spawn-time data.** `ModelActor` resolves the cast from bare `unit_id` strings and
   I did not trace every consumer. Doing this blind risks breaking model resolution for units nobody
   greps. **Do it as its own change, after someone maps `unit_id`'s consumers — not as a rider on the
   radio fix.**
4. **Weapons-as-sockets is the right end state and is a bigger job than it looks.** The sockets and
   `gun_placements.json` exist, but the weapon is currently a skinned/bone-parented mesh *inside* the
   character, and the animation clips were authored against it. Moving it out is a separate war.
5. **Variety has a ceiling the art sets, not the code.** 70 faces × 15 helmets is enormous, but every
   grunt still wears the same body, the same webbing, the same ruck. Toggling gear off gives
   *silhouette* variety at the cost of *kit* variety. If the squad still reads as clones at 40 m, the
   next lever is a second torso/trouser texture in the atlas — and that one **is** an art cost, and it
   is his to spend, not mine.
