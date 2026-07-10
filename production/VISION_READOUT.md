# RECONGAME — VISION READOUT

**Purpose of this document:** a self-contained briefing for any AI agent or collaborator on **the game
we are building toward** — the envisioned experience, not the current build state. Where the build lags
this vision, this vision wins. (As-built truth and binding law live in `production/GAME_GUIDE.md` and
`production/adr/`; consult those before touching code. Ratified 2026-07-10.)

---

## The pitch

A **hardcore Vietnam War tactical FPS** where every mission is generated, nothing is on rails, and the
war doesn't care about you. You lead a five-man Army fireteam: briefing → Huey insertion into an open
1–1.5km jungle AO → 2–4 objectives, any order, any route, loud or quiet → radio the bird and get out →
debrief, where the campaign remembers everything. Arma/OFP sandbox bones, SOCOM/Vietcong/Men of Valor
flavor, Hell Let Loose lethality, and the RECON RPG (1982) tabletop rules as the numbers soul.
The engine is Godot 4.7; the look is deliberate PSX-era low-poly 3D; the UI is modern sleek tactical
(Delta Force / R6 / Ghost Recon direction).

**Tone:** the grunt-infantry film canon — *Platoon, Hamburger Hill, Apocalypse Now*. Attrition, dread,
moral weight, boredom-then-terror. You are a draftee line grunt, worn and muddy, "just trying to stay
alive" — never a clean-kit operator. (Special Forces and Marines exist in the design as post-launch DLC
forks; launch is ONE faction, the Army grunt.)

## The five pillars (every decision is tested against these)

1. **Outstanding gunplay** — HLL lethality: 2–3 torso hits, one to the head — no armor, no sponges.
   Death comes from *situation* — ambush asymmetry, exposure, volume of fire — not from hit-point math.
2. **Atmosphere** — dense jungle, rolled weather and moon, night, load-bearing audio. The AO feels like
   a war is happening around you whether you participate or not.
3. **Freedom** — objectives are places and things in an open world; any route, any order. Stealth is an
   economy, never a gate. Nothing is on rails. Ever.
4. **The squad is the RPG** — named persistent teammates with MOS roles who improve, get wounded,
   rotate home, and die for real. Minimal stats, maximal attachment.
5. **Fail forward** — detection escalates, failure mutates, a dead mission generates the next story.
   Never reload-and-memorize.

**The fairness laws:** alert never buys the AI accuracy — accuracy ramps only with your continuous
exposure (first shots miss; camping kills you; repositioning resets your death clock). The first shot at
an unaware player is a near-miss crack. Muzzle flash, tracers, and vocalizations always telegraph.
Jungle foliage blocks sight, never bullets.

## A mission, minute to minute (the grammar)

Insert calm. Sixty to a hundred-twenty seconds of guaranteed contact-free approach — squad chatter,
point-man hand signals, the jungle loud with wildlife. Then the rhythm: **recon ring → objective spike →
lull**, repeated across 2–4 objectives, each raising the temperature. Valleys between peaks are filled
with *tension, not threat*: distant mortar thumps, wildlife going suddenly silent, a corpse on the
trail, an abandoned camp. Every compound offers a safe overwatch position 50–100m out — you always get
to *look* before you choose. The finale is dramatic (tempo, time pressure), not statistically hardest.
Completion visibly flips the world: the dead AA gun means a safer ride home; the stolen codebook
silences their mortars. Exfil is heat-scaled — earn a quiet walk-on, fight a hold-the-LZ crescendo
behind claymores you placed, or run a gauntlet to a fallback LZ 300–600m out, harder and darker. It
ends with the built-toward freeze-frame: the **boarding dash** — smoke pops, the door gunner opens up,
the squad boards by role under covering fire, you last.

## The systems, as envisioned

### Gunplay & damage — "the perception economy shoots back"
Flat, deterministic base damage per hit — the RECON tabletop lives on as the *averages*, not the rolls
(AK/SKS 22, the tumbling 5.56 at 28, Mosin 32) against 65–85-point enemies and a 100-point player.
Every scrap of variance sits where an FPS player can read it — range, hitzone, situation — never in
dice (ADR-016, Summoner-decreed). Two to three torso rifle hits down a man; the head is instantly fatal;
limbs *wound and degrade* — arm hits ruin weapon handling, leg hits kill your sprint and give you a
limp, a larynx hit silences a man's callouts. Deliberately wound-friendly: **the medic economy needs
wounded men, not corpses** — and the bleed-out clock is the medic's deadline. Projectile ballistics for rifles up; per-magazine stoppage rolls on fouled
weapons; diegetic ammo (no exact counter — check the mag). ADS uses per-weapon FOV zoom over a 75° base;
machine guns fire from the hip; the RPG raises its sight. And the crown rule — the **three-situation
asymmetry** from the tabletop: every firefight is a STAND-UP WAR, a TURKEY SHOOT (you set the ambush —
the only time full effectiveness applies), or an AMBUSHED scramble (heavy penalty until you reach
cover). Setting up the ambush IS the game, for both sides.

