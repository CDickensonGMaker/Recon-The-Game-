# Destroyed buildings — the plan, 2026-08-12

Written while the screened hooch was being built, so the *intact* build could be shaped to make
the destroyed one cheap. It generalises: this is the recipe for every building we make from here.

---

## 1. How destruction actually works today (measured, not assumed)

`scripts/world/destructible.gd:170 _do_destroy()`:

- hides the intact `MeshInstance3D` — `visible = false` (`:181`)
- **disables** the `CollisionShape3D` — `disabled = true`, with the comment *"rubble is not full
  cover"* (`:183`)
- spawns a rubble `MultiMeshInstance3D` (`_rubble_mmi`)
- `:191` — a disabled shape is skipped by `NavBaker._add_colliders`, so **the navmesh reopens
  through the hole by itself**. That is a real feature and it is why breaches become walkable.

**CORRECTION — an earlier draft of this file said there was no destroyed-model swap. That was
wrong.** `destructible.gd` carries `destroyed_mesh: Mesh` and a `RUIN_FOR` map:

```
"hut_thatch": "burned_hut.glb",   "hut_timber": "burned_hut.glb",
"bunker": "destroyed_bunker.glb", "bunker_mg": "destroyed_bunker.glb",
"tower": "rubble_heap_tall.glb",  "sandbag_stack": "rubble_pile.glb",
```

and states its own intent: *"One generic burned hut serves every house until per-building burned
versions are authored; that is ART, and the code needs no change when they land — extend this
map."* Also ruled there (Summoner, 2026-08-07): **the swap is hidden by the blast** — the
explosion plays over the intact→ruin pop on the same frame so the eye never catches it.

## 1b. THE TREE PRECEDENT — this is the model to copy

`scripts/world/tree_break_system.gd:3-8` (S29, his 8/7 ruling):

> *"the live canopy stays MultiMesh with ZERO standing colliders; ordnance finds trees by SPATIAL
> LOOKUP against this registry, never physics. Only a hit tree is **promoted** to its 3-part
> segmented form (`_stump`/`_stem`/`_crown` break bands), breaks at the joint nearest the hit
> height, and the parts above hinge-fall as cover — **state-swap only, never RigidBody**
> (ADR-031)."*

**PROMOTION ON HIT is the key idea.** The intact building is cheap and whole; it only becomes its
segmented form once something hits it. Break-band data lives in `data/veg_break_bands.json`,
generated from the segment art by `tools/gen_veg_break_bands.py`.

**A warning that comes with it:** without that JSON, `_bands` is empty, `register_chunk` drops
every instance, and the jungle is **silently unbreakable** — which it was, from 8/7 until 8/11.
A building version inherits that failure mode exactly: data missing = indestructible, no error.

**Conclusion: a hooch should break the way a tree breaks.** Segment art + a break-band table +
promotion on hit. Not a physics fracture (banned, ADR-031), and not only a single burned shell.

---

## 2. Why the modular build pays off here

The hooch is **62 shell modules**: 8 half-wall + 8 screen bays per long wall, 4 per gable,
16 roof panels. Every one is already a separate object on a 1.219 m module.

That means destruction can be **per bay**, which gives:

- **partial states for free** — a hooch with two bays blown out and the rest standing, different
  every time, with no authored variants
- **the breach is real** — the collider disables, the navmesh reopens, and men path through the
  hole. That is Pillar 1 working: the wall you blew is the way in
- **no second model to keep in sync** — a `_destroyed` twin drifts the moment the intact one
  changes, which is the fossil law in asset form

**Cost of the alternative:** one authored destroyed model = one binary state, no partials, and
two files to maintain per building.

---

## 3. What still has to be authored

Per-bay destruction covers walls. It does **not** cover these, and they are the actual work:

| # | Piece | Why it can't be emergent |
|---|---|---|
| 1 | **Collapsed roof section** | A roof panel whose supporting bay died must *sag*, not vanish. Hiding it leaves a hole with clean edges and reads as missing, not destroyed |
| 2 | **Charred / torn screen variant** | The screen is alpha-tested cloth. Burnt and hanging is a texture + a few bent verts, not a rubble pile |
| 3 | **Bent frame stubs** | A destroyed bay should leave the 2x4 uprights standing as splinters. Without them the hole is too clean |
| 4 | **Rubble profile for timber** | The rubble MultiMesh is presumably masonry-flavoured. A plank building needs splintered wood, not brick |
| 5 | **Scorch decal** | Cheapest single win for "this was destroyed" vs "this is missing" |

Reuse from the ruins library rather than modelling fresh: `rubble_debris_small.glb`,
`rubble_scatter_tiny.glb`, `wall_remnant.glb`, and `burned_hut.glb` as the charring reference.

---

## 4. The build order that makes this cheap

1. **Intact hooch stays modular.** Never join the shell into one mesh. The moment it is joined,
   per-bay destruction dies and a bespoke destroyed model becomes mandatory.
