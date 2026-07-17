## test_squad_body_pool.gd - verifies the weapon-pooled grunt body randomizer.
## Ensures specialist roles keep deterministic bodies while rifle roles draw from
## the shared M16 pool.
## Run: godot --headless --path . res://tests/test_squad_body_pool.tscn
extends Node3D

var _failures: int = 0


func _ready() -> void:
    await get_tree().process_frame
    _run()


func _bad(msg: String) -> void:
    print("FAIL: %s" % msg)
    _failures += 1


func _run() -> void:
    print("=== Squad Body Pool Probe ===")

    var squad := SquadSystem.new()
    squad._roster_rng.seed = 12345
    add_child(squad)

    # Deterministic roles must always return the same body.
    var deterministic: Dictionary = {
        "RTO": "us_grunt_rto",
        "MG": "us_grunt_mg",
        "GRENADIER": "us_grunt_grenadier",
        "MARKSMAN": "us_grunt_marksman",
    }
    for mos in deterministic:
        var expected: String = deterministic[mos]
        for i in range(20):
            var got: String = squad._pick_unit_for_mos(mos)
            if got != expected:
                _bad("%s deterministic body mismatch (expected %s, got %s on roll %d)" % [mos, expected, got, i])

    # Rifle roles must draw from the M16 pool only.
    var m16_pool: Array = SquadSystem.WEAPON_BODY_POOLS["m16a1"]
    var rifle_roles: Array = ["POINTMAN", "RIFLEMAN", "MEDIC"]
    var seen: Dictionary = {}
    for mos in rifle_roles:
        var local_seen: Dictionary = {}
        for i in range(60):
            var got: String = squad._pick_unit_for_mos(mos)
            if not got in m16_pool:
                _bad("%s drew body %s, which is not in the m16a1 pool" % [mos, got])
            local_seen[got] = true
        if local_seen.keys().size() < 2:
            _bad("%s pool produced only one body across 60 rolls: %s" % [mos, str(local_seen.keys())])
        for k in local_seen:
            seen[k] = true

    # Weapon mapping sanity.
    for mos in ["POINTMAN", "RTO", "MEDIC", "RIFLEMAN"]:
        if SquadSystem.MOS_WEAPON.get(mos) != "m16a1":
            _bad("%s weapon expected m16a1, got %s" % [mos, SquadSystem.MOS_WEAPON.get(mos)])
    if SquadSystem.MOS_WEAPON.get("MG") != "m60":
        _bad("MG weapon expected m60, got %s" % SquadSystem.MOS_WEAPON.get("MG"))
    if SquadSystem.MOS_WEAPON.get("GRENADIER") != "m79":
        _bad("GRENADIER weapon expected m79, got %s" % SquadSystem.MOS_WEAPON.get("GRENADIER"))
    if SquadSystem.MOS_WEAPON.get("MARKSMAN") != "m70":
        _bad("MARKSMAN weapon expected m70, got %s" % SquadSystem.MOS_WEAPON.get("MARKSMAN"))

    print("  deterministic: %s" % str(deterministic.keys()))
    print("  rifle pool used: %s" % str(seen.keys()))
    print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
    get_tree().quit(0 if _failures == 0 else 1)
