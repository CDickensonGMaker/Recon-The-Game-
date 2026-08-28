## squad_roster.gd - SquadMember generation + roster persistence helpers.
class_name SquadRoster
extends RefCounted

## 250 x 250 = 62,500 combinations. Drawn from the men the draft actually took:
## working-class, Southern, Appalachian, Black, Puerto Rican and Chicano, and the
## Italian/Polish/Irish/Slavic industrial cities. Not an officer-corps name list.
const FIRST_NAMES: Array[String] = [
	"JOHNNY", "EDDIE", "RAY", "TOMMY", "HANK", "LEROY", "SAL", "DUANE", "CARL", "WILLIE",
	"FRANK", "JESSE", "EARL", "MARV", "GUS", "BOBBY", "JIMMY", "DANNY", "RICKY", "LARRY",
	"WAYNE", "DALE", "CLIFF", "MERLE", "OTIS", "CURTIS", "DWIGHT", "VERNON", "ELMER", "FLOYD",
	"HOMER", "LESTER", "MELVIN", "NORMAN", "ORVILLE", "PERCY", "RUFUS", "SILAS", "VIRGIL", "WALLY",
	"ARNIE", "BUD", "CHET", "DEWEY", "ERNIE", "GLEN", "HERB", "IRV", "JUNIOR", "KENNY",
	"LEON", "MACK", "NED", "OZZIE", "PETE", "RALPH", "STAN", "TROY", "VANCE", "WOODY",
	"ALVIN", "BERNIE", "CECIL", "DARRELL", "EUGENE", "FORREST", "GARLAND", "HOYT", "IVAN", "JASPER",
	"KERMIT", "LOWELL", "MARION", "NEWT", "ODELL", "PRESTON", "QUINCY", "ROSCOE", "SHERMAN", "THURMAN",
	"ULYSSES", "VERGIL", "WENDELL", "ZEKE", "ABE", "BUFORD", "CLEVE", "DELBERT", "EMMETT", "FESTUS",
	"GROVER", "HARLAN", "ISAAC", "JETHRO", "KIRBY", "LUTHER", "MOSE", "NAT", "OSCAR", "PHINEAS",
	"REUBEN", "SAMPSON", "TITUS", "URIAH", "WARDELL", "AMOS", "BOOKER", "CLARENCE", "DESMOND", "ELIJAH",
	"FRANKLIN", "GARFIELD", "HORACE", "ISAIAH", "JEREMIAH", "LEVI", "MOSES", "NEHEMIAH", "OTHA", "PRINCE",
	"RAYFIELD", "SOLOMON", "TYRONE", "WILLARD", "XAVIER", "ANGELO", "BRUNO", "CARMINE", "DOMINIC", "ENZO",
	"FRANCO", "GINO", "LOU", "MARIO", "NICKY", "ORLANDO", "PASQUALE", "ROCCO", "SILVIO", "TONY",
	"VITO", "ALDO", "BENNY", "CIRO", "DANTE", "EMILIO", "FABIO", "GIANNI", "LUCA", "MASSIMO",
	"CASIMIR", "DARIUSZ", "EDMUND", "FELIKS", "HENRYK", "IGNACY", "JANUSZ", "KAZIMIERZ", "LECH", "MIECZYSLAW",
	"BRENDAN", "CONNOR", "DECLAN", "EAMON", "FERGUS", "LIAM", "PADRAIG", "SEAMUS", "SHANE", "TIERNAN",
	"CARLOS", "DIEGO", "ESTEBAN", "FELIPE", "GILBERTO", "HECTOR", "ISMAEL", "JAVIER", "LUIS", "MANUEL",
	"NESTOR", "OCTAVIO", "PABLO", "RAFAEL", "SANTIAGO", "TOMAS", "ULISES", "VICENTE", "ALEJANDRO", "BENITO",
	"CESAR", "DOMINGO", "EMILIANO", "FIDEL", "GUILLERMO", "HUMBERTO", "IGNACIO", "JORGE", "LAZARO", "MIGUEL",
	"CHESTER", "DUDLEY", "ELDON", "FENTON", "GAYLORD", "HOLLIS", "IRA", "JEWEL", "KENT", "LYLE",
	"MURRAY", "NOLAN", "OLIN", "PARKER", "QUENTIN", "RANDALL", "SEYMOUR", "TRUMAN", "UPTON", "VAUGHN",
	"WEBSTER", "ARCHIE", "BARNEY", "CLYDE", "DUKE", "ELROY", "FRITZ", "GIL", "HUGH", "IKE",
	"JAKE", "KIT", "LEFTY", "MOE", "NICK", "OLLIE", "PAPPY", "RED", "SHORTY", "TEX",
	"WHITEY", "ZACK", "AUGIE", "BEAU", "CHIP", "DUTCH", "EMIL", "GABE", "HANS", "JOSIAH",
]
const LAST_NAMES: Array[String] = [
	"MILLER", "JACKSON", "KOWALSKI", "REYES", "DUBOIS", "OBRIEN", "HAYES", "NAKAMURA", "STONE", "CARTER",
	"WOJCIK", "BAKER", "LONG", "PRICE", "GRIMES", "ANDERSON", "BENNETT", "BRADLEY", "BROOKS", "BRYANT",
	"BURNS", "CAMPBELL", "CHANDLER", "COLLINS", "CONNOR", "CRAWFORD", "DALTON", "DAVIS", "DAWSON", "DELANEY",
	"DILLON", "DONNELLY", "DOYLE", "DRAKE", "DUFFY", "DUNCAN", "EATON", "ELLIS", "FARRELL", "FINCH",
	"FLANAGAN", "FLETCHER", "FOSTER", "FOWLER", "GALLAGHER", "GARRETT", "GIBSON", "GILMORE", "GRADY", "GRANT",
	"GRAVES", "GREER", "HALLORAN", "HAMILTON", "HANLEY", "HARDIN", "HARPER", "HATFIELD", "HOLLAND", "HOLLOWAY",
	"HOPKINS", "HOWELL", "HUDSON", "HUGHES", "HUNTER", "IRWIN", "JENKINS", "KEANE", "KEATING", "KELLY",
	"KENDRICK", "KILGORE", "LANDRY", "LANE", "LARKIN", "LAWSON", "LEDBETTER", "LOCKHART", "LOGAN", "LYNCH",
	"MADDOX", "MAHONEY", "MALLORY", "MARSH", "MASON", "MATHIS", "MCBRIDE", "MCCOY", "MCGRATH", "MCKENNA",
	"MERCER", "MOONEY", "MORAN", "MORRISON", "MULLEN", "MURPHY", "NOONAN", "NORRIS", "OAKES", "ODELL",
	"OLSEN", "OSBORNE", "PARSONS", "PATTERSON", "PAYNE", "PEARSON", "PERKINS", "PHELPS", "PIERCE", "QUINN",
	"RAFFERTY", "RANKIN", "REDDING", "REEVES", "RHODES", "RILEY", "ROURKE", "RUSSELL", "RYAN", "SAWYER",
	"SHANNON", "SHEEHAN", "SHELTON", "SLATER", "SLOAN", "SPENCER", "STANTON", "STOKES", "SULLIVAN", "SUMNER",
	"SWEENEY", "TALLEY", "TATE", "THORNTON", "TRAVIS", "TUCKER", "TYLER", "VAUGHAN", "WADE", "WALSH",
	"WARNER", "WHEELER", "WHITAKER", "WHITMORE", "WILKINS", "WINSLOW", "YEAGER", "BARNES", "BOOKER", "COLEMAN",
	"DIXON", "FREEMAN", "GAINES", "GREENE", "HAMPTON", "HARRIS", "HAWKINS", "HOLMES", "INGRAM", "JEFFERSON",
	"JOHNSON", "LEWIS", "MAYS", "MITCHELL", "MOSLEY", "PORTER", "RANDOLPH", "SIMMONS", "TURNER", "WASHINGTON",
	"WHITFIELD", "WILKERSON", "WOODARD", "BANKS", "BRISCOE", "CALDWELL", "DUPREE", "FIELDS", "GILLIAM", "HOLLIS",
	"BARBIERI", "CAPUTO", "COSTA", "DELUCA", "ESPOSITO", "FERRARO", "GALLO", "GRECO", "LOMBARDI", "MANCINI",
	"MARCHETTI", "MORETTI", "PAGANO", "RIZZO", "ROMANO", "SANTORO", "VITALE", "ZAPPA", "BIANCHI", "CONTI",
	"BLASZCZYK", "CZAJKA", "DUDEK", "JAWORSKI", "KAMINSKI", "LEWANDOWSKI", "NOWAK", "PIETRZAK", "SIKORSKI", "ZIELINSKI",
	"ALVAREZ", "CASTILLO", "CERVANTES", "DELGADO", "ESCOBAR", "FUENTES", "GUERRERO", "HERRERA", "JIMENEZ", "MALDONADO",
	"MENDOZA", "MONTOYA", "NAVARRO", "OROZCO", "PACHECO", "QUINTANA", "RAMIREZ", "SALAZAR", "TORRES", "VALDEZ",
	"VARGAS", "VEGA", "ACOSTA", "BELTRAN", "CARDENAS", "ESPINOZA", "GALVAN", "IBARRA", "LUJAN", "MEDRANO",
	"BOUDREAUX", "BROUSSARD", "FONTENOT", "GUIDRY", "HEBERT", "LEBLANC", "THIBODEAUX", "ARCENEAUX", "COMEAUX", "PREJEAN",
]
## The five slots an AI fireteam fills. MARKSMAN is a valid MOS with a body and a
## skill, but is not a standing slot - he is drawn only as an alternate.
const MOS_ORDER: Array[String] = ["POINTMAN", "RTO", "MEDIC", "MG", "GRENADIER"]
## The player leads a reinforced squad: one of each specialist slot, riflemen filling
## the rest to size. Kept in lock-step with SquadSystem.SQUAD_SIZE.
const SQUAD_SIZE: int = 8
const FILL_MOS: String = "RIFLEMAN"
## Earned nicks only - a specialist gets his after NICK_MISSIONS tours. A MOS
## with no entry (grenadier, marksman, rifleman) NEVER gets one: a grunt goes
## by his name (Summoner, 2026-07-25).
const NICKNAMES := {
	"MEDIC": "DOC", "MG": "PIG", "RTO": "SPARKS", "POINTMAN": "EYES",
}
const NICK_MISSIONS: int = 3
## Player-facing role words. The MOS keys are save format - never print them raw.
const MOS_DISPLAY := {
	"RTO": "RADIO MAN", "MG": "MACHINE GUNNER", "POINTMAN": "POINT MAN",
	"MEDIC": "MEDIC", "GRENADIER": "GRENADIER", "MARKSMAN": "MARKSMAN",
	"RIFLEMAN": "RIFLEMAN",
}


