# Equipment viewmodels — radio, grenade, claymore

Spec given by Caleb 2026-07-30. Nothing here is authored yet; all three rigs in
`assets/player/arms/fp_arms_rifle.blend` are bare stubs (armature + arms mesh + prop +
a single `grip_R_*` empty, **zero actions, zero NLA tracks**).

## Models already exist — do not remodel

| prop | verts / tris | dims | note |
|---|---|---|---|
| `Radio_Handset` | 96 / 88 | 48 x 67 x 212 mm | this IS the handheld radio to replace the in-game box. **Rebuilt 2026-07-30** — the original was **9 disconnected intersecting boxes** with both ends tapering to valence-3 points instead of cups, which is why it never read as a handset. Now one lofted body (2 shells: body + PTT bar), manifold, ear cup 48 x 52 mm, mouth cup 46 x 50 mm, neck 32 x 24 mm. Original mesh kept as datablock `radio_handset` with a fake user if it is ever needed. Also reworked from H-189/GR reference: grip bar widened 14x9 -> 32x24 mm, press-to-talk bar added on the back of the grip, cord/U-229 boss added at the mouthpiece end, and the material moved off the shared `OliveDrab` to its own `HandsetBlack` — the real handset is black polycarbonate (Lexan), not olive drab. No published dimensions were found (MIL-H-55258B is paywalled; DTIC AD0295832 and RadioNerds both 403), so the 212 mm length is the model's own, not a sourced figure. |
| `Claymore` | 264 / 136 | 128 x 77 x 192 mm | width is under a real M18 (216 x 82 x 38 mm) — check before it ships |
| `M26_Grenade` | 106 / 104 | 59 x 57 x 74 mm | real M26 is ~57 x 99 mm — slightly short, acceptable |

## The trap: the idle clip MUST be named `rifle_idle`

`weapon_holder.gd:925` `_play_vm_idle()` asks for the literal string `rifle_idle` on
**every** viewmodel, gun or not. An item whose idle is called `radio_idle` plays nothing
and renders in bind pose. This is exactly what broke the Mosin for a day
([[recon-viewmodel-contract-first]]). So every item below ships its idle as `rifle_idle`,
however wrong that reads for a radio.

## Clip sets

All three get Half-Life / Counter-Strike style equip handling: a draw on equip, an idle
loop, and the draw reversed on holster.

**Radio** (RTO air-support call loop)
- `equip` — bring up to the face
- `rifle_idle` — held at the face, **fingers flex up and down slightly**; this is the
  whole idle, no body sway needed
- `holster` — reverse of equip

**M26 grenade**
- `equip` / `rifle_idle` / `holster`
- `pull_pin` — off hand pulls the pin
- `throw` — the projectile already exists in game and flies correctly; this is only the
  viewmodel half, so the release frame has to line up with whatever moment the code
  spawns the projectile

**Claymore**
- `equip` / `rifle_idle` / `holster`
- `place` — **two-handed** placement. The **FRONT TOWARD ENEMY face points AWAY from the
  player** when set down, and the mine is **live/armed the moment it is placed**.
  Gameplay is already rigged in game; this is the viewmodel and the placement orientation.

## Before authoring

None of the three has a `tools/viewmodel_manifest.json` entry, so the validator cannot
check them and a wrong clip name fails silently. Add entries first (gun_root, parts,
clips, `markers_under_gun: false` — these are not guns, so no `SightRear`/`SightFront`/
`MuzzlePoint`, only `grip_R_*` and for the claymore a `grip_L_*`), then author, then
validate.

Claymore placement needs an orientation marker so the engine knows which way the face
points — propose `face_Claymore`, an empty whose **+Y is the kill direction**, matching
the project rule that Blender +Y = Godot -Z ([[recon-vehicle-facing-convention]]).

The radio is the cheapest win of the three: the model is done and unexported, so the box
in the RTO loop can be replaced without waiting on any animation.
