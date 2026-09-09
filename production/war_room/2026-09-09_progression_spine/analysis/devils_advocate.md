# DEVIL'S ADVOCATE — THE PROGRESSION SPINE
## War Room 2026-09-09 · the case against, in ten charges

I am not here to be fair. I am here to be right about the risks. Every claim carries a pointer.

---

## CHARGE 1 — A SOLO PLAYER IN THIS GAME IS BLIND, NOT LONELY

I will not lean on the unverified "Easy Red 2 feels empty" claim (`evidence_pack.md` §7 flags it
honestly). I do not need it. The argument is inside our own code.

**The squad is this game's ONLY legibility layer, and the evidence pack proves it by accident.**
The suppression finding is the whole case: `combat_posture.gd` and `combat_manager.gd:402-468`
model suppression deeply and symmetrically, and **the player cannot see any of it** — zero hits for
"pinned"/"suppress" in `vo_manager.gd`, nothing in `mission_hud.gd:249-291`. Under a 45 m sight cap,
the player's information about the fight comes from *men talking*: contact callouts, direction, trap
warnings, the 5 m nameplate (`squad_nameplate.gd`), the ack bark (`squad_system.gd:303-311`).

Delete the squad and you have not made the player lonely. You have made him **deaf in a game whose
sim is invisible.** A firefight becomes: a crack, a hit, a death. The deep half of Brothers in Arms
with none of the legible half — and nobody left to narrate it.

Second blade: **Pillar 1 is "believable firefights."** A firefight of one man is not a firefight; it
is an ambush that resolves in two shots (ADR-016: rifles 27 base, TORSO ×2.5, HEAD fatal; player HP
100). With **ADR-040 §1's flat ban on any player-specific damage multiplier**, solo survivability
cannot be bought with health at all. It must be bought with *information* — which does not reach the
screen.

Third blade, from canon not Steam: **ADR-020's Ambience Law** — *"every ambient event must be safe to
ignore."* A living world of safe-to-ignore events, walked by a man with no squad and no stakes in any
of it, is a design where **the player is optional to his own game.** That is the emptiness charge
with nobody's reviews cited. And Pillar 5 has a hole: today the squad drags you out.

---

## CHARGE 2 — THE TOP RUNG IS THE THING HE ALREADY DIDN'T LIKE

His own 2026-07-19 playtest verdict on the squad **as it exists today** — four verbs, no cursor, no
attack order: ***"it felt like I was driving him."***

The reward for twenty hours of climbing is *more of that*: a fifth verb (ATTACK), an aggressive
escalation bound to the trigger, eight men to point. **The ladder's payoff is the state he
criticised.** Pillar 4's anti-puppeteer clause was dropped once before and its absence produced
exactly this defect, which is why it was restored as provisional rather than deleted (`BIBLE.md:74`,
`:88-94`). This proposal drops it again.

And it eats its own premise. If the pitch is *"you are alone in a war that does not need you,"* the
ladder's final state is *"you are a lieutenant with a radio and eight men."* The loneliness the pivot
was FOR is not preserved at the top — it is **spent**. The game may be best at rung 1 and worst at
rung 6: a progression that walks away from our own best hour.

---

## CHARGE 3 — THE LADDER IS A 20-HOUR TUTORIAL FOR A GAME THAT ONLY STARTS AT THE TOP

`mission_generator.gd:881` emits exactly one mission type: `"PATROL"` (ADR-029). No campaign order,
no mission list, no mission number. **"The 4th or 5th mission" has nothing to count**
(`measurements.md` §5).

So rungs 1-3 are not three kinds of content with capability withheld. They are **the same patrol,
repeated, with capability withheld** — not a waiting room, the same room with the door locked. "A
sense of growth" requires the low rungs be *good on their own terms*, and nothing here says what a
solo patrol is FOR with no squad to protect, no radio to call, and one mission type.

The knife: **the demo — the EA product — starts the player with eight men and a radio**
(`demo_game.gd:143-151` → `game_flow.gd:699-703`, `measurements.md` §6). Every stranger's first and
only exposure to this game is **rung 6**, and the campaign would then take it away. The ladder is
never validated by the artefact that ships, and the demo teaches the opposite of the campaign.

---

## CHARGE 4 — PILLAR 4 IS NOT DEFERRED, IT IS SWITCHED OFF; AND ADR-021 IS BEING DELETED WITHOUT A BURIAL

Pillar 4 is *"the squad is the RPG."* If the squad arrives at hour twenty, the entire opening has
four pillars, and the missing one carries **persistent named teammates, wounds, rotations home and
permadeath** — the whole attachment economy. That is not a pivot. It is a demotion of a pillar to a
late-game feature, and it should be argued as such openly.

