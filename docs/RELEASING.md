# Préparer une release

1. Épingler le code OS, le backend et les hashes RAW/XZ de l’image générique ; ne jamais distribuer une copie de SD personnalisée.
2. Exécuter les tests Swift, packaging et, si modifiée, la maintenance ext4 sur fixtures régulières.
3. Utiliser `scripts/build-app.py` avec une destination neuve, version/build explicites et scratch disposant de place. Le script produit toujours une app Universal : chaque exécutable doit contenir `arm64` et `x86_64`. Le mode de signature par défaut est ad hoc et offline.
4. Vérifier le bundle avec `scripts/verify-app.py`, avec le hash RAW et les commits OS/backend sélectionnés indépendamment du bundle. Le contrôleur exige les deux architectures dans l’app et le helper et examine leurs liens dynamiques.
5. Pour la distribution, signer l’exécutable helper puis l’app avec Developer ID, hardened runtime et timestamp. Utiliser uniquement l’identité et le profil de notarisation du propriétaire.
6. Créer un dossier contenant `inkyImager.app` et un lien symbolique `Applications` vers `/Applications`. Créer le DMG en lecture seule avec `hdiutil create -srcfolder <dossier> -format UDZO <fichier.dmg>`. Signer le DMG avec Developer ID et un horodatage.
7. Soumettre le DMG à `notarytool`, attendre `Accepted`, agrafer le ticket et vérifier la signature et le ticket du DMG. Monter le DMG en lecture seule, comparer les fichiers et permissions de l’app, puis vérifier sa signature avec `codesign --verify --deep --strict` et `spctl --assess --type execute`.
8. Mettre à jour le README et le changelog. Publier le tag, le DMG agrafé, son SHA-256 et sa provenance. Indiquer le commit compilé si les sources de la release contiennent des changements documentaires ultérieurs.

La CI teste le code mais ne signe, ne notarise, ne publie et ne flashe rien. Les credentials de signature ne sont pas requis dans GitHub Actions.
