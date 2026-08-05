# The CC0 stock arm clips, and what each equipment item borrows from them

Measured in the live `assets/player/arms/fp_arms_rifle.blend` on 2026-07-30. All 19 stock
actions survive in the file, all on the same 52-bone skeleton every `ArmsRig_*` uses, all
**sparse-keyed** (3–13 keys, not baked) — so they retarget by copying pose-bone values 1:1,
with no solving. Source: PSX First Person Arms v1.1.0, Drillimpact, CC0 (`SOURCE.md`).

## Actual roster (there is no `open` clip)

| action | frames | keys | note |
|---|---|---|---|
| `relax` | 1–60 | 4 | idle breathing, both arms empty |
| `rest` | 1–2 | 2 | the neutral pose — the retarget base |
| `grab.L` / `grab.R` | 1–22 | 9 | reach out, close the hand, pull back |
| `push.L` / `push.R` | 1–24 | 8 | flat palm press away from camera |
| `jab.L` / `jab.R` | 1–30 | 10 | straight punch out and back |
| `guard_draw` | 1–19 | 5 | hands up into a fighting guard |
| `guard_idle` | 1–65 | 5 | that guard, breathing |
| `knife_draw` | 1–13 | 4 | blade comes up into frame |
| `knife_idle` | 1–50 | 3 | blade held, slow sway |
| `knife_hit_01` / `_02` | 1–21 / 1–22 | 6 / 7 | two stab variants |
| `finger_gun_idle` / `_fire` / `_broken` / `_fix` | 1–60 / 15 / 60 / 40 | 4 / 6 / 4 / 13 | `_fix` is the only two-handed fiddling clip in the set |
| `flashlight_idle` | 1–1 | 1 | ours, not stock (52 bones — keys `hand.*` too) |

## The engine only has three item clip slots

`weapon_holder.gd:939` auto-plays **`charge_handle`** when a viewmodel is equipped, and
`:934` plays **`rifle_idle`**. There is no `equip` and no `holster` — nothing plays on
holster at all. So the Half-Life/Counter-Strike deploy is free (`charge_handle` *is* the
deploy slot) and a holster animation needs new code. `SPEC.md` in this folder calls for
`equip` / `holster`; it is wrong on that point and is corrected here.

Item vocabulary, exactly, no extras (`tools/viewmodel_manifest.json` → `items`):
`rifle_idle` = the held pose · `charge_handle` = the draw · `fire` = the action.

## Borrow map

| item | `charge_handle` (draw) | `rifle_idle` | `fire` |
|---|---|---|---|
| radio | `grab.R` — the reach becomes the raise to the ear | author: fingers flexing on the bar; take the breathing from `relax` | — (no action clip) |
| claymore | `grab.R` + `grab.L` — two-handed lift | both hands on the mine, slight sway | `push.L`/`push.R` — the plant is a two-handed press |
| bandage | `grab.L` | packet held, slight sway | `finger_gun_fix` — 13 keys of two-handed fiddling, the wrap |
| grenade | `grab.R` | held, thumb over the spoon | pin pull off `grab.L`; throw off `jab.R` |
| knife | `knife_draw` | `knife_idle` | `knife_hit_01`, alt `knife_hit_02` |

The knife needs no retarget at all — the stock set already **is** its clip set.

## Separate track: stock clips as new player verbs

`grab.L/R`, `push.L/R`, `jab.L/R`, `guard_draw/idle` are authored, unused, and cost
nothing but wiring. They are not viewmodel work — they are new player verbs (open a door,
shove a man, unarmed strike, hands-up) and need a design ruling and engine code before
any of them means anything. Recorded here so they are not lost; not in scope for the
equipment viewmodel pass.
