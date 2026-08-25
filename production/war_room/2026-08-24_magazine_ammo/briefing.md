# BRIEFING — Magazine-based ammo (Summoner directive, 2026-08-24)

The Summoner, verbatim: *"i wanted to change how the ammo works in the game. you have magazines
and when you half reload one it stayed half reloaded. no rounded easy ammo pick ups. And thats
when you can get ammo from the m60 gunner to resupply just like you could with bandages"*

Read as three connected asks:
1. **Magazines are discrete entities.** Reloading swaps magazines; a partially fired magazine
   keeps its actual round count and returns to the pouch. No pooled ammo counter that tops every
   reload to full.
2. **No rounded easy ammo pickups.** Kill whatever floor/pickup mechanic hands the player neat
   round-count refills.
3. **Squad resupply.** You get ammo from the M60 gunner (squad interaction) the same way you
   already get bandages from a squad member — find and cite the existing bandage mechanic and
   mirror its grammar.

Constraints the council must honor:
- Pillar 1 (believable firefights) and Pillar 4 (the squad is the RPG) — this feature serves both.
- r4bk law: mag state needs a HUD affordance or it does not exist. ADR-032 never-show-the-number
  lineage applies — judge what the player sees (count? weight-check? nothing?).
- Save/load standing check: mag states must persist and round-trip.
- Feature gate: demo playthrough gate is ACTIVE; sequencing vs the queued siege replay and the
  greenlit death body-swap must be named, not assumed. The Summoner's directive is the reason
  this is being specced now; the Summoner rules the build order.
- Fossil law: the replaced ammo system gets deleted in the same change, named file:line.
