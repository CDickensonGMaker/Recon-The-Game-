## war_facts.gd - loading-screen history.
##
## The war did not begin in 1965, and it was not born as a communist project. It began
## as a colonial one, and the men the player will be shooting at were, first and for a
## very long time, people trying to get foreigners off their land. Communism arrived as
## the vehicle that was offered - and the one the West kept refusing to outbid.
##
## RULES FOR THIS FILE:
##  - Every entry must be a fact with a date, not an opinion with a date.
##  - Where a number is genuinely contested, say so IN the line. Do not launder an
##    estimate into a certainty to make a cleaner sentence.
##  - No line may flatter either side. The Party's own atrocities are in here beside
##    everyone else's, because a file that only indicts one side is propaganda and the
##    player will smell it.
class_name WarFacts
extends RefCounted

const FACTS: Array[String] = [
	"1858 — French warships attacked Da Nang, beginning a conquest that took nearly thirty years. Vietnam had already spent a thousand years resisting Chinese rule; resisting foreign occupation was not a new idea imported with Marx.",

	"AD 40 — The Trung sisters raised a rebellion against Chinese occupation and briefly won. Vietnamese schoolchildren still learn their names. The instinct that would later be called communist insurgency is, in Vietnam, considerably older than communism.",

	"1887 — France formally bound Vietnam, Cambodia and Laos into French Indochina. Vietnam itself was administered as three separate pieces — Tonkin, Annam and Cochinchina — a division intended to make one nation harder to imagine.",

	"Under French rule, Vietnam exported rice while Vietnamese peasants went hungry. Colonial monopolies on salt, alcohol and opium were a major source of state revenue — the administration made money selling addiction to the people it governed.",

	"1919 — A young Vietnamese kitchen worker in Paris, calling himself Nguyen Ai Quoc, submitted a petition to the Versailles Peace Conference. He asked not for independence but for basic civil liberties and Vietnamese representation in the French parliament. He was ignored. He later took the name Ho Chi Minh.",

	"1930 — The Vietnamese Nationalist Party, which was not communist, launched the Yen Bai mutiny. The French crushed it and executed its leaders. Repression narrowed the field of Vietnamese resistance until the best-organised survivors were the communists.",

	"1930 — Ho Chi Minh founded the Indochinese Communist Party in Hong Kong. He had spent the preceding decade in Paris, London, New York and Moscow, and had by his own account turned to Lenin because Lenin was the only one talking about colonies.",

	"1940-45 — Japan occupied Vietnam but left the Vichy French administration in place. For most Vietnamese it meant two colonial masters instead of one, extracting from the same countryside.",

	"1945 — Famine killed enormous numbers in northern Vietnam while rice was requisitioned for the war effort. Estimates range from several hundred thousand to two million dead; the figure most often cited is around a million. It did more to recruit for the Viet Minh than any pamphlet.",

	"1945 — American OSS officers of the Deer Team parachuted in to train and supply Ho Chi Minh's Viet Minh against the Japanese. They treated Ho for malaria and dysentery. For a few months that year, the United States armed the man it would spend the next thirty years fighting.",

	"2 September 1945 — Ho Chi Minh declared Vietnamese independence in Hanoi, opening with a line borrowed deliberately from the American Declaration: that all men are created equal. He was speaking to Washington as much as to the crowd.",

	"1945-46 — Ho Chi Minh wrote repeatedly to President Truman seeking American support for Vietnamese independence. The letters were never answered. Washington had decided that keeping France on side in Europe mattered more.",

	"1946-54 — The First Indochina War. By its final year the United States was paying roughly 80 percent of France's costs. American money was in that war long before American troops were.",

	"7 May 1954 — The French garrison at Dien Bien Phu surrendered after a 56-day siege. Vietnamese troops had dragged artillery up mountains the French believed impassable and dug it in above them. A European army had been beaten in open battle by a colonial one.",

	"1954 — The Geneva Accords split Vietnam at the 17th parallel as a TEMPORARY military line, with nationwide reunification elections set for 1956. The line was never meant to be a border. The elections were never held.",

	"Eisenhower later wrote that had elections been held in 1956, possibly 80 percent of Vietnamese would have voted for Ho Chi Minh rather than the US-backed Emperor Bao Dai. That estimate is his own, in his own memoir.",

	"1953-56 — Land reform in the communist North turned into a purge. Thousands of Vietnamese were executed after denunciation, many of them poor farmers labelled landlords to fill quotas. The Party publicly admitted the campaign's errors. Ho's side was not clean either.",

	"1955 — Ngo Dinh Diem claimed 98.2 percent in a referendum to become president of South Vietnam. In Saigon he was credited with more votes than there were registered voters. The regime the United States would defend for the next eight years began with an obviously rigged count.",

	"Diem was a Catholic governing a country that was overwhelmingly Buddhist, and he favoured Catholics in land, appointments and army promotions. His government was not primarily fighting communism in the villages — it was collecting rent from them.",

	"11 June 1963 — The monk Thich Quang Duc burned himself to death at a Saigon intersection in protest against the Diem government, sitting motionless as he died. The photograph reached the world. Diem's sister-in-law publicly called it a barbecue.",

	"November 1963 — Diem was overthrown and murdered in a coup Washington had quietly approved. Three weeks later Kennedy was dead too. South Vietnam went through a series of governments in the following year; the state the US was defending could not reliably govern itself.",

	"4 August 1964 — The second Gulf of Tonkin attack, used to justify the resolution that opened the war, almost certainly never happened. A declassified National Security Agency study concluded there were no North Vietnamese boats there that night. Congress passed the resolution 416-0 and 88-2.",

	"Ho Chi Minh reportedly told the French that they could kill ten of his men for every one of theirs he killed, and that even at those odds they would lose and he would win. The arithmetic was not a boast. It was the strategy.",

	"The United States dropped more tonnage of bombs on Indochina than all sides combined dropped in the whole of the Second World War. Vietnam is a country roughly the size of New Mexico.",

	"The Viet Cong were not primarily a foreign army. Many were southerners fighting in the provinces they were born in — which is why they knew the ground, and why a village could be hostile in daylight and a base at night.",

	"North Vietnamese and Viet Cong logistics ran largely on bicycles. A reinforced Chinese-made bicycle pushed by a man on foot could carry several hundred pounds down the Ho Chi Minh Trail, and no amount of air power ever closed it.",

	"In Vietnam this war is not called the Vietnam War. It is called the Resistance War Against America — the sequel to the resistance war against France, which was the sequel to a thousand years of resisting China.",

	"1968 — The Tet Offensive was a severe military defeat for the communists, who lost the Viet Cong's veteran core and failed to trigger the general uprising they expected. It is also the moment American public support broke. Both statements are true at once.",

	"Ho Chi Minh died in September 1969, six years before the war ended. He had spent roughly thirty years fighting foreigners in his own country and had never governed a unified one.",

	"US advisers frequently reported that villagers cared little about Marxist theory and a great deal about land, rice and being left alone by armed men. The ideology was the vehicle. The occupation was the grievance.",

	"14-18 November 1965 — The Battle of Ia Drang, the first major clash between US and North Vietnamese regulars, at Landing Zone X-Ray in the Central Highlands. 237 Americans were killed; North Vietnamese losses are estimated at 1,800-2,000 dead, though Hanoi's own contemporaneous reports list far fewer. It was also the first large-scale helicopter air assault of the war and the first tactical use of B-52 strikes in close support of troops on the ground.",

	"249 Medals of Honor were awarded for actions in Vietnam. 156 of them — nearly 63 percent — were posthumous. Roughly 40 of the recipients are still living.",

	"2 May 1968, west of Loc Ninh — Staff Sergeant Roy Benavidez boarded an unarmed helicopter to reach a 12-man Special Forces team pinned down and surrounded. Over six hours, wounded repeatedly by rifle fire, a bayonet and grenade fragments, he organized the survivors, called in airstrikes and personally carried and dragged wounded men to extraction, saving at least eight lives. His Medal of Honor was not presented until 1981 — the recommendation stalled for over a decade until a radioman he'd believed dead surfaced as a living witness. Some accounts place the actual fight across the border in Cambodia, sanitized to Vietnam in the official record because American ground troops were not supposed to be there.",

	"22 October 1965, Phu Cuong — Private First Class Milton Olive III, 173rd Airborne Brigade, was moving through the jungle with four other soldiers when a grenade landed among them. He grabbed it and threw himself on top of it. He was 18 years old, and the first Black American to receive the Medal of Honor for actions in Vietnam.",

	"16 March 1966, War Zone D north of Saigon — Specialist Four Alfred Rascon, a combat medic, repeatedly crossed open ground under fire to reach wounded men, at one point using his own body to shield a soldier from a grenade blast. His award recommendation was submitted at the time and then lost in the chain of command; he received the Silver Star instead. Survivors he had saved tracked down the paperwork decades later, and Rascon was finally awarded the Medal of Honor in 2000 — 34 years after the action.",

	"Between 1962 and 1971, US forces sprayed roughly 19 million gallons of herbicide over Vietnam, Agent Orange accounting for about 11.2 million gallons of it, across some 3.6 million acres — close to a tenth of South Vietnam's land area. Its dioxin contamination is linked to cancers and birth defects in both Vietnamese and American veteran populations, and the two governments are still funding cleanup and health programs from it today.",

	"The average US infantryman in Vietnam was about 22 years old. Draftees made up roughly a third of American deaths — 17,671 of the 58,220 killed — despite volunteers outnumbering draftees in-country overall.",

	"About 12,000 helicopters served in Vietnam; more than 5,000 were destroyed by enemy fire or accident. Of roughly 7,000 UH-1 Hueys that flew there, over 3,300 were lost, and more than 2,700 American helicopter pilots and crew were killed flying them.",

	"MEDEVAC helicopters flew nearly 500,000 missions in Vietnam and airlifted upward of 900,000 patients. Average time from wounding to a hospital bed was under an hour — faster than any war before it — and of Americans who survived their first 24 hours after being hit, fewer than one percent then died of their wounds.",

	"591 American prisoners of war — 566 military, 25 civilian — came home in Operation Homecoming in early 1973. The longest-held among them spent close to nine years in captivity; the first pilot shot down and captured, Everett Alvarez Jr., was held for over eight.",

	"An estimated 10,000 American military women served in-country during the war, about 90 percent of them nurses. Eight are listed on the Vietnam Veterans Memorial Wall — women who died of disease, accident or hostile fire while treating the wounded.",

	"Around 2.7 million Americans served within the borders of South Vietnam over the course of the war, out of roughly 8.7 million who served in the US military during the Vietnam era as a whole.",
]


static func random_fact(rng: RandomNumberGenerator = null) -> String:
	if rng != null:
		return FACTS[rng.randi_range(0, FACTS.size() - 1)]
	return FACTS[randi() % FACTS.size()]
