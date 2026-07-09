# FP Arm Animation Spec — RECONgame

Base rig: `arms_rig.blend` (PSX First Person Arms, CC0). 52 bones, both arms,
3 phalanges/finger + thumb, palm bones, IK handles: `handIK.R/L`, `elbowIK.R/L`,
plus a `camera` bone. Ships with: knife_draw/idle/hit_01/hit_02, grab.L/R,
guard_draw/idle, jab.L/R, push.L/R, finger_gun_*, relax, rest.

## Principle (how the 1998-2007 era did it)
ONE rifle arm set, reused across every shoulder gun. Bespoke sets only where the
LEFT (support) hand has nowhere familiar to go. Within a set, guns differ by
support-hand Z-offset along the weapon + the reload sub-clip. Not a new skeleton.

Minimal clips per set: **idle, fire, reload, draw** (+ optional holster, sprint/lower).

## The 5 sets and our roster

### SET 1 — RIFLE  (author first)
Covers: **M16A1, AK-47, M14**. Mosin = this set + bolt_cycle overlay.
- Right hand: pistol grip, index on trigger, wrist slightly pronated. Grip at chest-right, low in frame.
- Left hand: cups UNDER the handguard/forestock, fingers wrapped, thumb over top. Slide along weapon long-axis per gun (M16 fwd-low, AK lower handguard, M14 under wood forestock).
- Weapon: buttstock in right shoulder pocket, bore runs up+slightly inward, canted ~5-15 deg inward, receiver reads 3/4. Lower-right of screen.
- Reload (mag): left releases handguard -> strips mag -> off-screen -> fresh mag up into well -> slap -> charge (M16 bolt-release ping, AK rock-and-lock, M14 mag). Right stays on grip.
- Clips: rifle_idle, rifle_fire, rifle_reload, rifle_draw. Variant: bolt_cycle (right hand lifts/pulls/pushes/rotates bolt, left anchors), reload_stripper.

### SET 2 — SMG
Covers: **PPSh-41** (+ future Thompson/MP40).
- Right hand: grip/stock wrist.
- Left hand: PPSh has NO foregrip -> grip wooden stock behind the drum, or the lower edge/side of the drum. Never the barrel (heat). Thompson/MP40: foregrip or mag housing.
- Carry: closer to chest, more canted, compact.
- Reload (drum): left releases drum catch, drum drops away (big down motion), fresh drum hauled up + slotted from below/front, charge. Slower than a stick mag.
- Clips: smg_idle, smg_fire, smg_reload, smg_draw.

### SET 3 — SHOTGUN  (future; no unit yet)
Pump. Right at shoulder, left on the fore-end (forward of a rifle handguard).
Cycle: left racks fore-end back-toward-camera then forward (~0.3-0.5s) per shot.
Reload: shell-by-shell, gun rolls to expose port, thumb shells up tube, final rack.

### SET 4 — LMG  (bespoke)
Covers: **M60, RPD**.
- Held LOWER + heavier than a rifle. Hip/underarm in run, shouldered but bulky.
- Right hand: pistol grip.
- Left hand: on the CARRY HANDLE / barrel shroud (M60) or wooden foregrip/lower handguard (RPD). Forward + up, NOT cupping underneath.
- Belt hangs from right feed side and sways; RPD drum sits under. Pushes weapon lower.
- Reload (feed tray): left flips UP the top feed cover, clear belt, lay fresh belt across tray, slam cover shut, charge. Long, ~3-5s, two-handed.
- Clips: lmg_idle, lmg_fire (more climb), lmg_reload, lmg_draw.

### SET 5 — RPG  (bespoke, least reusable)
Covers: **RPG-2** (RPG-7-style handling).
- Tube OVER the right shoulder, angled up-fwd, runs diagonally across upper-right of screen, warhead protrudes fwd-left of center. Camera sits left+below the tube.
- Right hand: pistol-grip/trigger group beneath the tube, lower-right.
- Left hand: forward on the wooden heat-guard grip mid-tube.
- Aim ALONGSIDE the tube (left-side sight), not through it.
- Reload (front): left fetches rocket, inserts warhead stem into the muzzle end, twists/seats; right re-cocks external hammer.
- Clips: rpg_idle, rpg_fire, rpg_reload, rpg_draw.

## Authoring order
1. RIFLE set on the M14 (unlocks medic + M16 + AK immediately).
2. LMG set (M60/RPD).
3. SMG set (PPSh).
4. RPG set.
5. Shotgun + sniper bolt variant + pistol as those weapons are added.

## Godot delivery (decided)
Arms mesh + Skeleton3D in the viewmodel scene. Weapon = separate mesh on a
BoneAttachment3D at `hand.R`. Play the matching arm set per weapon; weapon rides
the hand. Per-weapon alignment = offset from the hand bone, tuned in the viewmodel
editor. SubViewport second camera (from Catacombs `first_person_arms.gd`) renders
the viewmodel on top at its own FOV, no wall clipping.

Reference frames: IMFDB Battlefield:Vietnam (M16/AK/M60/RPG/Thompson in-setting),
Day of Defeat wiki (shared rifle hold differentiated by reload only).
