## ------
## -
## - Operational Security
## -
## - SafeWeb - Test du filtrage antivirus / reputation du proxy web (v.1.0)
## - Script de controle continu de la protection antivirale au niveau du proxy d'entreprise
## - Creation date :: 20/09/2026
## - Last update on :: 21/09/2026
## -
## - Principe : le script tente de telecharger, A TRAVERS LE PROXY, des fichiers de test
## - EICAR (inoffensifs) et des pages de test de reputation. Si le contenu arrive intact,
## - le proxy ne filtre pas -> ALERTE. S'il est bloque/neutralise -> protection OK.
## -
## - Le telechargement se fait EN MEMOIRE (jamais ecrit sur disque) afin que l'antivirus
## - du poste ne fausse pas le resultat : seul le proxy est evalue.
## -
## - /!\ A executer uniquement avec l'accord de la Direction Sécurité
## -
## ------
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

## --
## URLs de test de reputation / filtrage URL (pages de test publiques, inoffensives)
## --
$urlGsbMalware        = "https://testsafebrowsing.appspot.com/s/malware.html"    # Categorie "malware" (Google Safe Browsing test)
$urlGsbPhishing       = "https://testsafebrowsing.appspot.com/s/phishing.html"   # Categorie "phishing"
$urlGsbUnwanted       = "https://testsafebrowsing.appspot.com/s/unwanted.html"   # Categorie "logiciel indesirable"
$urlWicarMalware      = "https://www.wicar.org/test-malware.html"                # Page de test contenant du JavaScript malveillant simule

## --
## URLs de reference (controle de connectivite AVANT les tests)
## --
## Si aucune ne repond, le proxy est injoignable : le cycle est ignore pour eviter
## de conclure a tort que "tout est bloque".
$urlBaselineGoogle    = "https://www.google.com/generate_204"
$urlBaselineEicar     = "https://www.eicar.org/"

$baselineUrls = @(
    $urlBaselineGoogle,
    $urlBaselineEicar
)

## --
## Catalogue des tests (Enabled = $false pour desactiver un test sans le supprimer)
## CheckType : EicarText = recherche de la signature EICAR dans le contenu
##             Zip       = recherche de l'en-tete d'archive ZIP (PK)
##             Page      = page web : autorisee si HTTP 200 sans page de blocage
## --
$testUrls = @(
    [PSCustomObject]@{ Enabled = $true; Name = "EICAR HTTP .com";         Category = "Antivirus";  CheckType = "EicarText"; Url = $urlEicarHttpCom }
    [PSCustomObject]@{ Enabled = $true; Name = "EICAR HTTPS .com";        Category = "Antivirus";  CheckType = "EicarText"; Url = $urlEicarHttpsCom }
    [PSCustomObject]@{ Enabled = $true; Name = "EICAR HTTPS .txt";        Category = "Antivirus";  CheckType = "EicarText"; Url = $urlEicarHttpsTxt }
    [PSCustomObject]@{ Enabled = $true; Name = "EICAR HTTPS ZIP";         Category = "Antivirus";  CheckType = "Zip";       Url = $urlEicarHttpsZip }
    [PSCustomObject]@{ Enabled = $true; Name = "EICAR HTTPS ZIP x2";      Category = "Antivirus";  CheckType = "Zip";       Url = $urlEicarHttpsZip2 }
    [PSCustomObject]@{ Enabled = $true; Name = "Safe Browsing Malware";   Category = "Reputation"; CheckType = "Page";      Url = $urlGsbMalware }
    [PSCustomObject]@{ Enabled = $true; Name = "Safe Browsing Phishing";  Category = "Reputation"; CheckType = "Page";      Url = $urlGsbPhishing }
    [PSCustomObject]@{ Enabled = $true; Name = "Safe Browsing Unwanted";  Category = "Reputation"; CheckType = "Page";      Url = $urlGsbUnwanted }
    [PSCustomObject]@{ Enabled = $true; Name = "WICAR Malware JS";        Category = "Reputation"; CheckType = "Page";      Url = $urlWicarMalware }
)

