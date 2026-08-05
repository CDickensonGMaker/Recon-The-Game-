# PROGRAMMER — independent sight

## The hard part of the stretcher is that it is THREE bodies, not one

`civilian.gd` drives one man. `play_first()` picks a clip for the man it is attached to and returns.
There is **nothing in this codebase that phase-locks two actors** — no shared AnimationTree, no
sync group, no leader/follower blend. Six off-duty men are deliberately desynced
(`civilian.gd:436` seeds the pick per man) because desync is what ambient wants. A litter team wants
the exact opposite: front and rear must start the same clip on the same frame and stay there, or
the stretcher scissors.

There is exactly **one precedent** and it is the right one:

```gdscript
# enemy_base.gd:2563-2565
work_clip = "carry_wounded"
if _aid_target.sprite_actor is ModelActor:
    (_aid_target.sprite_actor as ModelActor).play("being_carried", true)
```

One driver owns the pair. It sets its own clip, reaches into the other body's `ModelActor` and calls
`play(..., true)` — the `restart: bool` arg exists precisely so a driver can force both onto frame 0
together. It then owns the other body's POSITION too (`enemy_base.gd:2576-2578` lerps the casualty
to a trailing offset). The other man has no opinion; he is a puppet for the duration.

**The litter team is that pattern with one more body.** A leader (front man) owns:
- his own clip (`litter_carry_front`),
- the rear man's clip (`litter_carry_rear`) and his position (a fixed offset behind, on the
  leader's basis, not a nav path — two navmesh agents will never hold a 1.8m gap),
- the casualty's clip (`laying_idle` / `being_carried`) and his position (between them).

Both carry clips are 2.40s and both load clips are 1.07s, so a single `restart: true` at each phase
change keeps all three locked with no per-frame correction. **Do not** give the rear man a
NavigationAgent and hope.

## The cockpit is nearly free

`seat_system.gd:51` is `const PILOT_CLIP := "cockpit_idle"`. It becomes a small state map, and the
one caller that knows whether the ship is on the ground, spooling, or flying is
`air_traffic.gd`/`heli_lift.gd`. Three clips, one setter, no new node.

The trap: `pilot_flips_switches` is 4.03s and `cockpit_controls` is 1.63s — these are NOT in
`model_actor.gd:_LOOP_NAMES`, and the `_LOOP_PREFIXES` heuristic will not catch them either
(`cockpit`/`pilot` match no prefix). `cockpit_idle` IS in `_LOOP_NAMES` (`model_actor.gd:337`).
So a pilot given `cockpit_controls` today plays it once, freezes on the last frame, and sits there
looking dead. **Whichever of these is meant to hold must be added to `_LOOP_NAMES` in the same
change**, or this ships as a bug that looks exactly like the frozen-quartermaster bug the comment at
`model_actor.gd:350-352` describes.

`cockpit_dead` at 0.33s is a one-shot slump and must stay OUT of `_LOOP_NAMES`.

## The jump clips have no caller because there is no airborne state

Measured: **`NavigationLink3D` appears zero times** in `scripts/` and `scenes/`. There is no vault,
mantle or ledge code. `player.gd:1671` jumps, but the player is first-person — he has a viewmodel,
not a third-person body, so a player jump has no body clip to play regardless.

For an NPC the sequence needed is: leave navmesh → airborne state → apply gravity → detect ground →
pick `hard_landing` vs a soft resume by impact speed → rejoin navmesh. That is a traversal system.
`ally_base.gd:702` / `enemy_base.gd:702` already read `is_on_floor()` but only to gate a body-hot
flag; nothing consumes an airborne duration.

The heli slice is different and is genuinely small: `heli_lift.gd` already sequences the disembark
per man, so appending a `jump_down` step-off and a `hard_landing` tail is a change inside a
sequence that already exists.
