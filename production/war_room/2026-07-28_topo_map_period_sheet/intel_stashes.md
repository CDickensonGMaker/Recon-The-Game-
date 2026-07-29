# DECREE — Intel stashes: the third ink

**Date:** 2026-07-28 · **Status:** Summoner's idea, design read
**Summoner, verbatim:**

> *"we could have intel stashs the players grab sometimes update the map with enemy locations they
> havent discovered yet or something."*

---

## 1 · Half of this already exists — do not build a second one

`CampaignState.intel_points` (`scripts/autoload/campaign_state.gd:32`) is live, persisted
(`:222,261,291,309`), and already earned from *"looted docs/captures"*. It is spent at the wire gate:
`field_director.gd:985-991` burns one point per walk-out to toast **S2 INTEL: VC CAMP REPORTED
NORTH-EAST** — a bearing, deliberately not a map mark. The comment there records the ruling:
*"the map circle stays a circle either way."*

So the currency, the earn, the spend and the persistence are all built. **What the Summoner is asking
for is a richer PAYOUT for the same currency** — put it on the paper instead of in a toast.

**Binding:** extend `intel_points`. Do NOT introduce a parallel intel resource. This project's recurring
failure mode is ~14 parallel live world-build systems; a second intel economy would be the fifteenth.

## 2 · The ADR-022 collision, and the one fix that survives it

ADR-022 is explicit about what the map may not become:

> *"it cannot become a fog-of-war overlay that fills itself in."*

An intel stash that stamps a **true, precise, permanent** enemy position is exactly that overlay. It
also breaks the layer taxonomy: OBSERVED is *"facts the player personally witnessed"* and ANNOTATED is
the player's own pencil. **Intel is neither — it is somebody else's claim.** It needs its own ink.

### THE THIRD INK — REPORTED

A mark whose provenance is *a document, not your eyes*. Visually distinct from both printed cartography
and the player's pencil, and governed by one law:

> ### **REPORTED INTEL IS A CLAIM, NOT A FACT. IT CARRIES A DATE, AND IT MAY BE WRONG.**

- A captured document is **accurate as of when it was written**, not as of now. It is dated on the
  sheet, and it reads older the longer it sits.
- It may point at a camp that has since moved, or one that was never there.
- **The game never reconciles it.** Same law as the pencil: walking there and finding nothing does not
  erase the mark. *You* erase it, or you leave it and stay wrong.

This is historically exact — captured VC documents were routinely stale by the time they were
translated — and it is the only version that does not turn the sheet into a quest log. The player gets
a *lead*, which is what intel is, rather than an *objective*, which is what ADR-022 forbids.

## 3 · Why this is worth building: it is the missing feedback loop

Today the map's economy is one-directional — you walk, you see, you mark. Intel stashes close the loop
and interlock with everything decided today:

- **Route ordering** (`patrol_route_and_hunters.md` §1): a document found on patrol 3 changes which
  circles you sequence on patrol 4. Intel becomes the reason last week's walk mattered.
- **Hunter teams** (§2): a stash can name a hunter staging area — the first time the player gets to
  hunt *them* instead of the reverse.
- **ADR-021's quiet patrol**: another thing a contactless evening can produce.
- **ADR-006, avoidance pays**: you can loot a camp you never fought.

## 4 · What is sacrificed

- **This is the closest any feature has come to the fog-of-war overlay ADR-022 banned.** The dated,
  fallible, third-ink treatment is what keeps it legal. If it ever ships as a precise permanent pin,
  the ADR has been violated and the map has become a quest log.
- **Rarity is load-bearing.** If every patrol yields a stash, the player stops learning the ground by
  walking it and starts waiting for handouts. It must stay rare enough that intel is an event.
- **A third ink on a sheet that already has two layers is a real UI problem** — ADR-022 already warned
  that if the layers are not instantly distinguishable at a glance, the whole law collapses into mush.
  Adding a third makes that harder, not easier, and the sheet must be legible FIRST (Phase A).

## 5 · SOURCE — Summoner's ruling, 2026-07-28

