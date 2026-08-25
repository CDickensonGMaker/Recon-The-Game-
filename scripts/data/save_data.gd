## save_data.gd - Typed save schema (Catacombs of Gore architecture, ported).
## One inner class per system, each with symmetric to_dict()/from_dict() and a
## DEFAULT for every field (a partial or old save must never crash a load).
## SaveManager brokers these dicts; systems never touch the file format.
class_name SaveData
extends RefCounted

const SCHEMA_VERSION: int = 2

var version: int = SCHEMA_VERSION
var campaign := CampaignSection.new()
var player := PlayerSection.new()
var hub := HubSection.new()
var meta := MetaSection.new()
## MissionSection reserved for Phase E (full save-anywhere): objective mask,
## live enemies, craters, heat. Schema slot exists so migration is a no-op later.
var mission: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"version": version,
		"campaign": campaign.to_dict(),
		"player": player.to_dict(),
		"hub": hub.to_dict(),
		"meta": meta.to_dict(),
		"mission": mission,
	}


static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.version = int(d.get("version", 1))
	s.campaign = CampaignSection.from_dict(d.get("campaign", {}))
	s.player = PlayerSection.from_dict(d.get("player", {}))
	s.hub = HubSection.from_dict(d.get("hub", {}))
	s.meta = MetaSection.from_dict(d.get("meta", {}))
	s.mission = d.get("mission", {})
	return s


func is_valid() -> bool:
	return version >= 1 and campaign != null and player != null


## ------------------------------------------------------------------ sections

## The campaign layer - brokers CampaignState's existing dict wholesale so the
## proven cfg-era fields (roster, xp, threat, log) ride along unchanged.
class CampaignSection:
	var data: Dictionary = {}

	func to_dict() -> Dictionary:
		return data

	static func from_dict(d: Dictionary) -> CampaignSection:
		var c := CampaignSection.new()
		c.data = d if d is Dictionary else {}
		return c


