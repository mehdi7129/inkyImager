# Distribution et composants

Le DMG officiel contient l’app macOS Universal (Intel `x86_64` et
Apple Silicon `arm64`, macOS 14+) et un raccourci vers Applications.
L’app embarque une image générique InkyOS compressée.
Le helper embarqué contient lui aussi les deux architectures.
L’app utilise les bibliothèques système de macOS, dont liblzma. Les en-têtes
xz nécessaires à la compilation ne sont pas une dépendance à installer pour
utiliser l’app.

L’image contient Raspberry Pi OS, ses paquets et Inky Studio. Les notices des
paquets sont conservées dans `/usr/share/doc` de l’image ; chaque composant
conserve sa licence. Les sources et informations amont Raspberry Pi OS sont
accessibles sur https://www.raspberrypi.com/software/operating-systems/ et
https://github.com/RPi-Distro ; les sources InkyOS et Inky Studio sont liées dans
le README. Le fait que les dépôts soient publics n’attribue pas une nouvelle
licence aux composants tiers ou aux sources du projet.

Les sauvegardes SD, profils Wi-Fi, clés, photos et diagnostics réels ne sont
jamais des assets de release. L’outil de maintenance accompagné est distinct
du bouton de flash neuf ; aucun paquet de mise à jour personnalisé n’est publié.
