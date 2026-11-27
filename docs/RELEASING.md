# Préparer une release

1. Épingler le code OS, le backend et les hashes RAW/XZ de l’image générique ; ne jamais distribuer une copie de SD personnalisée.
2. Exécuter les tests Swift, packaging et, si modifiée, la maintenance ext4 sur fixtures régulières.
3. Utiliser `scripts/build-app.py` avec une destination neuve, version/build explicites et scratch APFS local disposant de place. Le script produit toujours une app Universal : chaque exécutable doit contenir `arm64` et `x86_64`. Le mode de signature par défaut est ad hoc et offline.
4. Vérifier le bundle avec `scripts/verify-app.py`, avec le hash RAW et les commits OS/backend sélectionnés indépendamment du bundle. Le contrôleur exige les deux architectures dans l’app et le helper et examine leurs liens dynamiques.
5. Pour la distribution, signer l’exécutable helper puis l’app avec Developer ID, hardened runtime et timestamp. Vérifier la signature des deux architectures de chaque exécutable. Utiliser uniquement l’identité et le profil de notarisation du propriétaire.
6. Créer un dossier contenant `inkyImager.app` et un lien symbolique `Applications` vers `/Applications`. Créer le DMG en lecture seule avec `hdiutil create -srcfolder <dossier> -format UDZO <fichier.dmg>`. Signer le DMG avec Developer ID et un horodatage.
7. Soumettre une copie du DMG signé à `notarytool`. Attendre `Accepted`, agrafer le ticket, puis vérifier le SHA-256 final, le ticket, la signature et `hdiutil verify`. Monter en lecture seule et vérifier l’inventaire, les permissions et la signature du bundle. Contrôler le DMG et l’app avec Gatekeeper.
8. Publier un brouillon GitHub et contrôler la taille et le SHA-256 du DMG transféré avant de le rendre public. Utiliser `v<version>` et `inkyImager-<version>-Universal.dmg` pour le bouton **Mise à jour**. Publier les sommes de contrôle et les commits exacts compilés, même si le tag ajoute des changements documentaires. Vérifier ensuite le téléchargement sans connexion et l’entrée `releases/latest`.

La CI teste le code mais ne signe, ne notarise, ne publie et ne flashe rien. Les credentials de signature ne sont pas requis dans GitHub Actions.
