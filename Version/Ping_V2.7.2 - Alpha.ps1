﻿
param (
    [Parameter(Mandatory = $true)]
    [string[]] $NomsHotes,
    [string] $RepertoireLogs = "Logs",
    [int] $DelaiEntrePings = 1
)

$scriptPath = $MyInvocation.MyCommand.Path
$currentVersion = $scriptPath -replace '.*_V', '' -replace '\.ps1', ''
Write-Host "Version actuelle du script : $currentVersion"

# Vérifier les mises à jour disponibles sur GitHub
$latestReleaseUrl = "https://api.github.com/repos/DcSault/PingTools/releases/latest"
$latestRelease = Invoke-RestMethod -Uri $latestReleaseUrl
$latestVersion = $latestRelease.tag_name

if ($latestVersion -gt $currentVersion) {
    Write-Host "Une nouvelle version ($latestVersion) est disponible."
    $userChoice = Read-Host -Prompt "Voulez-vous mettre à jour votre script ? (O/N)"
    if ($userChoice -eq "O") {
        $updatedScriptUrl = "https://github.com/DcSault/PingTools/releases/download/V$latestVersion/Ping_V$latestVersion.ps1"
        $updatedScriptPath = $scriptPath -replace $currentVersion, $latestVersion
        Invoke-WebRequest -Uri $updatedScriptUrl -OutFile $updatedScriptPath
        Write-Host "Le script a été mis à jour avec succès."
        return
    }
}

# Créer le répertoire de logs si nécessaire
if (-not (Test-Path -Path $RepertoireLogs)) {
    New-Item -ItemType Directory -Path $RepertoireLogs | Out-Null
}

$donneesHotes = @{}
$nomPoste = $env:COMPUTERNAME

# Demande le numéro de dossier
$numeroDossier = Read-Host -Prompt "Entrez le numéro de dossier"

# Fonction pour générer une chaîne aléatoire
function Generate-RandomString {
    param (
        [int] $Length
    )
    
    $characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $randomString = ""
    
    for ($i = 1; $i -le $Length; $i++) {
        $randomIndex = Get-Random -Minimum 0 -Maximum $characters.Length
        $randomChar = $characters[$randomIndex]
        $randomString += $randomChar
    }
    
    return $randomString
}

$nombreAleatoire = Generate-RandomString -Length 6
$nombreAleatoire = $nombreAleatoire.ToUpper()
$nombreAleatoire = $nombreAleatoire -replace "_", "-"

# Création du chemin du fichier log
$fichierLog = Join-Path -Path $RepertoireLogs -ChildPath "${nomPoste}-${numeroDossier}-${nombreAleatoire}.json"

# Initialisation des données pour chaque hôte
foreach ($NomHote in $NomsHotes) {
    $donneesHotes[$NomHote] = @{
        "LatenceMax" = 0
        "NombreErreurs" = 0
        "LatenceTotale" = 0
        "NombrePings" = 0
        "Resultats" = @()
        "NomPoste" = $nomPoste
        "NumeroDossier" = $numeroDossier
    }
}

# Demande de la durée d'exécution du script
$dureeArretSecondes = Read-Host -Prompt "Entrez la durée en secondes après laquelle le script doit s'arrêter (0 pour une exécution indéfinie)"

$heureDebut = Get-Date

# Boucle principale du script
while (($dureeArretSecondes -eq 0) -or ((Get-Date) - $heureDebut).TotalSeconds -lt $dureeArretSecondes) {
    # Lancement des pings en parallèle
    foreach ($NomHote in $NomsHotes) {
        Start-Job -ScriptBlock {
            param($NomHote)
            try {
                $ping = New-Object System.Net.NetworkInformation.Ping
                $resultat = $ping.Send($NomHote)
                if ($resultat.Status -eq "Success") {
                    $statut = "Success"
                    $tempsAllerRetour = $resultat.RoundtripTime
                } else {
                    $statut = "Failed"
                    $tempsAllerRetour = 0
                }
            } catch {
                $statut = "Failed"
                $tempsAllerRetour = 0
            }

            @{
                "Statut" = $statut
                "Adresse" = $NomHote
                "TempsAllerRetour" = $tempsAllerRetour
                "Date" = (Get-Date -Format o)
            }
        } -ArgumentList $NomHote
    }

    # Attente et récupération des résultats des pings
    $jobs = Get-Job
    $jobs | Wait-Job
    $resultats = $jobs | Receive-Job

    # Traitement des résultats
    foreach ($resultat in $resultats) {
        $nomHote = $resultat.Adresse
        $donneesHote = $donneesHotes[$nomHote]
        $donneesHote.Resultats += $resultat

        if ($resultat.Statut -eq "Success") {
            $donneesHote.LatenceTotale += $resultat.TempsAllerRetour
            $donneesHote.LatenceMax = [Math]::Max($donneesHote.LatenceMax, $resultat.TempsAllerRetour)
            $donneesHote.NombrePings++
        } else {
            $donneesHote.NombreErreurs++
        }

        if ($donneesHote.NombrePings -gt 0) {
            $donneesHote.LatenceMoyenne = [Math]::Round($donneesHote.LatenceTotale / $donneesHote.NombrePings)
        } else {
            $donneesHote.LatenceMoyenne = 0
        }
    }

    # Nettoyage des jobs
    $jobs | Remove-Job

    # Sauvegarde des données dans le fichier log
    $donneesHotes | ConvertTo-Json -Depth 100 | Set-Content -Path $fichierLog

    # Pause entre les itérations
    Start-Sleep -Seconds $DelaiEntrePings
}