static func generate_member(rng: RandomNumberGenerator, mos: String) -> Dictionary:
	# RECON 2d100 attributes, 4-F reroll rule.
	var st: int = 0
	var ag: int = 0
	var al: int = 0
	for _attempt in range(20):
		st = rng.randi_range(1, 100) + rng.randi_range(1, 100)
		ag = rng.randi_range(1, 100) + rng.randi_range(1, 100)
		al = rng.randi_range(1, 100) + rng.randi_range(1, 100)
		if st + ag + al > 100 and mini(st, mini(ag, al)) >= 30:
			break
	var member := {
		"name": "%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], LAST_NAMES[rng.randi() % LAST_NAMES.size()]],
		"mos": mos,
		"nick": "",
		"st": st, "ag": ag, "al": al,
		"skills": {},        # skill_name -> level (rolled below - no blank recruits)
		"skill_uses": {},    # skill_name -> cumulative use-points (learn-by-doing)
		"xp": 0,             # personal use-XP, separate from the player's hidden reputation
		"kills": 0,
		"missions": 0,
		"alive": true,
		# His face and the paint on his pot ARE the man (Pillar 4) - assigned once
		# at generation, stored so no hash()/atlas re-cut can ever change a veteran.
		"face": rng.randi() % 70,
		"helmet": GruntDresser.HELMETS[rng.randi() % GruntDresser.HELMETS.size()],
	}
	_roll_starting_skills(member, rng)
	return member


