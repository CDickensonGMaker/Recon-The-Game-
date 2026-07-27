# US Fire Support Base — CONSTRUCTION detail, 1968-70

**Purpose:** how a firebase was actually BUILT, so the models are made of the right things.
Companion to `assets/reference/references/reference_firebase_layout.md`, which covers LAYOUT
(circle, bunker spacing, gun star, wire distances) and is the doctrine source. This document covers
materials, methods and the texture of daily life — the things that decide whether a bunker reads as
a bunker or as a box with a hole in it.

**Date:** 2026-07-26. Sources listed at the bottom; claims are attributed inline.

---

## 1. THE BUILDING KIT — what a firebase is physically made of

A firebase is assembled from **six materials and nothing else**. Get these right and it reads
correct; add anything outside this list and it stops being 1968.

| material | used for |
|---|---|
| **sandbags** | every revetment, parapet, blast wall, overhead cover, and the walls around each man's cot |
| **PSP** (pierced steel planking) | bunker roofs, helipad decks, duckboards, floors |
| **12x12 inch timbers** | bunker frames, roof stringers, gate uprights — HEAVY squared baulks, not poles |
| **emptied 105mm ammo crates, filled with dirt** | structural fill inside bunker walls |
| **corrugated sheet metal** | overhead cover under the sandbags, hootch roofs, latrine walls |
| **metal culvert sections** | ammo bunkers, personnel shelters |

> "Bunkers were built using emptied 105mm shell boxes filled with dirt, reinforced with 12-by-12-inch
> timbers, pierced steel planking for roofing, and sandbags for overhead cover."
> "Ammunition bunkers were built with any available material including 105mm wooden ammo crates,
> metal culverts, PSP, or wooden planks."

**Modelling consequence:** an ammo crate is not just clutter, it is a **wall material**. A bunker
wall should read as courses of dirt-filled crates behind a sandbag face, with 12x12 timber corners.

---

## 2. HOW A BUNKER WAS MADE — the crater method

This is the single most useful fact in this document, and it changes the silhouette.

> "Standard nine-foot bunkers built by **squaring up blown craters**. A standard package containing
> a shaped demolition charge, two sheets of pierced steel planking, and a bundle of sandbags was
> dropped at each bunker position, with shaped charges blown next to engineer stakes to create the
> initial hole."

- Engineer parties of **6-10 men**, working from dropped packages, one per position.
- The hole is **BLOWN, then squared up** — so a fighting bunker is a roughly-square pit with
  irregular, slumped edges, not a neat excavation. **Jitter the pit walls.**
- **Nine feet** (~2.7 m) is the standard bunker dimension.
- Two sheets of PSP is the entire roof allowance — so the PSP layer is thin and visible at the edges.
- Bunkers were also cut **into the earthen berm itself**: *"crewmen on the berm had built bunkers
  into the earthen wall of the perimeter, and to reinforce their construction the troopers had used
  ammunition boxes and sand bags."*

**Modelling consequence:** perimeter bunkers should be dug INTO the berm, not standing beside it.
The berm and the bunker are one object, which is also cheaper.

---

## 3. LIVING QUARTERS — the cot trench

> "Canvas tents with two-foot walls of sandbags were used for living quarters. **Each man dug a
> shallow trench for his cot, and then used the extracted dirt to fill sandbags which were then used
> to build individual walls around each cot.** This arrangement provided protection from mortar
> blasts and shrapnel."

This is the detail that will sell the tents. Inside a GP tent you should see:
- the cot sitting **in a shallow trench**, not on flat ground
- **its own low sandbag wall** around it, roughly 2 ft (0.6 m) — one per man, built by that man,
  so the heights and neatness should VARY
- the tent's own perimeter sandbag wall also ~**two feet**, NOT the 1.25 m I had

> "Soldiers filled sandbags for walling up hooches, which were new wooden barracks replacing the old
> tents. These hooches had cots inside, though they were very crowded."
> "Sandbags were layered like rock walls around the sides of hospital units and half-buried bunkers
> surrounded living quarters."

**Modelling consequence:** three distinct living types, not one — **GP tent** (canvas, 2 ft bag wall,
cot trenches), **hootch** (wooden barrack, sandbagged sides, crowded cots), and **half-buried
sleeping bunker**. Half-buried bunkers sit AMONG the quarters, not off on their own.

---

## 4. THE WIRE — and why ours looked wrong

> "Three strands of concertina wire encircled around the perimeter with **trip flares interspersed
> irregularly** in the wire. The concertina wire was a triple coiled spiral of barbed wire, with some
> bases having **five concentric circles of wire with three coils in each row — two coils on the
> bottom and one stacked on top**."

So a belt is a **pyramid: two coils at the bottom, one on top**. Not a single ribbon.

- **3 belts minimum**, up to 5 concentric rings.
- Trip flares **irregularly** spaced — never evenly. Evenly-spaced anything reads as procedural.
- Claymores, trip flares and ground illumination laced between the bunker line and the wire.

