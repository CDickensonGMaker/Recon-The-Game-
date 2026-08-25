# DEVIL'S ADVOCATE — Magazine ammo (2026-08-24)

Read: briefing.md · CLAUDE.md · 2026-08-22_player_death_lives/synthesis.md + rulings.md · code
(weapon_holder.gd, player.gd, squad_system.gd, field_cache.gd, world_weapon.gd, save_data.gd,
hud.gd, ally_base.gd, demo_game.gd, field_director.gd).

## 0. The inconvenient measurement first

The current system is ALREADY magazine-shaped, and in one respect HARSHER than the ask.
`weapon_holder.gd:24-25` stores `[current_magazine, spare_magazines]` per slot; `_finish_reload`
(`weapon_holder.gd:792-793`) does `spare_magazines -= 1; current_ammo = magazine_size`. A tactical
reload today EATS a full spare and the partial's rounds evaporate. The Summoner's "half reloaded
mag stays half reloaded" is not a hardcore-ification — round-for-round it makes the player RICHER
per reload. The hardcore payload is really ask #2 (kill rounded pickups) and #3 (squad resupply
verb). Worth saying out loud before anyone sells this as pure difficulty.

Also inconvenient: pickups are already denominated in MAGAZINES, not loose rounds — ammo box +2
mags (`player.gd:720`), tunnel cache +2 (`player.gd:978`), site crate +3 (`player.gd:1029`),
fallen squadmate's kit +2 (`player.gd:1072`). "No rounded easy ammo pickups" mostly indicts
`refill_ammo` (`player.gd:780-796`, +4 mags AND a free full magazine) — which is the ZOMBIE WALL
BUY economy (`player.gd:767`, `zombie_wall_buy.gd`), not the demo. The directive's target is
half phantom.

## 1. SEQUENCING — what inserting this costs

