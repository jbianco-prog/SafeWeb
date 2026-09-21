
##
## ============================================================================
## CONFIGURATION - Modifier ces variables pour adapter le script
## ============================================================================
##

## --
## URLs de test EICAR (source officielle : https://www.eicar.org)
## --
## Chaque variante teste une capacite differente du moteur antivirus du proxy
$urlEicarHttpCom      = "http://www.eicar.org/download/eicar.com"   # HTTP clair (peut etre redirige vers HTTPS par eicar.org)
$urlEicarHttpsCom     = "https://secure.eicar.org/eicar.com"        # HTTPS - necessite l'inspection SSL/TLS du proxy
$urlEicarHttpsTxt     = "https://secure.eicar.org/eicar.com.txt"    # HTTPS - extension .txt (contournement par extension)
$urlEicarHttpsZip     = "https://secure.eicar.org/eicar_com.zip"    # HTTPS - archive ZIP 1 niveau
$urlEicarHttpsZip2    = "https://secure.eicar.org/eicarcom2.zip"    # HTTPS - archive ZIP imbriquee 2 niveaux (scan recursif)
