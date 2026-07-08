## test_seed_replay.gd - R88: the seed the debrief prints must rebuild the world.
extends Node
var _fail := 0
func _bad(m: String) -> void: print("FAIL: %s" % m); _fail += 1
func _ready() -> void:
	# 4a: one seed identifies one operation.
	var rng := RandomNumberGenerator.new(); rng.seed = 12345
	var sel := MissionSelectScreen.new(); sel.roll_offers(rng)
	var offer: Dictionary = sel.offers[0]
	print("  offer: world_seed=%d mission_seed=%d" % [int(offer.world_seed), int(offer.mission_seed)])
	if int(offer.world_seed) != int(offer.mission_seed):
		_bad("world_seed != mission_seed; the debrief prints mission_seed, so replay loads a different world")
	var replay: Dictionary = MissionSelectScreen.offer_for_seed(int(offer.mission_seed), offer.type)
	if int(replay.world_seed) != int(offer.world_seed):
		_bad("offer_for_seed(%d) rebuilt world_seed %d, played %d" % [int(offer.mission_seed), int(replay.world_seed), int(offer.world_seed)])
	if str(replay.codename) != str(offer.codename) or str(replay.weather) != str(offer.weather):
		_bad("replay differs: %s/%s vs %s/%s" % [replay.codename, replay.weather, offer.codename, offer.weather])
	sel.free()

	# 4a: roll_offers must be reproducible for a seed (types.shuffle used global rng).
	var a := _types(999); var b := _types(999)
	print("  roll_offers(999) twice -> %s and %s" % [a, b])
	if a != b: _bad("roll_offers not deterministic")

	# 4c: seeding the global rng makes gameplay draws reproducible.
	seed(hash(4242))
	var r1 := [randf(), randi() % 100, [1,2,3].pick_random()]
	seed(hash(4242))
	var r2 := [randf(), randi() % 100, [1,2,3].pick_random()]
	print("  global rng after seed(hash(4242)): %s / %s" % [r1, r2])
	if r1 != r2: _bad("global rng not reproducible after seed()")

	print("PASS: seed replay" if _fail == 0 else "FAIL: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)

func _types(sv: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = sv
	var sel := MissionSelectScreen.new(); sel.roll_offers(rng)
	var out: Array = []
	for o in sel.offers: out.append(int(o.type))
	sel.free(); return out