## --
## Configuration du proxy
## --
$useProxy                   = $false                                 # $false = utiliser le proxy systeme (WinINET/PAC) ou connexion directe
$proxyAddress               = "http://proxy.entreprise.local:8080"  # Proxy explicite a tester
$proxyUseDefaultCredentials = $true                                 # $true = authentification SSO (Kerberos/NTLM) du compte courant
$proxyUser                  = "DOMAINE\svc-safeweb"                 # Utilise si $proxyUseDefaultCredentials = $false
$proxyPassword              = "Pa$$w0rd$!"                          # Utilise si $proxyUseDefaultCredentials = $false

## --
## Reconnaissance des pages de blocage du proxy
## --
## Codes HTTP consideres comme un blocage volontaire du proxy
$blockHttpCodes = @(403, 451)
## Mots-cles presents dans les pages de blocage (ajouter ceux de votre solution)
$blockPageKeywords = @(
    "Access Denied", "Access Blocked", "Web Page Blocked", "This page has been blocked",
    "Acces refuse", "Accès refusé", "bloqué", "Page bloquee",
    "Virus Detected", "Malware Detected", "Threat Detected", "Security Threat",
    "Zscaler", "Forcepoint", "Blue Coat", "Symantec Web", "Netskope",
    "FortiGuard", "Palo Alto Networks", "Sophos", "Cisco Umbrella", "Olfeo"
)

## --
## Configuration du cycle de test
## --
$intervalMinutes       = 15      # Intervalle entre chaque cycle (en minutes)
$requestTimeoutSeconds = 20      # Timeout par requete HTTP (en secondes)
$runOnce               = $false  # $true = un seul cycle puis arret (audit ponctuel / tache planifiee)
$enablePopup           = $true   # Popup d'alerte (bloquante : a desactiver en tache planifiee SYSTEM)
$userAgent             = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36 SafeWeb/1.0"

## --
## Journalisation
## --
$logFile       = ".\SafeWebLog.txt"      # Journal texte
$csvReportFile = ".\SafeWebReport.csv"   # Historique des resultats (exploitable Excel / SIEM). "" pour desactiver

## --
## Notification email
## --
$adminEmail   = "SecurityTeam@example.org"
$emailFrom    = "ScriptAuto@example.org"
$emailSubject = "[SafeWeb] ALERTE - Le proxy ne filtre pas les contenus malveillants"

## --
## Serveur SMTP
## --
## - Port 587 avec TLS (STARTTLS) : $smtpPort = 587, $smtpUseTLS = $true,  $smtpUseSSL = $false
## - Port 465 avec SSL            : $smtpPort = 465, $smtpUseTLS = $false, $smtpUseSSL = $true
## - Port 25 sans chiffrement     : $smtpPort = 25,  $smtpUseTLS = $false, $smtpUseSSL = $false
$smtpServer   = "smtp.mycompany.com"
$smtpPort     = 587
$smtpUser     = "ScriptAuto@example.org"
$smtpPassword = "Pa$$w0rd$!"
$smtpUseTLS   = $true
$smtpUseSSL   = $false
$smtpTimeout  = 30000

## --
## Modele d'email ({0} = liste des tests non bloques, {1} = date, {2} = proxy, {3} = poste)
## --
$emailTemplate = @"
Bonjour,

Le controle SafeWeb a detecte que le proxy n'a PAS bloque les contenus de test suivants :

{0}
Date   : {1}
Proxy  : {2}
Poste  : {3}

Merci de verifier le moteur antivirus du proxy, l'inspection SSL/TLS, le scan des archives
et les abonnements de reputation/categorisation URL.

Cordialement,
Le script de supervision SafeWeb
"@

##
## ============================================================================
## FIN DE LA CONFIGURATION - Ne pas modifier en dessous sauf maitrise du script
## ============================================================================
##

## --
# Signature EICAR stockee en Base64 : evite que l'antivirus du poste (ou AMSI)
# ne mette le script lui-meme en quarantaine - NE PAS MODIFIER
$eicarContent = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String(
    "WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo="))

## --
# Gestion des identifiants - NE PAS MODIFIER
$securePassword = $smtpPassword | ConvertTo-SecureString -AsPlainText -Force
$credential     = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)

