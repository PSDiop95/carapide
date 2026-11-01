# Journal de performance CARAPIDE

Release, installation neuve, 1er lancement (cache froid) pour FPS, RAM et draw calls. Seuils : APK ≤ 150 Mo (alerte 120), démarrage < 5 s, p50 ≥ 55, p5 ≥ 30, RAM < 350 Mo, draw calls < 120.

| Date | Commit | Fonctionnalité | APK (Mo) | Démarrage interactif (ms, médiane de 5) | FPS p50 | FPS p5 | RAM pic (Mo) | Draw calls pic | Appareil |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-11-01 | bd8a965+ | Ligne de base avant F1, 3D à 100 % (rouge) | 143.6 | 1930 | 47.4 | 40.0 | 361 | 111 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | bd8a965+ | Ligne de base avant F1, 3D à 75 % | 143.6 | 1930 | 73.3 | 59.6 | 342 | 111 | A23 3,6 Go (pas la réf. 2 Go) |
| 2026-11-01 | 2eff557+ | F1 Dioulé | 143.6 | 1873 | 72.0 | 56.5 | 347 | 114 | A23 3,6 Go (pas la réf. 2 Go) |
