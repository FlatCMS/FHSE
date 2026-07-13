# Checklist Alain — FHSE Raspberry Pi rc3.12

Cette rc3.12 est validée uniquement si, après flash avec Raspberry Pi Imager et sans aucune commande terminal :

- `http://fhse.local:8080` ouvre le wizard FHSE.
- `http://IP_DU_RASPBERRY:8080` ouvre aussi le wizard.
- Le wizard impose un mot de passe pour le compte technique Ubuntu `admin`.
- Si l’option SSH par mot de passe est activée dans le wizard, `ssh admin@IP_DU_RASPBERRY` fonctionne avec le mot de passe choisi pendant la configuration.
- L'étape Ubuntu passe.
- L'étape aaPanel passe.
- L'étape Nginx passe.
- L'étape PHP 8.5 passe.
- L'étape site aaPanel passe.
- L'étape FlatCMS passe.
- `http://IP_DU_RASPBERRY/` ouvre FlatCMS.
- Le bouton `Administration serveur avancée` ouvre bien l’URL aaPanel directe générée en fin d’installation.
- Le rapport final contient `CHECK_FLATCMS_ROUTE=ok`.

Si un seul point échoue, ne pas transmettre l'image au blogger.
