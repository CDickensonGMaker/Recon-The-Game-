extends Resource
## One household in a village. Rolls 1 child + 2 adults at build time; each
## adult rolls M/F and then peaceful/VC. The rolls are baked into the
## resource so the same mission always produces the same village.

@export var family_id: String
@export var has_child: bool = true
@export var adult_a_gender: int = 0  # 0=female, 1=male
@export var adult_b_gender: int = 0
@export var adult_a_is_vc: bool = false
@export var adult_b_is_vc: bool = false


static func roll_family(rng: RandomNumberGenerator, family_id_str: String) -> Resource:
	var Self := load("res://terrain/world/villager_family.gd")
	var f: Resource = Self.new()
	f.family_id = family_id_str
	f.has_child = rng.randf() < 0.7
	f.adult_a_gender = 0 if rng.randf() < 0.5 else 1
	f.adult_b_gender = 0 if rng.randf() < 0.5 else 1
	var vc_chance: float = 0.25
	if rng.randf() < vc_chance:
		f.adult_a_is_vc = true
		if rng.randf() < 0.3:
			f.adult_b_is_vc = true
	return f


func total_villagers() -> int:
	var n: int = 2
	if has_child:
		n += 1
	return n


func vc_count() -> int:
	var n: int = 0
	if adult_a_is_vc:
		n += 1
	if adult_b_is_vc:
		n += 1
	return n
