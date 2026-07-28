# Lane 1 — Industry FP weapon rigging practice (web research, 2026-07-27)

## Rig structure — CONVENTION
- Weapon moving parts are always BONES on a weapon skeleton, never loose object hierarchies. The fork
  is whether that skeleton merges into the arms skeleton or stays separate; both professionally attested.
- **CoD style**: `tag_weapon` master control — "majority of animating is done on tag_weapon, except the
  hands; weapon parented to it, hands IKed to it." Also `tag_view` (camera), `tag_ads`, `tag_flash`,
  `tag_brass`, `j_gun`. ALL clips start/end on the same tag_weapon pose "so you don't get any pops."
  https://wiki.zeroy.com/index.php?title=Call_of_Duty_4:_ViewModels
- **Single shared skeleton** (arms + all weapon bones; each gun skinned to it; not every mesh uses every
  bone): https://www.item42.com/dev-blog/2016/11/14/devblog-2-complete-fps-arms-rig-and-animation-tutorial-from-3ds-max-to-ue4
- **Separate skeletons, one DCC scene, exported separately** (UE mainstream): weapon root zeroed at
  export; in-engine attach to hand socket / `ik_hand_gun`. https://forums.unrealengine.com/t/workflow-questions-for-first-person-viewmodel-animation/61323
- **Epic/Lyra**: `ik_hand_gun` bone carries the weapon motion; hands reach via two-bone IK to
  `ik_hand_r`/`ik_hand_l`.
- **Kinemation** (Unity/UE middleware): WeaponBone + IK bones; "the gun is not parented to the right
  hand anymore"; IK bones parented to the WEAPON serve as IK targets.
  https://kinemation.gitbook.io/fps-animation-framework/tutorial/animation-workflow/ik-rig
- **Arma Reforger (public Bohemia docs — closest cousin to our marker contract)**: weapon skeleton root
  `w_root`; part bones prefixed `w_`; magazine snaps to `slot_magazine`; attachments pair `slot_*` (on
  weapon) with `snap_*` (on attachment) dummy points.
  https://community.bistudio.com/wiki/Arma_Reforger:Weapon_Slots_And_Bones

## Sockets / hands-on-gun — CONVENTION
- Weapon root bone AT the grip point; sockets = named locators parented to bones (UDK/UE doctrine).
- **Hands are IK-pinned to weapon-owned targets, not FK-posed in free space** — CoD, Kinemation, UE,
  Unity Animation Rigging all converge. THE GUN LEADS, HANDS FOLLOW.
- Pop-avoidance rule: every clip begins/ends on the identical weapon-bone pose.
- Grip bone must coincide with the in-engine attach socket → no runtime offsets.

## Hand-gun clipping — practice is PREVENTATIVE, not corrective
- Per-grip POSE LIBRARIES ("save a pose for idle/irons per weapon, revert easily") — CGCookie 10 tips.
  https://www.youtube.com/watch?v=dclA9iwZB_s
- Finger IK for per-digit contact; assign everything to Grip first, offset individual fingers.
- NO automated clip-checkers or proxy collision meshes surfaced anywhere — eyeballing at game FOV +
  pose libraries is the documented practice. (Our measured penetration probe is AHEAD of industry.)
- Destiny GDC: visual QA focuses on the "Combat Corridor" — the screen-center band the player watches.
  https://www.gdcvault.com/play/1022297/The-Art-of-First-Person

## Clip organization — CONVENTION
- One action per move; tactical vs empty reload universally split, sharing bookend poses with an
  inserted chamber-rack segment. Standard set: draw, idle, fire, ADS in/out, reload, reload_empty,
  holster, inspect.

## Talks worth mining
Overwatch animation pipeline (GDC 1024267/1024319), Destiny FP art (archive.org GDC2015Helsby),
Tarkov procedural-over-authored layer (https://80.lv/articles/escape-from-tarkov-game-tech-overview).

## Synthesis-grade
CONVENTION: (a) parts = bones, root at grip; (b) weapon owns the IK targets, gun leads; (c) author
arms+gun in one scene; (d) identical first/last weapon pose across clips; (e) named sockets for
magwell/muzzle/brass/attachments; (f) tactical/empty as separate clips with shared bookends.
OPINION: merged single skeleton vs separate-skeleton-plus-sync — engine-plumbing preference.