2. **Every solid bay gets its `-colonly` twin** (already done) — that twin is what gets disabled,
   and disabling it is what reopens the navmesh.
3. **Author the 5 pieces in §3 once.** They are shared by every plank-and-screen building we make
   — hooches, the HQ tent, village huts. Build them at the 1.219 m module so they drop into any
   bay.
4. **Roof rule:** a roof panel is a destructible whose `hp` is tied to the bay under it. When the
   bay dies the roof panel swaps to the sagging variant; when two adjacent bays die it drops to
   rubble.
5. **Then** wire the hooch into `CollisionTable.MATERIALS` — see §5.

---

## 5. The naming trap, and it is armed for this exact building

`CollisionTable._SOFT_NAME_HINTS` (`scripts/world/collision_table.gd:303`) substring-matches
`"hooch"`, `"hut"`, `"thatch"`, `"bamboo"`. `is_soft()` (`:293`) checks the authored `MATERIALS`
table first and only then guesses from the filename — with a `push_warning`, so it is loud rather
than silent. But:

- a `hooch_*.glb` with no `MATERIALS` entry guesses **SOFT** — a plywood-and-screen wall would be
  shootable through, which for the half-wall band is **wrong**
- the hooch is genuinely **mixed**: the screen band above 1.219 m *should* be SOFT (rounds pass),
  the plywood half-wall below *should not*

**So the hooch cannot be one material.** The half-wall and the screen must be separate destructible
parts with separate classes. The modular build already separates them — this is another reason not
to join the shell.

Also: `get_entry()` (`:182`) silently returns a 3x2x3 box for any unlisted model. A 9.75 m hooch
would get a 3 m nav carve. Add the entry when the building is added, not later.

---

## 5b. THE RECOMMENDATION — hooch break bands, on the tree model

Caleb, 2026-08-12: *"if we make the hooch in pieces like we did for trees, could we have
destructible hooches that bit piece apart?"* Yes. Three tiers, and they compose:

**Tier 1 — bay-level (nearly free, the modular build already gives it).**
Each 1.219 m bay is its own destructible. A blast kills the bays in radius: mesh hides, collider
disables, navmesh reopens through the hole (`destructible.gd:191`). Partial states emerge with no
authored variants.

**Tier 2 — promotion on hit, copied from the trees.**
The hooch stands as ONE cheap object with a single collider. First real hit promotes it to its
segmented form, and only then does it own per-bay parts. Cost is zero on every hooch nobody
shoots — which is most of them, most of the time. Break bands by HEIGHT, exactly like the tree's
`cut_low`/`cut_high`:

| Band | Height | Behaviour on break |
|---|---|---|
| `_sill` | 0 → 1.219 | plywood half-wall: splinters, leaves frame stubs, stays as low cover |
| `_screen` | 1.219 → 2.438 | screen bay: tears away almost entirely, it is cloth on a frame |
| `_roof` | 2.438 → 3.05 | corrugated sheet: **hinge-falls**, the same motion the tree crown uses |

The roof hinge-falling onto the blown bay is the single thing that sells it, and it is the tree
system's existing behaviour pointed at a different mesh.

**Tier 3 — the burned shell**, as the terminal state when enough bands are gone. `RUIN_FOR` maps
it; today `hut_timber` already resolves to `burned_hut.glb`, so a hooch entry is one line.

**What Tier 2 requires that Tier 1 does not:** segment art named on a strict convention
(`hooch_<bay>_sill` / `_screen` / `_roof`, mirroring `_stump`/`_stem`/`_crown`), and a break-band
table generated from that art. Copy `tools/gen_veg_break_bands.py` rather than inventing a second
format — and note its failure mode: **no table means silently indestructible, with no error.**

---

## 6. Deliverables for the destroyed hooch

**New art (5 items, shared across all plank buildings):**
- `roof_panel_sag` — collapsed roof variant at the 1.219 module
- `screen_panel_burnt` — torn/charred screen, alpha variant
- `frame_stub` — splintered 2x4 uprights, ~12 tris
- `rubble_timber` — plank splinter scatter for the MultiMesh
- scorch decal card

**Code (small, and it belongs with the other window's fixes):**
- roof panel destructible tied to the bay beneath it
- timber rubble profile selected by material class
- `MATERIALS` entries: `hooch_halfwall` = WOOD-but-not-soft, `hooch_screen` = SOFT

**Not needed:** a `hooch_destroyed.glb`. Say so out loud when someone asks for one.

---

## 7. What this sacrifices

Per-bay destruction will never look as *composed* as a hand-authored ruin. A collapsed building
made of 62 independently-hidden modules reads as "pieces removed", not "structure failed", unless
§3's sag and stub pieces are actually built. **If only one thing on this list gets made, make the
roof sag** — a roof that stays perfectly flat over a blown-out wall is what will break the illusion,
and it is the piece emergent destruction cannot fake.
