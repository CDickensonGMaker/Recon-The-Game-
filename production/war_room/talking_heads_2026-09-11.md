# Talking heads for cutscenes — quick decree 2026-09-11

**Query (Caleb):** moving mouths on the PSX rigs for cutscenes. Build for RECON: a human grunt
head, the skull-faced Conquest-of-Worms sniper, and a zombie skull in a helmet — the comic's
"skull in a helmet talking to the reader" beat as a cold open.

**Constraints that bind:** cutscenes are prerendered Blender FMV (ADR-024, no Godot export).
Game asset blends are READ-ONLY source art, appended never edited. 725v/41-bone gameplay
bodies untouched. Skull work follows `skeleton-and-gore-craft` §5 (mandible split, measured
against the CC0 CDmir skull). Never guess in Blender; verify in object space; save as you go.

**Decree:**
- Humans: dedicated CUTSCENE HEAD, ~+100 verts around mouth/eyes, same face-atlas UVs,
  100% Head-skinned, neck ring vert-identical to `grunt_head` so it swaps. Mouth = SHAPE KEYS
  (jaw_open, wide, pucker, blink, brow_up, brow_down). No jaw bone on humans — 4-6 mouth verts
  on the gameplay head cannot hinge.
- Skulls (sniper + zombie): a real low-poly skull with a SEPARATE MANDIBLE on a `jaw` bone
  under `mixamorig_Head`. A skull's jaw is a hinge; shape keys would fake what the anatomy
  already gives. One skull build, two dressings.
- Each head gets a 3 s talking test rendered MGS-style close-up 640x480 Eevee so Caleb judges
  on a render, not a gate table.

**Sacrificed:** a second head asset per speaking face (build only for faces that talk on
camera); neck-seam parity is a hard gate or the swap pops; humans and skulls use two different
mouth mechanisms, so the animator keys shape keys on one and a bone on the other.

**Alternatives rejected:** texture-flip mouth (fine at gameplay distance, dead at close-up);
jaw bone on the gameplay body (breaks the 41-bone fingerprint every variant is gated on).

**Next:** blender-modeler builds all three into `production/cinematics/talking_heads/`.
Caleb reviews the renders. Then blender-overseer authors the actual opening line.

---

# Addendum, same day — the necklace, and the neck gaps

**Caleb:** "weird gaps on the heads and necks of these people and i dont see a ear necklace
around gus at all. so maybe today we should make the idea of the necklace, and the items
that attach to it."

**Facts in reach:** the game already counts ears — `scripts/player/player.gd:243` `_take_ear`,
`CampaignState.ears_taken`, buckets `[1, 3, 6, 10, 15]` (`player.gd:237`). Nothing draws
them. Gus "ears" state carries pink blobs on the suspenders, not a necklace. The dresser
already hangs gear off named sockets on bones (`vc_nva_dresser.gd:440` `_hang`, ChestSocket on
Spine2, HelmetSocket on Head).

**Decree:**
- The necklace is the VISIBLE TROPHY LEDGER. A cord on the Neck bone with N hang slots along
  it; each item is its own tiny GLB snapped to a slot. Ears fill slots by `ears_taken`
  bucket; other charms (dog tags, a round, a P-38, a crucifix, a peace medallion, a tooth) are
  character dressing. Gus wears ears in the comic; the player earns them the same way.
- Art kit first, today: `assets/us/characters/necklace_kit.blend` — cord + charm library,
  PSX budget, Gus wearing a loaded cord in the cast file. Engine wiring (a `NeckSocket` hang
  like the chest rig, driven by `ears_taken`) is the next step, not today's.
- The neck/jaw gaps are a separate defect on the cast heads (dark band behind the jaw, pale
  banded neck under the chin). Diagnose against `grunt_head` in `us_base_v3.blend`, fix on the
  cast heads only, never re-unwrap the canonical head.

**Sacrificed:** the pink blobs on Gus's suspenders go; a per-slot GLB costs a draw each.

**RULED (Caleb, same day): "no 15 is a solid amount."** The cord holds 15 slots and the top
bucket shows fifteen real ears. The 8-slot cap is dead.

**RULED (Caleb, same day): "the faces are too small for the heads where we need to spread out
the uv more so it fits better."** The CoW face cells are whole painted heads (hair, ears, jaw)
but the mesh samples only an eyes-to-mouth strip and pads the rest with one pixel. Fix = a
measured full-cell head projection on the three cast heads + the two cutscene heads. This
overrides "never re-unwrap the head" for the CoW cast; the stock roster wrap is untouched.

---

# 2026-09-12 additions (Caleb, verbatim)

- "we just need to push the ears back to the sides of all their heads" — painted ears sat on
  the cheeks; re-solving the side-quad mapping to real ear depth on all cast + cutscene heads.
- "the cut off ears need to be more realistic, as well as a few in various stages of decay …
  from fresh to rotten" — one measured severed ear, five stages: fresh → days → rotten →
  dried → old; the flat disc is dead.
- "making gibbed us soldier piles and nva and vc piles to find randomly thru the map. like a
  pile of body parts with guts and maggots crawling out of it … very on brand with my artwork"
  — art first: six static piles (US/NVA/VC × small/large) from the sanctioned gib donors,
  viscera, blood decal, maggot decal + fx anchors, SOFT-cover export prefix. Engine wiring
  (random placement in the AO stamp, maggot/fly particles on the anchors) is the next decree.
- "did we finish making the ww1 soldiers" — NO. The 9/09 pass was blocking only: seven
  figures with placeholder white greatcoat/helmet blocks, rifles floating unheld, and Vietnam
  US webbing on French and German bodies. Not started on finish work.
- RULED: "queue the ww1 finish after the piles." WW1 finish pass (period kit, rifles in hand,
  WW1 webbing, painted greatcoats/helmets) starts when the gore piles land.