> *"not every patrol should yeild a intel stash. those typically would come from raiding a tunnel or the
> largest of a enemy encampments. its like a dungeon reward from the rpg side of the game"*

**A stash is a DUNGEON REWARD.** It is the payoff for entering a discrete, dangerous, enterable place —
never a pickup you walk over.

### The dungeon already exists

`scripts/world/tunnel_room.gd:1` — *"Tunnel-rat micro-dungeon (W51): a dark cache chamber 40m…"* — with
a `looted` flag (`:10`), a built cache mesh (`:61-70`) and a `cache_point()` (`:89`). The player
descends via `_enter_tunnel` (`player.gd:653`) and loots at `player.gd:616-618`. **The room, the cache,
the descent and the loot event are all built.** The stash needs a payload, not a place.

### The finding: the current earn contradicts the ruling

`intel_points` today comes from four sources, and they are not dungeon-shaped:

| Source | Yield | Pointer |
|---|---|---|
| tunnel cache | **+2**, once per room | `player.gd:616-618` |
| temple shrine | +1, one-time — *"OLD SHRINE - SOMEONE LEFT MAPS HERE"* | `player.gd:638-645` |
| **enemy corpse** | **+1 at a 20% roll, per body** | `player.gd:714-731` |
| (a fourth at `player.gd:680`, unread) | +1 | — |

**The corpse drip is the problem.** A ten-man contact yields roughly two intel points — the same as
raiding a full tunnel. That is exactly the "every patrol yields" economy the Summoner just ruled
against, and it already exists.

### THE THRESHOLD — Summoner's ruling, supersedes the council's two-tier proposal

> *"the points are silently added up and lets say you have to earn 20 to 30 intel points before the game
> will spawn in a real intel piece that can than reveal some map. so its rewarding the player for
> killing, checking bodies etc but wont always yeild some results"*

**One currency, one threshold.** Points accrue SILENTLY — no counter on the HUD, nothing to grind
against. At 20–30 accumulated, the world spawns a real intel piece in a tunnel cache or a large camp,
and THAT is what puts REPORTED ink on the sheet.

This is better than the council's two-tier split: it keeps every body-check meaningful without any
single one paying out, and the reward stays a dungeon reward because the *piece* still has to be walked
to and taken. Killing earns progress; it never earns a map.

**Silent is load-bearing.** A visible 17/25 counter turns patrolling into farming — the player stops
reading the ground and starts counting corpses. ADR-019 already governs this instinct: sentiment is
stated in words, never a number. Same law here.

### The conflict this creates, and it is real

`field_director.gd:987-988` **SPENDS** a point at every walk-out (`intel_points -= 1`) to fire S2's
bearing toast. A pool that drains every patrol fights a threshold that needs 20–30 banked.

Rough arithmetic on today's numbers: earn ≈ 2–4 per patrol (corpse rolls plus any cache), spend 1 →
net ≈ 1–3, so a threshold of 25 lands somewhere around **10–20 patrols**. That may be exactly the
campaign arc wanted, or it may be far too slow. It must be a decision, not an accident.

**Options (Summoner to rule):**
1. The bearing toast stops consuming — it fires whenever points > 0, and the pool only ever grows.
2. Keep the spend, and track a separate `lifetime_intel` accumulator for the threshold. Least
   disruptive to shipped behaviour.
3. Keep the spend and accept the slower arc.

Recommend **2**: it changes nothing that currently works, and the threshold reads off a number that only
counts up.

A "largest camp" needs a size threshold, exactly like the surveyed-village one
(`FieldDirector.SURVEYED_VILLAGE_MIN_R`). `vc_camp` sites carry `radius` (`site_planner.gd:961`).

## 6 · Where it lands in the plan

New stage, sequenced after the pencil (Stage 14) since it shares the mark-rendering and persistence it
introduces, and after hunters (Stage 17) if stashes are to name hunter staging areas.

## TUNE (Summoner)

- How rare is a stash — per patrol? per N patrols? only in camps? —
- Can reported intel be flatly WRONG, or only STALE —
- Does a stash reveal one location or several —
- Should intel points keep the existing bearing toast as an alternative spend, or does the map mark
  replace it entirely —