The queue, as ruled: **(a)** siege replay build FIRST (R1, rulings.md:6 — it validates six
unrelated fixes), **(b)** the greenlit body-swap AFTER (1-2 sessions, synthesis.md), **(c)** the
demo playtest gate is OPEN and only the Summoner discharges it (CLAUDE.md session entry gate;
rulings.md:15-17 — his 8/24 run didn't count, background Blender work). EA target **2026-09-06 —
13 days out**.

An ammo rework lands in `weapon_holder.gd` — the single hottest file in the player spine: fire,
burst, jam, reload, ADS, slot switching (`:592-596`, `:822-826`, `:852-862`), mounted-gun
snapshot/restore (`:103`, `:130`), captured-weapon pickup (`player.gd:738-747`). Every one of
those paths holds ammo state that a mag-list refactor must migrate. Destabilizing the reload path
in the two weeks the demo must be playtest-verified, BEHIND two builds already in line, is how
the date slips — and the date is his target (memory: EA date = target), but the body-swap is
GREENLIT and this is not.

**Is it demo-critical?** No. The demo already has the ammo economy it needs: grenadier's ammo
box (`squad_system.gd:324-334`), mounted M60 effectively infinite by design (`weapon_holder.gd:111`,
`[mag_size, 99]` "fed by the post"), 45-man siege tuned against that (`demo_game.gd:87`). Nothing
in the demo checklist (`demo_game.gd:26-69` arc) touches mag granularity. And the demo EXCLUDES
SAVES (`demo_game.gd:24`) — so the save-migration constraint in the briefing is pure campaign
work with zero demo payoff.

**Named sacrifice if built now:** either the EA date, or the body-swap slot, or the siege-replay
validation — one of the three. No free lunch.

## 2. SCOPE CREEP VECTORS (each one is "while we're in there")

1. **Squad AI ammo accounting exists NOWHERE.** `ally_base.gd`'s only ammo reference is a comment:
   "The skipped round costs cadence, not ammo" (`ally_base.gd:1928`). Allies fire from an infinite
   pool. Giving the M60 gunner a finite handout stock invents squad ammo bookkeeping from
   nothing — and the moment HIS pool is finite, someone asks why the riflemen's aren't. That is a
   whole system wearing a verb's clothing.
2. **Doctrine collision with his OWN standing ruling.** 2026-07-30, quoted in the code: the
   AMMO box belongs to the M79 GRENADIER (`field_cache.gd:7-10`, `squad_system.gd:14,324-334`).
   The new directive hangs resupply on the M60 gunner. Either the old grammar is superseded
   (then fossil law says the grenadier box path dies in the same change — briefing demands the
   corpse named file:line) or we ship TWO squad ammo grammars. Needs a ruling, not an assumption.
3. **The armory doesn't run on magazines.** Mounted M60 is belts (`weapon_holder.gd:111`);
   Mosin is stripper clips; shotgun is loose shells; M79 is single shells; LAW is one warhead
   (`:562`). "Magazine entity" cleanly covers roughly half the guns. Each exception is a branch
   in the reload path.
4. **Save migration.** `save_data.gd:73-74` persists `[current, spares]` with defaults; a mag
   list changes the schema and the briefing demands round-trip. Campaign-only cost (demo excludes
   saves).
5. **Every drop/pickup carries state.** `world_weapon.gd:32-33` already carries
   `ammo_in_gun/spare_mags` per dropped gun; captured pickup writes it back
   (`player.gd:742-747`). All of it becomes mag-list serialization. Enemy drop tables next.
6. **Zombie economy is priced in mags** (`refill_ammo`, wall buys). Touch it or exempt it —
   either way, a decision and a test.

## 3. FUN RISKS AT THE DEMO

- **Run-dry unwinnable night = Pillar 5 violation.** 45 men on the wire, no exfil, finite squad
  ammo, and the resupply source is one killable NPC. If the gunner dies at minute 2 of the
  assault (he stands on the wire), the player's ammo economy dies with him and the night is a
  slow fail-state — exactly what the body-swap was just built to abolish. Note the safety valve
  that remains is the mounted M60's infinite belt — meaning the systemic pressure of mag
  scarcity funnels the player onto the post gun and FLATTENS the siege into a turret sequence.
- **Mag juggling taxes the new player the demo must sell.** Tactical-reload husbandry is an
  acquired taste; the demo's audience is cold (fresh-player testing law). r4bk: mag state needs
  a HUD affordance or it doesn't exist — and ADR-032's never-show-the-number lineage collides
  with the HUD that TODAY prints the exact round count (`hud.gd:160-162`). Resolving count vs
  weight-check vs nothing is a UI council of its own, hiding inside this one.

## 4. REALISM TRAPS

- **The gunner GIVING ammo inverts real doctrine.** Riflemen carry spare belts FOR the M60; the
  gun is the squad's ammo SINK, not its source. Bandages-from-Doc works because Doc IS the
  medical source in doctrine — the mirror the briefing asks for is a false mirror. If realism
  is the motive, the grenadier's laid-down box (his own 7/30 ruling) is already the correct
  grammar. And an M60 gunner handing out 7.62 LINK to an M16 (5.56) is chambering fiction.
- **Half-mag retention without a consolidation verb = pouch clutter.** Ten mags of 3 rounds and
  no way to combine them; reload-order policy (fullest first? player picks?) is unspecified and
  every answer needs UI.
- **The mag in the gun on the body-swap (R1, ruled TODAY).** You die; your rifle lies on your
  own corpse (the synthesis's own mitigation); you wake in another man's kit —
  `set_weapon_data` issues a fresh `[mag_size, 3]` (`weapon_holder.gd:82`). Does the pouch die
  with the body? If yes, mag husbandry resets on every death and the system's whole point is
  void across the demo's 4-man pool (R2). If no, whose mags are you wearing? The two features
  ship the same month and neither spec has met the other.

## 5. EDGE CASES THAT SHIP BROKEN

- **Slot-mirror and snapshot aliasing — the one I'd bet on.** Ammo state is mirrored into
  `primary_ammo`/`secondary_ammo` at SIX sites (`weapon_holder.gd:592-596, 795-800, 822-826,
  852-862`) and the mounted-M60 snapshot does `"ammo": primary_ammo.duplicate()`
  (`:103`, restored `:130`). `duplicate()` on an `Array[int]` is safe; a mag LIST (array of
  counts or objects) shallow-copies into ALIASED state — mount the post gun during the siege,
  dismount, and your pouch is corrupted. The siege is precisely where the player mounts the gun.
- Reload interrupted by weapon switch/ADS: `_start_reload` commits nothing until `_finish_reload`;
  with discrete mags, WHERE the partial goes on an interrupt is a new state today's code never had.
- Resupply spam: the bandage verb is gated by `CARRY_MAX` and Doc's count (`player.gd:683-686`);
  the ammo mirror needs a cap or [F]-mashing drains the gunner in one visit.
- Gunner death mid-siege: ammo lost with the man is GOOD squad-is-the-RPG texture — and a demo
  difficulty cliff. Both true; pick one on purpose.

## 6. STRONGEST CASE AGAINST BUILDING NOW

The demo doesn't need it, the campaign can't save it yet (schema), the squad can't account for
it (no ally ammo), the armory only half-fits it, it contradicts a standing ruling about WHO
carries the ammo, and it lands in the hottest file of the player spine 13 days before EA behind
two queued builds and an undischarged playtest gate. The current system already consumes whole
magazines and already grants ammo in magazines. This is a POST-EA system with one demo-sized
verb inside it.

## 7. MINIMAL VERSION HONORING THE INTENT (if the Summoner rules "now")

1. `primary_ammo`/`secondary_ammo` become `Array[int]` of per-mag counts (index 0 = in gun).
   Reload: push partial back if >0, pop fullest. ~30-40 lines confined to `weapon_holder.gd`;
   the six mirror sites keep their shape. Deep-copy the mounted snapshot explicitly.
2. Exceptions NAMED, not built: mounted M60 belt (`:111`), Mosin/shotgun/M79/LAW keep current
   behavior. Rifles and SMGs only.
3. Kill exactly one rounded pickup class: `refill_ammo`'s free top-off — grants become full
   mags only (they nearly all already are). Zombie mode exempted by name.
4. Resupply verb: clone the bandage grammar (`player.gd:624-626, 1012-1019` /
   `squad_system.gd:339-347`) but hang it on the GRENADIER's existing box stock per his own
   7/30 ruling — and put the M60-gunner-vs-grenadier question to the Summoner as a gloss, since
   his directive and his prior ruling disagree. Cap draws like `CARRY_MAX` caps bandages.
5. HUD: keep `MAG: %d` (mag count), drop the round number for a press-and-hold weight check
   LATER — do not spend a UI council pre-EA.
6. Save schema untouched until post-EA (demo excludes saves); campaign migration is the
   post-EA change's first line item, with the fossil deletion (`_finish_reload`'s top-to-full
   path) named file:line in that change.
7. Sequencing: specced now, BUILT after siege replay and body-swap, and only pre-EA if both
   discharge early. The body-swap spec must answer "whose mags on wake" in ITS build, not this one.

— Devil's Advocate, in dissent by trade