## No blank recruits: MOS skill guaranteed L1-3 by aptitude, plus
## 0-2 al-weighted extra skills at L1. Every recruit reads as a distinct person at spawn.
static func _roll_starting_skills(member: Dictionary, rng: RandomNumberGenerator) -> void:
	var skills: Dictionary = {}
	var al: int = int(member.get("al", 100))
	var mos_skill: String = str(SkillCatalog.MOS_SKILL.get(str(member.get("mos", "")), ""))
	if mos_skill != "" and SkillCatalog.SKILLS.has(mos_skill):
		var lvl: int = 1 + (1 if al > 110 else 0) + (1 if al > 150 else 0)  # L1-3 by aptitude
		skills[mos_skill] = mini(lvl, int(SkillCatalog.SKILLS[mos_skill].max))
	# 0-2 extra skills, likelier for sharp (high-al) men.
	var extras: int = 0
	if rng.randf() < clampf(float(al) / 220.0, 0.15, 0.85):
		extras += 1
	if rng.randf() < clampf(float(al) / 320.0, 0.05, 0.55):
		extras += 1
	var pool: Array = SkillCatalog.SKILLS.keys()
	for _i in range(extras):
		var pick: String = str(pool[rng.randi() % pool.size()])
		if not skills.has(pick):
			skills[pick] = 1
	member["skills"] = skills


