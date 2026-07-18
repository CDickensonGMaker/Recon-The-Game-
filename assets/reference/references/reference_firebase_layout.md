# Vietnam FSB Layout — Verified Research (2026-07-17)

Deep-research run: 17 sources, 25 claims adversarially verified (24 confirmed, 1 refuted).
Primary sources: FM 5-15 Field Fortifications (1968), US Army CMH "Tactical and Materiel
Innovations" Ch. VIII (FSB Crook), 1/11 ACR after-action report (FSB Kramer, AHEC), SAMS
monograph ADA225455, Nicoli "Fire Support Base Development" (Marine Corps Gazette 9-69).

## The template (flat terrain — our AO)

- **Circle, laid out from a center stake.** FSB Crook: 40 m rope radius → ~80 m bunker-line
  circle, built in ONE day. Typical battery base ~250 m diameter (Kramer). Ridge-top bases
  elongate instead (Mary Ann: 500 × 75–125 m, 22 bunkers, continuous trench).
- **24 fighting bunkers every 15°** = the doctrinal ideal for one rifle company (Crook).
  Spacing 10–60 m depending on perimeter length.
- **~4 ft earthen berm** around the bunker line (Kramer).
- **Wire:** doctrine (FM 5-15) puts protective wire 40–100 m out (beyond grenade range);
  as built: 1–3 concertina belts, innermost 20–75 m from the bunker line, claymores + trip
  flares laced between bunker line and wire; 75–200 m cleared to the treeline.
- **6-gun battery in a star:** 5 guns on the points with full 6400-mil traverse, gun #6 at
  center firing illumination (Kramer, 155 mm). Diamond/square/rectangle accepted alternates.
  Gun pit: circular, ~30 ft (9 m) diameter, 3 ft berm; 155s sometimes demanded 40–60 ft.
  A full battery fit inside a 100–250 m perimeter — do NOT use modern (2016) 100 m dispersion.
- **TOC/FDC = nerve center**, central, dug in, mortar FDCs co-located inside it.
- **Mortar pits:** circular, parapet ≤50 cm high ≥90 cm wide, 1 m sighting gap ≈1,500-mil sector.
- **LZ:** approach/exit lanes ≥2 rotor diameters wide, clear of 30-ft obstructions for 150 ft.
- **Gates: barely documented** — typically just a dirt road interrupting trench + wire (Mary Ann
  had two). A road gap IS the historical gate.
- **Tempo:** built by a platoon + 6–10 engineers; guns firing within 5 h; everyone dug in with
  overhead cover by nightfall of day one.
- Perimeter extras: trip flares, claymores, fougasse drums, anti-RPG cyclone fence, sensors (post-'67).

**Refuted (do not use):** Mary Ann "two guns at each end" split-battery layout (0-3 votes).

## Game-scale mapping (kit, compressed ~60%)

| Real | Game (chunk kit) |
|---|---|
| 80 m company circle | `recipe_fsb_small` octagon, 46.7 m across flats, road-gap gate, no arty |
| 250 m battery circle | `recipe_fsb_battery` octagon, 72.7 m across flats, gate side, 6-pit star |
| 24 bunkers / 15° | 1 fighting position per wall chunk (10.75 m) ≈ same density |
| 9 m gun pit, 1 m berm | `fb_pad_gunpit_01` sandbag ring R4.5, `GUN_POINT` center |
| star R unknown (never pinned) | star R 13 m — open question, tuned to fit |
| wire 20–75 m out | belt ring ~8 m outside walls (compressed), cards @ 2.88 m spacing |
| LZ corridor | `APPROACH` marker on helipad pads, point over the perimeter |

## Open questions (research came up dry)

- Gun-to-gun star radius (no verified number exists) — ours is a fit-choice.
- Gate construction details; ammo point geometry; hooch placement rules; FSB Ripcord layout.
