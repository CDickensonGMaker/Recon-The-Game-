"""Single source of truth: which rig / meshes / weapon belong to each NPC unit.

Used by render_sprite_sheets.py (to isolate a unit) and the run scripts.
`meshes` names a collection OR a list of object names.
`trigger_hold` = where the trigger hand grips, only used for docs.
"""

UNITS = {
    # heads were split out of the joined rigs so their face pane can be re-UV'd;
    # they MUST be listed here or they float in every other unit's render
    'us_grunt': dict(
        faction='US Army and Co', rig='MixamoRig',
        meshes=['US_Grunt_Rigged', 'us_grunt_head'], gun='M16A1_Rifle', weapon='m16a1'),
    'us_grunt_black': dict(
        faction='US Army and Co', rig='RigUSM60',
        meshes=['US_Grunt_M60_Rigged', 'us_grunt_black_head'], gun='M60_MG', weapon='m60'),
    'vc1_farmer': dict(
        faction='Vietcong and NVA', rig='MixamoRig_VC1',
        meshes='VC1_Farmer', gun='AK47_Rifle', weapon='ak47'),
    'vc2_mainforce': dict(
        faction='Vietcong and NVA', rig='RigVC2',
        meshes='VC2_MainForce', gun='Mosin_Rifle_VC', weapon='mosin'),
    'vc3_sapper': dict(
        faction='Vietcong and NVA', rig='RigVC3',
        meshes='VC3_Sapper', gun='RPD_MG', weapon='rpd'),
    'vc5_nva': dict(
        faction='Vietcong and NVA', rig='RigVC5',
        meshes='VC5_NVA', gun='PPSh41_Gun', weapon='ppsh41'),
    'vc6_heavy': dict(
        faction='Vietcong and NVA', rig='RigVC6',
        meshes='VC6_Heavy', gun='RPG2_Launcher', weapon='rpg2'),
}

# Actions we don't render. These only make sense for aircrew - rendering them for
# infantry wastes ~1.5 hrs of render time and 448 frames per unit.
SKIP_ACTIONS = {
    'pilot_flips_switches', 'pilot_flips_switches_overhead',
    'm60_gunner_idle_l', 'm60_gunner_idle_r',
    'm60_gunner_scan_l', 'm60_gunner_scan_r',
    'm60_gunner_fire_l', 'm60_gunner_fire_r',
}

# Actions that must NOT loop - they play once and hold the final frame.
HOLD_LAST = {
    'death_forward', 'death_from_right', 'laying_breathless',
    'brutal_assassination', 'stand_to_cover', 'action_idle_to_standing_idle',
    'start_walking', 'stop_walking_with_rifle', 'reloading',
    'rifle_crouch_idle_to_walk', 'rifle_turn',
}

def actions_for(unit):
    """Blender actions this unit should render (call with bpy.data.actions)."""
    import bpy
    return [a for a in sorted(bpy.data.actions, key=lambda x: x.name)
            if a.name not in SKIP_ACTIONS]
