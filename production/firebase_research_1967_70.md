# Fire Support Base ground truth, 1967–1970

**Date:** 2026-07-26 · **Purpose:** source the FSB v3 layout. Sourced claims carry a link;
anything I inferred is marked INFERRED and is not to be cited back as fact.

The period matters: FSB doctrine settled early and then held. The construction pattern
"was developed early in the war and became increasingly precise and effective", so a
1967 base and a 1970 base differ in wear and clutter far more than in layout. Building to
1969 covers the whole band.

---

## 1. Shape is a function of terrain — the finding that reshapes v2.1

> "Firebases on flatter terrain were usually round, and those on ridges generally were
> rectangular due to terrain."
> — [Cherries Writer / HistoryNet](https://cherrieswriter.com/2023/08/19/what-was-the-concept-behind-fire-bases-in-vietnam/)

Sites were chosen by reconnaissance against the mission, not stamped to a template. The
designers weighed whether the perimeter already had fields of fire or whether the jungle had
to be cleared, and whether to take a flat open field for helicopter landings or a peak that
commanded the ground around it
([Anzac Portal](https://anzacportal.dva.gov.au/wars-and-missions/vietnam-war/experiences/fire-support-bases)).

**Consequence for us:** a perfect circle is the one shape that says "generated". A base on a
ridge is elongated along the ridge and irregular where the ground falls away. v3 uses a
harmonically perturbed closed curve with a 1.28× stretch on the ridge axis.

## 2. Size and the berm

FSB Kramer: **~250 m in diameter, ringed by a four-foot black earth berm, with one strand of
barbed wire 20 m beyond the berm**
([Anzac Portal](https://anzacportal.dva.gov.au/wars-and-missions/vietnam-war/experiences/fire-support-bases)).

Four feet ≈ **1.22 m** — which is why v3's `BERM_H` is 1.22 and not a rounded 1.2. The wire
standoff of 20 m sets the outer belt radius.

v2.1 was ~120 m across, under half of Kramer. v3 runs ~150 m on the short axis and ~190 m on
the long — still under Kramer but in the right band for a base the player walks.

## 3. The gun battery is a STAR, not an arc

> A six-gun battery deployed "in a star position, with the base piece at the center and the
> other five guns forming the points of the star". Smaller bases with two or four howitzers
> used "square or triangle formations".
> — [Cherries Writer / HistoryNet](https://cherrieswriter.com/2023/08/19/what-was-the-concept-behind-fire-bases-in-vietnam/)

**This is the single most valuable correction in the research.** v2.1 spaced six guns evenly
around a ring, which is a decoration, not a firing layout. The star exists so the battery can
mass fire in any direction without guns masking each other. v3 puts the base piece at the
centre and five on the points at 27 m.

Range, for siting against the AO: **105 mm ≈ 11,000 m, 155 mm ≈ 14,000 m** (same source).

## 4. Composition

- Larger bases: two or three infantry companies, possibly a battalion. Smaller: one infantry
  company with a two-gun artillery platoon (same source).
- Standard furniture across FSBs: **earthen berms, concertina wire, guard towers, sandbagged
  bunkers, and interconnected trenches**
  ([Grokipedia](https://grokipedia.com/page/Firebase_Vietnam_War)).
- "Most larger firebases contained a helicopter landing pad for resupply and medical
  evacuation" (Cherries Writer).
- Engineers built and often held part of the perimeter themselves — at FSB Coral in May 1968
  1 Field Squadron Group was allocated a large part of the defensive perimeter and held it
  during the fighting ([Anzac Portal](https://anzacportal.dva.gov.au/wars-and-missions/vietnam-war/experiences/fire-support-bases)).

## 5. What the sources did NOT give me

Searched for and **not** found in citable form: bunker-line spacing in metres, interior road
widths, duckboard/PSP coverage, latrine siting distances, sump and drainage detail. The
memoir-level material on mud, planks and tire ruts is abundant as recollection but I could not
pin numbers to it.

So the following in v3 are **INFERRED**, and are art decisions, not history:

| choice | value in v3 | basis |
|---|---|---|
| bunker spacing | ~13 around the perimeter, ≈35 m apart | matches the 20–40 m band already in our own brief |
| perimeter road | 4.4 m wide, 6.5 m inside the berm | wide enough for a mule/truck; INFERRED |
| wheel ruts | two 0.55 m strips at ±1.35 m | a 2.7 m track width; INFERRED |
| duckboard | 1.1 m wide spine through the camp | one plank run wide enough to pass; INFERRED |
| latrines | 4, set well downwind and away from the hootches | burn-out latrines were sited apart; distance INFERRED |
| parapet segment | 6 m, 140 HP | chosen for destruction granularity, not history |

## 6. Things to keep out

No HESCO (1990s), no Jersey barriers, no modern camouflage or signage typefaces, nothing
post-1969. Sandbags rotted and split within months, so a meaningful fraction should read
mildewed, torn, or sprouting weeds rather than uniformly new.

---

## Sources

- [Use of fire support bases during the Vietnam War — Anzac Portal (DVA)](https://anzacportal.dva.gov.au/wars-and-missions/vietnam-war/experiences/fire-support-bases)
- [What Was the Concept Behind Fire Bases in Vietnam? — Cherries Writer / HistoryNet](https://cherrieswriter.com/2023/08/19/what-was-the-concept-behind-fire-bases-in-vietnam/)
- [Firebase (Vietnam War) — Grokipedia](https://grokipedia.com/page/Firebase_Vietnam_War)
- [Fire support base — Military Wiki](https://military-history.fandom.com/wiki/Fire_support_base)
- [Vietnam firebase takes shape at artillery museum — army.mil](https://www.army.mil/article/233735/vietnam_firebase_takes_shape_at_artillery_museum)
