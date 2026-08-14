# RADIO VOICE PASS — toast/radio net consistency (DEMO_TIGHT_40 step 27)

**Date: 2026-08-14.** All pointers verified against code this date, after edits.
Parse gate after edits: `--import` clean, `res://tests/test_world_boot.tscn` PASS, zero SCRIPT ERROR.

**The established voice** (his, validated in play): ALL CAPS · period radio terseness · `-` beats ·
soldier's idiom · dark understatement · no meta/game-speak · no modern phrasing · no exclamation spam.
Reference lines: `pilot_recovery.gd:85,108,223,242`.

**Conventions treated as canon by this pass** (they are consistent across the net):
- Key hints in brackets: `[5]`, `[E]`, `[T]`, `[S]`, `[F]`, `[9]`, `[0]`
- Callsign prefixes with colon: `SIX:`, `S2:`, `DOC:`, `SQUAD:`
- Stock readouts in parens, ALL CAPS: `(%d LEFT)`, `(%d LEFT IN THE BOX)`
- Distances uppercase: `%dM`

---

## 1 · EDITED — 15 mechanical breaks fixed

| file:line | before | after |
|---|---|---|
| `scripts/missions/field_director.gd:554` | `...SNAKE EYE (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:558` | `...GET BACK (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:570` | `...SHOT OUT (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:585` | `...RAIN (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:589` | `...DANGER CLOSE (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:895` | `...SPOT ROUND OUT (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:920` | `...SHOT OUT (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:937` | `...SHOT OUT (%d left)` | `(%d LEFT)` |
| `scripts/missions/field_director.gd:811` | `GET TO A RADIO MAN (%dm)` | `(%dM)` |
| `scripts/missions/field_director.gd:398` | `LMB TO SEND, RMB TO BACK OUT` | `[LMB] TO SEND, [RMB] TO BACK OUT` (bracket convention) |
| `scripts/player/player.gd:1131` | `C-RATS DOWN. (%d left)` | `C-RATS DOWN (%d LEFT)` |
| `scripts/player/player.gd:1161` | `WEAPON CLEANED TO %d%%. (%d kits left)` | `WEAPON CLEANED TO %d%% (%d KITS LEFT)` |
| `scripts/squad/squad_system.gd:355` | `MAN DOWN! DOC IS MOVING TO YOU (%d bandages left)` | `MAN DOWN - DOC IS MOVING TO YOU (%d BANDAGES LEFT)` |
| `scripts/squad/squad_system.gd:381` | `DOC DIDN'T MAKE IT TO YOU.` | trailing period dropped (matches `THE PILOT DIDN'T MAKE IT`) |
| `scripts/allies/ally_base.gd:280` | `"%s — %s"` (Unicode em-dash) | `"%s - %s"` (the net's hyphen beat) |

No clear REGISTER breaks were found that could be fixed without inventing content — the meta-ish
lines are all listed as borderline below for his ruling.

---

## 2 · BORDERLINE — his radio voice, his call. NOT edited.

| file:line | current | proposed | note |
|---|---|---|---|
| `field_director.gd:385,522` | `%s: NONE AVAILABLE` | `%s: NEGATIVE - NOTHING LEFT` | "NONE AVAILABLE" reads like a vending machine, not a net |
| `field_director.gd:539` | `DANGER CLOSE - MEN NEAR THE TARGET - PRESS %s AGAIN TO CONFIRM` | `DANGER CLOSE - MEN NEAR THE TARGET - SEND %s AGAIN IF YOU MEAN IT` | "PRESS... TO CONFIRM" is UI-speak; proposal keeps the double-send mechanic legible |
| `field_director.gd:1508` | `AO IS %s - BATTALION RELEASED AIR TO US` | `AO IS RUNNING HOT - BATTALION RELEASED AIR TO US` | tier var prints `HIGH`/`CRITICAL` — threat-board labels; proposal loses the tier word |
| `field_director.gd:1827` | `ROUTE: %s` → `ROUTE: PLANNED 4, WALKED 2` | `S3 LOGGED THE ROUTE - PLANNED %d, WALKED %d` | debrief ledger tone; readable but flat |
| `player.gd:1152` | `FIELD-STRIPPING... %d%%` | leave, or `FIELD-STRIPPING - %d%%` | percent readout is mechanical by nature; ellipsis is the only oddity |
| `player.gd:980` | `TUNNEL CACHE - DOCUMENTS AND AMMO (+2 INTEL)` | `TUNNEL CACHE - DOCUMENTS AND AMMO - S2 WILL WANT THESE` | `(+2 INTEL)` is a stat popup; proposal loses the number |
| `player.gd:1001` | `OLD SHRINE - SOMEONE LEFT MAPS HERE (+1 INTEL)` | `OLD SHRINE - SOMEONE LEFT MAPS HERE - ONE FOR S2` | same class as above |
| `ally_base.gd:280` | `%s - %s` → e.g. `SPARKS - SMALL ARMS` | `%s - %s, LEARNED IT THE HARD WAY` | promotion bark is currently just name + skill label; dash fixed, content flat |
| `squad_system.gd:400` | `DOC: YOU'RE GOOD - ON YOUR FEET!` | drop the `!` | single exclamation in Doc's speech — arguably earned, so left alone |
| `weapon_holder.gd:440` | `WEAPON FOULED - IT WILL JAM. CLEAN IT AT THE FIREBASE.` | `WEAPON FOULED - IT WILL JAM - CLEAN IT AT THE FIREBASE` | internal/trailing periods vs. the net's dash beats |
| `game_flow.gd:467` / `field_director.gd:1835` | `FIELD PROMOTION: %s` | leave | orderly-room terse; flagged only because it is label-shaped |

---

## 3 · FULL INVENTORY — ON-VOICE (untouched)

### scripts/main/game_flow.gd
- `:252` GUN RUN INBOUND
- `:305` SAPPERS ON THE WIRE
- `:467` FIELD PROMOTION: %s *(see borderline note)*
- `:136` dev time readout (`_dev_report_time`) — **dev tool, exempt** (only fires off the dev keys)

### scripts/levels/demo_game.gd
- `:259-265` SIEGE_AIR_BEATS (emitted at `:312`): FAST MOVERS WORKING THE VALLEY · GUN RUN AND
  NAPALM - DANGER CLOSE · GUNS ON THE FLANK · NAPALM ON THE TREELINE · CBU IN THE TREES ·
  STRAFING THE APPROACH · LAST PASS - EVERYTHING THEY HAVE
- `:277` SOMEBODY ELSE'S WAR - NAPALM ON THE TREELINE
- `:378` SQUAD MOVING OUT
- `:446` PROBE ON THE WIRE
- `:450` HERE THEY COME
- `:536` GUNSHIPS ON STATION - GET YOUR HEADS DOWN

### scripts/missions/field_director.gd
- `:146` YOU'VE BEEN MADE - THEY'RE MOVING TO CONTACT
- `:192` MOVEMENT IN THE TREES - THEY'RE LOOKING FOR YOU
- `:296` THE RADIO'S DEAD - YOU'VE LOST THE NET
- `:323` ON THE HORN - SEND YOUR FIRE MISSION
- `:388,525` NET BUSY - STAND BY
- `:405,529` NO TARGET - AIM AT THE GROUND
- `:413` %s - CALL WITHDRAWN
- `:808` NO RADIO - YOUR RADIO MAN IS DOWN
- `:1041` RESUPPLY ALREADY FLOWN
- `:1052` POP SMOKE [5] FIRST - THE BIRD NEEDS A MARK
- `:1055` RESUPPLY INBOUND ON YOUR SMOKE - 20 SECONDS
- `:1088` CRATE DOWN - [E] TO RESUPPLY
- `:1179-1183` CRISIS_CALL: SIX: THE FIREBASE IS IN CONTACT · SIX: A VILLAGE IS CALLING FOR HELP ·
  S2: CAMP LOCATION CONFIRMED · SIX: FRIENDLY ELEMENT PINNED · SIX: CONVOY AMBUSHED
  (+ fallback `:1543` SIX: TROUBLE IN THE AO)
- `:1380` CAPTURED DOCUMENTS - %d POSSIBLE POSITIONS MARKED (DATE UNKNOWN)
- `:1426` S2 INTEL: %s REPORTED %s
- `:1504` DEPOT HIT LAST NIGHT - BATTALION SENT WHAT IT COULD
- `:1506` %s HAS THE HORN - [T] FOR THE NET
- `:1516` SIX WANTS US SWEEPING %s - %dM OUT
- `:1542` %s - %s, %dM (crisis + bearing + distance)
- `:1598` STAND DOWN - THE WIRE'S QUIET
- `:1625` STAND TO - THE WIRE'S IN CONTACT
- `:1654` THE MUNITIONS DUMP IS GONE - MORTARS DOWN, NEXT PATROL RUNS LIGHT
- `:1675` MOVEMENT ON THE WIRE - STAND TO · `:1680` STAND TO
- `:1688` THEY'RE INSIDE THE WIRE
- `:1709` THEY'RE BREAKING - %d OF %d DOWN, THE REST ARE PULLING BACK
- `:1712` THE WIRE HELD - ALL %d ACCOUNTED FOR
- `:1714` FIRST LIGHT - THEY'VE MELTED AWAY (%d OF %d DOWN)
- `:1840` BACK INSIDE THE WIRE - PATROL %d LOGGED, %d KILLS
- fire-mission dispatches `:554,558,570,585,589,895,920,937` — on-voice after the `(%d LEFT)` fix

### scripts/player/player.gd
- `:240` THE NECKLACE IS GETTING HEAVY · `:251` THEY SAW YOU DO THAT
- `:290` CONTACT - CALLED IT IN, MARKED THE MAP · `:292` %s MARKED ON THE MAP
- `:315` LEECHES. GODDAMN LEECHES.
- `:473` TOO FAR FROM YOUR RADIO MAN FOR THE HANDSET
- `:545` HANDSET IN HAND - RIFLE SLUNG · `:589` CORD TAUT - THE RADIO IS PULLING
- `:708` YOU ARE CARRYING ALL YOU CAN · `:958` CARRYING ALL YOU CAN
- `:714` BANDAGE TAKEN (%d LEFT IN THE BOX) · `:724` AMMO TAKEN (%d LEFT IN THE BOX)
- `:750,763` PICKED UP THE %s · `:1659` DROPPED THE %s · `:1669` FLARE OUT
- `:875` GOING DOWN. TIGHT IN HERE. · `:933` THE MOUTH IS GONE.
- `:956` TOOK %d BANDAGES · `:966` BACK IN THE GREEN
- `:1017` DOC HANDED YOU A BANDAGE (%d LEFT IN HIS BAG) · `:1019` DOC IS OUT - NOTHING LEFT IN THE BAG
- `:1042` RESUPPLIED - MAGS, FRAGS, MEDKITS, CHOW, KIT
- `:1051` WOUNDS PACKED - PRISONER SECURED · `:1059` PRISONER SECURED · `:1093` DOCUMENTS RECOVERED
- `:1076` %s'S KIT - MAGS AND A FRAG RECOVERED
- `:1112` YOU NEED CHOW - YOUR HANDS ARE GETTING SHAKY [9] · `:1124` NO RATIONS LEFT
- `:1142` NO CLEANING KIT · `:1146` WEAPON'S CLEAN · `:1168` FIELD-STRIP INTERRUPTED
- `:1335` CLIMBING - [S] TO DROP OFF · `:1432` ON THE GUN - [F] TO GET OFF

### scripts/squad/squad_system.gd
- `:233` SQUAD: ON ME · `:235` SQUAD: HOLD POSITION · `:240` SQUAD: MOVE THERE
- `:251` SQUAD: WEAPONS FREE / WEAPONS TIGHT - HOLD FIRE
- `:301` DOC RESUPPLIED FROM THE MEDICAL BOX · `:334` AMMO BOX DOWN
- `:400` DOC: YOU'RE GOOD - ON YOUR FEET! *(see borderline note)*

### scripts/player/health_system.gd · scripts/player/weapon_holder.gd · scripts/ui/hud.gd
- `health_system.gd:173` BANDAGED - BLEEDING STOPPED / FULL TREATMENT - BACK IN THE FIGHT
- `weapon_holder.gd:437` WEAPON'S GETTING DIRTY - CLEAN IT WHEN YOU CAN [0]
- `weapon_holder.gd:440` WEAPON FOULED - IT WILL JAM. CLEAN IT AT THE FIREBASE. *(borderline)*
- `weapon_holder.gd:450` WEAPON JAMMED - HIT RELOAD TO CLEAR
- `hud.gd:292` YOU ARE DOWN - STAY WITH US

### world events
- `civilian.gd:409` THAT VILLAGER TALKED - THEY KNOW YOU'RE HERE
- `camp_mortar.gd:148` INCOMING - MORTARS ON THE COMPOUND
- `ambient_encounters.gd:318` THE VILLE'S CLEAR - THEY WON'T FORGET WHO CAME
- `ambient_encounters.gd:372` FRIENDLY ELEMENT ON THE NET - PASSING TO YOUR %s
- `ambient_encounters.gd:427` GUNFIRE TO THE %s - SOMEBODY'S IN IT
- `ambient_encounters.gd:450` THEY'RE CLEAR - ELEMENT BREAKING CONTACT FOR HOME
- `pilot_recovery.gd:85,108,223,242,250` — the reference set + THE PILOT DIDN'T MAKE IT

### Dev surfaces — exempt from the radio voice (bench/arena tooling, not the shipping net)
- `ai_stress_arena.gd:1560,1611,1613,1701,2114` (WAVE/GOD MODE readouts; `:1672` sapper line is
  on-voice anyway)
- `support_fire_range.gd:604,706` (VFX size readout, assault spawner)
- `game_flow.gd:136` dev time toast

### No toasts found
- `siege_director.gd` (comments only), `heli_lift.gd`, `helicopter.gd`, `air_traffic.gd`,
  `cas_airplane.gd`, `fire_support_bench.gd` (wiring only), `mission_hud.gd` (display sink only)

---

**Counts:** ~110 player-facing strings inventoried · 15 mechanical breaks fixed · 0 clear register
breaks (all meta-ish candidates are borderline) · 11 borderline rows awaiting his ruling · 9 dev-tool
strings exempt.
