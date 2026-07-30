# firebase_main.tscn — the firebase as a real Godot scene

**Ruling, 2026-07-29:** *"we make the main firebase a real scene in godot and give me spawn
markers that i can place."*

## What it is

An **inherited scene** whose root IS `fsb_main_v3.glb`. Open it and every node in the model is
in the tree, selectable, and movable. Anything you ADD sits alongside the model's own nodes.

This matters more than it looks: **added nodes live in the .tscn, not in the GLB.** Re-export
from Blender as often as you like — the model updates underneath and every marker, tweak and
hand-placed node you added stays exactly where you put it. That is the whole reason to make it
a scene instead of loading the GLB directly.

## Spawn markers

`SpawnMarkers/spawn_bunk_01`, `spawn_bunk_02`, … — any `Marker3D` whose name starts with
`spawn_bunk`.

- **Add as many as you like.** Duplicate one, drag it where you want a man to wake up.
- The game takes the one **nearest the compound centre**. The rest are alternates.
- **It is used exactly as placed.** No floor raycast, no snapping, no reseating. If you put it
  half a metre above the cot, that is where he stands.

The two shipped ones are a starting guess and are almost certainly not where you want them —
open the scene, move them onto a cot you like, save. That is the whole workflow.

If a world has no `spawn_bunk` marker at all, the old behaviour is still there as a fallback:
sweep the model's `prop_sleep` markers and take the nearest with a floor under it.

## Why the spawn kept breaking

Worth writing down, because it was three regressions in a row and all three were the same
mistake. The spawn used to be picked by CODE guessing: find cots, raycast for a floor, seat the
player on what it hit. That works only while the ground stays where the code assumes.

Then the ground moved — terrain stopped reproducing the mound and the model became the ground
(his ruling) — and every guess broke in a different way: first the floor test could not reach
the mound and the spawn walked out to a village 142m away, then seating on the ray hit put him
*under* the mound.

An authored marker cannot break that way. **The fix for "the code keeps guessing wrong" is to
stop guessing.**

## What else belongs in this scene

Anything hand-placed inside the compound that should survive a re-export:

- spawn markers (done)
- fixed prop placements you do not want the generator to own
- hand-authored collision patches, if a mound face proves unwalkable and you want to shim it
  rather than re-cut the mesh

Keep GENERATED content in the generator (`tools/gen_firebase_v3.py`) — the parapet, the wire,
the vegetation. This scene is for the things a human decided.
