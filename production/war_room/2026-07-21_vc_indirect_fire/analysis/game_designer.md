# GAME DESIGNER — VC INDIRECT FIRE

**Lens:** fun and feel. Rule #1 — the world must be FUN to walk and FEEL like Vietnam.
**Method:** read the code, never the plan. Every claim below carries a `file:line`.

---

## 0 · FINDINGS THAT BEAT THE PLAN (verified pointers; these go first per the briefing)

### F1 — **A5 IS BROKEN AS SPECIFIED. The "incoming-fire wedge" is a hit marker, and for indirect fire it cannot fire at all.**

`mission_hud.gd:196 show_damage_direction` has exactly one caller: `player.gd:1177-1178`, inside
`take_damage`. Two consequences:

1. It runs **after** the player has already been damaged. It is a *hit* indicator, not a *warning*.
   A warning that arrives with the damage is not a warning.
2. It is gated on `if attacker is Node3D` (`player.gd:1169`). Every indirect terminal in the game
   passes `null` as attacker — `field_director.gd:560` (`_arty_impact`) and `:668`
   (`_mortar_impact`) both call `CombatManager.apply_explosion_damage(ground, …, null)`, and
   `combat_manager.gd:128` forwards that null straight into `player.take_damage`. **The wedge will
   never appear for a mortar round.** It does not appear for the player's own mortars today either.

The comment at `mission_hud.gd:195` — *"red wedge on a ring around center pointing at incoming
fire"* — is a lie in the map (POINTER LAW). It describes a system that does not exist. Correct or
bead it on contact.

**A5 must be rewritten.** Its instinct is right (no second indicator, no new HUD) and its
implementation is empty. See §1 for what replaces it: sound and a man's voice, both of which are
diegetic, both of which ADR-029 actively wants, and neither of which is HUD.

### F2 — **The briefing's premise about `fzxs` is wrong: allies do NOT break for the edge today.**

`fzxs` is an **open ask**, not shipped behaviour. Its own body says the override is *"added
DEFAULT-OFF, so nothing regresses until it is switched on."* Grep of `scripts/allies/` for
`FirePlan|fire_plan|danger|incoming|flee|scatter` returns **zero matches**. Today, when a fire
mission lands on your men, they stand in it.

And worse: `combat_manager.gd:149-150` gives **every null-attacker explosion** a 0.4× damage
discount against allies. That discount is keyed on *indirect-ness*, not on *friendliness*. If VC
indirect reuses the same null-attacker terminal (which A2's shared `IndirectFire` extraction makes
almost inevitable), **VC mortars will do 40% to your five men and 100% to you.** Rounds landing in
the middle of the squad and nobody dropping is the precise texture of "cheap." Re-key the discount
to the caller's faction before the shared path ships, or the fix for one feature silently defangs
the other.

### F3 — **Three more canon claims fail on inspection** (the doc sweep will want these)

