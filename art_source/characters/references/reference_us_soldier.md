# US Infantry Soldier, Vietnam War (1965-1972) — Visual Reference for Low-Poly Character Modeling

Purpose: reference for a PS1/PS2-style game character. Focus is on SILHOUETTE, PROPORTION, COLOR (hex approximations for texture painting), and details readable at 3-5 m. Compiled from Wikipedia, vietnamgear.com, militaria dealers (IMA-USA, Moore Militaria), reenactor guides, and veteran accounts.

---

## Quick Color Palette (texture master swatches)

| Item | Fresh | Faded / field-worn |
|---|---|---|
| Jungle fatigues (OG-107) | `#5A5F44` olive-gray green | `#8A8C77` grayish sage, almost khaki-gray |
| Web gear / canteen covers (OD7) | `#4A4E38` | `#6E7059` |
| Mitchell camo cover, green side | base `#7D8A5E`, dark leaves `#3F4E33`, pale leaves `#9AA37B`, brown twigs `#5C4A33` | whole cover washes toward `#8E9478` |
| Flak vest (both services) | `#565B41` | `#767A62`, USMC vests often sun-bleached to `#8F8E74` |
| Jungle boot leather | `#1C1C1C` near-black | scuffed `#3A3630`, red-dust dusted `#6B5140` |
| Jungle boot canvas | `#4F5540` OD green | `#767B63` |
| Helmet steel (rim/underside) | `#3E4436` OD | — |
| Skin-visible metal (buckles, frame) | `#5A5D52` parkerized gray-green | — |
| Towel | `#6B7355` OD green | bleached `#9A9C85` |
| M16 rifle | black furniture `#181818`, gray receiver `#2E2E2E` | — |
| Red laterite dust (weathering overlay on boots/trouser cuffs/ruck bottom) | `#8A5A3C` | — |

Rule of thumb for the whole character: **everything is a slightly different value of gray-green**. Nothing matches. Fatigues, webbing, helmet cover, and ruck are all separately faded, giving a patchwork of 4-6 olive values. That mismatch IS the Vietnam look — avoid a uniform single green.

---

## 1. Jungle Fatigues (Tropical Combat Uniform / "jungle fatigues", OG-107 color)

**What it is:** From 1964 on, troops in-country wore the Tropical Combat Uniform (TCU) — a lightweight cotton poplin (later ripstop) uniform in shade OG-107. It replaced the heavier stateside sateen utilities for field wear.

**Silhouette / cut:**
- The coat is a **bush-jacket style shirt worn OUTSIDE the trousers**, hanging to below the hips like a short jacket. This is critical: it is not tucked in. It creates a loose, boxy torso.
- Very baggy overall — cut oversized for airflow, then further loosened by sweat and wear. Fabric sags and wrinkles heavily; model the torso with a slight A-line flare at the hem.
- Trousers are baggy through the thigh with **large bellows cargo pockets on each thigh** (a bulge on the outer/front thigh, roughly hand-sized, often stuffed and lumpy).
- **Trouser cuffs bloused into or over the boot tops** — tied off with blousing bands or just stuffed; produces a puffed "pantaloon" break at the boot collar rather than a straight pant leg.

**Pockets (key ID feature):**
- **Two slanted chest pockets** — bellows pockets angled inward-downward (outer top corner higher than inner), with buttoned flaps. The slant is visible at distance and is THE signature of the jungle jacket vs. the vertical-pocket stateside shirt.
- **Two lower bellows pockets** at the hip level of the jacket skirt.
- Exposed buttons on early versions; covered button plackets on most. At 3-5 m just paint a shadow line down the front and flap rectangles.

**Sleeves:** In the field, **sleeves rolled above the elbow is the default look** for grunts in hot weather (roll shows a thick cuff of fabric on the upper forearm/elbow). Sleeves down during night ops, monsoon, or in heavy brush/mosquito country. For a game character, rolled sleeves + bare forearms reads instantly as "Vietnam."

**Color:** New OG-107 is a mid olive with a gray cast (`#5A5F44`). Tropical sun and daily washing faded it dramatically toward a **pale grayish sage** (`#8A8C77`) — veterans' uniforms look almost gray-khaki. Sweat produces darker patches (back, armpits, chest under gear) — a big dark sweat "V" or full dark back panel is very authentic. Knees/elbows/seat lighter from abrasion.

