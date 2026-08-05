## zombie_randomizer.gd - seeded random-zombie builder.
##
## The VC Zombies counterpart to GruntRandomizer, and the ONE shared core: the
## wave director and any bench both spawn through here, so a horde in the game and
## a horde on a test bench are dealt from the same deck. Fork this and the two drift.
##
## Bodies are discovered from the filesystem, so a thirteenth zed_* export appears
## in the pool with no code change.
class_name ZombieRandomizer
extends RefCounted

const ZOMBIE_DIR: String = "res://assets/zombies/characters/"
const UNIT_PREFIX: String = "zed_"


## Every zombie body on disk, sorted. Sorted because the spawn walk must be
## deterministic from a seed, and DirAccess order is not (ADR-010).
static func bodies(tier: String = "") -> Array[String]:
	var out: Array[String] = []
	for u in ModelActor.all_units():
		if not u.begins_with(UNIT_PREFIX):
			continue
		if not tier.is_empty() and ZombieDresser.tier_of(u) != tier:
			continue
		out.append(u)
	out.sort()
	return out


## Spawn + dress one zombie under `parent`.
## `tier` empty = any; "walker" / "rotted" to weight a round's mix.
## Returns {} on failure, else {"unit", "actor", "loadout"}.
static func spawn(parent: Node, rng: RandomNumberGenerator, tier: String = "",
		opts: Dictionary = {}) -> Dictionary:
	var pool: Array[String] = bodies(tier)
	if pool.is_empty():
		# A tier with no bodies must not silently fall back to the whole roster -
		# that is how "the rotted never spawned" becomes invisible for a week.
		if not tier.is_empty():
			push_warning("[ZRAND] no zombie body of tier '%s' on disk" % tier)
		return {}
	var unit: String = String(opts.get("unit", pool[rng.randi() % pool.size()]))

	var actor := ModelActor.new()
	parent.add_child(actor)
	if not actor.setup(unit):
		actor.queue_free()
		return {}

	var loadout: Dictionary = ZombieDresser.dress(actor, rng, opts)
	return {"unit": unit, "actor": actor, "loadout": loadout}


## Seed sequence for benches. Deterministic while spawn order is.
static var _bench_serial: int = 0


static func next_bench_seed() -> int:
	_bench_serial += 1
	return 66650001 + _bench_serial * 2654435761


static func reset_bench() -> void:
	_bench_serial = 0