### Stealth & detection — an economy, never a gate
Four AI tiers — RELAXED → SUSPICIOUS → ALERT → COMBAT — driven by a visibility *accumulator* (stance,
motion, foliage), never a boolean. Terrain caps sight: open paddies ~500m of HLL treeline terror,
forest ~90m, deep jungle ~45m — the jungle is your stealth resource. Weather and moon are rolled per
op and change everything: heavy rain crushes sight and halves hearing (move loud when the sky is loud);
night by moon phase; flares undo darkness locally, for everyone. Noise is the honest price of violence:
an unsuppressed gunshot carries ~150m; a suppressed shot is a 3m curiosity that isn't even identifiable
as gunfire. **A truly unwitnessed kill is silent** — the alarm belongs to witnesses: the sentry's buddy,
the corpse someone finds (bodies are a liability), the alarm runner sprinting for the radio you should
have destroyed first — kill him or cut the wire and the escalation dies with him. Query memory kills
peek-a-boo cheese (each re-sighting shortens grace toward instant combat). Sentries get bored and
oscillate. Civilians who see you inform within minutes if you let them walk. And when the alarm does
sound, it opens an **escalation menu, never a fail state**: QRF from a *finite* manpower pool (a loud
enough player can empty the AO — never infinite spawns), walking mortars onto your last-known position
with audible warning, patrols doubling, documents burning, the target officer retreating to his bunker.

### Enemy AI — jobs and personalities, not scripts
The war exists without you: supply parties, a tax collector with escort, a bathing unit, prisoner
escorts, door guards, mortar crews. Archetypes are data personalities — Local Force militia break under
pressure (some *Chieu Hoi* — throw down the rifle rather than die for the cadre), NVA regulars don't,
sappers sprint the wire with satchels in the final wave, snipers displace. Alert spreads locally through barks and discovery, never a
global flag. Enemies hunt your *believed* position — last-seen plus breadcrumbs — never your transform.
They suppress, flank with vocal telegraphs, throw grenades ("LUU DAN!" means move), and do it all as a
coordinated squad with a shared plan, not as individuals.

### The squad — the RPG
Five persistent named men, each an MOS verb: **Point** (reads trails — trap wires, ambush sign, hand
signals), **RTO** (carries the net — lose him and you lose CAS, mortars, resupply, and the easy ride
home), **Medic** (when you drop he runs to you — limited treatments, both of you vulnerable during),
**Pigman** (sustained M60 suppression — "PIG, SUPPRESS THAT TREELINE"), **Grenadier** (auto-lobs M79 at
clusters). Orders are a deliberately tiny ratified verb set — FOLLOW / HOLD / MOVE-TO / FIRE-DISCIPLINE
on four keys; the explored growth lane (design intent, not yet ratified) is context-aware commands —
tap for the smart order, hold for a small radial (Six Days in Fallujah is the closest analogue),
formations (jungle single-file is *very* Vietnam), a three-state fire posture. Buddy rules are sacred: they never break your stealth, never block
doors or muzzle lines, take honest shares of enemy fire, are effective without kill-stealing. Barks are
the primary status UI. They earn XP by *doing* — learn-by-doing, spent from a team pool on skills and
St/Ag/Al. Wounded men heal on the campaign calendar; veterans near the skill cap **rotate home alive —
losing your best man to the end of his tour is a victory**; the dead are gone for good, and green
replacements arrive with new names, new bios, new faces from the modular kit. Roster of ~20 deeply
written bios; drag-to-cover and taking the tags are a *beat*, not a save.

### Fire support — the radio ritual
All support flows through the RTO within arm's reach: rifle down, handset up, on the net. A menu of
verbs with budgets rolled at briefing — Skyraider dive-bombing (loitering, deliberate), **the F-4 pass**
(spawns 200m out at treetop height and screams *over your head* at 250 m/s before climbing into the
cloud deck), Spooky's pylon-turn minigun orbit, walked artillery (spotting round, then corrections every
volley — a bad call lands where you called it), napalm as an 80m fire strip that ignites huts, CBU as a
fireless shrapnel storm, illumination both ways at night. Physics-honest theater: you see the jet before
you hear it, Doppler on the pass, the earth shakes. Danger-close is real — a deliberate double-confirm
inside 45m, "GET DOWN," and it genuinely hurts you. Arc Light is pure off-map sound and trembling
ground: the war is bigger than your AO.

