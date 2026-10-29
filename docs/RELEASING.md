# Préparer une release

1. Épingler le code OS, le backend et les hashes RAW/XZ de l’image générique ; ne jamais distribuer une copie de SD personnalisée.
2. Exécuter les tests Swift, packaging et, si modifiée, la maintenance ext4 sur fixtures régulières.
3. Utiliser `scripts/build-app.py` avec une destination neuve, version/build explicites et scratch disposant de place. Le mode par défaut est ad hoc et offline.
4. Vérifier le bundle avec `scripts/verify-app.py`, avec le hash RAW et les commits OS/backend sélectionnés indépendamment du bundle.
5. Pour la distribution, signer l’exécutable helper puis l’app avec Developer ID, hardened runtime et timestamp. Utiliser uniquement l’identité et le profil de notarisation du propriétaire.
6. Soumettre un ZIP à `notarytool`, attendre `Accepted`, agrafer le ticket sur l’app et vérifier avec `stapler validate`, `codesign --verify --deep --strict` et `spctl --assess --type execute`.
7. Recréer un ZIP **après** stapling. Extraire cette archive, comparer les fichiers/permissions et revérifier signature, ticket et Gatekeeper.
8. Mettre à jour README et changelog. Publier tag, ZIP final, SHA256SUMS et provenance sans journaux privés ni credentials. Les sources peuvent contenir des changements documentaires postérieurs au commit compilé : les identifier séparément.

La CI teste le code mais ne signe, ne notarise, ne publie et ne flashe rien. Les credentials de signature ne sont pas requis dans GitHub Actions.