**Insignia:** In the field almost nothing visible — subdued (black-on-olive) name and "US ARMY" tapes over the chest pockets, subdued shoulder patch. From 5 m these are just faint dark rectangles; can be omitted or painted as 2 dark strips above the chest pocket flaps.

---

## 2. M1 Helmet with Mitchell ("leaf") Camouflage Cover

**Dome shape:** The M1 "steel pot" is a smooth, deep hemispherical dome — noticeably deeper and rounder than a modern PASGT/ACH. Sits low, covering the tops of the ears. Sides drop nearly vertical.
- **Brim:** an almost-flat, slightly flared rim runs the full circumference, with a subtle downward "lip" — the front edge projects like a tiny visor and the rear flares out a touch more over the neck. In profile: round dome + thin continuous brim ledge, front brim very slightly pronounced.
- It's a two-part system (steel shell over fiberglass liner) but visually one object; the liner's edge is only visible if the pot is off.

**Mitchell pattern cover (used by both Army and USMC, introduced 1959):**
- Reversible cloth cover: **green "leaf" side out in Vietnam essentially always**. Pattern = overlapping leaf/blob shapes: mid-green base `#7D8A5E`, dark green leaves `#3F4E33`, pale green-tan leaves `#9AA37B`, thin brown twig lines `#5C4A33`. Reverse (almost never seen worn) is a brown/tan "cloud" pattern (`#A08A62` / `#6B4F35`).
- Cover has small **buttonhole slits** scattered over it (for inserting foliage) — at low poly, 3-4 short dark dashes on the texture sell it.
- Heavily faded covers wash out to a soft gray-green where the pattern is barely readable — perfect for low-res textures anyway.

**Elastic helmet band (Army signature):** an olive elastic band ~2 cm wide around the helmet just above the brim. Grunts wedged things under it:
- **Cigarette pack** (small white/red rectangle — high-contrast detail, great for a game texture)
- **Plastic bug repellent bottle** ("bug juice" — small dull white/gray bottle, usually at the back or side)
- Playing cards (ace of spades), spoon, toilet paper, rifle-cleaning gear.
- One or two small light-colored rectangles tucked in the band at the side/back instantly reads "Vietnam grunt."
- **Marines were not issued the elastic band** — they used a strip of black inner-tube rubber or nothing, so a USMC helmet looks cleaner or has a thin black band instead of OD elastic.

**Graffiti:** Hand-inked in black ballpoint/marker on the cover, iconic and widespread (more associated with Marines and later-war troops): girlfriend's name, hometown, short-timer calendar, peace signs, slogans ("BORN TO KILL", "SHORT", FTA, ace of spades). For the model: 1-2 small dark scribble marks on the cover front or side.

**Chin strap:** Almost never worn under the chin. Standard looks: **straps buckled together across the back of the helmet above the rear brim**, or left dangling/swinging at the sides. USMC often looped theirs up over the brim. Model either strap-across-the-back (cleanest) or two short dangling straps.

---

## 3. Flak Vests

Worn far more consistently by **Marines** (I Corps policy) than Army; Army grunts on foot patrol frequently left theirs behind. If you model one soldier with a vest and one without, vest = Marine coding.

### USMC M-1955 Vest
- **Construction:** ballistic nylon + rigid Doron fiberglass plates → looks **stiff, quilted/segmented, and bulky**, with a visible horizontal+vertical seam grid (plate pockets) like large scales, especially across the chest.
- **Collar:** early ones collarless with a distinct **rope ridge on the right shoulder** (a raised cord welt to keep the rifle sling from slipping — subtle bump in silhouette); a 3/4 collar on later production.
- **Length:** short — ends at the **natural waist / navel**, riding above the pistol belt. Boxy crop-top proportion over the longer jungle jacket.
- **Closure:** front zipper under a flap; **very often worn fully open and flapping** in the heat — two stiff front panels hanging apart showing the shirt beneath. Extremely characteristic USMC-in-Vietnam look (see Hue 1968 photos).
- Lower front pockets and lots of hand-inked graffiti on the back ("UNCLE SAM'S MISGUIDED CHILDREN", short-timer calendars).
- Color: OD `#565B41`, USMC vests commonly bleached pale `#8F8E74`.

