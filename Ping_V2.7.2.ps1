﻿
param (
    [Parameter(Mandatory = $true)]
    [string[]] $NomsHotes,
    [string] $RepertoireLogs = "Logs"
)

# Créer le répertoire de logs si nécessaire
if (-not (Test-Path -Path $RepertoireLogs)) {
    New-Item -ItemType Directory -Path $RepertoireLogs | Out-Null
}

$donneesHotes = @{}
$nomPoste = $env:COMPUTERNAME

# Demande le numéro de dossier
do {
    $numeroDossier = Read-Host -Prompt "Entrez le numéro de dossier"
    if ($numeroDossier -match "^\d+$") {
        break
    } else {
        Write-Host "Le numéro de dossier doit être un nombre. Veuillez réessayer."
    }
} while ($true)

# Fonction pour générer une chaîne aléatoire
function New-RandomString {
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

$nombreAleatoire = New-RandomString -Length 6
$nombreAleatoire = $nombreAleatoire.ToUpper()
$nombreAleatoire = $nombreAleatoire -replace "_", "-"

# Création du chemin du fichier log
$fichierLog = Join-Path -Path $RepertoireLogs -ChildPath "${nomPoste}-${numeroDossier}-${nombreAleatoire}.json"

# Initialisation des données pour chaque hôte
$NomsHotesAccessibles = @()
foreach ($NomHote in $NomsHotes) {
    # Vérification de la connectivité de l'hôte
    if (Test-Connection -ComputerName $NomHote -Count 1 -Quiet) {
        $donneesHotes[$NomHote] = @{
            "LatenceMax" = 0
            "NombreErreurs" = 0
            "LatenceTotale" = 0
            "NombrePings" = 0
            "Resultats" = @()
            "NomPoste" = $nomPoste
            "NumeroDossier" = $numeroDossier
        }
        $NomsHotesAccessibles += $NomHote
    } else {
        Write-Host "L'hôte $NomHote n'est pas accessible. Il sera ignoré."
    }
}

# Demande de la durée d'exécution du script
do {
    $dureeArretSecondes = Read-Host -Prompt "Entrez la durée en secondes après laquelle le script doit s'arrêter (0 pour une exécution indéfinie)"
    if ($dureeArretSecondes -match "^\d+$" -and $dureeArretSecondes -ge 0) {
        break
    } else {
        Write-Host "La durée doit être un nombre positif ou zéro. Veuillez réessayer."
    }
} while ($true)

$heureDebut = Get-Date

# Création d'un pool de runspaces
$runspacePool = [runspacefactory]::CreateRunspacePool(1, [int]::MaxValue)
$runspacePool.Open()

# Boucle principale du script
while (($dureeArretSecondes -eq 0) -or ((Get-Date) - $heureDebut).TotalSeconds -lt $dureeArretSecondes) {
    # Lancement des pings en parallèle
    $runspaces = foreach ($NomHote in $NomsHotesAccessibles) {
        $powershell = [powershell]::Create().AddScript({
            param($NomHote)
            $heureDebutPing = Get-Date
            try {
                $ping = New-Object System.Net.NetworkInformation.Ping
                $resultat = $ping.Send($NomHote, 1000) # Ajout d'un délai d'expiration de 1000 ms
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

            $tempsEcoule = (Get-Date) - $heureDebutPing
            if ($tempsEcoule.TotalMilliseconds -lt 1000) {
                Start-Sleep -Milliseconds (1000 - $tempsEcoule.TotalMilliseconds)
            }

            # Assurez-vous que l'objet est correctement créé
            $resultatObj = New-Object PSObject -Property @{
                "Statut" = $statut
                "Adresse" = $NomHote
                "TempsAllerRetour" = $tempsAllerRetour
                "Date" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }

            return $resultatObj
        }).AddArgument($NomHote)

        $powershell.RunspacePool = $runspacePool

        # Lancement de la tâche en arrière-plan
        $handle = $powershell.BeginInvoke()
        [PSCustomObject]@{Handle = $handle; PowerShell = $powershell}
    }

    # Attente et récupération des résultats des pings
    foreach ($runspace in $runspaces) {
        $resultat = $runspace.PowerShell.EndInvoke($runspace.Handle)
        $runspace.PowerShell.Dispose()

        # Traitement des résultats
        $nomHote = $resultat.Adresse
        $donneesHote = $donneesHotes[$nomHote]

        if ($null -ne $donneesHote) {
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

            # Affichage du suivi dans la console
            $currentTime = Get-Date -Format "HH:mm:ss"
            Write-Host "Ping to $nomHote at $currentTime : $($resultat.Statut), Roundtrip Time: $($resultat.TempsAllerRetour) ms"
        }
    }

    # Sauvegarde des données dans le fichier log
    $donneesHotes | ConvertTo-Json -Depth 100 | Set-Content -Path $fichierLog

}

$runspacePool.Close()
$runspacePool.Dispose()