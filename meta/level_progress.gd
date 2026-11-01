class_name LevelProgress
extends RefCounted
## Progression 1 à N, sauvegardée. Numéros de niveau à partir de 1.

const KEY: String = "current_level"
const FIRST_LEVEL: int = 1


static func current_level(save: SaveService, level_count: int) -> int:
	return clampi(save.get_int(KEY, FIRST_LEVEL), FIRST_LEVEL, level_count)


static func is_last(level_number: int, level_count: int) -> bool:
	return level_number >= level_count


## Enregistre la victoire et renvoie le niveau à jouer ensuite (retour au 1 après le dernier).
static func record_win(save: SaveService, level_number: int, level_count: int) -> int:
	var next_level: int = FIRST_LEVEL if is_last(level_number, level_count) else level_number + 1
	save.set_int(KEY, next_level)
	return next_level


## Repart du premier niveau et le renvoie.
static func reset(save: SaveService) -> int:
	save.set_int(KEY, FIRST_LEVEL)
	return FIRST_LEVEL