## Where you are and what you carry. `context` says where the save happened:
## "hub" (firebase), "mission" (checkpoint/save-anywhere), "menu".
class PlayerSection:
	## Magazine-model version: 1 = per-mag round arrays, index 0 seated
	## (INTERNAL/SINGLE: [in_gun, pool]). An ABSENT key marks a legacy
	## [rounds, spare_full_mags] pair and triggers the rebuild in _read_mags.
	const MAG_MODEL: int = 1

	var context: String = "menu"
	var position: Vector3 = Vector3.ZERO
	var rotation_y: float = 0.0
	var hp: int = 100
	var health_packs: int = 3
	var stamina: float = 100.0
	var primary_path: String = ""
	var secondary_path: String = ""
	var mag_model: int = MAG_MODEL
	var primary_ammo: Array = [20, 20, 20, 20, 20, 20, 20]
	var secondary_ammo: Array = [7, 7, 7, 7]
	var grenade_count: int = 2
	var smoke_count: int = 2
	var claymore_count: int = 2
	var satchel_count: int = 2
	var flare_count: int = 3
	# Survival v1 (Phase C)
	var hunger: float = 100.0
	var weapon_condition: float = 100.0
	var ration_count: int = 2
	var repair_kit_count: int = 1

	func to_dict() -> Dictionary:
		return {
			"context": context,
			"pos": [position.x, position.y, position.z],
			"rot_y": rotation_y,
			"hp": hp, "health_packs": health_packs, "stamina": stamina,
			"primary_path": primary_path, "secondary_path": secondary_path,
			"mag_model": mag_model,
			"primary_ammo": primary_ammo, "secondary_ammo": secondary_ammo,
			"grenade_count": grenade_count, "smoke_count": smoke_count,
			"claymore_count": claymore_count, "satchel_count": satchel_count, "flare_count": flare_count,
			"hunger": hunger, "weapon_condition": weapon_condition,
			"ration_count": ration_count, "repair_kit_count": repair_kit_count,
		}

	static func from_dict(d: Dictionary) -> PlayerSection:
		var p := PlayerSection.new()
		p.context = str(d.get("context", "menu"))
		var pos: Array = d.get("pos", [0, 0, 0])
		if pos.size() == 3:
			p.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		p.rotation_y = float(d.get("rot_y", 0.0))
		p.hp = int(d.get("hp", 100))
		p.health_packs = int(d.get("health_packs", 3))
		p.stamina = float(d.get("stamina", 100.0))
		p.primary_path = str(d.get("primary_path", ""))
		p.secondary_path = str(d.get("secondary_path", ""))
		var legacy: bool = not d.has("mag_model")
		p.mag_model = MAG_MODEL
		p.primary_ammo = _read_mags(d.get("primary_ammo", []), legacy,
			p.primary_path, p.primary_ammo)
		p.secondary_ammo = _read_mags(d.get("secondary_ammo", []), legacy,
			p.secondary_path, p.secondary_ammo)
		p.grenade_count = int(d.get("grenade_count", 2))
		p.smoke_count = int(d.get("smoke_count", 2))
		p.claymore_count = int(d.get("claymore_count", 2))
		p.satchel_count = int(d.get("satchel_count", 2))
		p.flare_count = int(d.get("flare_count", 3))
		p.hunger = float(d.get("hunger", 100.0))
		p.weapon_condition = float(d.get("weapon_condition", 100.0))
		p.ration_count = int(d.get("ration_count", 2))
		p.repair_kit_count = int(d.get("repair_kit_count", 1))
		return p

	## JSON numbers come back float; counts must round-trip bit-exact as ints,
	## ragged arrays included. A legacy pair [rounds, spare_full_mags] rebuilds
	## as [rounds] + N full mags, shaped by the feed of the weapon at `path`.
	static func _read_mags(raw: Variant, legacy: bool, path: String, fallback: Array) -> Array:
		var arr: Array = raw if raw is Array else []
		var mags: Array = []
		for v in arr:
			mags.append(int(v))
		if mags.is_empty():
			return fallback.duplicate()
		if not legacy:
			return mags
		var rounds: int = int(mags[0])
		var spares: int = int(mags[1]) if mags.size() > 1 else 0
		var data: WeaponData = null
		if path != "" and ResourceLoader.exists(path):
			data = load(path) as WeaponData
		var size: int = data.magazine_size if data != null else maxi(rounds, 1)
		if data != null and data.feed == Enums.FeedType.INTERNAL:
			return [mini(rounds, size), spares * size]
		if data != null and data.feed == Enums.FeedType.SINGLE:
			return [mini(rounds, 1), spares]
		var out: Array = [mini(rounds, size)]
		for _i in range(spares):
			out.append(size)
		return out


## The firebase: which operation and its seed - the patrol world regenerates
## deterministically from it (ADR-029). v2 dropped the offer-board fields.
class HubSection:
	var operation_seed: int = 0
	var operation_name: String = ""

	func to_dict() -> Dictionary:
		return {
			"operation_seed": operation_seed, "operation_name": operation_name,
		}

	static func from_dict(d: Dictionary) -> HubSection:
		var h := HubSection.new()
		h.operation_seed = int(d.get("operation_seed", 0))
		h.operation_name = str(d.get("operation_name", ""))
		return h


## Slot-browser metadata (read without a full deserialize via get_save_info).
class MetaSection:
	var save_name: String = ""
	var timestamp: int = 0
	var missions_played: int = 0
	var playtime_s: float = 0.0

	func to_dict() -> Dictionary:
		return {"save_name": save_name, "timestamp": timestamp,
			"missions_played": missions_played, "playtime_s": playtime_s}

	static func from_dict(d: Dictionary) -> MetaSection:
		var m := MetaSection.new()
		m.save_name = str(d.get("save_name", ""))
		m.timestamp = int(d.get("timestamp", 0))
		m.missions_played = int(d.get("missions_played", 0))
		m.playtime_s = float(d.get("playtime_s", 0.0))
		return m
