extends Node
## Bus d'événements global (autoload `Events`). Signaux au passé.

signal level_started(level_id: int)
signal level_won(level_id: int)
signal level_lost(level_id: int)