$proxyCredential = $null
if ($useProxy -and -not $proxyUseDefaultCredentials) {
    $proxySecure     = $proxyPassword | ConvertTo-SecureString -AsPlainText -Force
    $proxyCredential = New-Object System.Management.Automation.PSCredential($proxyUser, $proxySecure)
}

## --
# Forcer TLS 1.2 / 1.3 (Windows PowerShell 5.1 utilise TLS 1.0 par defaut)
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

## --
## Fonction d'ecriture dans le journal
## --
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp  = Get-Date -Format "dd/MM/yyyy_HH:mm:ss"
    $logMessage = "$timestamp :: $Level :: $Message"
    Add-Content -Path $logFile -Value $logMessage
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG"   { Write-Host $logMessage -ForegroundColor DarkGray }
        default   { Write-Host $logMessage }
    }
}

## --
## Fonction d'affichage d'une popup
## --
function Show-Popup {
    param(
        [string]$Message,
        [string]$Title = "SafeWeb Alert"
    )
    if (-not $enablePopup) { return }
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Message, $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    } catch {
        Write-Log "Impossible d'afficher la popup (session non interactive ?) : $($_.Exception.Message)" "WARNING"
    }
}

## --
## Fonction d'envoi d'email avec support TLS/SSL (identique a SafeNAS)
## --
function Send-EmailNotification {
    param(
        [string]$To,
        [string]$Subject,
        [string]$Body
    )
    try {
        Write-Log "Envoi de l'email a $To" "DEBUG"
        Write-Log "Serveur SMTP : ${smtpServer}:${smtpPort} - SSL=$smtpUseSSL, TLS=$smtpUseTLS" "DEBUG"

        if ($smtpUseSSL) {
            # Port 465 : Send-MailMessage ne gere pas le SSL implicite, on passe par SmtpClient .NET
            $smtpClient             = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
            $smtpClient.EnableSsl   = $true
            $smtpClient.Timeout     = $smtpTimeout
            $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $credential.GetNetworkCredential().Password)

            $mailMessage            = New-Object System.Net.Mail.MailMessage
            $mailMessage.From       = $emailFrom
            $mailMessage.To.Add($To)
            $mailMessage.Subject    = $Subject
            $mailMessage.Body       = $Body
            $mailMessage.IsBodyHtml = $false

            $smtpClient.Send($mailMessage)
            $mailMessage.Dispose()
            $smtpClient.Dispose()
            Write-Log "Email envoye a $To via ${smtpServer}:${smtpPort} (SSL)" "SUCCESS"
            return $true
        }

        $mailParams = @{
            To         = $To
            From       = $emailFrom
            Subject    = $Subject
            Body       = $Body
            SmtpServer = $smtpServer
            Port       = $smtpPort
            Credential = $credential
            Encoding   = [System.Text.Encoding]::UTF8
        }
        if ($smtpUseTLS) {
            $mailParams.UseSsl = $true
            $mode = "TLS"
        } else {
            Write-Log "Connexion SMTP non chiffree (deconseille)" "WARNING"
            $mode = "Aucun chiffrement"
        }
        Send-MailMessage @mailParams -ErrorAction Stop
        Write-Log "Email envoye a $To via ${smtpServer}:${smtpPort} ($mode)" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Echec de l'envoi SMTP : $($_.Exception.Message)" "ERROR"
        if ($_.Exception.InnerException) {
            Write-Log "Inner exception : $($_.Exception.InnerException.Message)" "ERROR"
        }
        Write-Log "Verifier le serveur (${smtpServer}:${smtpPort}), les identifiants et les regles de flux" "INFO"
        return $false
    }
}

## --
## Construction des parametres communs Invoke-WebRequest (proxy, timeout, UA)
## --
function Get-WebRequestParams {
    param([string]$Url)
    $params = @{
        Uri             = $Url
        UseBasicParsing = $true
        TimeoutSec      = $requestTimeoutSeconds
        UserAgent       = $userAgent
        ErrorAction     = "Stop"
    }
    if ($useProxy) {
        $params.Proxy = $proxyAddress
        if ($proxyCredential) { $params.ProxyCredential = $proxyCredential }
        else                  { $params.ProxyUseDefaultCredentials = $true }
    }
    return $params
}

