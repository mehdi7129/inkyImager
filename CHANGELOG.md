# Changelog

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