**Measured defect in the current base (2026-07-26):** of 434 `bwire_card` instances, **414 (95%) are
misaligned** — median **72.8 deg** off the perimeter radius, worst 86.6 deg. They face ALONG the wire
run instead of across it, i.e. rotated ~90 deg. This is the same class of error as the marker-facing
convention (Godot local +Z == Blender local -Y): the card's normal is its local +Y and was treated as
+X. **Every card must be oriented tangent to the ring with its face on the radius, and the contract
probe must assert it.**

---

## 5. GROUND AND SURROUNDINGS

> "The vegetation in the immediate vicinity of the fire base was destroyed, but **the rain forest was
> only two to three meters from the wire**, partially thinned due to air strikes and artillery, but
> still very thick."

- Cleared ground inside and immediately outside the wire; **jungle resumes 2-3 m past the last belt.**
  Doctrine wanted 100 m of clearance and reality often gave metres. The claustrophobia is the point.
- Total base **200-300 m diameter** (this base is compressed to ~110 m, ~60%, consistent with the
  compression the layout doc already declares).
- Interior contains, at minimum: **LZ, command/comms bunker, FDC bunker, gun pits**
  — plus elevated **observation towers at intervals** (plural, not one).

---

## 6. WHAT THIS CHANGES IN OUR KIT

| piece | change |
|---|---|
| `fb_bunker_fighting` | dig it INTO the berm; square-up-a-crater silhouette with jittered, slumped pit edges; ammo-crate courses behind the sandbag face; 12x12 timber corners |
| `fb_gp_tent` | perimeter bag wall down to ~0.6 m; add a **cot trench + individual sandbag wall per cot**, with varying height and neatness |
| `fb_hootch` | it is a **wooden barrack** with sandbagged sides, distinct from the tent; crowded cots |
| `fb_sleeping_bunker` | half-buried, sited AMONG the quarters |
| `fb_wire_belt` | pyramid stack: **2 coils bottom + 1 top**; 3 belts; trip flares at IRREGULAR intervals |
| all wire | cards oriented tangent to the ring, face on the radius — assert it |
| `fb_supply_dump` / ammo | add **metal culvert** sections and dirt-filled ammo-crate courses |
| `fb_tower` | more than one, at intervals around the perimeter |
| overhead cover | corrugated sheet UNDER the sandbags, PSP thin and visible at the edges |

---

## 7. THE M101 105mm HOWITZER — the gun that belongs in the pits

> "The ubiquitous 105MM howitzer was the mainstay of every firebase and used in nearly every major
> battle of the Vietnam War." The **M101A1**, with the **larger shield**, was the predominant model
> in Vietnam.

| dimension | value |
|---|---|
| overall length (travel) | 5.94 m |
| width | 2.21 m |
| height | 1.73 m |
| barrel length | 2.31 m |
| weight | 2,260 kg |
| crew | 8 |

- **Split-trail carriage** — trails SPREAD when emplaced, so the in-pit footprint is wider and
  longer than the travel dimensions.
- **Horizontal sliding wedge breech**; hydropneumatic recoil with a constant 42-inch run — so the
  recoil cylinder above the tube is prominent and long.
- **A metal shield over the frontal arc**, protecting the crew from small arms and splinters.
  The A1's larger shield is the Vietnam silhouette.
- Wheels are **pressed-steel disc with pneumatic tyres** — **NOT spoked**. A spoked wheel reads as a
  WW1 gun and was the main thing wrong with the first attempt.

---

## Sources

- [FSB CROOK — US Army CMH, "Tactical and Materiel Innovations" Ch. VIII](https://webdoc.sub.gwdg.de/ebook/p/2005/CMH_2/www.army.mil/cmh-pg/books/vietnam/tactical/chapter8.htm)
- [US Army Heritage & Education Center — Vietnam Fire Support Base](https://ahec.armywarcollege.edu/trail/Vietnam/index.cfm)
- [Firebase (Vietnam War) — overview](https://grokipedia.com/page/Firebase_Vietnam_War)
- [Firebase Crook](https://en.wikipedia.org/wiki/Firebase_Crook)
- [Battle of Fire Support Base Ripcord](https://en.wikipedia.org/wiki/Battle_of_Fire_Support_Base_Ripcord)
- [A Year In Vietnam With the 101st Airborne, April 1969 - March 1970](https://currahee.org/ARCHIVES/A_Year_in_Vietnam.pdf)
- [M101A1 105mm Light Howitzer, Towed — FAS](https://man.fas.org/dod-101/sys/land/docs/m101a1.htm)
- [A Brief History of the M-101A1 105mm Howitzer — HistoryNet](https://historynet.com/a-brief-history-of-the-m-101a1-105mm-howitzer/)
- [M2A1 105mm Howitzer — Museum of the American G.I.](https://americangimuseum.org/collections/restored-vehicles/m2a1-105mm-howitzer-1941-1953/)
- [Storms of Steel — HistoryNet](https://historynet.com/storms-of-steel/)
- [Operations into the A Shau Valley, 1968-69 — Military Trader](https://www.militarytrader.com/militaria-collectibles/operations-into-the-a-shau-valley-1968-69)