### Army M-1952A / M69
- **Construction:** flexible layered ballistic nylon only — **softer, smoother, less segmented** than the Marine vest; drapes a little, with a quilted vertical stitch texture.
- M-1952A: **no collar**, web straps on shoulders, two low front pockets, zipper front. M69 (from 1968-70): same but adds a **3/4 stand-up collar** around the back/sides of the neck — a distinct raised ring under the helmet.
- Length: also waist-length. Elastic side/waist adjusters.
- Also worn unzipped in heat, though Army wore vests less often in the bush at all.

**Modeling note:** at 3-5 m the read is: stiff sleeveless waist-length OD vest, front zipper line, raised collar (Army M69) vs collarless + shoulder rope ridge and plate-grid texture (USMC M-1955). Both add ~10-15% width to the torso.

---

## 4. M1956 / M1967 Load-Carrying Equipment (LCE) — "web gear"

The web gear defines the mid-body silhouette. Canvas cotton (M1956, OD shade 7) or nylon (M1967, slightly darker/shinier green). Layout, front to back:

**Pistol belt:** wide (~5.7 cm) webbing belt worn at the natural waist over the jacket, with a dark metal T-hook or later Davis quick-release buckle at center front. Everything hangs from it.

**H-suspenders:** two padded straps over the shoulders, joined by a horizontal strap across the shoulder blades (H shape from behind). Front straps run down over the chest to hook onto the ammo pouches/belt. Shoulder pads are ~6 cm wide — visible padding bumps on the shoulders. A **field dressing/compass pouch** (small square pouch ~7 cm) is very commonly strapped to the front of ONE suspender strap at collarbone height — a little box on the chest. Sometimes a grenade hangs from the other side.

**Universal ammo pouches (x2):** on the belt at the **front, one each side of the buckle**, angled slightly outward at the hip-front. Small boxy pouches (~10 x 17 x 9 cm) with a top flap; a strap from each pouch top hooks up to the suspenders. **Fragmentation grenades were carried hung on the pouch's side loops** — one dark green M26/M67 grenade lump on the outer face of each pouch is period-perfect. M1967 nylon version is a shorter, squarer pouch.

**Canteens (x2, often more):** 1-qt canteens in fabric covers with dark snap flaps, **on the belt at the rear hips / kidneys** — one each side behind the hip, leaving the rear center free for the buttpack. Cover is a rounded-shoulder rectangle bulge. Grunts often carried extra canteens on the rucksack too.

**Buttpack (optional):** M1956 "field pack, combat" — a squat rectangular pack strapped to the rear center of the belt, resting on the buttocks (only when not carrying a rucksack; drop it if the character has a ruck).

**E-tool:** folding entrenching tool in an OD cover, hung from the belt at the hip or (more commonly with a ruck) strapped flat to the rucksack.

**Net effect on silhouette:** a lumpy ring of pouches around the waist — two boxes front, two round bulges rear — plus X/H straps on the torso. At low poly this can be 4 simple boxes + strap texture.

---

## 5. Jungle Boots

