class_name SafeClock
extends RefCounted
## Heure protégée contre le retour en arrière : le max de l'heure enregistrée et de l'heure actuelle.
## L'heure système est fournie par l'appelant : rien ici ne lit l'horloge.

const KEY: String = "clock_last_seen"
const SECONDS_PER_DAY: int = 86400

var _save: SaveService


func _init(save: SaveService) -> void:
	_save = save


func read(system_now: int) -> int:
	return maxi(_save.get_int(KEY, 0), system_now)


## À appeler quand l'état change : pas à chaque image, la sauvegarde écrit sur le disque.
func commit(system_now: int) -> int:
	var now: int = read(system_now)
	_save.set_int(KEY, now)
	return now


func day(system_now: int) -> int:
	return int(float(read(system_now)) / float(SECONDS_PER_DAY))
