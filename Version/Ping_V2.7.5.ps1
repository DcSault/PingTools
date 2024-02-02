<#
.SYNOPSIS
Script de ping pour tester la connectivité des hôtes spécifiés.

.DESCRIPTION
Ce script permet de tester la connectivité des hôtes spécifiés en effectuant des pings en parallèle. Les résultats des pings sont enregistrés dans un fichier log au format JSON. Le script prend en compte la durée d'exécution souhaitée et génère un numéro de dossier aléatoire pour chaque exécution.

.PARAMETER NomsHotes
Les noms des hôtes à tester. Il peut s'agir d'une ou plusieurs adresses IP ou noms de domaine.

.PARAMETER NumeroDossier
Le numéro du dossier à traiter. C'est une valeur entière.

.PARAMETER DureeArretSecondes
La durée de l'arrêt en secondes. C'est une valeur entière qui représente le nombre de secondes pendant lesquelles le script doit être arrêté.

.PARAMETER RepertoireLogs
Le répertoire dans lequel les fichiers logs seront enregistrés. Par défaut, il s'agit du répertoire "Logs" situé dans le répertoire du script.

.NOTES
Auteur : V.ROSIQUE
Version : 2.7.5
Date : 2024-02-02
#>

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
            try {
                $tempsDebut = Measure-Command {
                    $ping = New-Object System.Net.NetworkInformation.Ping
                    $resultat = $ping.Send($NomHote, 1000)
                    $ping.Dispose() # Éliminer l'objet Ping après utilisation
                }
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
    
            $tempsRestant = [math]::Round(1 - $tempsDebut.TotalSeconds, 2)
            if ($tempsRestant -gt 0) {
                Start-Sleep -Seconds $tempsRestant 
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

        # Traitement des résultats
        $nomHote = $resultat.Adresse
        $donneesHote = $donneesHotes[$nomHote]

        if ($null -ne $donneesHote) {

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
            
            # Suppression des variables temporaires
            Remove-Variable -Name nomHote
            Remove-Variable -Name donneesHote
        }

        # Nettoyage du runspace
        $runspace.PowerShell.Dispose()
        Remove-Variable -Name runspace

        # Suppression du résultat du ping de la mémoire
        Remove-Variable -Name resultat
    }

    # Sauvegarde des données dans le fichier log
    $donneesHotes | ConvertTo-Json -Depth 100 | Set-Content -Path $fichierLog
}

# Suppression des données des hôtes de la mémoire
$donneesHotes.Clear()

$runspacePool.Close()
$runspacePool.Dispose()