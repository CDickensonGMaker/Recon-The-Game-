# BRIEFING — Combat AI: life-preservation, cohesion, faction asymmetry (Summoner, 2026-08-24)

The Summoner, verbatim: *"im also really worried that the friendly and enemy AI isnt as strong and
'realistic of actions' as im hoping. I feel like they bounce around too much and areant really
hitting that cod style of life like preservation im looking for still. can we do more reasearch on
how our ais are set up, sync them together but maintaining the asyncronistic versions of thesmelves
(nva vc vs usa style) and do more reasearch on advance gameplay AI and what we can do (im saying
more for how long they hold cover, giving eachother supressing fire and moving as a unit not just
existing as npcs that somehwat move and think)"*

Read as three asks:
1. **Map how our AIs are actually set up** — friendly squad AI vs enemy AI vs garrison, where they
   share code and where they diverged (the divergent-systems blindspot is a known project disease).
2. **Diagnose the "bouncing"** — men leave cover too eagerly, goal churn, no visible team behavior.
   MEASURE it: dwell constants, goal-switch conditions, think cadence, hysteresis values as built.
3. **Research advanced gameplay AI** and propose: longer cover holds, mutual suppressing fire,
   moving as a unit (bounding, base-of-fire + maneuver), one shared brain with faction doctrine
   parameters — synced core, asymmetric styles (US methodical/firepower vs NVA/VC infiltration,
   hug-the-belt, ambush-and-fade).

Standing law this builds on (do not re-decree it — explain why it undershot):
- FEAR doctrine ruled 2026-08-04: no un-suppressed open-ground charges, bound cover-to-cover,
  suppress-then-move, kill from angles, in the SHARED goal scorer. Allies already got cover dwell +
  goal-switch hysteresis that day ("super squierly" conviction). The Summoner says it STILL bounces.
- His acceptance test outranks any probe metric: "I don't really feel like I'm in danger" /
  now also "they bounce around too much."
- Perf constraint: the frame is CPU-bound in the AI (charter §9); think is scheduled ~6-7 Hz
  separate from execute. Any proposal must state its per-man, per-think cost. Activity-tiered AI
  is the sanctioned lever.
- Siege exception: the assault_press path (ruled 7/30) must still press the wire — a siege where
  45 men all go to ground and plink is a broken siege.
