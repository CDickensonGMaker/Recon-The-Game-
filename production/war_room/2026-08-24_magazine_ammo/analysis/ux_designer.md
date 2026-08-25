# UX DESIGNER — Magazine ammo presentation (2026-08-24)

Read-only analysis. Pointers verified against code this session.

## 1. What the player sees today (the thing to replace)

- The HUD prints the exact round count and spare-mag count: `ammo_label.text = "%d" % current_ammo`,
  `mag_label.text = "MAG: %d" % spare_mags` — `scripts/ui/hud.gd:160-162`, labels declared at
  `hud.gd:11-12`, wired from `weapon_holder.magazine_changed` at `hud.gd:125,141`.
- The counter is fed from `scripts/player/weapon_holder.gd:6` (`magazine_changed(current_ammo,
  spare_magazines)`) and the ammo model is a pooled pair `[current_magazine, spare_magazines]`
  (`weapon_holder.gd:24-25`). Reload completion tops the mag to full: `spare_magazines -= 1;
  current_ammo = current_weapon.magazine_size` — `weapon_holder.gd:792-793`. That top-up is the
  lie the Summoner is killing.
- Rounded easy refills to delete (fossil law, same change):
  - Field ammo cache: `weapon_holder.spare_magazines += 2` — `scripts/player/player.gd:720`.
  - Firebase supply crate: `spare_magazines += 3` — `player.gd:1029`.
- Empty-gun tell today is a dry click only: `weapon_holder.gd:383-386`. A jam is dry click +
  reload ring (`hud.gd:230-234`). No bolt-lock state exists.

## 2. The law lineage this must obey

- **ADR-032** (`production/adr/ADR-032-player-reputation-titles.md:21-22`): reputation "is never
  rendered as a number, anywhere". Lineage runs through ADR-018 §2 (ADR-032:90-93). Same family:
  the hit-marker X was killed 2026-07-29, audio only (`hud.gd:311-315`); no HP bar by design
  (`hud.gd:5-7`).
- **The nuance that saves us**: never-show-the-number bans *abstractions* (XP, level, HP, score).
  This HUD already counts *discrete carried objects* with numerals: `"GREN: %d"` (`hud.gd:194`),
  `"MED: %d"` (`hud.gd:157`), `"[F] BANDAGE FROM DOC (%d)"` (`player.gd:626`), the downed/bleed
  clocks (`hud.gd:70,270`). A soldier knows how many magazines hang on his belt — that is an
  object count, period-legal. What he does NOT know is the round count inside the mag on the gun.
  **Rule of the package: mags are countable objects; rounds are never a number.**
- **ADR-030** (`production/adr/ADR-030-hud-buffer-doctrine.md:14-16`): the deferred period buffer
  names "ammo" as one of four persistent HUD elements. Whatever ships now must be expressible as
  a small bitmap glyph row later — pips survive that translation; a live counter would not.
- **r4bk law** (`production/adr/ADR-012-input-doctrine.md:52-55`): no visible affordance = the
  feature does not exist. Mag state, press-check, and the resupply verb each need a surface.
- Interact is F, everywhere (ADR-012:35). Hold-grammar already exists: `"[HOLD F] SATCHEL THE
  MOUTH"` (`player.gd:622`), `"HOLD [F] TO PATCH UP"` (`hud.gd:107`).

## 3. The bandage grammar to mirror (found, cited)

The resupply verb must copy this shape *exactly* — it is the game's only squad-hands-you-a-thing
interaction and it already solved every problem we have:

1. **Prompt**: `"[F] BANDAGE FROM DOC (%d)" % _squad_ref().medic_bandage_count()` —
   `player.gd:626`, rendered through the field-prompt slot (`hud.gd:43-47`, polled at 5 Hz,
   `player.gd:1541-1546`).
2. **The never-lie gate**: `_nearby_medic()` (`player.gd:679-690`) returns null unless Doc is
   alive, within 2.5 m, his bag has stock, AND the player is below carry cap. The comment at
   `player.gd:676-678` states the contract: "the prompt has to be able to lie about nothing".
3. **Execution + receipt toast**: `player.gd:1011-1020` — success `"DOC HANDED YOU A BANDAGE
   (%d LEFT IN HIS BAG)"`, failure `"DOC IS OUT - NOTHING LEFT IN THE BAG"`.
4. **The finite squad economy behind it**: `MEDIC_BANDAGES: int = 6` with the design note
   "Running it dry is meant to be one of the reasons you go home" —
   `scripts/squad/squad_system.gd:7-10`; hand-one-out at `squad_system.gd:339-343`.

The M60 gunner already exists as MOS `"MG"`, display "MACHINE GUNNER", earned nick "PIG"
(`scripts/squad/squad_roster.gd:64,73,77-78`), reachable via `member_by_mos("MG")` exactly as the
medic chain does (`squad_system.gd:283`).

## 4. Judgment on the option menu

