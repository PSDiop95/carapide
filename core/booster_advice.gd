class_name BoosterAdvice
extends RefCounted
## Conseil du solveur en gare bloquée.

const UNKNOWN: int = -1

var kind: BoosterAccess.Kind = BoosterAccess.Kind.COXEUR
## Véhicule à faire voler ; sans objet pour l'Apprenti.
var vehicle_id: int = BoardLogic.NO_VEHICLE
## Boosters encore nécessaires après celui-ci ; UNKNOWN si le calcul n'a rien prouvé.
var further_boosters: int = UNKNOWN
## Plafond de nœuds atteint : le conseil vient de la règle de repli, annoncée telle quelle.
var aborted: bool = false