## Learn-by-doing: add `n` use-points toward a member's skill, leveling it up when the
## cumulative curve is crossed. Mutates `member` in place (it IS the roster dict, so
## growth persists at the next campaign save - no disk write here, the mission-end save
## carries it). Returns the new level if a PROMOTION happened this call (so the caller
## can bark it), else 0. Only touches skills, NEVER attributes.
static func credit_use(member: Dictionary, skill: String, n: int = 1) -> int:
	if member.is_empty() or not SkillCatalog.SKILLS.has(skill) or n <= 0:
		return 0
	var uses: Dictionary = member.get("skill_uses", {})
	var total: int = int(uses.get(skill, 0)) + n
	uses[skill] = total
	member["skill_uses"] = uses
	member["xp"] = int(member.get("xp", 0)) + n
	var skills: Dictionary = member.get("skills", {})
	var level: int = int(skills.get(skill, 0))
	var cap: int = int(SkillCatalog.SKILLS[skill].max)
	var promoted: int = 0
	while level < cap and total >= SkillCatalog.uses_for_level(level + 1):
		level += 1
		promoted = level
	if promoted > 0:
		skills[skill] = level
		member["skills"] = skills
	return promoted


## THE FREE REFILL IS DEAD (Summoner, 2026-08-28: "i like replacements by bird").
## This prunes the dead and migrates old saves. It manufactures men in exactly ONE case -
## an EMPTY roster, which is a new tour and the squad you are handed to start with. Every
## man after that arrives on a Huey through `draft_replacements`, and losing one costs you
## his slot until the bird comes.
static func ensure_roster(rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var roster: Array = CampaignState.roster
	# Drop the dead (they stay in memory only via the log).
	var living: Array = []
	for m in roster:
		if bool(m.get("alive", true)):
			living.append(m)
	if living.is_empty():
		living = draft_replacements(rng, SQUAD_SIZE, living)
	# Back-fill fields added after an older save was written (learn-by-doing).
	for m in living:
		migrate_member(m)
		if not m.has("skill_uses"):
			m["skill_uses"] = {}
		if not m.has("xp"):
			m["xp"] = 0
		if not m.has("skills"):
			m["skills"] = {}
		# Older saves: derive once from the name, then it lives in the record.
		if not m.has("face"):
			m["face"] = absi(str(m.get("name", "")).hash()) % 70
		if not m.has("helmet"):
			m["helmet"] = GruntDresser.HELMETS[
				absi(str(m.get("name", "")).hash()) % GruntDresser.HELMETS.size()]
	CampaignState.roster = living
	CampaignState.save_campaign()
	return living


## Earned rank by missions survived. SP4 (E-4 Specialist) is the rank of the typical
## Vietnam infantryman - a technician's grade, NOT an NCO. CPL is the same pay grade
## but carries command authority, so a man only crosses to CPL if he is holding a
## leader billet (POINTMAN / RTO): rank gates authority, never ability (ADR-018).
## How many slots the squad is short. The ONE definition - the bird, the AAR and the
## roster board all read this, so they can never disagree about who is missing.
static func vacancies() -> int:
	var living: int = 0
	for m in CampaignState.roster:
		if bool((m as Dictionary).get("alive", true)):
			living += 1
	return maxi(0, SQUAD_SIZE - living)


## Cut `n` fresh men for the replacement bird. Specialist slots the squad has LOST are
## filled before riflemen - the medic and the radio are what you actually feel missing.
## They come green by construction: `generate_member` sets missions 0, so `rank_for`
## reads PVT and `nick_earned` is false. There is no separate "FNG" flag to drift.
static func draft_replacements(rng: RandomNumberGenerator, n: int,
		living: Array = []) -> Array:
	if n <= 0:
		return []
	var have: Array = living if not living.is_empty() else _living_roster()
	var out: Array = []
	var have_mos: Array = []
	for m in have:
		have_mos.append(str((m as Dictionary).get("mos", "")))
	for mos in MOS_ORDER:
		if out.size() >= n:
			break
		if not have_mos.has(mos):
			out.append(generate_member(rng, mos))
			have_mos.append(mos)
	while out.size() < n:
		out.append(generate_member(rng, FILL_MOS))
	return out


static func _living_roster() -> Array:
	var living: Array = []
	for m in CampaignState.roster:
		if bool((m as Dictionary).get("alive", true)):
			living.append(m)
	return living


static func rank_for(member: Dictionary) -> String:
	var missions: int = int(member.get("missions", 0))
	var leads: bool = str(member.get("mos", "")) in ["POINTMAN", "RTO"]
	if missions >= 16:
		return "SFC"
	if missions >= 12:
		return "SSG"
	if missions >= 8:
		return "SGT"
	if missions >= 4:
		return "CPL" if leads else "SP4"
	if missions >= 2:
		return "PFC"
	if missions >= 1:
		return "PV2"
	return "PVT"


static func skill_level(member: Dictionary, skill: String) -> int:
	return int((member.get("skills", {}) as Dictionary).get(skill, 0))


static func mos_display(mos: String) -> String:
	return str(MOS_DISPLAY.get(mos, mos))


static func nick_earned(member: Dictionary) -> bool:
	return int(member.get("missions", 0)) >= NICK_MISSIONS \
		and NICKNAMES.has(str(member.get("mos", "")))


static func earned_nick(member: Dictionary) -> String:
	if not nick_earned(member):
		return ""
	var nick: String = str(member.get("nick", ""))
	return nick if nick != "" else str(NICKNAMES.get(str(member.get("mos", "")), ""))


static func last_name(member: Dictionary) -> String:
	var parts: PackedStringArray = str(member.get("name", "")).split(" ", false)
	return str(parts[parts.size() - 1]) if parts.size() > 0 else ""


## What the men call him: earned nick, else his surname, else a bench rig's
## bare nick, else SOLDIER.
static func call_name(member: Dictionary) -> String:
	var nick: String = earned_nick(member)
	if nick != "":
		return nick
	var last: String = last_name(member)
	if last != "":
		return last
	nick = str(member.get("nick", ""))
	return nick if nick != "" else "SOLDIER"


## True exactly once, on the patrol he crosses the mark. The caller owns the toast.
static func christen(member: Dictionary) -> bool:
	if bool(member.get("christened", false)) or not nick_earned(member):
		return false
	member["christened"] = true
	member["nick"] = str(NICKNAMES.get(str(member.get("mos", "")), ""))
	return true


## Save shim: nicks became earned, RADIO became SPARKS, grunts carry none.
## Veterans past the mark keep theirs quietly - the flag lands with NO toast.
static func migrate_member(m: Dictionary) -> void:
	if str(m.get("nick", "")) == "RADIO":
		m["nick"] = "SPARKS"
	if not NICKNAMES.has(str(m.get("mos", ""))):
		m["nick"] = ""
	if nick_earned(m):
		m["nick"] = str(NICKNAMES.get(str(m.get("mos", "")), ""))
		m["christened"] = true
