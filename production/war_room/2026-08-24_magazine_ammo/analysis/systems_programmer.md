# SYSTEMS/PROGRAMMER — Magazine-based ammo (2026-08-24)

Read: briefing.md · CLAUDE.md (strict typing :69-164, fossil law :302-352, ADR-016 damage grammar :180-201) ·
`~/.claude/architect_knowledge/godot_standards.md` (typed signals, snake_case past-tense signal names).
All code READ, none touched.

---

## 1 · THE AMMO PATH AS BUILT

### 1a. Where ammo lives

- `data/weapons/*.tres` carry only **capacity**: `WeaponData.magazine_size` (`scripts/weapons/weapon_data.gd:14`),
  `reload_time` :15, `empty_reload_time` :16. No .tres carries live counts. Capacities of record:
  m16a1 20 · car15 20 · m14 20 · m1911 7 · m60 100 · rpd 100 · ppsh41 71 · mosin 5 · m70 5 · shotgun 8 ·
  launchers/grenade 1 (grep `magazine_size` over `data/weapons/`, e.g. `data/weapons/m16a1.tres:12`,
  `data/weapons/m60.tres:13`, `data/weapons/mosin.tres:12`, `data/weapons/shotgun.tres:13`).
- Live state is **per-slot pairs `[rounds_in_gun, spare_full_mags]`** on WeaponHolder:
  `primary_ammo: Array[int] = [30, 4]` / `secondary_ammo` (`scripts/player/weapon_holder.gd:23-25`), mirrored
  into working vars `current_ammo` / `spare_magazines` (:29-30). The mirror is hand-synced at **eight** sites:
  :67-72 (refresh_after_load), :86-87, :114-115, :139-140, :183-184 (_ready defaults), :591-594 (post-shot
  write-back), :796-800 (_finish_reload), :822-826/:852-862 (switch). This duplication is the #1 bug surface.

### 1b. Fire & reload flow, end to end

1. `_try_fire` gates on `current_ammo <= 0` → dry click (`weapon_holder.gd:383-386`).
2. `_fire_shot` decrements `current_ammo -= 1` (:423), writes back to the slot pair (:591-594), emits
   `magazine_changed(current_ammo, spare_magazines)` (:596; signal declared :6).
3. `_start_reload` (:738-767): jam-clear branch :742-748; refuses when `spare_magazines <= 0` (:750-751) or
   mag already full (:752-753); picks `reload_time` vs `empty_reload_time` (:757-761).
4. `_finish_reload` (:782-803): **`spare_magazines -= 1; current_ammo = current_weapon.magazine_size`**
   (:792-793). **This is the pooled-full-mag lie the Summoner is killing: a partial mag's remaining rounds
   are silently destroyed and the gun always comes back to exactly full.** Guard :752 exists precisely
   because reloading a near-full mag would waste a whole mag.
5. Launchers: `_warhead_fired = true` on fire (:562) — tube-empty until reload; `magazine_size = 1` and
   `spare_magazines` already behaves as a **loose-round count** for these.

### 1c. HUD readout

`scripts/ui/hud.gd:11-12` (`ammo_label`, `mag_label`) ← `magazine_changed` connected :125, primed :141,
rendered `_on_magazine_changed` :160-162 as `"%d"` rounds + `"MAG: %d"`. Reload ring: :237-249 via
`ActionProgress`. NOTE: the briefing cites ADR-032 never-show-the-number lineage; the HUD **currently shows
the exact round count** — that judgment belongs to UX/design, but every HUD change funnels through this one
signal, so the plumbing cost is one function.

### 1d. Every ammo grant/resupply site (the full census)

