extends RefCounted

const MAX_ANIMALS := 32
# Speed is in cell-view units/second. All land species use automatic capture
# when a selected human is within one physical metre (five cell-view units).
const SPECIES := {
	"deer": {"name": "Deer", "habitats": ["forest", "grassland"], "group": Vector2i(2, 4), "rarity": 1.0, "speed": 8.0, "health": 70, "temperament": "wary", "scene": "deer", "rigged": true},
	"boar": {"name": "Wild boar", "habitats": ["forest"], "group": Vector2i(1, 3), "rarity": 0.55, "speed": 6.0, "health": 120, "temperament": "dangerous", "scene": "wild_boar", "rigged": false},
	"horse": {"name": "Horse", "habitats": ["grassland"], "group": Vector2i(2, 4), "rarity": 0.7, "speed": 9.0, "health": 130, "temperament": "wary", "scene": "horse_brown", "rigged": true},
	"cow": {"name": "Cow", "habitats": ["grassland"], "group": Vector2i(2, 4), "rarity": 0.7, "speed": 4.5, "health": 140, "temperament": "calm", "scene": "cow", "rigged": true},
	"sheep": {"name": "Sheep", "habitats": ["grassland", "highlands"], "group": Vector2i(3, 5), "rarity": 0.9, "speed": 5.0, "health": 60, "temperament": "calm", "scene": "sheep", "rigged": false},
	"goat": {"name": "Goat", "habitats": ["highlands"], "group": Vector2i(2, 4), "rarity": 1.0, "speed": 6.0, "health": 70, "temperament": "calm", "scene": "goat", "rigged": false},
	"camel": {"name": "Camel", "habitats": ["desert", "steppe"], "group": Vector2i(1, 3), "rarity": 0.65, "speed": 6.0, "health": 150, "temperament": "calm", "scene": "camel", "rigged": false},
	"polar_bear": {"name": "Polar bear", "habitats": ["north_polar_coast"], "group": Vector2i(1, 1), "rarity": 0.18, "speed": 7.0, "health": 220, "temperament": "dangerous", "scene": "polar_bear", "rigged": false},
	"penguin": {"name": "Penguin", "habitats": ["south_polar_coast"], "group": Vector2i(3, 6), "rarity": 0.8, "speed": 3.0, "health": 40, "temperament": "calm", "scene": "penguin", "rigged": false},
}
const COMMANDS := ["move", "stop", "follow", "stay"]

static func habitat(sample: Dictionary, latitude: float, coastal: bool) -> String:
	var terrain := str(sample.get("terrain", "water"))
	var biome := str(sample.get("biome", ""))
	if terrain == "water" or float(sample.get("river", 0)) >= 0.1: return ""
	if terrain in ["snow", "tundra"] or biome in ["polar_ice", "snowfield"]:
		if coastal and absf(latitude) >= 0.8: return "north_polar_coast" if latitude > 0 else "south_polar_coast"
		return ""
	if terrain == "forest" or "forest" in biome or "woodland" in biome: return "forest"
	if terrain in ["hills", "mountains"]: return "highlands" if float(sample.get("moisture", 0.0)) > 0.25 else ""
	if terrain == "desert" and biome != "beach": return "desert"
	if terrain == "plains": return "steppe" if float(sample.get("moisture", 0.5)) < 0.28 else "grassland"
	return ""

static func eligible(species: String, habitat_name: String) -> bool:
	return SPECIES.has(species) and habitat_name in SPECIES[species].habitats
