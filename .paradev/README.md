# Workspaces Paradev

Le setup cible macOS 14+ sur Apple Silicon ou Intel,
Xcode avec Swift 6+ et Python 3.9+. Il vérifie les prérequis, installe `xz`
via Homebrew si ses headers sont absents, puis lance `swift package resolve`.
Les headers sont détectés dans `/opt/homebrew/opt/xz/include` (Apple Silicon)
ou `/usr/local/opt/xz/include` (Intel). Un chemin personnalisé peut être fourni
avec `INKY_XZ_INCLUDE`.
Les compilations restent à la demande : `swift build` et `swift test`.

Le projet n'a ni dev server, ni base de données, ni conteneur à lancer :
`run` est absent et `teardown` est vide. Homebrew est partagé par les workspaces
et ses packages sont conservés à leur suppression.

Le setup ne nécessite aucun `.env`. Le packaging nécessite une image InkyOS
et son manifeste fournis explicitement à `scripts/build-app.py` (voir le
README principal). Les tests Python ext4 demandent les outils e2fsprogs
épinglés décrits dans `maintenance/README.md` ; ils ne sont pas installés
automatiquement par le setup.
