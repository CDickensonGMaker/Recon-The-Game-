# FIREBASE — NEED TO DO BEFORE / DURING EXPORT

**Written 2026-08-07 at his request: *"write all of that as NEED TO DO for FIREBASE to export into
the game to help us keep on track."*** His framing: *"a lot of the game hinges on me finishing the
firebase."*

Every claim below carries a `file:line`. Where I could not verify something, it says **UNVERIFIED**.

---

## A. HIS ART QUEUE (his own order, 2026-08-07)

| # | Item | State |
|---|---|---|
| 1 | Medical complex animations | was last working on |
| 2 | Placing the artillery guns | — |
| 3 | Mortar animations | **IN PROGRESS** |
| 4 | HQ building + its animations | not started |
| 5 | 3 new hooches — screened-in, real-building feel; **one an underground dug bunker** (PLATOON, where the hippy types hang out) | not started |
| 6 | Confirm player + NPCs can **get inside bunkers**, + hanging-out-in-a-bunker animations | **code question — see C** |
| 7 | Confirm you can **shoot out of bunker slits** and **be hit through them** | **code question — see C** |

---

## B. THE ONE THING THAT COULD COST A RE-EXPORT — MESH WINDING

**Read this before exporting.** `site_planner.gd:1266-1271`:

> *"EVERY structure in the shipped GLB winds inward — measured 2026-08-02, signed volume is negative
> for all 19 families tested… ConcavePolygonShape3D only collides on its FRONT FACE, so the ground
> and the walls were both one-sided."*

The game currently papers over this at runtime: `_force_backface_collision` (`:1272`) walks the whole
tree and forces every concave shape double-sided. The root cause was **fixed at source** in
`tools/gen_firebase.py:146` (*"Faces wind CCW seen from OUTSIDE"*).

**Your verification signal.** On boot the firebase prints:

```
[FSB] N concave shape(s) forced double-sided (inward winding in the shipped GLB)
```

- **N > 0** → the new export still winds inward; the runtime patch is carrying it.
- **N == 0** → the export is correct and the patch is now dead weight (we then delete it — fossil law).

**This matters most for exactly the two things he wants to confirm**: one-sided walls are why you
could stand *inside* a bunker and have rounds pass straight out through the wall.

---

## C. THE TWO CONFIRMS — WHAT THE EXPORT MUST CARRY

### C1 — Getting inside a bunker / hooch

An enterable building must ship **`-col` trimesh collision**, not an authored box.
`site_planner.gd:181-184` is explicit:

> *"the authored box would double the collision AND block doorways/breaches, so skip it"*

Its kit entry must therefore set **`mesh: true`**, or the box seals the doorway shut and no one gets
in regardless of how the interior is modelled.

**So for the dug bunker and the 3 hooches: model the interior as real hollow geometry, export
`-col` trimesh, register with `mesh: true`.** A box-collided hooch can never be entered.

### C2 — Shooting out of a slit, and being hit through it

Three separate things must all hold, and they fail independently:

1. **The slit must be a real hole in the collision trimesh.** A box hull seals it — same root cause
   as C1.
2. **The winding must be correct (section B)**, or the slit is one-sided: rounds pass one way and
   not the other.
3. **The material tag must be right.** `_tag_fsb_ballistics` (`:1348`) grades by mesh family, and the
   comment (`:1345-1348`) is the law: *"Canvas, plywood and tin are CONCEALMENT — a GP tent, a hootch
   wall or a water trailer does not stop a 7.62. Everything else on this compound is filled sandbags,
   earth, timber."* A **screened-in** hooch wall is concealment, not cover — which is exactly the
   feel he is going for, and it must be tagged that way or screens will stop bullets.

**UNVERIFIED:** I have not put a round through a slit in a live scene. The mechanism is right on
paper; it is a playtest item, and `test_bullet_flight` now proves the sweep resolves against Area3D
hitzones and layer-1 bodies correctly (`bullet_system.gd:123`).

---

## D. NAMING CONTRACTS — GET THESE RIGHT AND NOTHING NEEDS RE-EXPORTING

### D1 — Destruction + penetration
Already a documented skill: **`recon-destructible-export`**. Names decide both penetration and
destruction, and **both defaults fail silently**. New ruling 2026-08-07: **only explosives demolish
a building; gunfire penetrates.** Enforced at `destructible.gd:35`.

Buildings now get HP by **mesh-name prefix** (`site_planner.gd` `FSB_STRUCTURE_KINDS`) — no manifest
entry and **no re-export needed** to add a family. New hooches/HQ should use a stable prefix.

### D2 — Ruins
A destroyed building swaps to a burned shell (`Destructible.RUIN_FOR`). Today one generic
`burned_hut.glb` covers all houses. **His ask: one burned version per building.** Zero code work when
they land — drop the GLB in `structures/ruins/` and extend the map.

### D3 — Markers (HQ, hooches, bunker hangout)
- Prefix **`work_`**, convention `work_<building>_<role>` (`site_planner.gd:495`).
- Export as plain **`Node3D`, never `Marker3D`** (`:543-545`).
- Matching is `begins_with`, so number them freely: `work_hq_plot_01`, `work_bunker_hang_02`.
- **Tree order is not sorted** — number any sequence that has an order.
- A new role needs one line in `FSB_WORK_OCCUPATION` (`:830`). **Tell me the role names before you
  export and I will map them ahead of time**, as was done for the chow hall's tray return.

### D4 — Chow hall
`CHOW_HALL_EXPORT_CONTRACT.md`. Six of his seven diner stages already have locked markers; **stage 6
(return the tray) needed a new one** — `work_chow_tray_return`, already mapped code-side.

---

## E. WHAT CODE OWES HIM (not blocked on art)

- [ ] Chow-hall diner state chain — buildable now against the contract, runs the moment he exports.
- [ ] Bunker hangout occupation + clip routing — needs his role names (D3).
- [ ] HQ occupation mapping — needs his role names.
- [ ] Delete `_force_backface_collision` once his re-export prints **0** (section B).
- [ ] `plan_demo_world` has **no automated test** — the EA product's own planner is uncovered.
