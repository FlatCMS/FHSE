# FlatCMS Home Server Edition — Raspberry Pi image rc3.10

Objectif : fournir une image prête à flasher avec Raspberry Pi Imager.

## Parcours utilisateur attendu

1. Télécharger l'image FHSE générée.
2. Ouvrir Raspberry Pi Imager.
3. Choisir le modèle Raspberry Pi.
4. Choisir `Utiliser une image personnalisée`.
5. Sélectionner `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img` ou `.img.xz`.
6. Flasher le SSD ou la carte SD.
7. Brancher le support sur le Raspberry Pi en Ethernet.
8. Attendre quelques minutes.
9. Ouvrir dans le navigateur :

```text
http://fhse.local:8080
```

Adresse de secours :

```text
http://IP_DU_RASPBERRY:8080
```

## Accès technique Ubuntu

SSH est uniquement prévu pour le support :

```text
user: admin
password: défini dans le wizard FHSE
```

Le wizard affiche ensuite les identifiants aaPanel générés pendant l'installation.

## Notes

Cette image embarque FHSE v0.18.2 sans les anciens PagesBuilder, MenuBuilder et FooterBuilder.
