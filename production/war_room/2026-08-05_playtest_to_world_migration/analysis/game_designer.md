# GAME-DESIGNER — what the player is supposed to feel, and which of these deliver it

## The acceptance test is his, and it is one sentence

*"I don't really feel like I'm in danger."* (Summoner, 2026-08-04.) Every item in this migration
gets scored against that, not against a diff.

## Scored

| Item | Does it move "I feel in danger"? |
|---|---|
| Shoot-through materials in the world | **Already shipped, and it is the single biggest one.** A thatch hut that stops bullets is a bunker; a thatch hut that does not is a place you can be killed while you think you are safe. This is live — huts, temple, camps, firebase. |
| RTO strikes with the tuned values | **Already shipped.** The danger it adds is *his own steel*: danger-close 45 m, the 5 s confirm, the 40 m no-overfly. Live in the world. |
| Village huts get HP | **Weakly.** Flattening a hut is spectacle. It becomes danger only when it removes the cover he was using — which it does — and when the VC react to it, which they do not. |
| Felled trees become real cover | **Strongly, and in the direction he did not ask for.** The value is not that he gains cover. It is that *the enemy* gains cover, and that a bombardment rearranges the ground under a fight already in progress. |
| Felled trees stay decoration | **Negative.** Today a blast deletes cover and hands back nothing. Bombardment currently makes the jungle *safer to cross*, which inverts the fantasy. |
| Segmented trees (break at blast height) | Real, but it is a fidelity upgrade on a system that first has to matter. Do not do it before the log is cover. |
| Arena's spotting constants | No. It is scaffolding. |
| Arena's multipliers / mirror mode | No. Instruments. |

## The one design point I want in the decree

**Destruction that only subtracts is anti-tactical.** Right now every explosive in the game is a
*clearing* tool: it deletes trunk cover, it will delete huts, it flattens. Nothing any weapon in this
game does *creates* terrain.

Vietnam firefights read the other way — the ground gets uglier, not tidier. A downed tree is the
most iconic piece of cover in the entire genre, and the game already models it correctly on two
benches (`fellable_tree.gd:129-140` lays a real capsule collider along the fall direction) and
throws it away in the world he actually plays.

**If exactly one thing on this list ships, it should be that the fallen tree is cover.** It is the
only item that changes what a firefight *is* rather than what it *looks like*.

## What I will not let the council promise him

Buildings with HP will not make the demo feel more dangerous. He will enjoy watching a hut collapse
for about ninety seconds. It belongs in the migration because the world should obey the same laws
everywhere — the firebase being the only destructible place in a destructible-feeling game is an
inconsistency he will find — but it is an **atmosphere and consistency** item and must be sold to
him as one, not as a danger item. ADR-031 said so first: *"buildings buy atmosphere but no new
verb."*
