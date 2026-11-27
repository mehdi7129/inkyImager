# inkyImager

Application macOS pour installer [InkyOS](https://github.com/mehdi7129/inkyOS)
sur une carte SD et préparer le Wi-Fi d’un cadre photo e-paper. Au premier
démarrage du Raspberry Pi, scannez le QR affiché avec
[Inky Studio](https://github.com/mehdi7129/inky-studio) sur votre iPhone.

[![Tests macOS](https://github.com/mehdi7129/inkyImager/actions/workflows/tests.yml/badge.svg)](https://github.com/mehdi7129/inkyImager/actions/workflows/tests.yml)

## Télécharger

**[Télécharger inkyImager 0.1.5 pour Mac (.dmg)](https://github.com/mehdi7129/inkyImager/releases/download/v0.1.5/inkyImager-0.1.5-Universal.dmg)**

macOS **14 ou ultérieur**, sur **Intel et Apple Silicon**. Ouvrez le DMG signé
et notarisé, puis glissez **inkyImager.app** dans **Applications**. L’app inclut
[InkyOS 2026.11.27-rc3](https://github.com/mehdi7129/inkyOS/releases/tag/2026.11.27-rc3)
et s’utilise sans Homebrew ni compte développeur Apple.

Le bouton **Mise à jour** ouvre le téléchargement de la dernière version stable
sur GitHub. Glissez la nouvelle app dans **Applications** pour remplacer
l’ancienne. Le bouton reste indisponible pendant une opération SD.

## Préparer une carte

1. Prévoyez environ **6 Go libres sur le Mac** et renseignez le Wi-Fi **2,4 GHz**.
2. Insérez la SD dans le lecteur interne ou USB. Choisissez-la dans la liste, puis
   cliquez sur **Flasher la carte**.
3. Vérifiez le nom, l’identifiant disque et la capacité dans la confirmation.
   **Le flash efface tout le contenu du support sélectionné.**
4. Autorisez l’accès macOS à la carte. Attendez la fin de la relecture et
   l’éjection, puis insérez la SD dans le Raspberry Pi éteint.
5. Allumez le cadre et scannez son QR dans Inky Studio sur un iPhone connecté au
   même réseau. L’invitation initiale expire après cinq minutes. Si elle expire
   avant le premier appairage, redémarrez le cadre pour obtenir un nouveau QR.

L’app choisit la première langue compatible des préférences de macOS, avec le
français comme repli. Elle transmet la langue à InkyOS au flash, pour que les
instructions autour du QR s’affichent dans la même langue. Langues disponibles
dans l’app et à l’écran du cadre : arabe, allemand, anglais, espagnol, français,
italien, japonais, coréen, portugais, chinois simplifié et chinois traditionnel.

Le Wi-Fi est préparé dans un espace temporaire privé. Au premier démarrage,
InkyOS enregistre le profil localement, puis retire le fichier de configuration
transitoire de la partition de démarrage.

## Écrans compatibles

La détection repose sur l’EEPROM et le pilote Pimoroni `inky` 2.6.0. Les essais
logiciels couvrent les Impression 4″, 5,7″ et 7,3″, les Spectra 6 4″, 7,3″ et
13,3″, ainsi que les pHAT et wHAT. Le premier démarrage de cette image sur carte,
le rafraîchissement e-paper et la lecture optique restent à vérifier sur matériel.

Les **Inky Frame à Pico intégré** suivent le parcours firmware UF2 de Pimoroni.
Les anciens écrans sans EEPROM exploitable demandent une configuration spécifique.
Consultez la [matrice InkyOS](https://github.com/mehdi7129/inkyOS/blob/main/docs/DISPLAY-COMPATIBILITY.md)
pour les résolutions et variantes couvertes.

## Compiler et tester

Installez Xcode avec Swift 6, Python 3.9+ et les en-têtes liblzma (`brew install xz`).
Le package détecte Homebrew sur Intel et Apple Silicon. Utilisez `INKY_XZ_INCLUDE`
si vos en-têtes sont installés ailleurs.

```sh
swift build -c release
swift test
python3 -I -B -m unittest discover -s scripts/tests -v
```

Pour assembler l’app Universal avec son image, récupérez `InkyOS.img.xz` et
`InkyOS.json` dans la même release InkyOS. Prévoyez une destination neuve et de la
place pour les deux builds dans le répertoire de travail.

```sh
python3 scripts/build-app.py \
  --image /chemin/InkyOS.img.xz \
  --manifest /chemin/InkyOS.json \
  --destination /chemin/de/sortie/inkyImager.app \
  --scratch-path /chemin/de/sortie/build \
  --app-version 0.1.5 --build-number 8
```

Le script assemble l’app et son helper pour `arm64` et `x86_64`. Le
[vérificateur](scripts/verify-app.py) contrôle leurs architectures, leurs
signatures et les hashes de l’image. Les tests FAT optionnels utilisent une
image synthétique via `INKY_IMAGER_FAT_FIXTURE`. Le guide de
[maintenance](maintenance/README.md) décrit le parcours séparé pour conserver
les photos, l’identité et les accès d’une carte existante.

- [Changelog](CHANGELOG.md)
- [Guide de release](docs/RELEASING.md)
- [Composants et distribution](docs/DISTRIBUTION.md)
- [Signaler un problème](https://github.com/mehdi7129/inkyImager/issues)

Le code d’inkyImager est sous [licence MIT](LICENSE). InkyOS, Inky Studio et les
composants tiers embarqués conservent leurs propres licences et notices.