- Silhouette: standard combat-boot shape, shaft to mid-calf (~25 cm / 8" high), laced full height with speed eyelets; slightly rounded plain toe.
- **Two-material look (key feature): black leather foot/toe/heel + OD green cotton canvas shaft and tongue**, with black webbing reinforcement bands up the sides and around the collar. Ankle-height leather band, green upper.
- Two small brass **drain vent eyelets at the instep** (inner ankle) — two tiny dots, can be skipped or painted.
- Sole: black cleated "Panama" or Vibram sole, thin visible black edge line.
- Weathering: red-brown laterite dust (`#8A5A3C`) caked on soles, toes, and lower canvas; canvas fades badly.
- Trousers bloused over the boot top hide the upper third of the shaft — model boots + puffed trouser cuff overlapping.

---

## 6. Rucksacks

### Lightweight Tropical Rucksack (M1965 "lightweight ruck") — most iconic Army pack
- OD nylon/canvas bag on an **exposed tubular aluminum X/ladder frame — the bare metal frame is visible** above and beside the bag (dull silver-gray `#8E9088` or OD-painted).
- Bag is a single main sack with **three external flap pockets across the outside face** (one center, two flanking) — three bumps in a row.
- **Mounted LOW on the frame** — the bag rides at the small of the back/on the buttocks with empty frame showing above the shoulders. Distinctive "low-slung sack + skeletal frame" profile.
- Top flap with straps; drawstring throat.

### Tropical Rucksack (1968) — similar bag, larger, on the same style frame, bag mounted higher.

### ARVN Rucksack — the small pack
- Small-to-medium canvas pack on a **close-fitting steel X-frame that doesn't show much**; sits **HIGH between the shoulder blades**, clearing the belt gear.
- **Two small C-ration-can-sized pockets on the outer face**, entrenching tool strapped between them under the flap.
- Popular with Army grunts and LRRPs wanting a lighter load. Read: compact hump high on the back vs the big low-slung tropical ruck.

### What's strapped on (both types) — this is where the "loaded grunt" look comes from:
- **Poncho / poncho-liner roll** — horizontal OD sausage strapped under the flap or across the top or bottom.
- **Entrenching tool** in carrier, flat against the pack face.
- **Machete** in sheath, vertical on the side (Army; USMC often a Ka-Bar on the belt instead).
- **C-ration cans in a spare sock** tied on, canteens, smoke grenades (dark cylinders with colored tops) clipped to the frame or straps.
- **Claymore bag** (small OD satchel) slung or tied on.
- Air mattress roll, spare bandoliers, sandbags. The pack should look overloaded and lumpy, never neat.

---

## 7. Extra Ammunition — Bandoliers and MG Belts

- **M16 cloth bandoliers:** cheap OD cotton sleeves with **7 pockets** (one 20-rd magazine each) on a narrow strap. Worn **slung diagonally across the chest, 1-3 at a time**, often crossed both directions (X across the torso). They ride as a flat, slightly saggy strip of small rectangular bulges. Faded pale green `#7A7D68`. This plus the towel is the classic rifleman chest.
- **M60 belts:** 100-rd linked 7.62 belts worn **draped bandit-style in an X across the chest/shoulders** by gunners and by riflemen humping spare ammo for the gun. Visually: a strip of brass-and-black repeating texture (`#8C6E3A` brass, black links) — very high-contrast, great game detail. (In reality often carried in cans to keep clean, but the crossed-belt look is period-photographed and genre-iconic.)

---

## 8. Towel, Boonie Hats, Headgear Culture

- **OD towel around the neck** — draped like a scarf under the ruck straps, hanging down the chest both sides. Used as sweat rag and shoulder padding. THE iconic grunt signature; bleached pale green `#9A9C85`. On the model: a simple flat U-shaped band around the neck with two hanging tails.
- **Boonie hat** (jungle/tropical hat): soft full-brim floppy hat, shallow round crown, ~6 cm wavy brim, foliage loops around the crown (thin horizontal band texture). OG-107 green or, later, ERDL camo. Worn when helmets weren't required: rear-area troops on patrol-light ops, LRRPs, recon, SF, and many ordinary grunts on patrol when command allowed. Brim often shaped/snapped up.
- General rule for a squad: **helmets on line infantry and anyone expecting contact/artillery; boonies on recon/SF/LRRP and "cool" veterans**; occasionally a bare head with the towel. Mixing 1 boonie into a helmeted squad is authentic.
- Marines: also used the utility cover (flat-brimmed cap) in rear areas, but in the bush it's M1 helmet.

---

## 9. Body Proportions, Load, and Posture

- Average grunt: **19-22 years old, lean** — heat, humping, and C-rations kept them skinny. Model a slim build; no gym bulk. Height average ~5'9" (175 cm).
- **Load: 60-85 lbs (27-38 kg)** with ruck — roughly half body weight. Consequences for the model/animation:
  - **Forward lean** from the hips (10-15°) when the ruck is on; head juts forward, neck bent to see from under the helmet brim.
  - Hands often hooked into the ruck shoulder straps at the chest, or cradling the rifle at port/low ready.
  - Plodding wide-based gait, short steps; standing at rest = hip-shot slouch, weight on one leg.
- Silhouette math: the gear roughly **doubles apparent torso depth** — helmet dome + ruck hump behind + pouch ring at waist + bandolier chest. The head looks small relative to the loaded torso. Legs stay comparatively slim (just cargo-pocket bulges + bloused boots), which gives the classic top-heavy grunt outline.
- Without the ruck (firebase/assault): posture upright, torso reads as jacket + vest/webbing only — much slimmer; keep the pouch belt and bandolier so it still reads loaded.

---

## 10. Skin and Small Details

- **Faces:** young — 19-22. Sunburnt/tanned faces and forearms (`#B07B57` tan, sunburn `#C08060`; Black soldiers ~`#6E4A33` — integrated squads are historically correct and standard). Stubble common in the field; short hair, sideburns creeping longer 1969+. Mustaches common later-war.
- **Tattoos:** rare and small in this era (maybe a single forearm USMC bulldog/eagle); no sleeve tattoos — skip them.
- **Face camo:** NOT worn by ordinary line infantry. Only LRRPs, recon teams, SEALs, snipers painted faces (green/black stripes). A regular grunt has a bare, sweaty face — add a specular/sweat sheen instead.
- **Dog tags:** two tags on a chain — but usually **taped together (black tape) to stop noise, or one tag laced into a boot**. Visible options: thin chain at the neck disappearing into the shirt, or a small dark rectangle on the boot laces. With shirt open, tags on the bare chest.
- Other authentic micro-details: P-38 can opener on the dog-tag chain, cigarette in the helmet band, peace-sign medallion (1969+), rosary, insect-bite scabs on forearms, wedding-band on a bootlace. Wristwatch with OD strap, often worn face-inward.
- Shirt frequently worn **open at the collar 2-3 buttons**, or fully open / shirtless in firebase scenes (helmet + flak vest over bare torso = very Vietnam, esp. USMC at Khe Sanh).

---

## Army Grunt vs. Marine at a Glance (3-5 m read)

| Feature | US Army | US Marines |
|---|---|---|
| Flak vest | Often NOT worn in the bush; if worn: smooth M69 with stand-up 3/4 collar | Almost always worn: M-1955, stiff plate-grid texture, collarless w/ rope ridge on right shoulder, worn hanging open |
| Helmet band | OD elastic band stuffed with cigarettes/bug juice | No issue band — bare cover or thin black inner-tube strip; more graffiti |
| Rifle (early war) | M16/XM16E1 from 1965-66 | M14 (wood stock) until 1967-68, then M16A1 |
| Rucksack | Lightweight/tropical ruck on visible aluminum frame, or ARVN ruck | Marine M1941 haversack early, then tropical ruck; generally less pack, more vest |
| Camo uniform | OG-107 plain green; ERDL camo mostly SF/LRRP | ERDL camo utilities more widespread by 1969-70 |
| Overall vibe | Slimmer torso, big framed ruck, elastic helmet band | Bulkier armored torso, open flapping flak vest, graffiti helmet |
| Blade | Machete on ruck | Ka-Bar knife on the belt |

Both wear the same M1 helmet w/ Mitchell cover, same jungle fatigues, same jungle boots, same M1956-style webbing — the vest and helmet-band details do the distinguishing.

---

## Suggested Low-Poly Build Priority (what sells the silhouette)

1. M1 helmet dome + brim + band items (cigarette-pack rectangle)
2. Untucked baggy jacket w/ slanted-pocket texture, rolled sleeves
3. Waist ring: 2 front ammo pouches + grenades, 2 rear canteens
4. Towel around neck + crossed bandolier strip
5. Ruck: low bag + exposed frame + poncho roll (Army) — or open flak vest (Marine)
6. Two-tone boots + bloused trousers
7. Forward-lean posture under load

## Sources
- https://en.wikipedia.org/wiki/OG-107 , /Jungle_boot , /M-1956_load-carrying_equipment , /M-1952_Flak_Jacket , /Flak_jacket , /M1_helmet , /ERDL_pattern
- https://www.vietnamgear.com/kit.aspx?kit=374 (Mitchell cover), kit=32 (suspenders), kit=26 (M1955), kit=16 (bandoleer), kit=120 (ARVN ruck)
- https://www.mooremilitaria.com/whats_new/body-armor-vietnam-use-and-development/
- https://www.ima-usa.com (original USMC M1 helmets w/ graffiti, M-1955 vests)
- https://veteransbreakfastclub.org/why-did-vietnam-marines-not-wear-helmet-bands/
- https://cherrieswriter.com/2018/08/27/helmet-cover-graffiti/
- https://charliecompany.org/2013/01/19/what-did-vietnam-soldiers-carry/
- https://military-history.fandom.com/wiki/ARVN_Rucksack ; https://ciehub.info/equipment/loadbearing/RucksackARVN.html
- https://strikehold.wordpress.com/2010/07/06/u-s-army-m1956-load-carrying-equipment-lce/
