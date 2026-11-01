class_name LevelVehicle
extends RefCounted
## Véhicule d'un niveau. Coordonnées en float 64 bits : pas de Vector2, limité à 32 bits.
## `pos_*` = centre de la boîte, en unités de case, origine en bas à gauche, y vers le haut.
## `angle` en degrés : 0 = +X, 90 = +Y (vers la gare), sens trigonométrique.

var id: int
var type_name: String
var dest: String
var pos_x: float
var pos_y: float
var angle: float
var capacity: int
var length: float
var width: float
