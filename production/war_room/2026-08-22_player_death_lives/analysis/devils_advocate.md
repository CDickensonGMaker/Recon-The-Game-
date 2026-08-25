# DEVIL'S ADVOCATE — lives economy & respawn-as-another-man (2026-08-22)

## 1. The premise is half wrong: the CAMPAIGN already has a death answer

The briefing frames this as "how do we keep the game balance fair when I die." But the campaign
already answers death: `field_director.gd:219-220` routes `_on_player_died()` → `fail_mission("KIA")`
→ debrief; `hud.gd:326-335` explicitly suppresses restart UI in flow-managed play ("GameFlow routes
death to the debrief (fail-forward); no restart UI"). Missions commit all-or-nothing at exfil
(ADR-007, verified: `campaign_state.gd:21-27,131-138` per the ADR's own audit). Death = mission
failed, campaign continues, next story seeds. That IS Pillar 5.

What he actually felt is DEMO-specific: `demo_game.gd:546` `_on_demo_death` → end card →
"RESTART THE NIGHT" (`demo_game.gd:582`). Dying at minute 18 of a ~20-minute siege costs the whole
night. That is a real wound — but it is a wound in ONE scene, not in the game loop. Do not let a
demo bandage become a core-loop rewrite.

## 2. Easy Red is a category error against Pillar 4 and ADR-032

Easy Red has no protagonist. RECONgame has exactly one: hidden reputation → earned rank →
armory rack, all bound to "you" (ADR-032, `campaign_state.gd:62-95`; the ONLY gameplay consumers
are the bench at `armorers_bench.gd:152` and fire support). Body-swap respawn forces an
unanswerable question: does SSG-you follow the swap into PFC Nguyen's replacement body?
- If YES: rank is a disembodied ghost, "you" die for free, and Pillar 4's "die for real" is
  repealed for the one man the player IS. The men calling you by your earned rank are now
  saluting a soul, not a soldier.
- If NO: every death resets a 40-level ladder — double jeopardy so vicious nobody plays IRONMAN
  honestly again.
Either answer damages ADR-032. There is no third answer; anyone proposing this owes the council one.

## 3. Any lives counter under REGULAR saves is theater

ADR-007 (`production/adr/ADR-007-save-architecture.md:23`): REGULAR = F5/F9 anywhere + 30s
autosave, and the ADR itself already names REGULAR "a standing repeal of Pillar 5 at the default
setting" (:45). F9 before the death animation finishes refunds the life. A lives economy that
binds only when the player volunteers into HARD/IRONMAN is not an economy — it is decoration.
The honest version of this proposal is "make IRONMAN (or HARD) the default," which repeals
ADR-007's consent-based tier ladder. If that is the actual desire, say it out loud and rule on
THAT, not on a counter.

## 4. "40" is a transplanted organ, and the body already has the organ

Easy Red's ~40 tickets are shared by a whole side of hundreds. RECON fields a 4-6 man squad and
a 50-hot-cap garrison whose casualty ledger IS the scoreboard (ruled 7/30; medical tent, body
bags). The lives pool already exists: it is the roster. An abstract counter on top creates
double jeopardy (lose Doc permanently AND tick a counter) or never binds (dead UI). Worse:
ADR-032's founding decree is "i should never see anything about XP but feel the rewards" — a
"LIVES: 37/40" HUD element is precisely the visible arcade number this game's identity forbids.

## 5. Scope: 19 days out, this is a core-loop rewrite in a demo tweak's coat

A campaign lives economy touches CampaignState, SaveManager tiers, roster, HUD, debrief, and
amends ADR-007 + ADR-032 — with ADR-015 requiring Summoner-verified playtests for every close,
while the demo playthrough gate itself is still undischarged. Nothing here pulls from
DEMO_SHIP_BACKLOG's ship gate ("The VC attempt to overrun the firebase" — spectacle, allies, air).

The minimum honest version of his felt problem: **demo-only garrison body-swap.** On death in the
siege, take over a living named defender (the demo already has a named roster and an end card);
when the garrison is dead, the base falls and the card plays. The roster IS the lives cap — no
number, no counter, no campaign change, no save-tier entanglement (the demo has no saves). "3
lives" is strictly worse than "the garrison is your lives": it is the same cap with an arcade
number stapled on.

## 6. Edge cases the proposal must survive

- Last man alive: pool empty → end card. Fine — and note this makes any separate counter redundant.
- Swap into a man mid-bleed-out or inside a sapper breach: instant re-death chains burning "lives"
  through no player action. Swap targeting needs a safety filter.
- Command/fire support after swap: does the new body keep squad authority and the RTO leash
  (ADR-011)? If yes, why did rank matter; if no, the demo's air beats die with you.
- Death as fast travel: dying on purpose to teleport into a better-positioned defender. Cheap
  to exploit in a holdout.
- Determinism: swapping which body the player drives perturbs the siege AI script the demo's
  timeline depends on.

## 7. Steelman — the hole fail-forward genuinely does not cover

Concede this fully: **a siege has no exfil.** Fail-forward is a patrol-shaped answer — "mission
failed, walk home, next story." Inside the wire at minute 18 there is no home to walk to and the
battle is still being fought without you; the end card discards a living fight. THAT is the real
hole, and body-swap inside a holdout is its natural, pillar-compatible patch — the garrison
fights on, you fight on with it, and the men you burned through are named on the card. Ship that,
demo-scoped. Everything else — campaign body-swap, abstract pools, "40" — is Easy Red's skin
stretched over a game with a different skeleton.

**Named sacrifice of my own position:** demo-only swap means demo and campaign death rules
diverge, and EA players will ask why the campaign doesn't do the cool thing the demo did. That
question is the POST-EA council, held with playtest data instead of a borrowed number.
