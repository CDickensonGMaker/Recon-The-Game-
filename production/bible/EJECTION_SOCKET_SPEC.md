# Case Ejection — the Blender ⇄ Godot contract

**Ratified 2026-07-29.** Measured, not assumed: every claim below has a probe
(`tests/probe_eject.tscn`, `tests/probe_eject2.tscn`).

## The short version for the Blender window

**You author the GUN. Godot authors the BRASS.**

You never key a casing. You place one static empty and animate the gun's own
moving parts; Godot reads that empty at the instant of fire and spawns the case.

---

## 1. What Godot actually does (verified)

`eject_M16A1` is a **static Node3D** parented to `M16A1_gun` — measured travel
across the whole `fire` clip is **0.0000 m**. It is a spawn socket, and that is
exactly right. At fire time Godot reads its world transform and launches a
rigid-body case from it.

Timing comes from **code**, not the clip. `weapon_holder.gd:918-922` already
plays the clip and rescales it (`speed_scale = clip_len / duration`) to match the
weapon's fire rate, so the game already knows the exact moment the shot happened.

## 2. What Godot CANNOT do — do not plan around it

**Timeline markers and Call Method tracks do not survive the pipeline.**

The imported clips are embedded sub-resources of the GLB — measured resource path
`res://assets/player/viewmodels/m16_fp.glb::Animation_nmm3d`. A method track can
be added at runtime, but it is **destroyed on the next reimport**, and every
export reimports. If you author eject events on the Blender timeline expecting
Godot to fire them, they will silently evaporate.

*(The supported escape hatch is Advanced Import Settings → the animation →
"Save to File", which extracts the clip to a `.res` you own. It works, but it adds
a hand-maintained artifact per clip and cuts against the export-only pipeline law.
Not recommended — the code-driven route costs nothing.)*

---

## 3. THE SOCKET SPEC

| Rule | Value |
|---|---|
| Name | `eject_<GunId>` — e.g. `eject_M16A1`, `eject_AK47`, `eject_Mosin` |
| Type | **Empty → Plain Axes.** Never a mesh. |
| Parent | The gun body object (`M16A1_gun`, `AK47`, `Mosin_body`) — **not** the skeleton, **not** a reciprocating part |
| Scale | **1.0, applied.** A scaled socket corrupts the spawn basis |
| Keyframes | **NONE.** It must be static; it rides the gun because it is parented |
| Placement | At the mouth of the ejection port, just proud of the receiver so the case does not spawn inside collision |
| **Orientation** | **+Y (Blender) points the way the brass flies.** |

### Why +Y

Blender **+Y** → Godot **−Z**, which is Godot's own forward for a Node3D. This is
the same convention already proven on the vehicle pintles, so there is exactly one
facing rule in this project instead of two. Godot reads the direction as
`-socket.global_transform.basis.z`.

Aim it the way a real case leaves: **out to the right, slightly up, slightly
rearward** for the M16/AK/Mosin family. Roll about that axis is free.

---

## 4. CURRENT STATE — all four existing sockets are non-conforming

Measured local bases. There is no shared axis between them, so a socket-driven
eject direction would throw brass a different way on every gun:

| Gun | Node | Verdict |
|---|---|---|
| `m16_fp` | `eject_M16A1` | Empty, correct parent. **Arbitrary rotation** — needs re-aim to +Y |
| `ak_fp` | `eject_AK47` | Empty, correct parent. **Arbitrary rotation** — needs re-aim to +Y |
| `mosin_fp` | `eject_Mosin` | Empty, correct parent. Axes are a clean 90° swap, still **not +Y** |
| `m60_fp` | `M60_MG_insert_ejectingzone.016` | **WRONG ON EVERY COUNT** — it is a MESH, not an empty, carries non-uniform scale **2.266** on X, and does not follow the `eject_` name. Replace it. |

Position is fine on all four; only orientation (and the M60's type/name) needs work.

## 5. MISSING — 9 of 13 viewmodels have no socket at all

Have one: **m16, ak, m60, mosin.**

Missing: **m14, m70, ppsh, colt45, m79, ithaca, rpd, rpg2.**

`m14`, `m70`, `ppsh` and `colt45` already ship a `jam` clip but have nowhere to
throw brass from. `m79` breaks open and `rpg2` is a launcher — neither ejects, so
neither needs one. `ithaca` and `rpd` do.

---

## 6. What TO animate (this is the part Godot cannot do for you)

In the `fire` clip, and this is already right on the M16:
- **Charge handle / bolt carrier** reciprocating — `M16A1_charge_handle_slide_back`
  is a position track in the fire clip today.
- **Dust / port cover** opening — `M16A1_port_cover` is a rotation track today.
  **Only the M16 has one.**

In the `jam` clip (1.867 s on the M16): the short-stroke, the stuck case standing
proud, and the mortar-and-clear. Godot ejects the stuck round at a scripted offset
into this clip.

## 7. What NOT to animate

- **No casing mesh in the GLB.** No arc, no spin, no bounce, no keys. Godot spawns
  and simulates it.
- **No timeline markers or events** — see §2.
- **No keys on the socket empty** — see §3.