| Claim | Reality |
|---|---|
| `GAME_GUIDE.md:138` — escalation ladder includes *"walking mortars on last-known"* | No such code. `field_director.gd:79-106 _process_escalation` spawns **hunters only** (`nva_regular.tres`, ALERT, seeded at the player's last position). There has never been a walking mortar. |
| `GAME_GUIDE.md:184` — *"enemy mortars use the same system. Verified genuinely fixed."* | False, and this is the sentence that let the gap survive. |
| `GAME_GUIDE.md:184` — *"budgets rolled at briefing"* / *"spotting-round → walk-in corrections"* | Briefing is dead (ADR-029); budgets roll at the **wire gate** (`field_director.gd:815 _grant_fire_support`). The spot round exists (`:575`) but **there is no correction verb** — the player cannot walk it in. The sheaf is fixed at dispatch. |
| `GAME_GUIDE.md:186` — danger-close at `field_director.gd:357-359` | Stale pointer. It is `:540-552 _danger_close_to_squad`. |

---

## 1 · WHAT IS THE PLAYER'S EXPERIENCE OF BEING MORTARED?

### What already exists to build the feeling from (all verified)

- Player suppression: full-screen shader, camera h/v jitter, and a Master-bus lowpass that closes
  from 20.5 kHz to **650 Hz** (`player.gd:1226-1295`). This is a *deafening* effect and it is
  already built and unused by indirect fire.
- Prone/crouch decays suppression faster (`player.gd:1294`) — going to ground is already mechanically
  rewarded.
- Real shells: `Ballistics.fire_arc` with `SHELL_FLIGHT_S = 4.0` (`field_director.gd:241`).
- Positional squad barks (`vo_manager.gd:61 play_squad`) and positional radio from the RTO's
  backpack (`:44 play_radio`).
- The toast queue: 3.5 s hold, 1 s fade (`mission_hud.gd:283-290`).

### THE BEAT SHEET (t = 0 is the tube firing)

| t | He HEARS | He SEES | He DOES |
|---|---|---|---|
| **0.0** | **THE THUMP.** A hollow *pock*, positional 3D at the real tube, long-range, unlike any other sound in the game. | nothing | recognises it — or doesn't, the first time |
| **0.5–4.0** | **silence** | nothing | this is the dread. 4 s is ~20 m at a sprint — exactly one blast radius (`MORTAR_BLAST_M` 10 m + sheaf). Enough to live, only if he moves *now* and moves *right*. |
| **4.0** | crump | **THE SPOT ROUND**, ±15 m off (`FirePlan.MORTAR_SPOT_M`) | reads where the sheaf will walk |
| **4.0–4.5** | **"INCOMING!"** from a man, positional | five men hit the dirt | *this is the indicator.* Not a pip. |
| **4.5–7.0** | — | — | **THE DECISION:** break perpendicular to the tube bearing, get terrain between, or go prone and pray |
| **7.0+** | 3–4 crumps ~1 s apart; the world drops to 650 Hz | grey shader, camera jitter, his rifle is useless | he is **pinned**, not necessarily dying |
| **end** | silence, and the lowpass slowly opening | craters | *now* he decides: run, or go find that tube |

### Is the spot round enough warning to be FAIR?

**No, not alone.** It gives ~4 s of notice, it carries no bearing, and it is delivered by the weapon
that is already killing him — at green-RTO scatter it can land nearly on top of him. A5's "the spot
round IS the warning" hands the player a bearingless 4-second window and, worse, gives him **no way
to learn where the tube is** — which collapses §2's entire hunt loop.

**Add the launch thump and it becomes ~8 seconds with a direction, and it is fair.** The thump is
the feature; the spot round is the confirmation. The thump is also the Fairness Law made audible:
*the thing that kills you announced itself, from the place it lives.*

### Does the existing wedge serve this?

No — see F1, it cannot even fire. And conceptually it is wrong for indirect: a directional damage
pip answers "who shot me," a question the player already answered by getting hit. Indirect fire has
no attacker to point at. It has a **bearing** and a **time**, and both belong in the audio mix, not
on a CanvasLayer. ADR-029's whole posture is anti-HUD.

**Recommendation: do not reuse the wedge, and do not build a second indicator either. Build the
thump and the bark.** The bark's toast line is the accessible mirror of the thump (see §6's named
sacrifice on audio), not a second channel. Leave `show_damage_direction` as what it actually is —
a direct-fire hit marker — and fix its lying comment.

---

## 2 · DOES "HUNT THE TUBE" WORK AS A LOOP?

Five links. Each must be diegetic, with no marker and no briefing.

**1. LEARN A TUBE EXISTS.** The thump. Two or three barrages and he knows the sound. The squad
names it for him **once, ever** — a point-man bark: *"MORTAR — THAT'S OUTGOING. THEY'RE CLOSE."*
That is a tutorial that is also a character, and it is Pillar 4 doing teaching work.

**2. LEARN ROUGHLY WHERE.** The thump is positional at the tube's real world position. It has a
bearing you can *hear*. **This is the single most important architectural consequence of the
Summoner's ruling.** The player's own shells cheat: `_fire_shell` spawns them high on an azimuth
from `fsb_center` (`field_director.gd:598-601`) because his guns are off-map. **A VC tube must NOT
inherit that trick.** An off-map enemy gun cannot be hunted, and "kill the tube" becomes a lie.
A2's generalisation of the gun origin is therefore not refactor hygiene — it *is* the feature.

