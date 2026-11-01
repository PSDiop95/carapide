class_name LevelLoadResult
extends RefCounted
## Résultat d'un chargement : `level` valide, ou `errors` non vide et `level` à null.

var level: LevelData = null
var errors: PackedStringArray = PackedStringArray()


func is_ok() -> bool:
	return errors.is_empty()
