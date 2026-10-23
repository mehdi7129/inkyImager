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

## État au 23 octobre 2026

La version locale **0.1.1** a permis le flash, le démarrage jusqu’au QR et le
parcours photo avec Inky Studio iOS 16, confirmés sur le cadre de test.
Le profil initial vise **macOS 14+ sur Apple Silicon**, le **Pi Zero 2 W**,
la France et un réseau **WPA2 sur 2,4 GHz**. Les autres matériels et profils
réseau ne sont pas qualifiés par cet essai.

Inky Studio iOS **17** est distribué en interne sur TestFlight. Le partage
d’accès PHOTOS par QR entre iPhone exige aussi la mise à jour du service du
cadre : le backend installé reste `b75bf1e7…` et le candidat `716104b1…` est
préparé, **pas encore appliqué à la SD de test**.

Ce dépôt publie les sources. L’app 0.1.1 a été assemblée et signée localement ;
la distribution publique d’un binaire notarisé reste à préparer. L’image OS et
son manifeste sont fournis au packaging, sans être stockés dans Git.

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
  --destination /chemin/de/sortie/inkyImager.app
```

L’image générique et son manifeste vérifiés proviennent du
[profil d’assemblage InkyOS](https://github.com/mehdi7129/inkyOS/tree/main/inkyImager/OS).
Le script exige une destination neuve, vérifie les hashes, assemble l’app avec
son image et appose une signature locale. Compiler ou packager ne flashe pas de SD.

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
[guide](maintenance/README.md) avant toute opération. La maintenance réelle du
backend de partage reste en attente de la SD.

## Écosystème

| Dépôt | Responsabilité |
|---|---|
| **inkyImager** | App Mac, accès SD natif, packaging et outils de maintenance. |
| [InkyOS](https://github.com/mehdi7129/inkyOS) | Image Raspberry Pi, premier démarrage, réseau et intégration système. |
| [Inky Studio](https://github.com/mehdi7129/inky-studio) | Backend du cadre et app iOS. |

Les images, copies de SD, photos, identités, credentials et diagnostics réels
restent hors du dépôt. Les fixtures sont synthétiques.
