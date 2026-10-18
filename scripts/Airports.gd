class_name Airports
extends RefCounted
## Named airports for every scenario. Landing somewhere for the first time earns a stamp in the logbook.

const POOLS: Array = [
	["Maple Field", "Cedar Flats", "Harbor Heights", "Prairie Creek", "Willow Run", "Fairview Strip"],   # standard
	["Timber Notch", "Pine Ridge", "Stumpy Meadow"],                                                      # short field
	["Dead Stick Dunes", "Last Chance Strip", "Hollow Mesa"],                                            # engine out
	["Moonlight Bay", "Starlit Field", "Nightingale Field"],                                              # night
	["Eagle's Perch", "Skyline Mesa", "Thin Air Strip"],                                                  # mountain
	["USS Hotshot", "USS Whiskers", "USS Greaser"],                                                       # carrier
	["Lake Mirror", "Pelican Cove", "Reed Bay"],                                                          # seaplane
	["Route 66 Flatbed", "Hauler's Highway", "Big Rig Run"],                                              # truck
	["Mudhen Meadow", "Clover Knoll", "Buttercup Strip"],                                                  # soft field
	["Abeam Acres", "Glide Slope Gap", "Coasting Creek"],                                                 # power-off 180
	["Minimums Field", "Overcast Intl", "Mistral Airfield"],                                              # instrument
]

static func count() -> int:
	var n := 0
	for p in POOLS:
		n += (p as Array).size()
	return n

static func pool_size(scn: int) -> int:
	return (POOLS[clampi(scn, 0, POOLS.size() - 1)] as Array).size()

static func pick(scn: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, pool_size(scn) - 1)

static func name_of(scn: int, idx: int) -> String:
	return (POOLS[clampi(scn, 0, POOLS.size() - 1)] as Array)[clampi(idx, 0, pool_size(scn) - 1)]

static func id_of(scn: int, idx: int) -> String:
	return "%d_%d" % [scn, idx]

## Every airport, in scenario order: [{id, scn, idx, name}]
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for scn in POOLS.size():
		for idx in pool_size(scn):
			out.append({"id": id_of(scn, idx), "scn": scn, "idx": idx, "name": name_of(scn, idx)})
	return out
