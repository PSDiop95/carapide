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
