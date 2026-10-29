# inkyImager

Application macOS native pour installer [InkyOS](https://github.com/mehdi7129/inkyOS)
sur une carte SD et préparer le Wi-Fi d’un cadre photo e-paper
[Inky Studio](https://github.com/mehdi7129/inky-studio).

Le parcours : **Wi-Fi saisi sur le Mac → carte SD vérifiée → démarrage du Pi →
QR scanné sur l’iPhone → photo affichée sur le cadre**.

## Utiliser l’app

1. Saisir le nom et le mot de passe du Wi-Fi **2,4 GHz**.
2. Insérer la SD, sélectionner la carte puis cliquer sur **Flasher la carte**.
   Cette installation neuve efface la carte sélectionnée.
3. Autoriser l’accès macOS aux volumes amovibles et l’écriture de la carte.
4. Après vérification et éjection, insérer la SD dans le Pi éteint, puis l’allumer.
5. Scanner le QR affiché avec Inky Studio sur un iPhone connecté au même Wi-Fi.

L’app assemblée contient l’image InkyOS et utilise uniquement les bibliothèques
système macOS : aucun Python, Homebrew ou environnement Linux à installer pour
ce parcours. La configuration Wi-Fi est ajoutée dans une image temporaire privée.
Le Pi l’importe au premier démarrage puis supprime le fichier transitoire de sa
partition de démarrage. Aucun mot de passe Wi-Fi n’est placé dans les arguments
de commande ou les journaux.

## État au 29 octobre 2026

Le cadre de référence de Mehdi a reçu le service de partage
`716104b130d34d1973001e78f15e25989d4c2e76` par une maintenance conservant les
photos, accès, identité et Wi-Fi. Le partage QR entre deux iPhone a fonctionné
du premier coup ; Mehdi rapporte ensuite plusieurs jours sans bug avec Inky
Studio. Ce retour utilisateur concerne cette installation existante.

Une **candidate locale inkyImager 0.1.2 (3)** est en préparation avec une image
générique vierge intégrant directement ce service. Elle réutilise le parcours
Wi-Fi sur le Mac puis QR sur l'iPhone. Les artefacts préparés ne constituent
pas encore un téléchargement public signé et notarisé, ni une nouvelle
qualification physique de toutes les installations.

Le périmètre reste **macOS 14+ sur Apple Silicon**, le **Pi Zero 2 W**, le profil
**Inky Impression 7,3 pouces / 800 × 480 / AC073**, la France et un réseau
**WPA2 sur 2,4 GHz**. Ne pas extrapoler ce résultat aux autres dalles ou réseaux.

Le dépôt publie les sources. La signature Developer ID avec horodatage Apple,
la notarisation, le stapling et la publication sont des étapes de livraison
séparées. Le packaging par défaut reste local et ad-hoc, sans appel Apple.

## Compiler

Prérequis de développement : Xcode avec Swift 6, Python 3.9+ pour le packaging,
et les en-têtes liblzma de `xz`. Leur chemin Apple Silicon est actuellement
fixé à `/opt/homebrew/opt/xz/include` dans [Package.swift](Package.swift).
Les exécutables produits utilisent la liblzma système de macOS.

```sh
swift build -c release

python3 scripts/build-app.py \
  --image /chemin/InkyOS.img.xz \
  --manifest /chemin/InkyOS.json \
  --destination /chemin/de/sortie/inkyImager.app \
  --scratch-path /chemin/de/build/sur/disque/externe \
  --app-version 0.1.2 --build-number 3
```

L’image générique et son manifeste vérifiés proviennent du
[profil d’assemblage InkyOS](https://github.com/mehdi7129/inkyOS/tree/main/inkyImager/OS).
Le script exige une destination neuve, vérifie les hashes, assemble l’app avec
son image et appose une signature locale. Compiler ou packager ne flashe pas de SD.

`--jobs` limite le nombre de compilations simultanées (2 par défaut). Les
caches et fichiers temporaires du packaging sont placés sous `--scratch-path`.
L'icône existante est versionnée dans `Resources/AppIcon.icns` et copiée telle
quelle ; sa régénération Swift n'est pas nécessaire à chaque packaging.
L'option `--sign-identity` prépare une signature Developer ID ; elle exige
`--timestamp`, qui autorise explicitement l'appel au service d'horodatage
Apple. Aucune notarisation ou publication n'est effectuée par ce script.

Le [contrôleur du paquet](scripts/verify-app.py) vérifie la version, la signature,
les liens système et la ressource XZ, puis décompresse celle-ci en mémoire par
blocs pour comparer la taille et le SHA du RAW à un pin de release indépendant.
Ses tests utilisent de vraies archives XZ synthétiques corrompues/tronquées :

```sh
python3 -I -B -m unittest discover -s scripts/tests -v
```


## Tester

```sh
swift test
python3 -I -B -m unittest discover -s maintenance/tests -p 'test_*.py' -v
```

Les tests Swift couvrent notamment la sélection des supports, les hashes,
la décompression, les erreurs système et les plages d’écriture. Le test FAT
optionnel nécessite `INKY_IMAGER_FAT_FIXTURE` pointant vers une image régulière
de test ; il ne doit jamais cibler un périphérique.

Au nouveau chemin du dépôt, la suite Swift compte **30 tests réussis** et un
test FAT optionnel non exécuté. Les **14 tests natifs de maintenance** en font
partie. Les **12 tests de l’éditeur ext4** passent
sur fixtures, dont de vraies images ext4 de 32 MiB. Ces derniers utilisent les
outils e2fsprogs épinglés décrits dans le [guide de maintenance](maintenance/README.md).
Ils ne constituent pas une mise à jour déjà effectuée sur le cadre.

## Maintenance d’une carte existante

Le bouton **Flasher la carte** sert à une installation neuve. La maintenance
conservant photos, identité, accès et Wi-Fi suit un parcours séparé : sauvegarde
complète, préparation sur une copie ext4, vérification des données conservées,
puis écriture de la seule partition système et relecture.

Les outils sont `inkyMaintenance` et les scripts de [maintenance/](maintenance/).
Ils sont destinés à une opération accompagnée ; les requêtes et pins sont
établis depuis la carte réellement détectée. Consulter le
[guide](maintenance/README.md) avant toute opération. La maintenance du cadre de référence a été effectuée le 25 octobre ;
elle ne remplace pas une image générique distribuable pour un nouvel utilisateur.

## Écosystème

| Dépôt | Responsabilité |
|---|---|
| **inkyImager** | App Mac, accès SD natif, packaging et outils de maintenance. |
| [InkyOS](https://github.com/mehdi7129/inkyOS) | Image Raspberry Pi, premier démarrage, réseau et intégration système. |
| [Inky Studio](https://github.com/mehdi7129/inky-studio) | Backend du cadre et app iOS. |

Les images, copies de SD, photos, identités, credentials et diagnostics réels
restent hors du dépôt. Les fixtures sont synthétiques.
