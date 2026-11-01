# Journal de performance CARAPIDE

Release, installation neuve, 1er lancement (cache froid) pour FPS, RAM et draw calls. Seuils : APK ≤ 150 Mo (alerte 120), démarrage < 5 s, p50 ≥ 55, p5 ≥ 30, RAM < 350 Mo, draw calls < 120.

| Date | Commit | Fonctionnalité | APK (Mo) | Démarrage interactif (ms, médiane de 5) | FPS p50 | FPS p5 | RAM pic (Mo) | Draw calls pic | Appareil |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-11-01 | bd8a965+ | Ligne de base avant F1, 3D à 100 % (rouge) | 143.6 | 1930 | 47.4 | 40.0 | 361 | 111 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | bd8a965+ | Ligne de base avant F1, 3D à 75 % | 143.6 | 1930 | 73.3 | 59.6 | 342 | 111 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 2eff557+ | F1 Dioulé | 143.6 | 1873 | 72.0 | 56.5 | 347 | 114 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 060b94c+ | F2 Garage | 143.6 | 1943 | 72.0 | 67.3 | 341 | 114 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | dc4511e+ | F3 Hub | 143.6 | 2203 | 72.0 | 47.4 | 329 | 115 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 4fa93a2+ | F4 Victoire et économie (rouge : écran de fin, draw calls) | 143.6 | 2244 | 72.0 | 55.4 | 330 | 125 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 4fa93a2+ | F4 Victoire et économie | 143.6 | 2326 | 70.0 | 59.7 | 322 | 115 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 8b02199 | F5 Station et Roue (avant correctif plein écran) | 143.7 | 2303 | 90.0 | 60.0 | 313 | 117 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 72da941 | F5 Station et Roue | 143.7 | 2383 | 89.6 | 60.0 | 306 | 117 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 72da941 | Contrôle niveau 14, hors mesure du prompt (rouge : draw calls) | 143.7 | 2331 | 72.0 | 59.1 | 330 | 123 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | a706564 | Toit fondu, contrôle niveau 14 | 143.7 | 2360 | 73.3 | 60.0 | 327 | 107 | A23 3,6 Go (pas la réf. 2 Go) |

Notes :
- F1 et F2 : démarrage faussé, le témoin de sonde n'était pas supprimé (chemin réécrit par MSYS), ces démarrages chargeaient le niveau 10. Chiffres fiables à partir de F3.
- F3 : p5 en baisse (47,4 contre 67,3) dû à l'effet mesuré, qui reconstruit le niveau toutes les 4,8 s. Démarrage +350 ms : prix de la police MSDF, qui retire 38 Mo de mémoire vidéo.
| 2026-11-01 | a706564 | Toit fondu, niveau 10 | 143.7 | 2407 | 73.3 | 55.3 | 328 | 100 | A23 3,6 Go (pas la réf. 2 Go) |