| Site | File:line | What it grants |
|---|---|---|
| Field AMMO box (grenadier's) | `scripts/player/player.gd:716-724` | `spare_magazines += 2` + 1 frag per draw; box = `scripts/props/field_cache.gd` (AMMO_STOCK 10 :28, draw :69-74, nearest :78-91) |
| Supply crate `supply_crates` group | `player.gd:1025-1044` | **arcade full kit**: `+3` mags, 2 frags, medkits, smoke/claymore/satchel/flares/rations — then `crate.queue_free()` |
| Tunnel cache | `player.gd:977-980` | `spare_magazines += 2` |
| Fallen squadmate kit | `player.gd:1063-1076` | `spare_magazines += 2` + 1 frag |
| Ground weapon pickup | `player.gd:729-750` | carries real state via `WorldWeapon.ammo_in_gun/spare_mags` (`scripts/props/world_weapon.gd:32-33`); enemies drop `(0, 1, captured)` at `scripts/enemies/enemy_base.gd:2974` |
| Zombie wall buy | `scripts/zombies/zombie_wall_buy.gd:54-66` → `player.refill_ammo` `player.gd:780-796` | full mag + 4 spares |
| Armorer's rack draw | `scripts/levels/armorers_bench.gd:207-209` | fresh `[magazine_size, 4]` |
| Mounted MG | `weapon_holder.gd:98-123` | snapshot/restore; mount = `[magazine_size, 99]` "fed by the post" (:111) |
| Labs (not shipping loop) | `ai_stress_arena.gd:1322-1328`, `gun_range.gd:148,345`, `gore_lab.gd:282` | bench stocking |
| Death strip | `player.gd:1650-1656` | zeroes the pair |
| Enemy captured equip | `weapon_holder.gd:78-90` | fresh `[magazine_size, 3]` |

Save path: capture `save_manager.gd:163-171` → `save_data.gd` PlayerBlock `primary_ammo: Array = [30, 4]`
:73-74, to_dict :93, from_dict :112-113 → restore `save_manager.gd:248-259` → `refresh_after_load()`
(`weapon_holder.gd:62-75`).

---

## 2 · THE BANDAGE GRAMMAR TO MIRROR

The mechanic is a **prompt/verb pair on the player + a counted stock on SquadSystem**:

- Stock: `SquadSystem.medic_bandages: int = MEDIC_BANDAGES` (6) (`scripts/squad/squad_system.gd:10,25`) —
  explicitly non-self-refilling ("running it dry is meant to be one of the reasons you go home", :7-9).
- Gate: `player.gd:_nearby_medic()` :679-690 — squad ref via `health_system.revive_handler` (:670-673),
  refuse when player at `CARRY_MAX`, when bag empty (:685), when Doc dead, **range 2.5 m** (:690). The
  comment states the law: *the prompt must not promise a verb that can lie* (:676-678).
- Prompt: `"[F] BANDAGE FROM DOC (%d)"` in the prompt chain `player.gd:624-626` — note its **priority slot**
  in the [F] chain (after tunnels/MG/shrines, before field caches).
- Verb: `_try_field_interact` `player.gd:1011-1020` → `sq.take_medic_bandage()` (`squad_system.gd:339-343`,
  decrement + true/false) → toast with remaining count.
- Member lookup: `member_by_mos("MEDIC")` (`squad_system.gd:220-223`). The M60 gunner already exists as
  MOS `"MG"` carrying `"m60"` (`squad_system.gd:143-151`, body `us_grunt_mg` :158).
- Restock loop: Doc pulls from a laid MEDICAL box (`_medic_restock` :293-301); grenadier lays the AMMO box
  `_drop_ammo_box` :324-335 on the same resupply cadence (:39-46).

**The mirror is mechanical**: `mg_ammo_stock: int` on SquadSystem (counted in MAGAZINES, or belts-for-mags
flavor), `_nearby_gunner()` on player (gate: alive `member_by_mos("MG")`, ≤2.5 m, stock > 0, player pouch
not full), prompt `"[F] AMMO FROM <GUNNER> (%d)"` in the chain at :624-ish, verb branch beside :1011,
`take_mg_ammo()` beside :339. Optional restock from the grenadier's AMMO FieldCache exactly as
`_medic_restock` does. Ally-side ammo accounting is NOT needed — see §3.

---

## 3 · MINIMAL MAGAZINE MODEL

### Shape

Per-slot **`Array[int]` of round-counts, index 0 = seated mag**, e.g. `[14, 20, 20, 7, 0]`. No Mag class,
no Resource — it matches the existing `Array[int]` pair, serializes as-is through `to_dict`, and keeps
strict typing trivial. Working mirrors `current_ammo`/`spare_magazines` DIE; derive
`current_rounds() -> int` (= mags[0]) and `spare_mag_count() -> int` (= mags.size() - 1) instead — deleting
the eight hand-sync sites is half the point of the change.

Add `@export var feed: Enums.FeedType` to WeaponData (new enum in `scripts/enums.gd` alongside FiringMode):

- **MAGAZINE** (m16a1, car15, m14, m1911, ppsh41, ak47): reload = pouch the seated mag (keeping its true
  count, dropping a 0-mag), seat the **fullest** spare (`selection rule: max; ties → lowest index`). Partial
  mags persist forever. Tactical reload keeps guard :752 semantics only when NO spare beats the seated mag.
- **BELT** (m60, rpd): identical array semantics — a "mag" is a 100-round belt; a part-fed belt persists.
  The M60 does NOT need a separate variant: linked-belt flavor is presentation (HUD label "BELT", reload
  anim), not model. The **mounted** MG keeps its own snapshot path (`weapon_holder.gd:98-143`) — convert its
  `[magazine_size, 99]` to an array of 99 belts or, better, an `is_mounted_infinite` flag; the post feeds it.
- **INTERNAL** (mosin, m70, shotgun): array model does NOT apply — these have no detachable mag. Keep
  `tube: int` + `loose_rounds: int` pool per slot. Mosin: from-empty = stripper clip, 5 in one stroke
  (`empty_reload_time` `mosin.tres:14` already authored 9.33 s); partial = round-by-round top-up, shotgun
  same. This is the one place a pooled count legitimately survives, because that is the hardware truth.
- **SINGLE** (m79, m72_law, rpg2, rpg7, m26): `spare_magazines` is already a loose-round count
  (`magazine_size = 1`); map to `loose_rounds`, `_warhead_fired` path (:562) untouched.

### What breaks (every consumer of the pair shape)

- `weapon_holder.gd` — all sites in §1a/§1b, plus `equip_captured_weapon` :82, mount/unmount :111/:130,
  drop-strip callers.
- `player.gd` — :720, :743-747, :786-796, :978, :1029, :1072, :1650-1656 (all §1d rows).
- `save_manager.gd:169-170, 254-255` + `save_data.gd:73-74, 93, 112-113` — the Array serializes unchanged
  structurally; **semantic migration needed**: old `[30, 4]` decodes as "mag of 30 + one mag of 4". Add a
  `mag_model` version key to PlayerBlock; on absence, rebuild `[magazine_size, magazine_size × N]` from the
  old pair. Cheap, and demo saves are short-lived.
- `hud.gd:160-162` — signal payload changes to `(current_rounds: int, mags: Array[int])`; render per UX
  decree (count vs pips vs nothing).
- Labs: `ai_stress_arena.gd:1322-1328`, `gun_range.gd:148,345`, `gore_lab.gd:282`, `armorers_bench.gd:207-209`.
- `enemy_base.gd:2974` — drop signature `(0, 1)` → a captured gun should drop with its true part-mag
  (seeded partial, ADR-010-style deterministic) — the anti-"rounded pickup" payoff.
- **AI squadmates track no ammo at all** — `ally_base.gd` has zero ammo state; :1928 is explicit ("the
  skipped round costs cadence, not ammo"). Nothing to convert; the MG-gunner stock is a new SquadSystem
  counter like `medic_bandages`, NOT per-ally accounting.
- Grenades are untouched: loose `grenade_count` on `equipment_manager.gd:16,165-180`.

### The "rounded easy pickup" kill-candidates (Summoner ask #2 — needs his ruling on scope)

`supply_crates` full-kit verb `player.gd:1025-1044` (the arcade one) · tunnel cache +2 :977-980 · corpse
kit +2 :1063-1076 · `refill_ammo` full-top :780-796 (zombie-mode only — can stay pooled-flavored there or
convert to "+N full mags"). Field caches can stay: a box handing **whole mags** is discrete, not rounded.

---

## 4 · FOSSIL KILL-LIST (die in the same change, ADR-023)

- `weapon_holder.gd:24-25` pair semantics; `:29-30` `current_ammo`/`spare_magazines` mirrors; sync blocks
  `:67-72, :86-87, :114-115, :139-140, :183-185, :591-596, :822-826, :852-862`; `_finish_reload` full-mag
  top-off `:792-800`; `_start_reload` spare-count gate `:750-753`.
- `player.gd:720-721, :786-796 (or rewritten for zombies), :978-979, :1029-1030, :1072-1073, :1650-1656`
  — every `spare_magazines +=/=` write.
- `save_data.gd:73-74` defaults `[30,4]/[7,3]`; `save_manager.gd:169-170/254-255` only if field names change.
- `hud.gd:160-162` old payload; `armorers_bench.gd:207` `[magazine_size, 4]`; `gun_range.gd:148,345`;
  `gore_lab.gd:282`; `ai_stress_arena.gd:1325-1328`; `weapon_holder.gd:111` mount `[magazine_size, 99]`.
- If the Summoner kills the supply-crate verb: `player.gd:630-633` prompt + `:1025-1044` verb + whatever
  spawns `supply_crates` (grep the group before deleting — prompt/verb contract means both sides die).

The probe cannot let `spare_magazines` survive as a name anywhere — a fossil count next to a mag array is
exactly the two-systems trap the law exists for.

---

## 5 · BUILD SIZE & REGRESSION PROBE

**Two sessions** (a third if the Summoner also rules HUD redesign + supply-crate deletion into scope):

1. **S1 — the model**: FeedType enum + WeaponData field + .tres tags · WeaponHolder array conversion,
   mirror deletion, reload selection rule, INTERNAL/SINGLE paths · all §3 call-site rewrites · save
   migration · HUD signal payload · fossil deletions · probe green.
2. **S2 — squad resupply + edges**: SquadSystem `mg_ammo_stock` + take/count · player prompt/verb mirroring
   the bandage grammar · gunner-dead/dry states · enemy part-mag drops · labs re-stocked · demo-gate
   playtest prep.

**Probe ships with S1**: `tests/test_magazine_ammo.gd/.tscn`, same shape as `tests/test_flat_damage.gd`
(headless `_ready → _run`, duplicated constants-of-record, exit code) — asserts: (a) fire decrements
mags[0] only; (b) reload pouches the partial with its EXACT count and seats the fullest spare; (c) all-empty
reload refuses; (d) INTERNAL: mosin from-empty loads 5, partial loads stepwise, pool decrements; (e)
SaveData `to_dict → from_dict` round-trips a ragged array `[14, 20, 7, 0]` bit-exact, plus the legacy
`[30,4]` migration case; (f) `spare_magazines` symbol has zero grep hits (fossil tripwire, same trick as
`tests/test_fossils.tscn`); (g) MG-gunner take decrements squad stock and refuses at 0 (S2).

**Sequencing**: this touches WeaponHolder + save schema — do NOT interleave with the queued siege replay
(save-layer freeze law) or the death body-swap; run it as its own change with the demo gate re-verified after.

**Biggest integration risk**: the save-schema semantic change riding through an untyped `Array` — it will
load without erroring and be silently wrong. The migration key + probe case (e) is the fence.
