# GAME DESIGNER — Magazine ammo, pickup kill, gunner resupply (2026-08-24)

Lens: fun, tension, pillars. Code read directly; every claim carries a pointer.

## 1. What the code does TODAY (the ground truth the directive changes)

The system is already magazine-COUNTED, not pooled — but it **destroys partials**:

- Ammo is `[current_magazine, spare_magazine_count]` per slot
  (`scripts/player/weapon_holder.gd:23-25`).
- Reload consumes one spare and sets the mag to full: `spare_magazines -= 1;
  current_ammo = current_weapon.magazine_size` (`weapon_holder.gd:792-793`). The rounds
  left in the partial mag **evaporate**. Reload is refused only when full
  (`weapon_holder.gd:752`) or out of spares (`weapon_holder.gd:750`).
- So today, tactical reload = maximum waste, and the game hides that waste. There is no
  decision in the reload key. The Summoner's directive turns the reload key into a
  *decision* — that is the whole fun case, and it is a good one.

**The pickups that hand rounded refills** (targets for ask #2):

| Source | What it hands | Pointer |
|---|---|---|
| `supply_crates` RESUPPLY verb (airdropped crate) | +3 full mags, +2 frags, medkits, whole-kit | `scripts/player/player.gd:1025-1033`, drop at `scripts/missions/field_director.gd:1063-1091` |
| Grenadier's AMMO FieldCache | +2 full mags, +1 frag per press | `player.gd:716-724`, box `scripts/props/field_cache.gd:24-28` |
| Tunnel cache | +2 full mags | `player.gd:976-980` |
| Fallen squadmate kit | +2 full mags, +1 frag | `player.gd:1064-1076` |
| Zombie wall buy `refill_ammo` | full mag +4 spares | `player.gd:780-796` (zombies economy, separate mode) |

One pickup is already honest: a gun off the ground carries whatever was left in it
(`player.gd:729-750`). That is the grammar the whole game should speak.

**The bandage grammar to mirror** (ask #3) — it is complete and good:

- Doc's bag is a counted pool, `MEDIC_BANDAGES = 6` (`scripts/squad/squad_system.gd:10,25`).
- Prompt gated on: Doc alive + in reach + bag not empty + player not at carry cap
  (`player.gd:679-691`); prompt text shows the pool: `"[F] BANDAGE FROM DOC (%d)"`
  (`player.gd:626`).
- One item per press (`squad_system.gd:339-343`, and the law written at `player.gd:703-704`:
  *"taking has to feel like taking, not like refilling"*).
- Doc restocks himself from medical boxes when dry (`squad_system.gd:291-300`) — the pool
  is finite but world-refillable.
- The squad HAS the man: MOS `"MG"` = MACHINE GUNNER exists in the roster
  (`scripts/squad/squad_roster.gd:78`, weapon special-cased at `squad_system.gd:88`).

**HUD today:** exact numerals — `"%d"` rounds and `"MAG: %d"` (`scripts/ui/hud.gd:160-162`).

**Allies burn no ammo** — the AI's only ammo reference is a cadence comment
(`scripts/allies/ally_base.gd:1928`), and a player-mounted MG is belt-fed `[mag, 99]`
(`weapon_holder.gd:111`). So the gunner's hand-out stock is a *designed* number, not a
simulated one. That is fine — Doc's bag is exactly the same fiction and it works.

**Save:** `primary_ammo`/`secondary_ammo` arrays round-trip already
(`scripts/autoload/save_manager.gd:169-170, 254-255`); a mag-list shape change must keep
that contract. Demo runs saves sandboxed (`scripts/levels/demo_game.gd:24`).

## 2. Judgment: what retention does at HLL lethality

TTK math: base 27 × torso 2.5 = 67 vs enemy HP 65-85 (CLAUDE.md:199-200) — 1-2 torso
hits kill. Aimed fire is cheap; **suppression fire is what eats mags**, and RECON's AI
suppression loop (CLAUDE.md:64-66) means players genuinely hose. With M16 mags at 20
(`data/weapons/m16a1.tres:12`), a firefight is 2-4 mags. Retention means after three
contacts the pouch is 20/20/13/9/4 — and *that pouch is the day's story written in brass*.

**The panic value is real but it must be AUTHORED, not random.** Draw order decides
everything:

- **FIFO/rotation** — mid-fight you randomly draw the 4-round stub. Reads as jank. Players
  will blame the game, not themselves.
- **Fullest-first (RECOMMENDED)** — every reload gives your best remaining mag. Reliability
  up front, desperation at the back: the deeper into the siege, the shorter your mags get,
  until the last reloads are 6-round gasps. That curve IS fail-forward (Pillar 5) — the
  game escalates by your own history, and the 4-round mag arrives exactly when the fight
  is worst. The panic is earned, legible, and self-inflicted. Ship fullest-first.

**Top-off consolidation: NO in v1.** Repacking loose rounds between mags dissolves the
stub pouch, and the stub pouch is the pressure that makes the gunner matter. The two
mechanics are rivals: consolidation is a free fix, the gunner draw is a *social* fix
(Pillar 4). Ship without it. If the Summoner's playtest reads stub-frustration instead of
tension, add it as a slow lull ritual (hold-R out of combat, 12s, interrupted by damage) —
it would be atmospheric (repacking mags at stand-to), but it is a dilution, so it must
earn its way in by playtest, not by spec.

## 3. The gunner inversion — fantasy vs play

The Summoner inverts reality: riflemen fed the M60 in a real squad; here the M60 gunner
feeds you. Judged for play, **the Summoner's read wins**, for three reasons:

1. **One legible node.** Doc = health node, Gunner = ammo node. The squad becomes a walking
   set of stations (Pillar 4: the squad is the RPG). A distributed "ask any rifleman"
   version has no geography and no ritual.
2. **The node is the loudest, most-targeted man on the wire.** Running to the gun under
   fire is a designed risk-run — resupply costs exposure, exactly like reaching Doc while
   bleeding. The M60's position (base of fire) makes the resupply run a *tactical*
   movement, not a menu.
3. **The mortality stake mirrors Doc.** Gunner dies → the ammo node dies (prompt gate
   mirrors `player.gd:679-691`). At HLL lethality that is a real siege event.

The fiction cost (5.56 mags out of a 7.62 gun team) is cheap to paper over: prompt reads
**"[F] DRAW AMMO FROM THE GUN TEAM (%d)"** — the gun position carries the squad's spare
bandoliers, which is period-true (the gun team WAS the squad's ammunition anchor, and
ammo bearers were its own MOS). Do not name the round type in the prompt. Reciprocity —
the player feeding belts TO the gun — is the future verb that fully dissolves the
inversion, and it is a beautiful post-EA hook; out of demo scope, name it and park it.

## 4. The demo siege economy (the number that decides if this is fun)

Demo: 45-man assault (`demo_game.gd:87`), ~6-min fight, squad AI does most of the
killing, player is one rifle in it. Player realistically fires 150-250 rounds across the
whole 30-min day. The pools:

- **Player start: 1 + 6 mags of 20 (140 rds) M16; M1911 1+2.** Current code issues only
  3 spares (`weapon_holder.gd:82`) — at HLL lethality with retention, 3 spares (80 rds)
  goes dry mid-siege with no margin for stub decay. 6 spares carries the day patrol AND
  leaves the player entering the siege with a degraded pouch — which is the point.
- **Gunner stock: 8 draws, 1 full mag per press** (mirror Doc's one-per-press,
  `player.gd:703-704`; Doc's bag is 6 — the gunner carries more because ammo outconsumes
  bandages ~3:1 in playtested shooters). +160 rds of insurance, behind an exposure run.
- **Gunner restock:** at the firebase ammo point / grenadier's box, mirroring Doc's
  self-restock (`squad_system.gd:291-300`). Pre-siege stand-to = the gunner tops off; the
  siege itself is a closed economy. Total ceiling for the night ≈ 300 rds. Finite, but a
  player who goes dry did a LOT of hosing — and dry-at-the-wire with the gunner dead is a
  legitimate fail-forward beat, not a design failure. The bayonet-and-frags endgame is
  Vietnam-true.
- **Dead gunner recourse:** extend the ally-corpse loot (`player.gd:1064-1076`) so the
  gunner's body yields his *remaining stock* instead of the flat +2. The node dies, the
  cache remains at his body — under the enemy's feet. That is a war story generator.

## 5. What to kill, what to keep (ask #2, fossil law)

- **KILL** the `supply_crates` whole-kit RESUPPLY verb (`player.gd:1025-1033`, both the
  verb and the `player.gd:630-633` prompt) and convert `_drop_supply_crate`
  (`field_director.gd:1063-1091`) to deploy a `FieldCache.Kind.AMMO` instead — same
  airdrop fiction, box grammar, finite stock. Fossil law: the group registration at
  `field_director.gd:1086` and both player.gd loops die in the same change.
- **KEEP** the FieldCache but retune: 1 full mag per press (not 2+frag) — it becomes the
  thing that restocks the *gunner* first and the player second.
- **RETUNE** tunnel cache (`player.gd:976-980`) and corpse kit (`player.gd:1064-1076`) to
  hand **partial mags with rolled counts (5-18 rds)** — dead men's mags are part-used.
  Scavenged ammo stops being "rounded easy" and starts being flavor.
- **LEAVE** the zombie wall buy (`player.gd:780-796`) as-is — separate arcade economy,
  separate mode, its full-mags-for-points is coherent there.
- Mounted-MG `[mag, 99]` (`weapon_holder.gd:111`) stays: the post feeds the post gun.

## 6. HUD (r4bk law × ADR-032 lineage)

ADR-032's law is "never rendered as a number" for progression
(`production/adr/ADR-032-player-reputation-titles.md:20,101`); the briefing extends the
spirit here. Current HUD prints exact rounds (`hud.gd:161`). Recommendation:

- **Pouch: one pip per magazine**, three fill states per pip (full / part / sliver at
  <20%). Mags are discrete objects now — show them as discrete objects. This satisfies
  r4bk (state visible or it does not exist) without a numeral.
- **Current mag: no live counter.** Replace with a weight-check: tapping reload when the
  mag is full/near-full toasts "MAG FEELS FULL" instead of cycling (extend the existing
  full-mag refusal at `weapon_holder.gd:752`), plus the last-rounds audio tell. Checking
  your mag becomes a physical act, which is the period fantasy.
- The exact-count HUD labels (`hud.gd:11-12,160-162`) get deleted in the same change,
  per fossil law.

## 7. Sequencing & risks

- This rewires the core combat loop's economy — it must land and be playtested **before**
  siege replay tuning, because it changes what the siege costs. The death body-swap is
  structurally untouched. The Summoner rules the order; the dependency is named.
- Save shape change (`save_manager.gd:169-170`) must round-trip a mag LIST; old saves
  carry `[int, int]` — migrate on load (treat as N full mags + partial), never crash.
- **Top risk (fun):** stub-pouch frustration in a 30-min demo if the loadout is lean.
  6 spares + fullest-first + gunner's 8 mirrors the bandage economy's proven feel. The
  guard is the Summoner's playtest gate — this feature is exactly what ADR-015 playtests
  exist for.
- **Second risk:** players never notice retention exists (r4bk). The pip HUD plus a
  one-time toast on first partial-mag stow ("HALF MAG POCKETED") makes the rule visible
  the first time it fires.

## Named sacrifices

- Convenience: no consolidation verb v1 — some players will resent unfixable stubs.
- Realism: the gunner-feeds-riflemen inversion stands, papered by "GUN TEAM" wording;
  true belt-feeding reciprocity is parked post-EA.
- The whole-kit airdrop resupply verb (frags + medkits in one press) dies with the crate;
  frag resupply must find its own home (grenadier's box already hands frags,
  `player.gd:723`).
