# BRIEFING — Mocap → Blender Pipeline Deep Dive

**Convened:** 2026-08-05, overnight, at the Summoner's order.
**Query (his words):** *"Why are we having so much issues with taking footage of gun workings
and then turning that into FPS arms model animations? Or even with the animations we're making
with the NPCs as well. Perform internet research on all of this and come up with a solution
for me to review in the morning that we can improve what we're doing in both workflows."*

## Scope

Two workflows, treated as one pipeline until now:

| Lane | Input | Output | Consumer |
|---|---|---|---|
| **A — Weapon / FP arms** | video of Caleb working a gun (or a broom prop) | `fp_arms_rifle.blend` clips → viewmodel GLB | first-person viewmodel |
| **B — NPC bodies** | video of humans doing a thing (his own, or YouTube) | actions on `PSXRig_*` → `anim_library.glb` | soldiers, crews, chow hall, medical |

## Constraints binding this council

1. **RECONgame is a commercial product.** Anything that touches shipped animation must be
   commercially licensable. (This turned out to be the decisive constraint — see synthesis.)
2. **RECONgame is a war game.** Some research licences explicitly bar military-themed use.
3. **Hardware is fixed and modest:** i7-10850H, 15.6 GB RAM, **Quadro P620 (4 GB VRAM,
   Pascal)**. No GPU delegate exists for MediaPipe on Windows desktop anyway — the current
   stack is CPU/XNNPACK only.
4. **Fossil law** — no parallel second pipeline. Harden, don't replace.
5. **`take.json` is the only contract.** Backends never import `bpy`; the addon never imports
   the solver. Any new solver must slot in behind that contract.
6. **Blender 5.0 only.** Addon code is CPython 3.11 syntax.
7. Demo Day scope is live; this must not become a rebuild that eats the demo.

## The measured record this council was given

- Weapon takes are **48–51 % inferred depth** even at the best camera angle. A 3/4 turn fixes
  *detection* (0.885 → 0.999 core) but barely moves *depth* (51 % → 48 %).
- On his own Mosin footage, **all 40 finger joints came back below the 80 % detection threshold.**
- Game/viewmodel footage as a mocap source is **dead** — 1041 frames probed, hands detected in
  1 %, both hands 0 %.
- Four separate defects on 7/31 were making the FP arms workflow "garbage," and **none of them
  was the mocap being bad**: a stale installed addon copy, `rest_delta` advertised but
  implemented nowhere (frame 0 moved 17,243 mm), autoscale measuring finger bones (returned
  3.99× — life size × 4), and `feature.preview` claimed but drawing nothing.
- Body/crew work *does* come out usable — his words on the artillery clips: *"came out well
  that way, it just took some adjusting."* The complaint there is cost, not failure.

## Architects summoned

technical-director · lead-programmer (pipeline) · animator/rigging (blender-overseer lens) ·
game-designer (what the player actually sees) · **devil's advocate**.
