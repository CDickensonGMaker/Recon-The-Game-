# US Armory Audit — `weapons_us.blend` — 2026-07-24

Headless audit ahead of authoring first-person weapon animations. 209 objects,
132 roots, 4 collections, 73 actions.

## Headline

**The gun parts are already separate objects. They are not parented, and not named.**

The blocker is *assembly and identification*, not modeling. Nothing needs to be cut apart
except the Thompson.

## Assembly state

| Weapon | Mesh objs | Tris | Parented | Loose but in place | Status |
|---|---|---|---|---|---|
| M16A1 | 36 | 744 | **2** | 21 (+13 in a second cluster) | parts loose |
| M60_MG | 73 | 1,144 | **1** | 65 | parts loose |
| M14 | 6 | 744 | 6 | 0 | assembled |
| Colt45_Pistol | 11 | 220 | 11 | 0 | assembled |
| Thompson | 1 | **1,919** | 0 | 0 | **single mesh, never split** |
| Ithaca37 / M70 / M79 / M72_LAW / M26 | — | — | all | 0 | assembled |

The loose parts sit at correct world positions — they visually form the weapon, they just
have no parent and carry auto-increment names (`M16A1.017`, `M60_MG.028`). For animation
each one needs a real name.

## The marker contract holds

Every assembled weapon carries the same five empties, which is the foundation the arm IK
will bind to:

```
grip_LeftHand_<gun>   grip_RightHand_<gun>
muzzle_<gun>          sight_front_<gun>   sight_rear_<gun>
```

Pistol and grenade correctly carry `grip_RightHand` only.

## Parts already split and named (usable today)

| Weapon | Named moving parts |
|---|---|
| Colt45_Pistol | slide, hammer, trigger, trigger_face, **magazine**, magfloor |
| M60_MG | chandle, feedcover |
| M70sniper | bolt |
| Ithaca37 | pump |
| M79_Launcher | barrel (breaks open — this *is* the reload), rear_leaf |
| M72_LAW | inner_tube (telescoping extend), trigger_bar, caps, bands |
| M16A1 | chandle |
| M14 | chandle, **chandle.001/.002/.003** (4 total — likely duplicates), shoulderrest |

**Only the Colt45 has a named magazine.** Every rifle reload is mag-out/mag-in, so
identifying the magazine object inside the loose M16A1/M60 pools is the single highest
-value next action.

## Open questions

1. **The M16 has two clusters.** 21 parts at x≈3.15–3.56, and 13 more at x≈2.65–2.80 —
   about half a unit apart. This is the "two armories on the M16 ruler". Which cluster is
   canonical? Nothing gets deleted until that's answered.
2. **`PARTS_OLD` holds 36 objects; `PARTS_NEW` is empty.** A reorganisation was started and
   stalled. All M16A1 parts live in `PARTS_OLD`; M60 parts live in `Scene Collection`.
   Per ADR-023 the fossil goes once its replacement exists — but not before.
3. **M14 has four charging handles** at x = 2.68 / 2.84 / 3.02 / 3.00. A rifle has one.
4. **Thompson is 1,919 tris** — nearly 3× the next-heaviest gun (M14 at 744) and the only
   truly unsplit weapon.

## Junk in the file

`Cube.004` (5,989 tris — the largest object in the file), `Camera`, `Light`, `Armature`,
`4e1e45f1092c4a8e925bb6d2e2377b74.fbx`. Import debris, safe to remove once confirmed.

## Actions

All 73 actions are **body** animations on `PSXRig` (`walk_forward`, `sprint_left`,
`death_from_back_headshot`, `reloading_fixed`, `firing_rifle_fixed`) — the third-person
soldier set, present because `REF_SOLDIER` holds `PSXRig` + `us_grunt_joined` as reference.

**There are zero weapon-part animations.** First-person weapon motion starts from nothing.

## Recommended order

1. Name + parent the M16A1 loose parts (21 objects) — resolve the two-cluster question first.
2. Same for M60_MG (65 objects).
3. Split the Thompson.
4. Delete M14's three duplicate charging handles.
5. Author reload clips against the timing standard in
   [`fps_arms_animation_study_2026-07-24.md`](fps_arms_animation_study_2026-07-24.md).