## --
## Controle de connectivite prealable (evite les faux "bloques")
## --
function Test-Baseline {
    foreach ($url in $baselineUrls) {
        try {
            $params = Get-WebRequestParams -Url $url
            $null = Invoke-WebRequest @params
            Write-Log "Connectivite de reference OK : $url" "DEBUG"
            return $true
        } catch {
            Write-Log "Connectivite de reference KO : $url - $($_.Exception.Message)" "WARNING"
        }
    }
    return $false
}

## --
## Execution d'un test : retourne ALLOWED (danger), BLOCKED (OK) ou INCONCLUSIVE
## --
function Invoke-ProxyTest {
    param([PSCustomObject]$Test)

    $result = [PSCustomObject]@{
        Date     = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        Name     = $Test.Name
        Category = $Test.Category
        Url      = $Test.Url
        Status   = "INCONCLUSIVE"
        Detail   = ""
    }

    try {
        $params   = Get-WebRequestParams -Url $Test.Url
        $response = Invoke-WebRequest @params

        # Lecture du contenu brut EN MEMOIRE (aucune ecriture disque)
        $bytes = $response.RawContentStream.ToArray()
        $text  = [System.Text.Encoding]::ASCII.GetString($bytes)
        $blockKeyword = $blockPageKeywords | Where-Object { $text -match [regex]::Escape($_) } | Select-Object -First 1

        switch ($Test.CheckType) {
            "EicarText" {
                if ($text.Contains($eicarContent)) {
                    $result.Status = "ALLOWED"
                    $result.Detail = "Signature EICAR recue intacte ($($bytes.Length) octets)"
                } else {
                    $result.Status = "BLOCKED"
                    $result.Detail = "Contenu remplace/neutralise" + $(if ($blockKeyword) { " (page de blocage : '$blockKeyword')" } else { "" })
                }
            }
            "Zip" {
                if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B -and $bytes[2] -eq 0x03 -and $bytes[3] -eq 0x04) {
                    $result.Status = "ALLOWED"
                    $result.Detail = "Archive ZIP recue intacte ($($bytes.Length) octets) - scan des archives inefficace"
                } else {
                    $result.Status = "BLOCKED"
                    $result.Detail = "Archive remplacee/neutralisee" + $(if ($blockKeyword) { " (page de blocage : '$blockKeyword')" } else { "" })
                }
            }
            "Page" {
                if ($blockKeyword) {
                    $result.Status = "BLOCKED"
                    $result.Detail = "Page de blocage detectee ('$blockKeyword')"
                } else {
                    $result.Status = "ALLOWED"
                    $result.Detail = "HTTP $([int]$response.StatusCode) sans page de blocage - categorie non filtree"
                }
            }
        }
    }
    catch {
        $httpCode = $null
        if ($_.Exception.Response) {
            try { $httpCode = [int]$_.Exception.Response.StatusCode } catch { }
        }

        if ($httpCode -and ($blockHttpCodes -contains $httpCode)) {
            $result.Status = "BLOCKED"
            $result.Detail = "HTTP $httpCode renvoye par le proxy"
        }
        elseif ($httpCode -eq 407) {
            $result.Detail = "HTTP 407 - echec d'authentification proxy (verifier les identifiants)"
        }
        elseif ($httpCode -eq 404 -or $httpCode -eq 410) {
            $result.Detail = "HTTP $httpCode - URL de test obsolete, a mettre a jour"
        }
        elseif ($httpCode) {
            $result.Detail = "HTTP $httpCode inattendu"
        }
        elseif ($_.Exception.Message -match "SSL|TLS|certificat|certificate|trust") {
            $result.Detail = "Erreur TLS - certificat d'inspection SSL du proxy non approuve ? ($($_.Exception.Message))"
        }
        else {
            # Connexion reinitialisee/fermee apres controle de connectivite OK : blocage probable
            $result.Status = "BLOCKED"
            $result.Detail = "Connexion interrompue par le proxy : $($_.Exception.Message)"
        }
    }

    return $result
}

