# DEMO PLAYTEST SCRIPT — one pass, in the order it happens

**Written 2026-07-31** because the demo backlog audit found the bottleneck is not code: nearly
every item is **built and unverified**, and under ADR-015 only YOUR playtest discharges that.

**How to use this.** One run, top to bottom. Each row says what to watch and **what "right" looks
like**, so a wrong answer is a finding and not a vibe. Write PASS / FAIL / DIDN'T SEE in the
margin — "didn't see it" is data too, and usually means it never fired.

Rough length: **45 minutes** if the night goes the distance.

---

## BEFORE YOU BOOT

Open the project in Godot 4.7 once and let it finish importing. Several animation and script
changes landed today.

**Fresh save, not a dev save.** Dev saves mask the fresh-player bugs this pass exists to find.

---

## 1 · FIRST SIXTY SECONDS — inside the wire (fixed TODAY, all unverified)

| # | Watch for | Right looks like |
|---|---|---|
| 1.1 | **Are men doing different things?** | Off-duty GIs should NOT all be smoking. Six different chains now. If they still smoke in unison, the rotation isn't reaching them. |
| 1.2 | **The working party** | Somebody digging, somebody at the wash drums, somebody hauling water, somebody burning the latrines. These posts seated NOBODY before today. |
| 1.3 | **The aid station** | A medic **and a man on the ground being worked on**. If the medic is alone he is miming surgery over dirt — the seed failed. |
| 1.4 | **A man carrying crates** | He should keep moving. If he freezes mid-carry holding the box, the loop fix didn't take. |
| 1.5 | **A sentry pivoting on his post** | His feet should turn, not slide. Only fires when he is otherwise idle and turning faster than ~46°/s. |
| 1.6 | **Anyone lying down who shouldn't be** | Sleeping men use a sleep pose. If a *sleeping* man looks like a casualty, the 7/30 fix regressed. |

**Note for 1.2:** only **seven** work-post men exist at any time (24-man ceiling minus 17 curated).
Do not expect all twenty jobs manned — expect seven, and expect them to be *different jobs*.

## 2 · WALK THE COMPOUND — the garrison at work

| # | Watch for | Right looks like |
|---|---|---|
| 2.1 | **Do sentries WALK to the wire at dusk?** | Movement between quarters and post. If they're just standing where they spawned, `ACTION_WORK` still isn't walking them. |
| 2.2 | **Two men in one skin** | Should not happen. If it does, it's follow-slot convergence, not spawn. |
| 2.3 | **`[NAV] ally … no path` in the log** | Was 8 per boot. Count it. Anything left is navmesh islands, not clamping. |
| 2.4 | **Villagers, if you leave the wire** | A hamlet asleep should NOT be sixteen copies of one pose. |
| 2.5 | **VC camp at the talk hour** | American open-palm gesturing is now pulled from VC and villagers per your ruling. If a VC still gestures like a salesman, one slipped through. |

## 3 · THE AIR — the ship gate's biggest item (all built, none verified)

| # | Watch for | Right looks like |
|---|---|---|
| 3.1 | **How much is up at once?** | Three movements per daylight hour, each a FORMATION — 6-9 Hueys or 3-5 jets. Not single ships. |
| 3.2 | **A Huey landing** | Fly in, flare, touch down, **men actually get out or get on**, lift. If it lands empty and leaves, `HeliLift` isn't attaching. |
| 3.3 | **Does anything fly through the compound?** | Transits are held 150m off, Spooky 420m. Watch for a jet through the tower. |
| 3.4 | **Spooky's gun** | The rope of tracer should be ~148m of a 206m line, 2s hot / 2.5s cold. Rounds are real now — a man behind the berm should be spared **by the berm**. |

## 4 · THE FIREFIGHT — take a patrol out and get shot at

| # | Watch for | Right looks like |
|---|---|---|
| 4.1 | **Get shot from the LEFT** | He should fall left. This direction did not exist before 7/30. |
| 4.2 | **Shoot a man in the BACK** | He should fall **forward, away from you**. Until today the whole rear arc fell as if shot in the chest. |
| 4.3 | **Headshot someone** | There are now dedicated headshot falls, front and back. |
| 4.4 | **Pin a man with sustained fire** | **NEW: he should go PRONE** — about 1.2s of held heavy fire, then a 1.8s drop. He stays down while you keep firing. |
| 4.5 | **Then stop firing** | He must **GET UP** within a couple of seconds, or at the 8s ceiling regardless. **A man who never rises is the bug I most want to hear about.** |
| 4.6 | **Does a prone man shoot back?** | He should. If prone men never fire, the latch isn't surviving into COMBAT. |
| 4.7 | **Take a solid non-lethal hit yourself** | The stumble should read. |
| 4.8 | **Go prone yourself and get shot at** | Fixed today: your hitzones follow your capsule now. Previously a round through **empty air a metre above you** was a fatal headshot. |

## 5 · THE NIGHT — the siege (the demo's centrepiece)

Debug build only: **[J]** triggers the siege early. Otherwise it opens on the 720s arc.

| # | Watch for | Right looks like |
|---|---|---|
| 5.1 | **The reinforce line** | `[Siege] reinforced +34 — the assault is now 45 men` at 720s. Every demo night before 7/30 was **11 men, announced twice**. |
| 5.2 | **Can you SEE them cross?** | The garrison pops its own illum 140m out on the attack bearing, 12s after stand-to, then every 70s. Burn is 55s — **it should go dark between rounds.** That gap is deliberate. |
| 5.3 | **Do they funnel at the gate?** | The lane is the gate by design. |
| 5.4 | **"THEY'RE INSIDE THE WIRE"** | Fires ONCE, with the siren, at 3 men inside, measured per-bearing. |
| 5.5 | **Does the base blow up?** | Parapet segments have HP and ride the blast bus. |
| 5.6 | **Grenades** | Expect FEW — all 45 men share one squad, so it's one grenade per 12s across the whole assault. **You have already ruled this: four squads, flanking. Not built yet.** |
| 5.7 | **Does the assault break as one body?** | Same root cause as 5.6. Watch whether they all lose heart simultaneously. |

## 6 · AMBIENT — anytime

| # | Watch for | Right looks like |
|---|---|---|
| 6.1 | **Distant war audio** | Two parties 15-40m apart **answering each other** — bursts, a 2-6s lull, going ragged at the end. Not one lonely gunshot. |
| 6.2 | **Convoys** | Should start ON their road, not inside the compound, and should turn into bends rather than crabbing sideways. |

---

## WHAT I EXPECT TO FAIL

Being honest about where I'd bet, so a failure here is confirmation rather than a surprise:

1. **4.5 — a prone man who never gets up.** Three independent releases guard it, but it is new
   today and it is the worst failure mode on this page.
2. **1.3 — the patient on the aid station floor.** He is seated at a `work_medic` marker, and the
   cots are in the medical complex that is not exported yet. He may be lying somewhere daft.
3. **1.5 — turn-in-place never firing.** The 46°/s threshold is a guess against a damped turn.
4. **2.1 — sentries still standing where they spawned.** Fixed 7/30, never seen working.
