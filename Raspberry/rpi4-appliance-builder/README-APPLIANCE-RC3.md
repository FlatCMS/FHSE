# FlatCMS Home Server Edition — Raspberry Pi Appliance RC3.13

RC3.13 abandonne la dépendance exclusive à cloud-init.

La génération de l'image doit être faite depuis Linux, car RC3.13 patche directement la partition rootfs ext4 de l'image Ubuntu Raspberry Pi officielle.

Objectif produit :

- flasher l'image avec Raspberry Pi Imager ;
- brancher le SSD ou la carte SD sur le Raspberry Pi ;
- attendre quelques minutes ;
- ouvrir `http://fhse.local:8080` ;
- aucune commande utilisateur finale.

## Génération sous Linux

Depuis une VM Ubuntu, un PC Linux, ou GitHub Actions :

```bash
unzip fhse-rpi4-appliance-builder-v0.18.2-rc3.13.zip
cd fhse-rpi4-appliance-builder-v0.18.2-rc3.13
sudo ./tools/linux-build-fhse-rpi4-appliance-image.sh --download
```

Image générée :

```text
dist/fhse-rpi4-v0.18.2-rpi4.1-rc3.13-1.1.7.img
dist/fhse-rpi4-v0.18.2-rpi4.1-rc3.13-1.1.7.img.xz
```

## Validation

Après flash et boot :

```text
http://fhse.local:8080
http://IP_DU_RASPBERRY:8080
```

Accès secours technique :

```text
ssh admin@IP_DU_RASPBERRY
mot de passe : choisi dans le wizard FHSE
```

## Différence avec RC2.2

RC2.2 dépendait de cloud-init depuis la partition boot.
RC3.13 injecte directement un service systemd dans la partition rootfs :

```text
/etc/systemd/system/fhse-rootfs-firstboot.service
/usr/local/sbin/fhse-rootfs-firstboot.sh
```

Ce service prépare le compte technique `admin` en état verrouillé, laisse SSH par mot de passe désactivé par défaut, installe/active Avahi, puis démarre le wizard FHSE qui impose le choix du mot de passe technique.
