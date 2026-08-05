# PARKED DESIGN — The Cord (trophy tokens) · 2026-08-05

**Status: PARKED by the Summoner — "more just a planned idea not a feature were jumping
into right away."** No build until he green-lights and a council sizes it. Filed so the
design survives; his words verbatim where it matters.

## The design (his ruling, 2026-08-05)

- **Acquisition rides the EXISTING body-search verb** — *"just like the intel scoring
  system we should have common and uncommon items linked to X amount of searches of enemy
  bodies leads to getting this token."* Tokens are milestone drops on the search counter,
  common → uncommon tiers. **The bodies-give-intel-only decree (2026-07-30) stands
  untouched** — searching remains the one corpse interaction; tokens piggyback it.
- **The arc is the point** — *"The first few tokens should be a little innocent but than
  eventually you get like 10+ ears in a row and than you get maybe a small bhuedda as the
  last find on people themselves."* The necklace is a moral descent the player assembles:
  innocent souvenirs → a string of ears → the Buddha as the final body-find. The
  collection IS the tour's story. Fits the never-show-XP progression decree: the cord is
  a diegetic scoreboard.
- **Other sources:** *"some other items can be found in tunnels or searching enemy
  camps"* — tunnel loot chamber and camp searches already exist as verbs.
- **Where it reads:** *"the player can see their necklace when they pause the game or in
  whatever inventory system we end up making."* Pause/inventory only — NO first-person
  chest rendering, no physics cord on the player model. This kills the hardest technical
  question outright.

## Art spec — the work order, re-tuned to house pipeline

The original order (chat, 2026-08-05) was written Unreal-flavored. Adopt with these cuts:
- **The "Retro" column IS the game profile** (ADR-001 PSX): single small unlit texture,
  Retro tri budgets (30–140 tris/token), NO PBR set, NO high-poly/normal bakes, NO LODs.
  The entire "Game" fidelity column is cut.
- **KEEP:** real-mm scale · origin at the hang point, dangle −Z, face +Y (zero-fixup
  threading convention — genuinely good) · modeled eyelet/hole, never textured · ONE
  shared atlas + one material for the whole cord (256–512) · per-instance tint via vertex
  color so ten ears don't read cloned.
- **House conventions:** lowercase snake naming per the existing kit (not `SM_TOH_*`),
  glTF through the existing export pipeline, grunt-UV-wrap texture discipline.
- **Token list:** DEFINITE — ear ×3 variants, intact 5.56 round, spent casing, tiger
  claw, snake fang. OPTIONAL — dog tag, Zippo, ace of spades, P-38, jade amulet/bead
  (jade = flat green, no subsurface at PSX).

## Open for the council when unpacked

1. Milestone table: which token at which search count; where the tiers break; whether the
   ear run is fixed-count or kill-context-driven.
2. Does the squad react to the cord (the most Tour of Hell version of a cost)?
3. Which tokens come from tunnels/camps vs bodies.
4. Pause-screen presentation (ties into whatever inventory system ships).

Pointer law: this doc records a chat ruling of 2026-08-05; no code exists. Related:
`recon-bodies-give-intel-only`, the progression decree (XP never shown), ADR-001.
