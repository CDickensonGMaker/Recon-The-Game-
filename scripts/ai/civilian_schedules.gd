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
		# ---------------- THE GARRISON ----------------
		# A FIREBASE DOES NOT GO TO BED. These blocks were the villager's day with military
		# labels on it: the sentry slept from 20:00 and walked to a RICE PADDY at dawn, the
		# gun crew stood down at 21:30. The demo opens at dusk, so the whole garrison was
		# scheduled asleep at the exact moment the player first sees the base - "the other NPC
		# allies just stand there", 2026-07-29. Rewritten so the night shift is the BUSY one.
		#
		# ACTION_WORK sends a man to his own working_point_pos - his post, his gun, his radio -
		# so "work" at night means STANDING THE WIRE, not farming.
		"sentry":
			# Day watch. Hands over at last light and sleeps through the small hours.
			if sim_hour >= 21.0 or sim_hour < 4.5:
				return ACTION_SLEEP
			if sim_hour < 5.5:
				return ACTION_WALK_FIRE      # up, coffee, before stand-to
			if sim_hour < 12.0:
				return ACTION_WORK
			if sim_hour < 12.75:
				return ACTION_WALK_FIRE      # chow
			if sim_hour < 19.0:
				return ACTION_WORK
			if sim_hour < 20.0:
				return ACTION_TALK           # handover to the night shift
			return ACTION_WALK_HOME
		"sentry_night":
			# THE NIGHT WATCH. On the wire from dusk to dawn - this is the shift the player
			# meets at demo open, and it must be manned, not asleep.
			if sim_hour >= 18.0 or sim_hour < 5.5:
				return ACTION_WORK
			if sim_hour < 6.5:
				return ACTION_WALK_FIRE      # off shift, warm up
			if sim_hour < 13.5:
				return ACTION_SLEEP          # sleeps through the DAY
			if sim_hour < 15.0:
				return ACTION_SIT
			if sim_hour < 16.5:
				return ACTION_TALK
			return ACTION_WALK_FIRE          # fed and watered before going back on
		"quartermaster":
			if sim_hour >= 22.0 or sim_hour < 5.0:
				return ACTION_SLEEP
			if sim_hour < 6.0:
				return ACTION_WALK_FIRE
			if sim_hour < 12.0:
				return ACTION_WORK           # the dump: crates, belts, water
			if sim_hour < 13.0:
				return ACTION_WALK_FIRE
			if sim_hour < 19.0:
				return ACTION_WORK
			# Ammo goes UP to the posts before dark, and stays available after it.
			return ACTION_WORK
		"gun_crew":
			# Guns are laid and manned around the clock; fire missions come at night.
			if sim_hour >= 23.0 or sim_hour < 4.0:
				return ACTION_REST           # resting AT the pit, not in a hootch
			if sim_hour < 5.0:
				return ACTION_WORK
			if sim_hour < 11.0:
				return ACTION_WORK
			if sim_hour < 12.0:
				return ACTION_SIT
			if sim_hour < 13.0:
				return ACTION_WALK_FIRE
			if sim_hour < 18.0:
				return ACTION_WORK
			return ACTION_WORK               # dusk onward: on the gun
		"radioman":
			# The net is never unmanned.
			if sim_hour >= 23.5 or sim_hour < 4.5:
				return ACTION_REST
			if sim_hour < 13.0:
				return ACTION_WORK
			if sim_hour < 13.75:
				return ACTION_WALK_FIRE
			return ACTION_WORK
		"mess_cook":
			if sim_hour >= 21.5 or sim_hour < 3.5:
				return ACTION_SLEEP
			if sim_hour < 4.0:
				return ACTION_WALK_FIRE
			if sim_hour < 8.0:
				return ACTION_COOK
			if sim_hour < 10.0:
				return ACTION_WORK
			if sim_hour < 13.5:
				return ACTION_COOK
			if sim_hour < 15.5:
				return ACTION_REST
			if sim_hour < 20.0:
				return ACTION_COOK           # hot meal before the night shift goes on
			return ACTION_WORK               # cleaning down
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
			# Last hours before lights out are the busy ones, not the idle ones: kit squared
			# away, sandbags topped up, ammo moved. These are also the hours the demo opens
			# in, and a base full of seated men reads as a base with nothing to do.
			return ACTION_WORK
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
