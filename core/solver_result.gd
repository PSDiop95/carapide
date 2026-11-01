class_name SolverResult
extends RefCounted
## Résultat du solveur. `aborted` = plafond de nœuds atteint : rien n'est prouvé.

var solvable: bool = false
var min_margin: int = -1
var min_slots: int = -1
var nodes_explored: int = 0
var solution: PackedInt32Array = PackedInt32Array()
var aborted: bool = false