**3. BANK THE BEARING.** ← **this is the hole.** A bearing heard 90 seconds ago while being shelled
is not something a player holds in his head, and ADR-029 forbids a marker.
**The fix is already built and needs no new law:** the RTO's net plus the grease-pencil circle
(`topo_map.gd:136-142`). `raise_crisis` (`field_director.gd:863-879`) *already* retargets the sweep
and toasts a bearing + range through the net, and its header already carries the Fairness Law.
Add one crisis kind, `"vc_mortar"`, with one `CRISIS_CALL` line (`:744-750`):
`"S2: WE HAVE A TUBE WORKING"`. Zero new UI, zero new law, zero new indicator.
The mark appears **because** you were shelled and **because** a man with a radio was standing next
to you — nothing from nothing.
- **The cost falls in exactly the right place:** off the net (RTO dead, or you walked away from the
  10 m leash, `_radio_check` `:504-511`), you get **no circle**. You have to remember the bearing
  yourself. That is the hardcore version, and it falls out of a rule that already exists.

**4. GET THERE.** Free — that is the game. But the circle must be **fat and inaccurate**: an area,
not the tube. He walks it and finds the emplacement with his eyes, his binoculars
(`player.gd:143`) and his ears. `FirePlan.sheaf_scale(fo)` already models "how well the radioman
reads indirect fire" — reuse it to set the circle's tightness. Existing table, new consumer,
no new numbers.

**5. KNOW HE SUCCEEDED.** ← the second hole, and **this project has already solved it once.**
The tunnel-mouth satchel (`player.gd:493-533`): a HOLD-interact world verb, one line of text
(*"THE MOUTH IS GONE."*), persistence through `CampaignState.remember_collapsed_tunnel`, and an
explicit header — *"there is deliberately no counter, panel or marker — the only way to learn what
you have destroyed is to walk back and look."* **Copy it exactly.** Kill the tube, get one bark,
and then: **the thump never comes again.** The proof of success is *the absence of a sound.* That
is the most Vietnam thing in this entire proposal and it costs one bark and one persistence call.
- Anti-hole: he must be able to tell a **dead** tube from a tube that simply isn't firing right now.
  Answer: it is a physical object. **Do not despawn it.** Leave a bent tube and a crater he can
  stand in and look at. Same lesson as the collapsed mouth.

**Verdict: the loop closes** — no marker, no briefing, no new UI class — **provided the tube is a
real on-map emplacement and the launch report is a real positional sound.** Cut either and the
feature is a random damage event with a fake counter attached.

---

## 3 · THE CAMPING PUNISHMENT

A4's gate is "observed + static + live tube in range." The framing is half right and the wrong half
is dangerous.

**The lesson must not be "do not stand still." It must be "do not stand still WHERE THEY CAN SEE
YOU, once they have seen you."** Those are different games. The first is a nag that punishes the
map-reader, the medic, the sniper and the man catching his breath — every one of which is something
this game wants. The second is Vietnam.

So **OBSERVED does all the work**, and observation must be earned by real eyes under the witness
discipline this project already enforces (`enemy_base.gd:742 _can_witness`, and the informer's
explicit *"proximity is not sight"* LOS check at `civilian.gd:218-221`). The static clock only
accumulates while an enemy or informer genuinely has line of sight. That one rule resolves every
legitimate-static case for free:

| Static, and why | Observed? | Rounds? | Reads as |
|---|---|---|---|
| Overwatching a village from concealment at 200 m | no | **no** | *you did the hard thing right and the game rewarded it* |
| Bandaging behind a berm, squad in cover | no | **no** | fair |
| **Reading the topo map** (a full-screen Control — he is standing there blind) | — | **must be no** | shelling a man for opening the map is the cheapest thing this feature could do. **Rule: the static clock does not accumulate while the map is open.** One boolean, prevents a betrayal. |
| Sniping from a treeline for six minutes, four witnessed kills | yes | **yes** | *you have been firing a rifle from one spot in a war* |

