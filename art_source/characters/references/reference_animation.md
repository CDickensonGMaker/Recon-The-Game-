# Animation Reference — Walk Cycles, Rifle Carry, Retro FPS Frames

Research compiled 2026-07-07 for Hell of Duty sprite units.

## 1. Classic 4-Pose Walk Cycle (Williams + gait biomechanics)

Poses: **Contact → Down → Passing → Up**, mirror for second half. 24 frames/cycle @ 24fps (12 per step). PS1-era walks: 8 keys total, or 4-frame sprite loops.

| Joint (leading leg) | Contact | Down | Passing | Up |
|---|---|---|---|---|
| Hip/thigh swing | +25 to +30 (fwd) | +10 to +15 | 0 | -10 to -15 (back) |
| Knee bend | 0-5 | 15-20 | 40-50 (max) | 30-40 |
| Ankle | -5 to 0 | +5 to +10 | -10 (toe clears) | +15 to +20 (push-off) |

| Channel | Contact | Down | Passing | Up |
|---|---|---|---|---|
| Arm swing (shoulder) | ±25-30 | ±20-25 | ~0 | ±15-20 |
| Elbow bend | 10-15 | 15-20 | 20-25 | 10-15 |
| Torso lean fwd | 5-8 constant | — | — | — |
| Hip twist (Z) | ±5-8 toward fwd leg | ±4 | 0 | opposite |
| Hip roll | ±3-5 | max | 0 | opposite |
| Vertical bob | mid | LOWEST | mid | HIGHEST |

- Hip range: +30 fwd / -10 back. Knee peak flexion 45-50 (65 for march).
- Bob: 4-7% of leg length (stylized up to 10%). Down = lowest, Up = highest.
- Arms contra-lateral: right arm fwd with left leg.
- Chest counter-rotates hips ±5-10.

## 2. Rifle Patrol Walk (two-hand low carry)

Legs/torso identical to normal walk. Upper body changes:
- **Arm swing: ±3-5 only** (arms are a rigid ring holding the gun, not pendulums)
- Right elbow bent **75-90°**, drawn back near ribs. Hand on pistol grip.
- Left elbow bent **100-120°**, forward/lower. Hand on handguard.
- Rifle across body, **muzzle 20-30° below horizontal** (low ready 30-45).
- Torso lean **8-12°** forward. Chin down, eyeline over weapon.
- Reduce chest counter-rotation to ±2-4 (shoulders stay "aimed").
- Keep left-arm angles nearly constant across all keys; accept 1-3cm hand float — err toward hand slightly inside the handguard. Invisible at sprite res.

## 3. Blender Prop Bone Rules

- Object-to-bone parenting attaches relative to the bone **TAIL** (documented gotcha).
- Weapon bone: child of right hand, **tail at the pistol grip** → rotations pivot at grip.
- Zero the mesh local offset (grip coincides with bone anchor).
- Child-Of constraint instead of bone parent only when swapping hands/holstering (influence slider + Set Inverse).

## 4. Retro FPS Sprite Frame Counts (Doom conventions)

| State | Frames | Notes |
|---|---|---|
| Idle | 1 | all 8 rotations |
| Walk | 4 (looped) | × 8 rotations |
| Fire | 2 | pre-fire + muzzle-flash/recoil, ~0.1-0.2s |
| Pain | 1 | |
| Death | 5 | stagger → knees buckle → mid-fall → near-ground → corpse. **Rotation 0 (one angle only)** |
| Gib death | 8-9 | |

Recoil (rigged): weapon kicks up/back 5-10° over 1-2 frames, ease back over 2-3.
Death keys: hit/stagger, lean back, hip collapse, ground impact, settle. ~0.4-0.6s.

Sources: Musculoskeletal Key biomechanics, UW CSE459 walk cycle notes, Animator's Survival Kit, MoCap Online weapon-animation guides, Blender manual (bone parenting), DoomWiki sprite docs.
