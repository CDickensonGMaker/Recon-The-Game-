# STUDY — how the shooters he named handled big maps with a lot going on, and what RECON adopts

*Technical director, 2026-09-14. Sources are cited inline; where a claim rests on my reading of the
games rather than a document, it is marked (reading). Nothing below asks the engine to do anything
RECON's code does not already do somewhere.*

## What each game actually did

**Ghost Recon (Red Storm, 2001).** The whole game is **twenty 400 × 400 m maps**
([Wikipedia](https://en.wikipedia.org/wiki/Tom_Clancy%27s_Ghost_Recon_(2001_video_game))). Nothing
streams; the map is resident. Enemies are placed by the IGOR editor as platoons with **plans, triggers
and zones** — "you can use triggers to specify a trigger event for a certain point … and specify what
zones are used for" ([IGOR FAQ](https://gamefaqs.gamespot.com/pc/516717-tom-clancys-ghost-recon/faqs/16963),
[IGOR trigger-plans tutorial](https://www.youtube.com/watch?v=n9ifkypwNVM)). A platoon idles on a
cheap plan (guard, patrol a path) until a zone trigger fires a new plan — a reinforce, a flank, a
retreat. Cost was controlled by **map size and by plans that do nothing until triggered**, not by a
distance ring: 400 m across, 30-odd enemies, every one resident (reading).

**SOCOM (Zipper, 2002, PS2).** Twelve linear-ish missions, 4-man team, small terrain squares with
patrol routes and alert states ([SOCOM wiki](https://socom.fandom.com/wiki/SOCOM:_U.S._Navy_SEALs)).
Zipper published no technical postmortem I could find; the PS2's 32 MB forced small resident levels and
a handful of active AI, with patrols on paths and a stealth alert ladder driven by sight and sound
(reading). The lesson from SOCOM is not a technique but a proportion: **a dozen men on a small map with
a real alert ladder feels bigger than sixty men who can't hear.**

**Medal of Honor: Allied Assault / Pacific Assault (2015 Inc / EA LA, id Tech 3).** Quake 3 levels, so
BSP hub maps of a few hundred metres; "triggers are used to spawn actors" — enemies are **spawned by
trigger when the player reaches a volume**, scripted actors run a scripted plan, ambient patrols walk
paths ([MoH:PA AI scripting doc](http://fallout.bplaced.net/gameserver/mohpa/files/mohpa_mdk/radiant/mohpa_ai_scripting.htm),
[MoH:AA](https://en.wikipedia.org/wiki/Medal_of_Honor:_Allied_Assault)). Nothing far from the player
exists yet; nothing behind him is kept. The whole "war" is a corridor of trigger volumes. It is the
opposite of RECON's Pillar 3 and it is why Omaha Beach feels huge and plays 80 m wide.

**Far Cry (Crytek, 2004).** CryEngine's island levels: "all of the level territory is accessible to the
player without loading pauses", long draw distances, vegetation impostors
([Wikipedia](https://en.wikipedia.org/wiki/Far_Cry_(video_game))). AI is placed by hand in the Sandbox
with area/proximity triggers ([Sandbox triggers tutorial](https://gamebanana.com/tuts/12141),
[Sandbox manual](https://fcdb.crymods.net/resources/pdf/sdk/FC_editor_manual_v1.1.pdf)); enemies far
from the player idle on a patrol/guard behaviour with sensor cones for sight and hearing, and the
level's outposts are laid out so the player can "try different angles for assaults, or even
completely circumvent enemies" (Wikipedia). The level is resident; the cost is held down by **idle
behaviours that are cheap and sensors that have range** — a man who cannot see or hear you is doing
almost nothing (reading; the manual's AI chapter documents the sensor parameters).

**Far Cry 2 → 3/4 (Ubisoft Montréal, Dunia).** 50 km², "constantly streaming from the hard drive and
never having to dump the player to a load screen"
([Hocking postmortem, Game Developer](https://www.gamedeveloper.com/design/the-making-of-i-far-cry-2-i-)).
The price of that scale is the bubble: FC3/4 keep "active non-player characters within less than 500
metres of the player, with enemy characters and animals being added and removed to the world as the
player moves around", with **"only 12 NPCs max in the world at once and up to 20 animals"**, a director
that spawns ahead of the player's heading and speed, and deletes characters "too far away and won't
ever catch you" ([Thompson, The systemic AI of Far Cry](https://www.gamedeveloper.com/programming/the-definition-of-artificial-insanity-the-systemic-ai-of-far-cry)).
FC2's outposts "respawn as soon as the player leaves the immediate area"
([ModDB](https://www.moddb.com/mods/scubrahs-patch)) — the far world is not simulated, it is
re-rolled. That is the design cost of a streamed world: **nothing you did at 600 m is still true.**

## The dividing line, and which side we are on

Every one of these games sits on one of two sides of ~1–2 km:

- **Resident** (GR, SOCOM, MoH, Far Cry 1): the map fits in memory, everything exists, and the budget is
  spent on **who thinks** — cheap idle plans, sensors with range, triggers/zones that promote a plan
  only when the player is near enough for it to matter.
- **Streamed** (FC2+): the map cannot fit, so the world is a ~500 m bubble with a hard NPC cap and a
  director that fakes the rest, and far state is discarded.

ADR-013 already chose: ≤ 2 km loads whole and never streams. At 1024 m (the honest size for "3x" —
see the analysis, §1.1) RECON is a Far Cry 1 / Ghost Recon world, not a Dunia one. The FC2 bubble is
the wrong model for a game whose H&M ledger and evidence ledger promise that what you did at the
village is still true when you come back (ADR-029 Amendment B, ADR-038).

## The technique we adopt, and WHY

**Resident world, three player-centred rings, one clock.** All three rings already exist in the code;
the study's contribution is to say which is which and what binds them.

| Ring | Radius | Game analogue | RECON code |
|---|---|---|---|
| NEAR — full brain | ≤ 80 m (demote 105 + 3 s, sticky ≤ 160) | GR's "plan fired by zone"; FC1's "sensor contact" | `scripts/ai/ai_lod.gd:44-56` (shipped 9/09) |
| FAR — cheap brain | 105–240 m | FC1's idle patrol/guard with sensors live | `enemy_base.gd:41-56, 2208` `_execute_far`, 0.3–0.6 s think, 10 Hz anim |
| ASLEEP — no body | > 240 m (resume 210) | GR's untriggered platoon; FC1's far outpost | `scripts/missions/terrain_watchdog.gd:8-9, 45-73` (shipped, undocumented) |

Plus the one bodiless mover we already have — the siege's `MarchingCell` (`scripts/enemies/marching_cell.gd`),
a fireteam that walks as a single node at 4 Hz and becomes men at 80 m — which is FC3's "spawn ahead of
the player" done honestly: the men are counted, seeded and reported before they have bodies.

**Why this and not the bubble:** the bubble's cap (12 NPCs) would delete the garrison, the village and
the camp every time he walks 500 m, and re-roll them on return. Our pillars forbid that: Pillar 3 says
the seeded world generates the stories; ADR-038 says the ledger is deeds. A resident world with sleeping
bodies costs RAM (which we have: ~1 MB per chunk of patch cache, a few MB of men) and costs zero CPU
per sleeping man. **The only per-frame cost that grows with the map is the watchdog's O(N) scan, and
that is a time-slice fix.**

**Why not triggers/zones like GR and MoH:** we will use them — the scripted-event system this council
is also asked for is exactly GR's "zone fires a plan" — but as *promoters of a plan on men who already
exist*, never as spawners. A trigger that creates men is MoH's corridor.

**The one law the technique needs written down** (it holds today by accident): the sleep radius must
exceed every noise radius (`SUSPEND_DIST 240 > GUNSHOT 150`), so that a sleeping man is never inside a
sound he should have heard. That is what keeps ADR-005's witness rule and ADR-026's cold-tier guard-rail
true at the same time, and it is what Far Cry 1 got right and Far Cry 2's respawning outposts got wrong.