**Pillar 3:** observed-gated, this **serves** it. Pillar 3 says stealth is an economy, not a gate —
and a threat that bites only the observed is literally a price on being seen, the strongest
stealth-economy pressure in the game, paid in the currency Pillar 3 cares about (freedom of route)
rather than in a locked door. Nothing is forbidden; being seen just got more expensive.

It **fights** Pillar 3 badly if it is a timer on standing still, because then constant motion is
the only viable playstyle and the AO stops being a place you can *occupy*.

**One more rule, non-negotiable: breaking contact must work.** Move 100 m+, stay unobserved for a
while, and the fire mission lapses — the thumps stop. If the tube can follow you forever, the
lesson is "you cannot escape," which is the exact inverse of Pillar 5.

---

## 4 · PILLAR 4 — WHAT DO THE FIVE MEN DO?

**Today: nothing** (see F2). They stand in the sheaf and eat 40% damage. That reads as *"my squad
is made of cardboard and also invincible"* — the worst of both.

What they SHOULD do, in order, none of it a new order verb:

1. **SHOUT.** Whoever hears the thump first calls it, positionally, from a man. This is the warning,
   the characterisation and the Pillar 4 statement in one asset.
2. **GO DOWN, THEN GO OUT.** Prone/low posture instantly — `ally_base.gd:368 _low_posture` already
   exists and is driven by suppression, so **feeding indirect suppression into it makes this free**
   — then break perpendicular out of the beaten zone via `FirePlan.escape_vector` per `fzxs`.
   Keep fzxs's own rule that **a suppressed man does not move**: it means a heavily-shelled squad is
   genuinely PINNED, and the player watching his men fail to move is the emotional beat of the
   whole system.
3. **RALLY ON THEIR OWN.** When the rounds stop they come back to the leash unprompted. If the
   player has to press FOLLOW to un-scatter them, the feature has just made him a puppeteer under
   fire — a Pillar 4 violation manufactured by a system meant to serve it.

**The player's role becomes: DECIDE THE DIRECTION, not the men.** He already has exactly that verb —
MOVE-TO, aimed at the ground (`squad_system.gd:141-144`). Under a barrage MOVE-TO stops meaning "go
there" and starts meaning *"get off this hill and onto that one."* He calls the move; they save
themselves; the failures — the pinned man, the wounded man, the man who breaks the wrong way — are
**theirs**, which is what makes losing one hurt.

**What must NOT ship:** a TAKE-COVER command key, an indirect-fire order submenu, or any ability to
assign individual men to individual craters. That is precisely the puppeteering Pillar 4 names.

**One deliberate cruelty worth having:** the RTO is a man with an antenna. A barrage that kills him
costs the player his fire support *and* his ability to get S2's circle (§2, link 3). That is a
story, not a stat.

---

## 5 · THE NIGHT AT THE FIREBASE

**This is the highest-value half of the feature, and the easiest to ruin.**

**Good version:** you come back inside the wire, the AAR banks (`_bank_patrol` `:1051`), it gets
dark, and the base is a place you are supposed to feel safe. Then a hollow *pock* out in the black,
four seconds of nothing, and the mess area goes up. That is *Platoon*.

It also completes a loop the game **already has**. `_maybe_launch_sappers` (`:957-968`) already
rolls once per night against the threat tier the player earned, and `launch_sapper_assault`
(`:973-1004`) already spawns a **loud diversion element** behind the silent sappers, for exactly
this reason. A stand-off barrage as the **opening move of the sapper night** is the most authentic
thing on the table: the barrage pulls the garrison to the wrong side of the wire and the sappers
come in behind it. The code is already shaped for it.

**Two conditions decide interruption vs. atmosphere:**

- **He must have something to DO.** Being shelled while you can only run in circles inside your own
  base is a cutscene with damage. The answer is already geometry: `fsb_main.glb` has bunkers and
  trenches. **The verb at the firebase is GET IN THE HOLE**, and the barrage is what teaches the
  player the bunkers are *for* something. Costs nothing beyond making sure a bunker actually
  protects — `_can_damage_multipoint` (`combat_manager.gd:210-241`) already gives that for free.
