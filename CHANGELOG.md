# Changelog

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
