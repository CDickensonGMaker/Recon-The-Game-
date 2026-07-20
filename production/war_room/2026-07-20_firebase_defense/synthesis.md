# DECREE — The Firebase Defense Fantasy (Arbiter synthesis, 2026-07-20)

Council: systems-designer, devil's-advocate, lead-programmer (all read the code; 3 independent doors).
Verdict: **ACCEPT-WITH-CHANGES.** Build it, with the six corrections below. Full analyses in `analysis/`.

## The encounter, as ruled
A night coordinated attack: 3 SILENT sappers crawl the wire in the dark while a LOUD assault fireteam
charges behind them. The garrison stands-to and fights as soldiers holding the perimeter. If a sapper
reaches the munitions bench, the satchel breaches the depot — the player's next patrol loses mortars.
The flare is the player's counter to the dark; killing his RTO cuts his fire net.

## The six corrections the council forced (each closes a real defect the plan had wrong)

1. **HOLD is a lie in combat (systems + programmer).** `order_mode` is read ONLY in `_execute_idle`;
   `_execute_combat` ignores it and advances to `preferred_range` (12m) + strafes + cover-hunts, so a
   plain-HOLD garrison would CHARGE 300-500m off the wire into the dark. This is the exact turret-farm-
   vs-abandonment binary. RULING: add a default-OFF **post-leash** to AllyBase (`post_anchor`/`post_leash`):
   a defender never `may_close_distance`, and combat movement is pulled back inside the leash. Off by
   default → zero regression to the squad / friendly_patrol. This is the ONLY escape from the binary and
   is how the garrison fights without becoming a turret farm — they hold the wire, duck, strafe locally,
   fire outward, get hit, and die.

2. **The satchel/`spare_garrison` (devil A).** `spare_garrison` protects only the `civilians` array;
   promoted garrison are `allies`, so the 250/14m satchel already hits them full. RULING: the firefight
   is the CRAWL-IN (garrison vs sappers), which PRECEDES detonation — the blast is the climax/fail, not
   the fight. Keep garrison as participants: flip `spare_garrison=false` (the decree). Posts are at the
   perimeter, not on the bench, so the blast is a real cost, not a wipe. SACRIFICE: a sentry caught near
   the bench dies to the satchel — intended.

3. **Silent sapper is one accidental line + a loaded RPD (devil B + programmer).** Silence today rests
   solely on the `assault_objective!=ZERO` early-return, and `vc_sapper.tres` is an RPD gunner. RULING:
   make silence an INVARIANT — add `silent_infiltrator` to EnemyBase that hard-gates `_fire_at_target`
   and suppresses combat-sting/contact VO; relabel `vc_sapper.tres` to a real quiet sapper. Ship an
   invariant probe: a sapper never fires even if the objective is cleared.

4. **Fork B is cosmetic unless `_grant_fire_support` reads the penalty (devil C + programmer).** That
   function HARD-ASSIGNS a fresh dict every wire-cross. RULING: persist a `CampaignState.depot_loss`
   dict through all five save seams; `_grant_fire_support` subtracts it from the next allotment then
   CLEARS it (persistent ≠ permanent — a one-patrol cost). On breach, also dock the LIVE mortars for
   in-the-moment legibility. Toast names the loss.

5. **The loud assault must actually fire (Arbiter catch).** An `assault_objective` enemy early-returns
   to movement-only and never fires — so the CHARGING element cannot use the sapper drive or it goes
   silent too. RULING: the assault fireteam reuses the shipped HUNTER pattern (`_process_escalation`):
   spawned ALERT with `last_known_target_pos = fsb_center`, they advance and go loud when the garrison
   opens up. Only the sappers carry the objective drive. The firefight bootstraps from the garrison
   firing first (sentries open on the shadows), which wakes the assault into COMBAT.

6. **Probes must carry their named controls (all three).** Non-negotiable, this suite has been burned
   3× today: promotion needs a PEACETIME negative control (one lone enemy → garrison stays Civilian,
   never fires); night-stealth needs `SimClock.sim_hour` SET to NIGHT (else darkness mult=1.0 and the
   flare branch is dead code) AND a narrow-band unit test (end-to-end passes with/without the stealth
   stat); crisis re-fire needs a MULTI-poll two-wave probe with a sustained clear (single-poll passes
   against both keys); the RTO-kick asserts `player.holding_handset==false`, never `_radio_check()`
   (which already errors on the unfixed build).

## Trigger gating (peacetime control holds)
Stand-to fires from `launch_sapper_assault()` (the definitive assault) and from `_poll_firebase_threat()`
(needs `near>=2` AND `patrol_out`). A lone wanderer trips neither → garrison stays passive. Promoted men
join `"garrison_promoted"`, NOT `"firebase_garrison"` (keeps `test_firebase_garrison` valid).

## What the encounter SACRIFICES (named, no free lunch)
- ~7 post-men become full AllyBase FSMs during the rare one-per-op night assault while the player is
  often 300-500m away — a controlled CPU spike on an already CPU-bound frame, paid only for the event.
- The garrison is pinned to the perimeter (post-leash), so they will NOT chase a breaking enemy or
  exploit a rout — a firebase defence is a held line, not a maneuver. Intended.
- A sentry near the bench dies to the satchel; the base can lose men and materiel in one night.
- Silence is enforced by a flag, so a "sapper" is now a demolition role, not a usable MG — the RPD
  reskin identity is retired for this unit.

## Crisis re-fire shape (against the loiterer edge)
Per-wave key = `base_hash ^ (wave * prime)`; `wave` bumps only after `near<2` holds for a SUSTAINED
clear window (not an in/out edge), and an `active` latch blocks the 0.5s re-emit within a wave.