##
## ============================================================================
## SCRIPT PRINCIPAL - Boucle de supervision
## ============================================================================
##

if (Test-Path $logFile) {
    Write-Log "### Debut du script de test antivirus proxy SafeWeb ###" "START"
} else {
    "### SafeWeb - Journal des tests ###" | Out-File -FilePath $logFile -Encoding UTF8
    Write-Log "### Fichier journal cree ###" "START"
}

$activeTests = @($testUrls | Where-Object { $_.Enabled })
$proxyLabel  = $(if ($useProxy) { $proxyAddress } else { "Proxy systeme / direct" })

Write-Log "Script demarre - $($activeTests.Count) test(s) actif(s) - Proxy : $proxyLabel" "START"
Write-Log "Configuration : intervalle = $intervalMinutes min, timeout = $requestTimeoutSeconds s, RunOnce = $runOnce" "INFO"

do {
    Write-Log "### Nouveau cycle de test ###" "INFO"

    if (-not (Test-Baseline)) {
        Write-Log "Aucune URL de reference joignable via $proxyLabel - cycle ignore (proxy ou reseau indisponible)" "ERROR"
    }
    else {
        $results    = @()
        $testNumber = 0

        foreach ($test in $activeTests) {
            $testNumber++
            Write-Log "Test $testNumber/$($activeTests.Count) [$($test.Category)] $($test.Name) : $($test.Url)" "INFO"

            $r = Invoke-ProxyTest -Test $test
            $results += $r

            switch ($r.Status) {
                "BLOCKED" { Write-Log "$($r.Name) : BLOQUE - $($r.Detail)" "SUCCESS" }
                "ALLOWED" { Write-Log "$($r.Name) : NON BLOQUE - $($r.Detail)" "ERROR" }
                default   { Write-Log "$($r.Name) : NON CONCLUANT - $($r.Detail)" "WARNING" }
            }
        }

        if ($csvReportFile) {
            $results | Export-Csv -Path $csvReportFile -Append -NoTypeInformation -Delimiter ";" -Encoding UTF8
        }

        $allowed      = @($results | Where-Object { $_.Status -eq "ALLOWED" })
        $blocked      = @($results | Where-Object { $_.Status -eq "BLOCKED" })
        $inconclusive = @($results | Where-Object { $_.Status -eq "INCONCLUSIVE" })

        Write-Log "Bilan : $($blocked.Count) bloque(s), $($allowed.Count) non bloque(s), $($inconclusive.Count) non concluant(s)" "INFO"

        if ($allowed.Count -gt 0) {
            $list = ($allowed | ForEach-Object { "- [$($_.Category)] $($_.Name)`r`n  URL    : $($_.Url)`r`n  Detail : $($_.Detail)`r`n" }) -join "`r`n"

            $popupMessage = "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')]`n`n$($allowed.Count) contenu(s) de test NON bloque(s) par le proxy :`n`n" +
                            (($allowed | ForEach-Object { "- $($_.Name)" }) -join "`n")
            Show-Popup -Message $popupMessage -Title "SafeWeb - Filtrage proxy INEFFICACE"

            $messageBody = [string]::Format($emailTemplate, $list, (Get-Date), $proxyLabel, $env:COMPUTERNAME)
            if (Send-EmailNotification -To $adminEmail -Subject $emailSubject -Body $messageBody) {
                Write-Log "Notification email delivree" "SUCCESS"
            } else {
                Write-Log "Notification email en echec - verifier la configuration SMTP" "ERROR"
            }
        }
        else {
            Write-Log "Aucun contenu de test n'a traverse le proxy : protection operationnelle" "SUCCESS"
        }
    }

    Write-Log "### Cycle de test termine ###" "INFO"

    if (-not $runOnce) {
        Write-Log "Attente de $intervalMinutes minute(s) avant le prochain cycle..." "INFO"
        Start-Sleep -Seconds ($intervalMinutes * 60)
    }
} while (-not $runOnce)

## --
## Fin du script
##
