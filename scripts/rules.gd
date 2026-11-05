class_name WorldRules
extends RefCounted

const VERSION = 1
const ENGINE = "4.6.3"
const BUILDINGS = {
 "storehouse": {"title":"Storehouse", "wood":18, "work":60, "era":0},
 "home": {"title":"Dwelling", "wood":12, "work":40, "era":0},
 "farm": {"title":"Terraced farm", "wood":14, "work":50, "era":0},
 "well": {"title":"Village well", "wood":10, "work":35, "era":0},
 "levee": {"title":"Stone levee", "wood":8, "work":30, "era":0},
 "market": {"title":"Caravan market", "wood":24, "work":90, "era":1},
 "workshop": {"title":"Workshop", "wood":28, "work":100, "era":1},
 "windmill": {"title":"Wind generator", "wood":35, "work":120, "era":2},
 "observatory": {"title":"Orbital observatory", "wood":55, "work":180, "era":3}
}
const POWERS = {
 "rain": {"cost":12, "radius":4.0, "title":"Rain"},
 "heal": {"cost":8, "radius":4.0, "title":"Heal"},
 "forest": {"cost":10, "radius":3.0, "title":"Restore soil"},
 "raise": {"cost":14, "radius":3.0, "title":"Raise earth"},
 "lower": {"cost":14, "radius":3.0, "title":"Lower earth"},
 "fire": {"cost":12, "radius":3.0, "title":"Ignite"},
 "shield": {"cost":15, "radius":5.0, "title":"Shield"},
 "lightning": {"cost":18, "radius":2.5, "title":"Lightning"},
 "quake": {"cost":25, "radius":5.0, "title":"Earthquake"},
 "resurrect": {"cost":20, "radius":4.0, "title":"Resurrect"},
 "spawn": {"cost":15, "radius":1.0, "title":"Create life"},
 "wind": {"cost":5, "radius":5.0, "title":"Change wind"},
 "cool": {"cost":10, "radius":5.0, "title":"Cool climate"}
}
const ERAS = ["DAWN", "SETTLEMENT", "INDUSTRY", "PLANETARY"]
