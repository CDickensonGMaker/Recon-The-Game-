# GAME DESIGNER — Analysis (Player Experience / Fun / Attachment lens)

**Pillar 4: the squad IS the RPG. Minimal stats, MAXIMAL attachment.** Every recommendation
below is scored on one question: *does this make me grieve when JOHNNY KOWALSKI catches a round?*

Ground truth I'm building on: a member is `{name, mos, nick, st, ag, al, skills{}, kills, missions,
alive}`. Skills cap at level 8. Fire support is already wired (bombs/napalm/arty/mortar/Spooky on the
RTO `[T]` menu, cooldown scaled by the RTO's `fo_fac`). CBU is built but not on the menu.

---

## PROPOSAL 1 — LIVING SQUAD XP

### 1a. Does learn-by-doing create attachment? YES — but only if growth is VISIBLE and NARRATED.

Use-based growth is the single strongest attachment engine we have, because it converts *the player's
own memories* into stats. XCOM's grief works because "the guy who clutched the Gatecrasher mission" is
now a Colonel — the number is a **souvenir of a story you lived**. A shared team-XP pool can never do
that; it launders individual deeds into fungible currency. So the design bet is right. The failure mode
is silent growth: if PIG gets better at the MG and I never *notice*, he's still a stat block. **Growth
must be sensory, not menu-discovered.** Four visibility layers, cheapest-first:

1. **The promotion bark (MANDATORY, ship day one).** The instant a skill ticks up mid-mission, a toast +
   audio sting: `PIG — SMALL ARMS ⭑ III`. This is the dopamine hit. It fires *in the field, at the moment
   of the deed*, so the player connects "he just held that treeline" → "he got better at it." One toast,
   reuses the existing on-screen bark system. Non-negotiable — without this, the whole feature is invisible.
2. **Skill pips on the squad status HUD.** The existing status pips get tiny role-skill dots (● per level).
   You watch DOC's medic dots fill over a campaign. Passive, always-on pride.
3. **Earned rank in the name.** Missions survived promote the displayed rank prefix: `PVT → PFC → CPL →
   SGT` at 0/2/5/9 missions. `SGT KOWALSKI` reads as a veteran before you check a single stat. Free
   attachment from one string.
4. **Earned nicknames (the crown jewel, ship in a fast-follow).** Right now `nick` is role-generic (all
   pointmen are "EYES"). Convert it to *deed-earned*: cross a threshold and the grunt earns a personal
   handle the squad now calls him by. 15 confirmed kills → "REAPER". 3 saves without losing a man → DOC
   becomes "MIRACLE". Survive a danger-close strike → "LUCKY". This is the highest attachment-per-byte
   feature in the entire proposal — a nickname is a *portable legend*. It's one field already in the
   schema; we just need earn-triggers.

### 1b. Fresh recruit vs. 10-mission veteran — make the delta VISCERAL, and make rookies distinct AT SPAWN.

The current generator ships `skills: {}` — every recruit is mechanically identical mush. That's the
enemy of attachment; you can't love a blank. **Roll random starting skills so every recruit has a face
from second one.** Concrete design:

- **Starting-skill roll:** each recruit rolls **1–3 skill points** distributed with a bias toward his MOS
  skill (60% of points land on his `MOS_SKILL`, 40% scatter to a random other). So a rookie POINT reliably
  arrives with detect_ambush 1–2, but *might* also have a stray small_arms 1 or silent_movement 1. That
  scatter is the personality generator — "this pointman can also shoot" is a character trait you discover.
- **A one-line trait/quirk tag** rolled at generation and shown on his card: `STEADY`, `GREEN`, `TWITCHY`,
  `LUCKY`, `MOUTHY`, `LONER`. Pure flavor, zero mechanics needed to matter (though STEADY could nudge a
  skill roll). This is what makes two identical-MOS rookies feel like different men. **Cheapest attachment
  lever in the doc — a string array and one `rng` pick.**
- **The veteran fantasy — numbers that FEEL different:** a 10-mission vet should be `SGT "REAPER" HAYES`,
  small_arms 5–6, a full pip row, a nickname, and a visible kill count in the double digits. A rookie is
  `PVT MILLER, GREEN, small_arms 1`. The player should be able to tell them apart *in the heat of a
  firefight by how they perform* — the vet's bursts are tight and he doesn't panic; the rookie sprays and
  gets suppressed. Skill effects are already wired to spread/jam/suppression, so this delta is largely FREE
  once the numbers diverge. **That behavioral tell is the payoff — you protect the veteran because he's
  visibly better, not because a menu says so.**

### 1c. Permadeath — make it DEVASTATING-GOOD, not sunk-cost-BAD. (Pillar 5: fail forward.)

This is the knife's edge. A leveled soldier dying is *supposed* to hurt — that ache is the entire point
of Pillar 4. The line between "devastating in a good way" (grief = proof you cared) and "frustrating"
(sunk-cost = the game punished my investment) comes down to **whether the loss produces STORY or just a
downgrade.** Design rules to keep it on the story side:

- **Death must be legible and earned, never random-feeling.** He dies because a decision happened (I
  pushed too fast, I called the strike too close, I left him on point in the bamboo). Pillar-2 telegraph
  discipline already mandates this. A death you can narrate is a death you can mourn; a death you can't
  explain is a death you resent.
- **Fail-FORWARD, not fail-STATE:** one man down does NOT end the mission. The squad absorbs it and the
  war grinds on. His death *changes the story going forward* — see the memorial below.
- **The KIA log is sacred and must be SEEN.** Right now dead members are silently dropped from the roster
  (`ensure_roster` filters `alive`). That's a data operation, not a funeral. **Add a memorial screen at
  debrief:** the fallen man's name, nickname, rank, final kill count, missions survived, and *his best
  deed* ("held the treeline at the ravine — 4 confirmed"). Ten seconds of ceremony converts a stat-loss
  into a story-beat. This one screen is the difference between the two emotional outcomes.
- **Anti-sunk-cost pressure valves:** (1) a dead veteran's replacement is a green rookie, so the *gap*
  itself becomes gameplay motivation (rebuild the legend) rather than a dead-end penalty; (2) keep a
  battlefield-recovery beat — dog-tags/drag-to-cover already in DESIGN §4.5 — so the player has *agency in
  the loss*, a chance to have saved him. Agency-in-loss is what separates tragedy from arbitrariness.
- **DON'T over-punish.** No cascading roster-collapse spirals, no "lost your best man, now you can't win."
  The war continues; you fight on with grief, not with a broken run. Grief is fuel; a death-spiral is a
  quit button.

### 1d. Barracks fate — HYBRID (learn-by-doing is the engine; team-XP is a steering wheel).

Pure emergent learn-by-doing alone is a trap: it silently railroads growth (the pointman only ever
improves point skills, the player has zero agency, and it can't repair a roster gap fast). Pure barracks-
spend alone is what we're trying to escape (fungible, storyless). **Keep both, but re-rank them:**

- **Learn-by-doing is PRIMARY** — the emotional spine, the thing that turns deeds into stats. Most growth
  comes from the field.
- **Team-XP becomes a scarce "TRAINING" accelerator, not the main road.** Between missions the player can
  spend the shared pool to *nudge* a specific man — coach the green replacement up to fighting shape, or
  push a favorite toward a nickname threshold. This preserves player AGENCY (Pillar 4 is an RPG — RPGs let
  you invest in who you love) and gives a *sink that expresses favoritism*: choosing to train KOWALSKI over
  MILLER is a small act of attachment. The existing `buy_skill`/`team_xp` code is reused verbatim — it just
  stops being the only faucet.
- **Tuning so field-growth dominates:** field learn-by-doing should deliver ~70% of a career's skill
  gains; barracks the other ~30% (rookie catch-up + targeted pushes). Roughly: a skill level costs on the
  order of "do the thing well ~8–15 times" in the field, versus the existing 100–150 team-XP in barracks.
  Keep skill cap at 8. **Design intent: you should almost always feel growth was EARNED in blood, and only
  occasionally bought.**

---

## PROPOSAL 2 — RADIO FIRE SUPPORT

### 2a. What makes calling a strike FEEL powerful and tense.

The strike is already mechanically wired; "make it real" is 90% **procedure, delay, and consequence** —
the theater around the button, not the button. The feeling we're selling is *You are a small team that
just reached up and pulled the whole war down onto one grid square.* That awe only lands if it's
**earned, slow, and dangerous:**

- **Radio procedure as ritual (diegetic, Pillar-2 gold).** Calling a strike is not a keypress; it's the
  RTO working the handset with real-cadence VO: *"Any station this net, fire mission, over."* → readback →
  *"Shot, over."* → *"Splash, over"* (5-second warning). Text-to-placeholder first per DESIGN §4.10. The
  back-and-forth **is the tension** — those seconds where you're committed and waiting are the whole
  experience. The RTO must be alive and *stationary and vulnerable* while transmitting — kill the radio,
  kill the call.
- **Delay is a feature, not lag.** Spotting round → correction → fire-for-effect (DESIGN §4.7 already
  specs this walk-in). The delay forces you to *predict* where the enemy will be, and to *hold your nerve*
  while rounds are inbound. A strike that lands instantly is a win-button; a strike you have to earn across
  20 tense seconds is a set-piece.
- **DANGER CLOSE is the emotional core.** A red danger-close ring; call inside it and you risk your own
  squad. This single mechanic does three jobs: it makes the strike genuinely *scary to use* (not free
  power), it creates the "LUCKY"/"danger-close-survivor" nickname beats, and it's the fail-forward story
  generator (the strike that killed the machine-gun nest AND wounded DOC). **Friendly fire from your own
  called strike is the most memorable thing this system can produce — lean into it, telegraph it fairly.**
- **Sensory payoff scaled to cost.** Napalm/CBU/Spooky must *look and sound* apocalyptic — screen shake,
  the delayed thud-roll of distant detonation, the treeline going orange. The spectacle is the reward for
  the procedure tax.

### 2b. Escalation, not a win-button. (Pillar 3.)

Fire support must be a **costly, limited LIFELINE**, never the primary tool — the moment arty trivializes
firefights, gunplay (Pillar 1) dies and the game becomes a targeting screen. Guardrails:

- **Scarcity by budget** (already generated per-mission): 0–3 total calls for a whole mission, rolled by
  mission type/region at briefing (DESIGN §4.7). A raid deep in-country might get *one*. Scarcity makes
  each call a decision you'll remember.
- **Friction, not just cooldown:** the procedure time + spotting delay + danger-close risk means you can't
  spam it reactively mid-close-quarters. It's for *breaking a hard point or covering an exfil*, not winning
  a fair fight.
- **It should feel like admitting you're in trouble.** The best framing: calling fire support is the team
  saying "we can't handle this alone." That keeps it Pillar-3 escalation (the AO responds to pressure)
  rather than a power fantasy. Overuse should even carry a soft cost — noise/heat that hardens the AO
  (ties to the §4.2 escalation menu). **No free lunch: every strike is loud, finite, and can hurt you.**
- **Expose CBU** on the menu (it's built) — but slot it as an *area-denial/soft-target* option distinct
  from napalm's wall-of-fire, so the menu is a set of tactical *choices* (troops in open → CBU; bunker →
  arty; treeline → napalm; sustained cover → Spooky), not a single "big button" with reskins.

### 2c. RTO fo_fac learn-by-doing — YES, this is the keystone tie-in.

This is where Proposal 1 and Proposal 2 fuse into something better than either alone. **The RTO getting
better at calls the more he calls them is the strongest single attachment hook in the whole briefing.**
Because:

- `fo_fac` already scales fire-support turnaround/cooldown. Wire it to learn-by-doing: **each successful
  fire mission ticks the RTO's fo_fac progress.** A rookie RADIO fumbles — long spotting scatter, slow
  corrections, a wide first-round error. A veteran RADIO drops fire-for-effect fast and tight on the first
  correction. **The player literally hears him get better at the handset over a campaign.**
- This makes the RTO *irreplaceable in a way you FEEL*. DESIGN §4.5 already says "lose him, lose the
  verbs." Now it's "lose him, lose the verbs AND the twenty missions of skill that made those verbs
  deadly-accurate." Losing a maxed RTO should be the most painful death in the game — that's Pillar 4
  working exactly as intended. Protecting the radioman becomes an instinct, not a rule.
- Earned nickname payoff: a maxed fo_fac RTO earns something like **"STEEL RAIN"** or **"ZEUS"** — the man
  who calls thunder. Perfect fusion of both systems.

---

## SUMMARY (my position)

- **Both proposals are RIGHT and should ship — but their value is 90% in VISIBILITY, not mechanics.**
  Learn-by-doing and wired arty are inert without the promotion barks, earned ranks/nicknames, HUD pips,
  and a KIA memorial screen that convert stats into felt story. Build the *narration layer* or the feature
  is invisible.
- **Squad XP: HYBRID, with learn-by-doing primary (~70%) and team-XP demoted to a scarce "training"
  accelerator (~30%).** Roll random starting skills (1–3 pts, MOS-biased) + a one-word quirk tag so every
  recruit has a face at spawn; make the rookie-vs-veteran gap *visible in combat behavior*, not just menus.
- **Permadeath = devastating-GOOD via ceremony + agency-in-loss + fail-forward.** Deaths must be legible
  (telegraphed, decision-caused), get a 10-second memorial screen, and never spiral the run. Grief is fuel;
  the KIA log is sacred; the war grinds on.
- **Fire support = costly, limited, PROCEDURE-heavy lifeline with DANGER CLOSE as its beating heart — and
  the RTO's fo_fac learn-by-doing is the keystone that fuses both proposals.** A veteran radioman you'd die
  to protect is Pillar 4's thesis statement. Expose CBU as a distinct tactical choice; keep every strike
  loud, finite, and able to hurt you.