### Insertion & exfil — live systems, not cutscenes
Briefing is the tabletop's **seven elements** — insertion, fire support, enemy intel, terrain & weather
roll, objectives, special rules, extraction — and the intel *can be wrong*, quality by source; your own
looted documents and photographed targets sharpen the next one. You pick the LZ and
ingress on the map. The ride in is real: AA and MG sites live in the world (loud past missions raise AA
threat; clean work and anti-AA sweeps lower it), the bird can be waved off or **shot down — a crash-site
E&E is a mutated mission, not a game over.** Hot-LZ outcomes span cold, tight (rappel), the VC spotter
with a bamboo telegraph (an invisible tail raising the AO's alert until you find him), spotter with a
rifle, hot. ABORT is always on the radio for partial credit. Missed the bird? The fallback LZ is final.

### The campaign — the war remembers
A persistent province map: villages, firebases, VC/NVA zones, trail networks, a war state that shifts
with every outcome. Home is a **walkable firebase hub** — the TOC briefing table, the roster tent, the
pad where your bird waits. Pick from generated operation offers weighted by the war state; forced events
(firebase defense) when a zone goes hot. Between missions: heal on the calendar, spend the team XP pool,
set loadouts by MOS, read the new man's bio. **Scoring pays avoidance** — +25 per contact avoided, −25
per detected, danger pay by enemy tier, minus every point of blood your team lost — **and kills pay
zero**: they're after-action information, not income. The ghost run and the gun run are both *viable*,
but the campaign quietly teaches patience. Three save tiers: REGULAR (default — quicksave anywhere),
HARD (checkpoint saves only, at mission-graph nodes — every firefight plays to its conclusion, and
death spends the checkpoint), IRONMAN (one slot, the unlockable covenant).

### World & presentation
1–1.5km generated AOs from biome presets — highland forest, jungle, swamp, paddy lowland — with rivers,
trails, dirt roads running firebase-to-village (giving convoys and car-bomb events a stage), villes with
attitudes, tunnel mouths as surface objectives (mark them, blow them — crawling *into* them is the
deferred tunnel-rat mode), and ground that **craters for real** under grenades, mortars, and bombs. The jungle must feel wrong-continent hostile: layered undergrowth, wind in
everything, patchy density, elephant grass you part with your barrel. **PSX low-poly 3D models for
everything** (~3–6k tris, nearest-filtered textures, the retro look sharpened — not excused — by the
render scale); 2D sprites are permitted only as distant-LOD stand-ins if measurements prove the win.
Gore is readable, stylized, PSX-honest: hard-edged dark splats that read on jungle green, exit wounds on
the wall behind, growing pools as the "he's gone" beat, ragdolls with directional impulses, gibs
reserved for explosions and point-blank headshots — constant gibbing kills the tone. Audio is
load-bearing, not polish: distance-filtered weapon reports with tails, jungle beds that go silent when
something moves, rain squalls that deafen, radio-procedure VO in your ear, Vietnamese shouts in the
trees. UI is diegetic-first — hand signals, barks, wildlife, one subtle "being noticed" pip — wrapped in
a modern minimal tactical shell: compass strip, mag-icon ammo, squad pips, weapon condition. The map is
a topo sheet, not a minimap.

## Scope honesty (what launch is NOT)

Launch: single-player, one faction (Army grunt), the full mission-generation loop, the squad RPG, the
campaign layer. **Post-launch/DLC horizon:** SF and Marines operation styles, 2–4 player host-authoritative
PvE co-op (feasibility studied and design sketched, deliberately deferred — humans replacing your AI
roster tensions Pillar 4 and gets its own design pass), tunnel-rat interiors, driveable vehicles,
flyable Huey, riverine insertion, prisoner capture, big-battle firebase defenses at full director
volume. Frozen means frozen: none of
it is worked until the core is undeniable.

## Working agreements every agent must know

- **Perf first, always.** A gating FPS number beats any feature. The PSX aesthetic is a perf strategy
  as much as a look.
- **A feature without a visible HUD affordance does not exist.** Simulation without presentation is
  unfinished work, not shipped work.
- **One seed per operation.** All mission-generation randomness derives from the operation's seed —
  deterministic, replayable, testable. Global RNG is for non-persistent cosmetics only.
- **Never block systems on art** — capsules and placeholders are honorable; two tracks run in parallel.
- **Canon over memory:** `production/GAME_GUIDE.md` + `production/adr/` (15 ADRs) are law; `DESIGN.md`
  is the founding vision; dated reports are history. Task truth lives in beads (`bd prime`).
- **The verification law:** nothing is "done" without a probe, a measurement, or a verified playtest.
- **The Summoner (Caleb) holds final authority.** Pillar-touching changes convene the War Room first.
