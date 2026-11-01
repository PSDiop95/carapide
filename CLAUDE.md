# CLAUDE.md — CARAPIDE

Jeu mobile puzzle « car jam + tri de passagers » au contexte sénégalais.
Source de vérité design : GDD CARAPIDE v1.0 (artifact claude.ai). En cas de conflit, le GDD gagne ; signale l'écart, ne l'arbitre pas seul.

## Stack
- Godot 4.x (dernière stable), GDScript typé statiquement. Pas de C#.
- Rendu : Mobile (Compatibility en repli). Cible Android 8+, 2 Go RAM.
- Tests : GUT (`addons/gut`). Lancement headless : `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.

## Règles de jeu (résumé — détail dans le GDD §2–3)
- **Bouchon** : véhicules fléchés (angle libre). Tap → avance tout droit ; voie libre jusqu'au bord → sort vers la gare ; sinon choc + retour.
- **Gare** : 4 places de base + 1 place Coxeur + 3 verrouillées.
- **File** : seule la tête embarque, dans un véhicule garé de même destination. Plein → départ, place libérée, chaînage.
- **Victoire** : file vide. **Défaite** : gare pleine, aucune correspondance, aucun coup utile.
- Capacités : Taxi/Clando 4, Car rapide 8, Ndiaga Ndiaye/Tata 12, Moto Jakarta 2.

## Architecture (ne pas dévier sans le dire)
```
res://
  core/        # logique pure, AUCUNE dépendance Node/scène → 100 % testable
    level_data.gd      # Resource : vehicles[], queue_blocks[], slots, mechanics
    board_logic.gd     # grille, OBB, test de sortie (raycast logique)
    station_logic.gd   # places, chargement, départs
    queue_logic.gd     # file en blocs {destination, count}
    game_rules.gd      # tick d'action → événements (moved, blocked, boarded, departed, won, lost)
    solver.gd          # DFS + mémo, utilisé par l'éditeur et la détection de défaite
  game/        # présentation : scènes, animations, input ; écoute les événements du core
  meta/        # hub, gare à construire, roue, Station, boutique
  services/    # save, ads, iap, analytics (interfaces + implémentations mock)
  data/levels/ # JSON des niveaux
  tests/
```
- Le **core est déterministe** : aucune logique de jeu dans `_process`, aucun `randf()` sans seed injectée.
- La présentation n'écrit jamais l'état ; elle rejoue les événements renvoyés par `game_rules`.
- Services derrière des interfaces ; mocks par défaut en dev (aucun SDK pub avant la phase MVP).
- Données > code : prix, capacités, déblocages dans `data/config/*.json`, pas en dur.

## Conventions
- snake_case fichiers/fonctions, PascalCase `class_name`, constantes UPPER_CASE.
- Typage obligatoire (`var x: int`, retours typés). Warnings GDScript traités comme erreurs.
- Signaux au passé : `vehicle_departed`, `level_won`.
- Pas de nœuds singletons sauf `Services` et `Events` (autoloads).
- Fonctions < 40 lignes ; un fichier = une responsabilité.

## Budgets perf (bloquants)
APK < 80 Mo · 60 fps cible / 30 plancher sur Mali-G52 · < 120 draw calls · RAM < 350 Mo · foule en MultiMesh (1 draw call / couleur).

## Méthode de travail
1. Lire le ticket, poser les questions bloquantes **avant** de coder.
2. Core d'abord, avec tests GUT ; présentation ensuite.
3. Lancer les tests avant de déclarer « fini ». Pas de test vert = pas fini.
4. Petits commits, message en français : `feat(core): test de sortie des véhicules`.
5. Ne jamais copier asset, nom, icône ou maquette de Bus Fever Party! (risque juridique).
6. Fin de tâche : 3–5 lignes — ce qui est fait, comment tester, ce qui reste. Pas de récap verbeux.

## Hors scope tant que non demandé
Pubs/IAP réels, backend, multijoueur, générateur procédural runtime, localisation (garder les clés `tr()` dès le départ).