- **It must leave a consequence he can walk out and answer in the morning.** The model exists:
  `on_firebase_breach` (`:943-951`) docks the *next* patrol's ordnance through
  `CampaignState.depot_loss`. A night barrage that wrecks something, plus a bearing he heard in the
  dark, **is the reason he walks out at dawn.** ADR-029's north star is *"i just wanna leave the
  camp and go find problems."* This makes the problem come find him first — and then he goes and
  settles it. That is the loop the pivot was asking for, arriving from the world instead of from a
  briefing.

**Named risk:** on a fixed nightly roll it becomes a chore. Cap it exactly as the sappers are
capped — one per night, gated on threat tier via the existing `SAPPER_CHANCE` shape (`:714`), and
**never while the player is skipping/sleeping through time with no chance to act.**

---

## 6 · THE ONE THING MOST LIKELY TO MAKE IT FEEL CHEAP

> ### A round that lands on him with no bearing he could have heard.

Everything else here is a tuning problem. This one is a **betrayal**, and it is live in the current
plan in three separate places:

1. **A5 as written.** "The spot round IS the warning" + a wedge that cannot fire (F1) means the
   first thing the player perceives is the explosion. He will not read that as *"a mortar found
   me."* He will read it as *"the game hit me."* That is the exact inverse of the Fairness Law the
   `raise_crisis` header (`:858-862`) proudly enforces three hundred lines away.
2. **The off-map gun.** If the VC tube borrows `_fire_shell`'s `fsb_center` azimuth cheat
   (`:598-601`), the shells come from nowhere, there is nothing to hunt, and the Summoner's
   "kill the tube" ruling is decorative. **Nothing may appear from nothing binds sources, not just
   markers.**
3. **Rounds that KILL rather than PIN.** `_mortar_impact` is 140 max / 40 min over
   `MORTAR_BLAST_M` 10 m (`:668`), and `_explosion_damage_at` gives **full damage across the inner
   40%** (`combat_manager.gd:98-103`) — a 4 m guaranteed-140 core against a 100 HP player. Four of
   those walking onto a static man is a coin flip on instant death with no counterplay, and the
   lesson is "reload." **The Summoner already ruled the way out on `fzxs`: suppression is the
   payload.** Make the barrage reliably pin, blind and deafen; make it kill only when he refuses to
   move or gets genuinely unlucky. A weapon whose job is to stop you fighting back, inside an
   economy that pays avoidance and pays zero for kills (ADR-006), is doing design work every time
   it fires.

**Runner-up, and it will be missed:** VC indirect inheriting the `attacker == null` 0.4× ally
discount (`combat_manager.gd:149-150`). Rounds among your men, nobody drops. That is the *texture*
of cheap even when the geometry is honest.

---

## 7 · WHAT IS SACRIFICED (no free lunches)

- **Overwatch is taxed.** A player who likes to sit and glass a village pays a price for being seen
  doing it. That is intended, but it is a real loss for a patient playstyle, and it means the
  observed-gate must be tight or that playstyle dies rather than costs.
- **The feature will scare far more than it kills, and will look weak on paper.** A 4-second
  time-of-flight makes the shell a fair object, so a competent player beats it nearly every time.
  Its damage numbers will read low in any audit. **That is the correct trade and it must not be
  "fixed" later by buffing lethality** — the moment it reliably kills, it teaches reloading.
- **Audio becomes load-bearing.** The thump *is* the warning. A player with sound down, or a bad
  speaker setup, loses the feature's fairness entirely. The squad bark's toast line is the required
  accessible mirror — not a second indicator, the same one, written down.
- **The RTO becomes even more of a single point of failure.** He already gates fire support and the
  net; now he also gates the circle that makes the hunt findable. Losing him costs three systems.
  That is good drama and bad robustness, and a playtest will feel it as "the RTO is everything."
- **The night gets busier.** Adding a barrage roll on top of the sapper roll risks the firebase
  becoming a place you never rest. The caps in §5 are load-bearing, not polish.
- **One more killable emplacement class to author, place, balance and keep alive across saves**
  (`SitePlanner.stamp_vc_camp` `site_planner.gd:664`), and a persistence entry so a destroyed tube
  stays destroyed. That is real cost, and it is the cost of the ruling being honest.
