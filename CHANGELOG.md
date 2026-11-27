# Changelog

## 0.1.5 (9) — 2026-11-27

- Onze langues pour l’app macOS et les instructions autour du QR du cadre, selon les préférences de langue du Mac au moment du flash.
- Chargement du chinois simplifié et traditionnel même quand SwiftPM change la casse des dossiers de ressources.
- Sélection explicite du support et confirmation d’effacement avec nom, identifiant BSD et capacité exacte. Une modification des supports entraîne une nouvelle sélection.
- Nettoyage au lancement des espaces de flash abandonnés reconnus, avec protection des sessions encore actives.
- InkyOS 2026.11.27-rc3 et backend PHOTO 0.5.0rc4. La capsule Wi-Fi est retirée après enregistrement durable. Le premier QR a une échéance fixe de cinq minutes.
- Contrôle strict de la signature des deux architectures dans l’app et le helper. Distribution par DMG Universal pour macOS 14 et ultérieur.

Les 49 tests Swift et 13 tests de packaging ont réussi. Le mainteneur a ensuite confirmé le fonctionnement sur deux écrans Spectra, dont un grand format, et un Inky Impression.

## 0.1.4 — 2026-11-20

- Bouton **Mise à jour** pour vérifier GitHub et télécharger le DMG stable Universal, hors opération SD.
- Image InkyOS 2026.11.20-rc2 avec détection des Impression, Spectra 6, pHAT et wHAT équipés d’une EEPROM prise en charge.
- Écran d’accueil adapté aux petits panneaux, au même format QR PHOTO qu’avant pour Inky Studio.

Les nouveaux écrans et leur lecture du QR ont été évalués en logiciel. La lecture optique et le premier démarrage physique restent à qualifier.

## 0.1.3 — 2026-11-14

- App et helper Universal : compilation explicite pour Intel (`x86_64`) et Apple Silicon (`arm64`), puis assemblage avant signature.
- Détection des headers xz sur les deux architectures et option `INKY_XZ_INCLUDE` pour les installations personnalisées.
- Vérificateur refusant un exécutable mono-architecture ou une dépendance Homebrew dans une des architectures.
- CI Swift native Intel ajoutée ; setup Paradev compatible avec les deux familles de Mac.
- Image InkyOS 2026.10.29-rc1 inchangée, macOS minimum 14.0.

Aucun essai de flash sur un Mac Intel physique n’est annoncé.

## 0.1.2 — 2026-10-29

- Première release GitHub avec ZIP Apple Silicon signé Developer ID, horodaté, notarisé et agrafé.
- Image InkyOS générique 2026.10.29-rc1 embarquée, service de partage QR iPhone → iPhone intégré.
- Parcours de préparation Wi-Fi sur le Mac, écriture et relecture de la SD ; bibliothèques système uniquement au runtime.
- Packaging contrôlé : destination neuve, pins des images, caches externes possibles et concurrence limitée.
- Icône existante versionnée pour éviter sa régénération à chaque packaging.
- Vérificateur du bundle, provenance et décompression XZ bornée avec comparaison du RAW à un hash indépendant.
- Éditeur de maintenance : lecture brute des ACL POSIX pour préserver leur encodage et détecter leurs changements.
- CI macOS pour Swift, packaging et maintenance ; aucune écriture de support physique.

Validation locale : 31 tests Swift dont une fixture FAT réelle, 7 tests de packaging ; les tests ext4 sont séparés. Aucun premier boot physique de cette nouvelle image générique n’est annoncé.

## 0.1.1 — historique, 2026-10-23

Correction de l’accès natif à la SD via authopen. Installation, premier démarrage et QR confirmés sur le cadre de référence. Cette version n’avait pas de release GitHub.
