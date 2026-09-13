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
- RULED (9/12 night): "the gore piles arent quite what i was thinking. lets make just one person
  gored out with their guts and maggots … and once we get that good we can go from there." One
  whole US grunt, dead on his back, cavity open, guts spilled, face intact. The six piles stay
  on disk but are NOT the direction. Get the single corpse right first, then variants.
- He edits faces himself in his live Blender window now (cast file open with sniper + WW1
  appended into REVIEW_APPENDED; strip before export). Write-back + re-export is my job when
  he says done.
- 2026-09-13, Caleb, verbatim: "McCleary is a larger and bulkier dude with large forarms and a
  larger jaw always chewing on a cigar and has a bandana on most the time but someitmes has a
  helmet. Lt Champs is a younger but sharp black guy with a real cool head on his shoulders."
  → McCleary: bulk + forearms + jaw + cigar + bandana default / helmet alt. Champs: young Black
  Lt., composed. Also ruled: corpse legs flat, no twisted elbows, guts+maggots must READ; WW1
  needs a real quality pass; Sgt + Champs get built now.
- 2026-09-13, Caleb, verbatim: "i think the real win is making a gore pile of one single person
  for each npc type in a few various ways as well as a few that are propped up onto trees or
  something and all of them can be sprinkled into the terrain." → DIRECTION: a corpse matrix,
  factions (US / NVA / VC / civilian) × poses (supine, prone, propped against a tree, slumped
  sitting), from the one-command `tools/gore_corpse/build_gore_corpse.py`; the engine sprinkles
  them through the AO stamp (propped ones need a tree anchor). Six-man piles are dead. Gate:
  the single US supine corpse (v2) gets his look verdict first.
- 2026-09-13, Caleb, verbatim: "we could have a dogtag recovery from dead us soldiers and pilots
  they find, as well as intel or chance to recover a item for your necklace." → CORPSES ARE
  INTERACTABLE. Design for the engine decree (not built):
    · US dead + downed pilots → dog tags (KIA recovery; feeds rank/standing per ADR-018 and the
      squad's read of you — Pillar 4; a pilot's tags are worth more, he was somebody's air).
    · NVA/VC dead → chance of INTEL (map / document / diary → reveals a site or a patrol route
      on the seeded AO; Pillar 3, the world generates the story).
    · Any corpse → chance of a NECKLACE CHARM from the charm library (tooth, crucifix, round,
      P-38, medallion, dog tags); ears stay the atrocity path (`_take_ear`, witnessed, H&M cost
      per ADR-019). Charm vs ear is the moral fork on the same body.
    · One interact verb on the corpse prop; loot table by faction row; the corpse matrix props
      carry a `loot_socket` empty where the hand goes.
  Engine wave = placement + soft-cover rows + maggot/fly fx + this loot verb, one decree.
- RULED 2026-09-13 (corpse interact): SEARCH is the prompted verb (hold interact, weapon lowered
  ~3 s) → tags / intel / charm by loot roll. TAKING AN EAR IS NEVER PROMPTED — knife out, crouch
  at the head, hold attack; witnessed per `_take_ear`. Caleb: "we have to at least tell the
  player about it once because otherwise its just a hidden system" → the teach is GUS, once,
  diegetic: first enemy body searched with Gus in the squad, he says it (or does it, Issue 3 p9
  beat) and offers the next one. No UI ever names it. If Gus is dead it is never taught.