| Option | Verdict |
|---|---|
| Press-and-hold check-mag | **IN — the centerpiece.** Period-authentic (soldiers press-check and heft the mag). Hold-R while tap-R reloads; plays a viewmodel tilt via the existing `_play_vm_clip` machinery (`weapon_holder.gd:765`) and prints a *band*, not a number: `FEELS FULL / ABOUT HALF / RUNNING DRY / LAST ROUNDS`. Bands are feel-text — fully inside ADR-032. |
| Pouch list on inventory screen | **OUT as a screen** (no inventory screen exists; building one for this is scope). **IN as a HUD pip row**: one pip glyph per mag in the pouch — an object count, same legality as `GREN: %d`. Replaces `ammo_label`+`mag_label` (`hud.gd:11-12,160-162` deleted, fossil law). |
| Tracer at mag end | **IN.** Last-3-rounds tracers on the player's own weapon. It is the ONLY tell that works mid-siege at night without reading anything, and it is period practice. Cheap: the fire path already knows `current_ammo` (`weapon_holder.gd:423`). |
| Hard bolt-lock on empty | **IN.** M16/M1911 lock open: first empty trigger pull = distinct bolt-open viewmodel state + deeper click, so empty is never mistaken for a jam (jam keeps its dry-click + ring tell, `hud.gd:230-234`). AK/Mosin family keeps the plain dry click — period-correct differentiation for captured weapons. |

**Reload choice: the system auto-picks, fullest mag first; the player feels the consequence.**
No mag-picker UI. Reasons: (a) Pillar 4 — the player is IN the squad, not managing spreadsheets;
(b) fullest-first is real drill AND produces the intended decay — late in a fight the "fullest"
mag is a half mag, and the press-check is how you learn that; (c) a picker UI is exactly the
gamey surface ADR-032's lineage keeps burning down. The partial mag ALWAYS returns to the pouch
(the Summoner's directive verbatim) — nothing is discarded, so there is no wasted-half-mag
failure mode, only an honestly decaying pouch.

### The memory refinement (recommended, one step further)

Pips render fill-state (3 glyph states: full / part / low) only for mags the player *knows*:
fresh from resupply = known full; the mag he just swapped out = the band he last saw;
press-check updates the current mag's glyph. An untouched-since-fight mag shows a neutral pip.
This is ADR-022's philosophy (the map is your memory, `production/adr/ADR-022-the-map-is-your-memory.md`)
applied to the belt. If the council judges knowledge-tracking too rich for the demo gate, ship
uniform neutral pips + press-check only — the package degrades gracefully.

## 5. The resupply verb, spelled out (mirror of §3, line for line)

- Prompt: `"[F] MAGS FROM %s (%d)" % [SquadRoster.call_name(gunner.member), sq.gunner_mag_count()]`
  — new arm in `field_interact_prompt()` beside `player.gd:624-626`.
- Gate `_nearby_gunner()`: clone of `player.gd:679-690` — alive, ≤2.5 m, stock > 0, pouch below
  carry cap. The prompt lies about nothing.
- Execution beside `player.gd:1011-1020`; toasts: `"PIG HANDED YOU TWO MAGS (%d LEFT)"` /
  `"THE GUNNER IS OUT - NOTHING ON THE BELT"`.
- Economy: `GUNNER_SPARE_MAGS` constant beside `MEDIC_BANDAGES` (`squad_system.gd:10`), finite,
  never self-refilling — running the pig dry is another reason to go home. Mags handed over are
  FULL mags (the squad's cross-load fiction; one line in the bible covers why the M60 man is the
  ammo mule — he is, historically, the reason everyone else carries his belts).
- Field caches/crates (`player.gd:720,1029`) stop granting `+N spare_magazines` and instead hand
  mag *objects* through the same grammar (`"MAGS TAKEN (%d LEFT IN THE BOX)"`), or are cut —
  Summoner's call; the briefing's ask #2 leans cut for floor pickups.

## 6. Failure modes, answered

- **Night siege confusion**: carried by the two non-visual tells — last-3 tracers (visible only
  at the moment they matter) and bolt-lock (tactile/audible). The pip row is glanceable but never
  required mid-burst.
- **Wasted half-mags**: impossible by construction — retention is unconditional; the cost
  surfaces as pouch decay, which is the intended feeling.
- **Discoverability with no tutorial**: the resupply verb inherits the bandage verb's proximity
  prompt (r4bk satisfied by the same surface). Press-check gets a one-time teach: the first time
  a reload returns a partial to the pouch, toast `"HOLD [R] TO CHECK A MAGAZINE"` on the
  mission_hud channel (`hud.gd:290-292` shows the pattern). One toast, once, then silence.
- **Save/load**: the pip row derives from the persisted pouch array — no HUD state to save.

## 7. Fossil-law deletions this package requires (named for the record)

- `hud.gd:11-12` `ammo_label`/`mag_label` + `hud.gd:160-162` `_on_magazine_changed` numeral body.
- `weapon_holder.gd:792-793` top-up reload (replaced by mag-swap against the pouch array).
- `player.gd:720` (+2 mags) and `player.gd:1029` (+3 mags) rounded refills.
- The `magazine_changed(current_ammo, spare_magazines)` signal signature itself
  (`weapon_holder.gd:6`) — its int pair IS the old model; it should carry the pouch instead.

## The package, named: "THE POUCH AND THE PRESS-CHECK"

1. Pip row of mag-objects replaces both ammo labels (numbers only ever count objects).
2. Hold-R press-check → viewmodel heft + feel-band text. Tap-R reloads, auto-pick fullest,
   partial always retained.
3. Last-3 tracers + bolt-lock-open on empty (US weapons) as the no-HUD hard tells.
4. `[F] MAGS FROM <gunner>` copying the bandage grammar verbatim, finite gunner stock.
5. One one-time teach toast; everything else discovered the way the bandage verb is.
