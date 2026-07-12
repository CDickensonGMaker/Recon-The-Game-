# Weapon Design + ADS Workflow

Established 2026-07-11 on the M14 rework. **Every player gun goes through this before it
becomes a viewmodel.** Goal: guns that read right in PSX style AND aim true — where the
blade points is where rounds land.

## The Workflow (per gun, one gun at a time)

1. **Reference deep-dive.**
   - Real photos: Wikimedia Commons museum side profiles (`noBG` cutouts are gold —
     measure proportions off them). Get published dimensions (overall length, barrel).
   - Game-feel: CoD/Battlefield ADS screenshots via IMFDB (`imfdb.org/wiki/<game>`,
     needs a browser user-agent to download). The games exaggerate: thin rings, big open
     apertures, sight furniture in the lower half of the screen. Match that read, not
     literal scale.

2. **Build in `weapons_us.blend` (or VC equivalent) at real dimensions.**
   - PSX style: side-profile polygons extruded in Y (`prof`), octagonal tubes for barrels
     (`tube`), boxes for hardware. Flat shading, existing material set (Walnut/Parkerized/
     BluedSteel/AluMag). Wood must be flat colors or baked images — NO procedural
     ColorRamp base colors (glTF exports them white; see tools/bake_gun_wood.py).
   - Muzzle at local x=0, butt at x=length, bore axis at a fixed z. Silhouette first:
     stock shape, receiver depth, magazine placement carry the read.
   - If the owner wants to hand-arrange: split into named loose parts (TH_* pattern),
     let him move, then rebuild curves in place preserving his bounding boxes.

3. **Design the ADS irons deliberately.**
   - Construct a **sight line**: y=0, z = bore + sight height, parallel to bore.
   - Rear sight: a real see-through aperture (thin ring, big hole — game-style), centered
     on the sight line. Front sight: base clamped/collared to the barrel (never floating),
     blade tip ON the sight line, protective wings per the real gun (blade ~half wing
     height reads best through the ring).
   - Verify with an ADS render: camera on the sight line behind the aperture, looking
     downrange. You must see blade centered in the ring.

4. **Plant the truth markers** (empties parented to the gun, `matrix_parent_inverse` = identity):
   - `sight_rear_<gun>` — aperture center, on the sight line.
   - `sight_front_<gun>` — blade tip, on the sight line.
   - `muzzle_<gun>` — exact bore exit (y=0, z=bore), rotated so its forward axis
     converges with the sight line at **50 m** (the standard zero:
     tilt = atan(sight_height / 50)).

5. **Verify with renders** (offscreen `bpy.ops.render.opengl`, overlays off, localview):
   side profile vs reference, muzzle 3/4 closeup, ADS view. The owner's eye is the gate.

6. **Pipeline to viewmodel** (existing loop): append into `fp_arms_rifle.blend` → stage
   via pose json + grip nodes → owner poses → lock → export via `tools/export_viewmodel.py`
   (strips all pose-bone constraints; keeps only the gun's idle action). Include the three
   markers in the export set. Then compute `ads_position`/`ads_rotation` analytically from
   the sight markers (bead RECONgame-9h9f) — no hand-tuning.

## Why this guarantees accuracy for the player

- Damage rays fire from the camera. ADS transform (computed from markers) puts the camera
  origin ON the sight line → whatever the blade covers is where the ray lands.
- Tracers/muzzle flash spawn at `muzzle_<gun>`, whose 50 m zero makes the visible bullet
  path cross the point of aim like a zeroed rifle. No lateral error anywhere (everything
  shares y=0).

## Status

- **M14** — full workflow applied (design + irons + markers + zeroed muzzle). Reference
  for all future guns.
- **Thompson 1928** — scratch-built, owner-arranged parts, curved furniture. Still needs:
  ADS irons pass + markers + weld into one object.
- **All other roster guns** — need the ADS pass (steps 3–5) retrofitted; they have designs
  but no constructed sight lines. Track per-gun in beads.
