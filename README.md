# inkyImager

Application macOS native pour installer [InkyOS](https://github.com/mehdi7129/inkyOS)
sur une carte SD et préparer le Wi-Fi d’un cadre photo e-paper
[Inky Studio](https://github.com/mehdi7129/inky-studio).

Le parcours : **Wi-Fi saisi sur le Mac → carte SD vérifiée → démarrage du Pi →
QR scanné sur l’iPhone → photo affichée sur le cadre**.

[![Tests macOS](https://github.com/mehdi7129/inkyImager/actions/workflows/tests.yml/badge.svg)](https://github.com/mehdi7129/inkyImager/actions/workflows/tests.yml)

## Télécharger

**[Télécharger inkyImager 0.1.3 Universal pour Mac Intel et Apple Silicon](https://github.com/mehdi7129/inkyImager/releases/download/v0.1.3/inkyImager-0.1.3-UNIVERSAL-NOTARIZED.zip)**

macOS **14 ou ultérieur**, Mac **Intel et Apple Silicon** (Universal `x86_64` + `arm64`). Décompresser le ZIP,
puis déplacer **inkyImager.app** dans Applications. L’app est signée Developer
ID, notarisée par Apple et contient son ticket agrafé. Aucun compte Apple de
développement, Python ou Homebrew n’est nécessaire pour l’utiliser.

Le ZIP contient l’image [InkyOS 2026.10.29-rc1](https://github.com/mehdi7129/inkyOS/releases/tag/2026.10.29-rc1).
Les hashes SHA-256 et la provenance sont joints à la release.

## Utiliser l’app

Prévoir environ **6 Go libres sur le Mac** pour le téléchargement, l’app et la
préparation. Le fichier RAW temporaire est créé dans le cache privé du Mac ;
l’app exige sa taille (environ 3,06 Go) plus 1 Gio de réserve avant de commencer.


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

## Version Universal — 14 novembre 2026

**inkyImager 0.1.3 (4)** contient les architectures `arm64` et `x86_64` dans
l’app et son helper. L’image InkyOS embarquée reste identique à celle de 0.1.2.
Les tests Swift natifs couvrent Apple Silicon et Intel dans GitHub Actions.
La compatibilité annoncée commence à macOS 14 ; aucun essai de flash sur un
Mac Intel physique n’est revendiqué.

## Validation du cadre et de l’image — 29 octobre 2026

Le cadre de référence de Mehdi a reçu le service de partage
`716104b130d34d1973001e78f15e25989d4c2e76` par une maintenance conservant les
photos, accès, identité et Wi-Fi. Le partage QR entre deux iPhone a fonctionné
du premier coup ; Mehdi rapporte ensuite plusieurs jours sans bug avec Inky
Studio. Ce retour utilisateur concerne cette installation existante.

**inkyImager 0.1.2 (3)** intègre une image générique vierge avec le service de
partage QR. La signature, l’horodatage, la notarisation, le ticket agrafé et
Gatekeeper ont été vérifiés, y compris après extraction du ZIP. L’interface
signée a été ouverte et contrôlée sans lancer de flash.

Le périmètre reste **macOS 14+ sur Apple Silicon**, **Pi Zero 2 W**, profil
**Inky Impression 7,3 pouces / 800 × 480 / AC073**, France et réseau
**WPA2 sur 2,4 GHz**. L’image embarquée est une **release candidate** : son
premier démarrage sur une nouvelle carte n’a pas encore été observé. Les
retours d’usage du cadre existant et les tests logiciels restent distincts.

Consulter le [changelog](CHANGELOG.md), le [guide de release](docs/RELEASING.md)
et les [informations de distribution](docs/DISTRIBUTION.md).

## Compiler

Prérequis de développement : Xcode avec Swift 6, Python 3.9+ pour le packaging,
et les en-têtes liblzma de `xz` (`brew install xz`). [Package.swift](Package.swift)
les détecte dans `/opt/homebrew/opt/xz/include` ou `/usr/local/opt/xz/include`.
Pour une installation personnalisée, définir `INKY_XZ_INCLUDE`.
Les exécutables produits utilisent la liblzma système de macOS.

```sh
swift build -c release

python3 scripts/build-app.py \
  --image /chemin/InkyOS.img.xz \
  --manifest /chemin/InkyOS.json \
  --destination /chemin/de/sortie/inkyImager.app \
  --scratch-path /chemin/de/build/sur/disque/externe \
  --app-version 0.1.3 --build-number 4
```

Le packaging compile explicitement `arm64` et `x86_64`, puis assemble les deux
architectures avec `lipo` pour l’app et son helper avant signature. Un simple
`swift build` reste natif pour le Mac de développement.

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
les deux architectures de chaque exécutable, les liens système et la ressource XZ, puis décompresse celle-ci en mémoire par
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

La recette locale du 29 octobre couvre **31 tests Swift réussis**, dont les
**14 tests natifs de maintenance** et le test FAT avec une véritable image
synthétique. Les **7 tests de packaging** vérifient les archives XZ et l'accord
explicite nécessaire avant une demande d'horodatage Apple. Les tests de
l'éditeur ext4 sont distincts et utilisent les outils e2fsprogs décrits dans le
[guide de maintenance](maintenance/README.md). Les fixtures ne constituent pas
un essai sur une carte physique ni une qualification de tous les matériels.

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
