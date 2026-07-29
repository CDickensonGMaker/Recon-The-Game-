## hamlet_names.gd - Vietnamese settlement names for the topo sheet.
## Deterministic by (mission seed, site index): a province is the same province every
## session, which is what makes a campaign map worth learning.
##
## Printed WITHOUT diacritics, in caps, as US 1:50,000 sheets labelled them. That is
## both period-correct and the only form guaranteed to render - ThemeDB.fallback_font
## carries no Vietnamese glyphs, and a missing glyph prints as a box.
class_name HamletNames
extends RefCounted

## Hand-checked against real Vietnamese place-name elements rather than generated from
## syllables, which produces nonsense to anyone who reads the language.
const GIVEN: Array[String] = [
	"BAC", "BINH HOA", "TAN AN", "PHU MY", "LONG THANH", "AN LOC", "VINH LONG",
	"HOA BINH", "THANH TRI", "DUC HOA", "XUAN LOC", "BEN CAT", "CU CHI",
	"TRANG BANG", "DAU TIENG", "PHUOC LONG", "GO DAU", "BA RIA", "TAN PHU",
	"MY THUAN", "HIEP HOA", "LOC NINH", "CHAU THANH", "TAN HIEP", "PHU CUONG",
	"BINH MY", "AN NHON", "THUAN AN", "LAI THIEU", "PHUOC VINH",
]

## A hamlet is an "AP"; a larger settlement is a "XA". The sheet uses the prefix as a
## size cue, the same way a real sheet's type size did.
const XA_MIN_RADIUS: float = 44.0


static func name_for(seed_value: int, index: int, radius: float) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value * 7919 + index)
	var stem: String = GIVEN[rng.randi_range(0, GIVEN.size() - 1)]
	var prefix: String = "XA" if radius >= XA_MIN_RADIUS else "AP"
	return "%s %s" % [prefix, stem]