Worse: **ADR-021 §4 is the only onboarding design this project has ever ratified** — *new in country,
YOU FOLLOW an NPC sergeant; trusted, YOU LEAD.* Diegetic, unscripted, no UI. The solo pivot deletes
it. And the 2026-09-07 demo audit measured that the game has **no onboarding at all** (`grep
PLAYER_MANUAL` = 0 hits; blocker #1 of five). This proposal removes the paper tutorial from a game
with no practical tutorial, and offers nothing but "be alone and figure it out."

**ADR-023, the fossil law, binds here:** if solo replaces ADR-021's follow-tutorial, ADR-021 must be
**named for deletion in the same decree.** Nobody has proposed that. A decree that leaves a
contradicted ADR standing is manufacturing the exact lie-in-the-map this project legislated against.

---

## CHARGE 5 — THIS SESSION IS THE DISEASE PRESENTING AGAIN

His own diagnosis of a rival: *"expanding the content too much and not making a good game."*

The ledger, all pointered:

- **The EA date (2026-09-06, `GAME_GUIDE:377`) has passed with the entry gate undischarged.**
- **`build/RECON_Demo.exe` is dated 2026-07-31** — verified on disk today, five and a half weeks
  stale. **There is no artefact to hand anyone.**
- **The siege forms up off the map.** `RING_MIN 300`/`RING_MAX 500`, `MORTAR_TUBE_STANDOFF 700`
  (`siege_director.gd:19-20`, `:50`) on a 512 m map — **1,057 `floor_y` no-collider misses** in one
  siege. The climax of the shipping demo happens on nothing.
- **The 2026-08-28 art/layout items 11-21, 25-27, 30-32 are ALL OPEN. "Not one has been started."**
  Seven commits since that playtest; exactly one touched art. **17 of 145 tests failed on 09-06.**
- `__bolt`/`__mg`/`__launcher` clip families do not exist — every MG, bolt-action and RPG man in the
  45-man assault holds his weapon like a rifle, in the one fight the demo is built on.

Against that, today we design: six progression rungs, a fifth order verb, **a conversation system that
does not exist** (`measurements.md` §4 — the grep for dialogue returned *zero files*), **a campaign
mission counter that does not exist**, a player-carried radio that repeals ADR-011's central law, an
adaptation of an unfinished comic, and a second war.

Yes — he ruled it post-demo, and that ruling is real. But **the cost is not zero.** The briefing names
"THE DOORS TO KEEP OPEN" as *the highest-value output* — meaning this decree constrains live
decisions (firebase pivot, event census, squad AI) **starting today**, for a payoff arriving after a
launch that has already slipped, while the briefing itself concedes *"this project loses parked
decisions."* We pay the constraint cost now and plausibly collect the benefit never. **That is the
disease.**

---

## CHARGE 6 — THE BORROWED RADIO IS A LOOTABLE FIRE-SUPPORT VENDING MACHINE

Fire support is the game's most powerful verb: eight call types including a multi-round arty spiral
(`field_director.gd:558-600`). The gate is `_radio_check()` → `nearest_radioman()` — **a search of the
group `"radioman"` for any living man within 10 m** (`field_director.gd:814-821`, `:364`). It checks
group membership. **It does not check ownership, permission, faction, or consent.** And the player
already walks up and takes the handset: `_aimed_radioman()` (`player.gd:438-451`) plus `[F]` →
`set_on_net()` (`player.gd:1055-1058`).

**So the abuse case is not hypothetical, it is the current code path.** Seed friendly RTOs and the
player who wants to break this does: find NPC, call the strike, walk away, find the next NPC. The
only question is the budget, and **nobody has picked a branch:** *per-RTO* → N radiomen = N × the
arty allotment, and the strongest verb in the game becomes a foraging loop; *global* → borrowing
grants nothing you did not already have, and the rung is decoration. Both branches are bad. That is
a design hole, not a tuning knob.

**And the murder case.** `_hand_off_radio()` (`squad_system.gd:829-865`) proves the radio is a
transferable object that survives its carrier. Nothing stops the player shooting a friendly RTO and
taking it. ADR-011's law is *"no bypass paths"* — **a corpse with a handset is a bypass path**, and
it is available today.

**Then rung 5 repeals ADR-011 outright.** The ADR names its own cost as a feature: *"the 10 m leash
punishes aggressive solo play … that friction is deliberate."* A handheld deletes that friction
permanently. The ladder's endgame removes the game's most deliberately designed piece of friction —
and ADR-023 says whatever this replaces must be named for deletion.

*(In passing: `project.godot:250-254` binds an input action `radio` to key G with zero script
references — a fossil that is the exact bind a handheld would want. Wire it or delete it.)*

---

## CHARGE 7 — THE COMIC IS THE DIFFERENTIATOR AND IT HAS NO ENDING

The genre claim is *"it sits apart from Easy Red 2 by … having this story."* Examine what we sell:

- **The story has no ending.** The author, verbatim: *"thats about as far of a story i had written
  overall."* **Issue 4 is drawn but never scripted.**
- **The causal chain binding the two wars** — Louie spares a German → SS officer → tortured Russian →
  the sniper hunting Louie's grandson — **is mostly undrawn.** It exists as synopsis.
- **There is no delivery mechanism.** Standing law is against cutscenes (ADR-020: *"the player is a
  WITNESS, never a puppet"*; ADR-041: *"a PLACE that says everything, not a cutscene"*). The
  comic-panel interstitial is reconciled with nothing. And **ADR-024, the cinematic-direction ADR,
  DOES NOT EXIST as a file** — it is a `(DRAFT)` row at `GAME_GUIDE.md:535`.
- **The horror — the most distinctive thing in the comic — is ruled out as a feature by him
  personally:** *"that is the vibe of the comic,"* not a mechanic. No sanity system is authorised.

So the differentiator is an unfinished story with no ending, no delivery pipeline, and its most
distinctive element demoted to atmosphere. **That is a store-page claim, not a differentiator** —
writable today, unbuildable today, the exact shape of a promise that gets a game reviewed badly.

One concession: **the sniper as a recurring, non-boss ambient hunter** — rumour, silhouette,
fragment — is mechanical, buildable, and **does not need the story to have an ending.** If the comic
gives the game one thing, that is it.

---

## CHARGE 8 — WW1 MAKES THE VIETNAM GAME WORSE, AND IT DOES SO NOW

The franchise is standing canon (2026-07-30), so I argue not the ambition but the
**period-agnostic frame**, which costs us today.

**There is no radio ladder in WW1.** In 1917 there is no man-portable set — runners, field telephones
on wire, flares, pigeons. To make the ladder "generalise" you must abstract the RTO into *"a way to
call support"* — and the moment you do, **you have abstracted away ADR-011, the most
identity-defining system in this game.** The radio is a MAN with a 10 m leash who can die and hand
the set to a rifleman. That is Vietnam. Make it era-agnostic and you get "call support" in three wars
and a soul in none.

Note too that the franchise decree's justification — *"matches how TerrainEngine is already built
(swappable elevation data + presets per region)"* — reasons about **terrain**, the cheapest layer,
and is silent on weapons, AI, comms, animation and VO, which are all of the cost.

---

## CHARGE 9 — THE AIMED-AND-TRIGGER-PULLED ATTACK FIRES INTO A NULL

`ally_base.gd:1417-1491`: **`order_mode` is read ONLY inside `_execute_idle`.** A man in COMBAT,
SUPPRESSED, SEEKING_COVER, ADVANCING or FLANKING **silently ignores every order.** An *aggressive
attack order* is by definition issued when men are in contact — **the exact state that cannot hear
it.** The headline verb of the top rung is unreachable in the only situation it exists for.

Now overload the fire button on top of that. Pillar 1 is the gunplay; under 1-2 shot lethality the
trigger is the most safety-critical input in the game. Bind an order to it and the failure reads:
the player pulls to command, **the order ray misses and is dropped silently**
(`squad_system.gd:286-288` — no toast, no VO), no man responds because they are all in COMBAT, and he
may have just put a round downrange and given away his position. The worst possible failure mode for
the pillar the whole game rests on.

And it is a **fifth verb**. ADR-012 permanently spends F1-F4 *and* C/H/X/N — *"neither may be
removed."* The 2026-09-07 game-designer lens pre-argued it: *"Four is enough. I want no fifth key and
I will argue against one."* ADR-029 Amendment C §5 already gated forgiving squad orders as
**spec-ready but enabled only once the AI provably obeys in a playtest.** That playtest has never
been run. **The gate was written for this proposal before it was made, and it is still shut.**

---

## CHARGE 10 — WHAT I CANNOT ARGUE AGAINST

**Borrowing a stranger's radio is a genuinely excellent idea and the council must not lose it while
answering everything above.**

It is the one rung nearly free in code (`measurements.md` §3: the gate already reads the *group*, not
the squad; the grab ships at `player.gd:438-451`), needs **no** conversation system and **no** mission
counter, and is wordless — cheaper and more period-honest than any dialogue tree we could build.

More importantly it answers Charge 1. **It makes strangers in the world mechanically matter.** In
Easy Red 2 soldiers are fungible bodies with no identity, so relationship stakes are structurally
impossible. A world where *that man over there, the one with the set on his back, is the difference
between you having artillery and not* is genuinely new — and it turns ADR-011's 10 m leash from a
punishment into the gameplay: **find him, reach him, keep him alive, and stand next to him while the
rounds come in.**

Build that rung. Prove it in a playtest. Then argue about the other five.

---

**What is sacrificed, as Law 2 requires:** every hour on this spine is an hour not spent on 1,057
attackers walking on nothing, thirteen untouched art items, the five-week-old exe, or the onboarding
a stranger needs to play at all. That is the trade; make it with open eyes or not at all.
