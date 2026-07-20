## civilian_schedules.gd - per-occupation daily schedule templates.
## Each block is a list of (start_hour, end_hour, action_name). The BT's
## schedule subtree reads SimClock.sim_hour + civilian.occupation and picks
## the action whose window contains the current hour.
class_name CivilianSchedules
extends RefCounted

const ACTION_IDLE: StringName = &"idle"
const ACTION_WALK_HOME: StringName = &"walk_home"
const ACTION_WALK_PADDY: StringName = &"walk_paddy"
const ACTION_WALK_FIRE: StringName = &"walk_fire"
const ACTION_WALK_MARKET: StringName = &"walk_market"
const ACTION_WORK: StringName = &"work"
const ACTION_REST: StringName = &"rest"
const ACTION_COOK: StringName = &"cook"
const ACTION_SLEEP: StringName = &"sleep"
const ACTION_FISH: StringName = &"fish"
const ACTION_SIT: StringName = &"sit"
const ACTION_TALK: StringName = &"talk"


## Returns the action the BT should pursue for (occupation, sim_hour).
## sim_hour is 0.0-24.0. Returns an empty StringName if no action fits
## (caller falls back to idle).
static func action_for(occupation: String, sim_hour: float) -> StringName:
	match occupation:
		"farmer":
			if sim_hour < 5.0 or sim_hour >= 22.0:
				return ACTION_SLEEP
			if sim_hour < 6.5:
				return ACTION_WALK_PADDY
			if sim_hour < 11.0:
				return ACTION_WORK
			if sim_hour < 12.0:
				return ACTION_REST
			if sim_hour < 13.0:
				return ACTION_WALK_HOME
			if sim_hour < 17.0:
				return ACTION_WORK
			if sim_hour < 18.0:
				return ACTION_WALK_FIRE
			if sim_hour < 19.5:
				return ACTION_COOK
			return ACTION_WALK_HOME
		"fisherman":
			if sim_hour < 5.0 or sim_hour >= 21.0:
				return ACTION_SLEEP
			if sim_hour < 6.0:
				return ACTION_WALK_PADDY  # uses a water-side working point
			if sim_hour < 12.0:
				return ACTION_FISH
			if sim_hour < 13.5:
				return ACTION_REST
			if sim_hour < 17.0:
				return ACTION_FISH
			if sim_hour < 18.5:
				return ACTION_WALK_FIRE
			return ACTION_WALK_HOME
		"cook":
			if sim_hour < 5.0 or sim_hour >= 22.0:
				return ACTION_SLEEP
			if sim_hour < 6.0:
				return ACTION_WALK_FIRE
			if sim_hour < 9.0:
				return ACTION_COOK
			if sim_hour < 10.0:
				return ACTION_WALK_MARKET
			if sim_hour < 12.0:
				return ACTION_COOK
			if sim_hour < 13.5:
				return ACTION_REST
			if sim_hour < 17.0:
				return ACTION_COOK
			if sim_hour < 18.5:
				return ACTION_COOK
			return ACTION_WALK_HOME
		"elder":
			if sim_hour < 5.0 or sim_hour >= 21.0:
				return ACTION_SLEEP
			if sim_hour < 7.0:
				return ACTION_SIT
			if sim_hour < 9.0:
				return ACTION_WALK_FIRE
			if sim_hour < 11.0:
				return ACTION_TALK
			if sim_hour < 12.0:
				return ACTION_REST
			if sim_hour < 14.0:
				return ACTION_TALK
			if sim_hour < 17.0:
				return ACTION_SIT
			if sim_hour < 18.5:
				return ACTION_WALK_FIRE
			return ACTION_WALK_HOME
		"sentry":
			if sim_hour < 5.0 or sim_hour >= 20.0:
				return ACTION_SLEEP
			if sim_hour < 5.5:
				return ACTION_WALK_PADDY
			if sim_hour < 12.0:
				return ACTION_WORK
			if sim_hour < 13.0:
				return ACTION_WALK_HOME
			if sim_hour < 13.5:
				return ACTION_WALK_PADDY
			if sim_hour < 18.0:
				return ACTION_WORK
			if sim_hour < 18.5:
				return ACTION_WALK_HOME
			return ACTION_TALK
		"sentry_night":
			if sim_hour < 5.0:
				return ACTION_WORK
			if sim_hour < 5.5:
				return ACTION_WALK_HOME
			if sim_hour < 13.0:
				return ACTION_SLEEP
			if sim_hour < 15.0:
				return ACTION_SIT
			if sim_hour < 17.0:
				return ACTION_TALK
			if sim_hour < 17.5:
				return ACTION_WALK_FIRE
			if sim_hour < 18.5:
				return ACTION_WALK_PADDY
			return ACTION_WORK
		"quartermaster":
			if sim_hour < 5.5 or sim_hour >= 21.0:
				return ACTION_SLEEP
			if sim_hour < 6.5:
				return ACTION_WALK_PADDY
			if sim_hour < 11.5:
				return ACTION_WORK
			if sim_hour < 12.5:
				return ACTION_WALK_FIRE
			if sim_hour < 13.5:
				return ACTION_REST
			if sim_hour < 17.5:
				return ACTION_WORK
			if sim_hour < 18.5:
				return ACTION_WALK_FIRE
			if sim_hour < 20.0:
				return ACTION_TALK
			return ACTION_WALK_HOME
		"gun_crew":
			if sim_hour < 6.0 or sim_hour >= 21.5:
				return ACTION_SLEEP
			if sim_hour < 7.0:
				return ACTION_WALK_PADDY
			if sim_hour < 10.0:
				return ACTION_WORK
			if sim_hour < 12.0:
				return ACTION_SIT
			if sim_hour < 13.0:
				return ACTION_WALK_FIRE
			if sim_hour < 14.0:
				return ACTION_REST
			if sim_hour < 17.0:
				return ACTION_WORK
			if sim_hour < 18.5:
				return ACTION_WALK_FIRE
			if sim_hour < 20.5:
				return ACTION_TALK
			return ACTION_WALK_HOME
		"radioman":
			if sim_hour < 5.0 or sim_hour >= 22.0:
				return ACTION_SLEEP
			if sim_hour < 5.5:
				return ACTION_WALK_PADDY
			if sim_hour < 12.5:
				return ACTION_WORK
			if sim_hour < 13.5:
				return ACTION_WALK_FIRE
			if sim_hour < 19.0:
				return ACTION_WORK
			if sim_hour < 20.0:
				return ACTION_WALK_FIRE
			return ACTION_WALK_HOME
		"mess_cook":
			if sim_hour < 4.0 or sim_hour >= 21.0:
				return ACTION_SLEEP
			if sim_hour < 4.5:
				return ACTION_WALK_PADDY
			if sim_hour < 8.0:
				return ACTION_COOK
			if sim_hour < 10.0:
				return ACTION_WORK
			if sim_hour < 13.5:
				return ACTION_COOK
			if sim_hour < 15.5:
				return ACTION_REST
			if sim_hour < 19.5:
				return ACTION_COOK
			return ACTION_WALK_HOME
		"off_duty":
			if sim_hour < 6.0 or sim_hour >= 22.0:
				return ACTION_SLEEP
			if sim_hour < 7.5:
				return ACTION_WALK_FIRE
			if sim_hour < 9.5:
				return ACTION_SIT
			if sim_hour < 11.0:
				return ACTION_WORK
			if sim_hour < 12.5:
				return ACTION_WALK_FIRE
			if sim_hour < 14.5:
				return ACTION_TALK
			if sim_hour < 16.5:
				return ACTION_REST
			if sim_hour < 18.5:
				return ACTION_WALK_FIRE
			if sim_hour < 20.5:
				return ACTION_TALK
			return ACTION_SIT
		_:
			return ACTION_IDLE


## Pick an occupation from a weighted list. Returns a string id.
static func pick_occupation(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.60:
		return "farmer"
	if roll < 0.80:
		return "elder"
	if roll < 0.90:
		return "cook"
	return "fisherman"
