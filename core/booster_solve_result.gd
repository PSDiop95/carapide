class_name BoosterSolveResult
extends RefCounted
## Métrique de l'éditeur : boosters minimum pour gagner.

const UNKNOWN: int = -1

## UNKNOWN : aucune victoire trouvée dans la limite de boosters, ou plafond atteint.
var needed_min: int = UNKNOWN
var nodes_explored: int = 0
var aborted: bool = false
