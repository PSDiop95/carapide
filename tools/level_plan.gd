class_name LevelPlan
extends RefCounted
## Plan des niveaux du prototype, GDD §4 plage 1–20 et exception validée :
## niv. 1–3 à 2 destinations, 4–5 à 3, marge 3 ; 6–9 marge 2 ; niveau 10 à 5 destinations, marge 1 ;
## 11–15 marge 2, de quoi atteindre le déblocage du Dioulé (niv. 13).

const CARDINAL: Array[float] = [0.0, 90.0, 180.0, 270.0]
const WITH_DIAGONALS: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
const FREE_ANGLES: Array[float] = [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]
const DEST_ORDER: Array[String] = ["colobane", "petersen", "parcelles", "pikine", "rufisque"]
const BASE_TYPES: Array[String] = ["taxi", "car_rapide"]
const WITH_CLANDO: Array[String] = ["taxi", "clando", "car_rapide"]
const WITH_NDIAGA: Array[String] = ["taxi", "clando", "car_rapide", "ndiaga_ndiaye"]
const SEED: int = 221


static func all() -> Array[LevelSpec]:
	return [
		LevelSpec.make(1, Vector2(7, 7), BASE_TYPES, CARDINAL, _dests(2), 8, 3),
		LevelSpec.make(2, Vector2(7, 8), BASE_TYPES, CARDINAL, _dests(2), 9, 3),
		LevelSpec.make(3, Vector2(8, 8), BASE_TYPES, WITH_DIAGONALS, _dests(2), 10, 3),
		LevelSpec.make(4, Vector2(8, 9), BASE_TYPES, WITH_DIAGONALS, _dests(3), 12, 3),
		LevelSpec.make(5, Vector2(8, 10), BASE_TYPES, WITH_DIAGONALS, _dests(3), 14, 3),
		LevelSpec.make(6, Vector2(9, 10), WITH_CLANDO, WITH_DIAGONALS, _dests(3), 15, 2),
		LevelSpec.make(7, Vector2(9, 11), WITH_CLANDO, FREE_ANGLES, _dests(4), 16, 2),
		LevelSpec.make(8, Vector2(9, 11), WITH_CLANDO, FREE_ANGLES, _dests(4), 17, 2),
		LevelSpec.make(9, Vector2(10, 11), WITH_CLANDO, FREE_ANGLES, _dests(5), 18, 2),
		LevelSpec.make(10, Vector2(10, 12), WITH_NDIAGA, FREE_ANGLES, _dests(5), 20, 1),
		LevelSpec.make(11, Vector2(10, 12), WITH_NDIAGA, FREE_ANGLES, _dests(3), 18, 2),
		LevelSpec.make(12, Vector2(10, 12), WITH_NDIAGA, FREE_ANGLES, _dests(4), 19, 2),
		LevelSpec.make(13, Vector2(10, 12), WITH_NDIAGA, FREE_ANGLES, _dests(4), 20, 2),
		LevelSpec.make(14, Vector2(10, 13), WITH_NDIAGA, FREE_ANGLES, _dests(5), 21, 2),
		LevelSpec.make(15, Vector2(10, 13), WITH_NDIAGA, FREE_ANGLES, _dests(5), 22, 2),
	]


static func _dests(count: int) -> Array[String]:
	return DEST_ORDER.slice(0, count)
