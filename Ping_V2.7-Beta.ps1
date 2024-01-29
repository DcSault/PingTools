<#
.SYNOPSIS
    Script de ping pour tester la connectivité des hôtes spécifiés.

.DESCRIPTION
    Ce script effectue des pings vers les hôtes spécifiés et enregistre les résultats dans un fichier JSON.
    Il mesure la latence maximale, le nombre d'erreurs, la latence totale, le nombre de pings et la latence moyenne pour chaque hôte.

.PARAMETER NomsHotes
    Les noms des hôtes à pinger. Ce paramètre est obligatoire.

.PARAMETER RepertoireLogs
    Le répertoire dans lequel les fichiers de logs seront enregistrés. Par défaut, il s'agit du répertoire "Logs" dans le répertoire courant.

.PARAMETER DelaiEntrePings
    Le délai en secondes entre chaque ping. Par défaut, il est de 1 seconde.

.EXAMPLE
    # Pinger google.com et microsoft.com avec un délai de 1 seconde entre les pings
    # Sauvegarder les fichiers journaux dans le répertoire "C:\Logs"
    # Utiliser le numéro de dossier "12345"
    # Arrêter le script après 1 heure (3600 secondes)
    .\Ping_V2.7-Beta.ps1 -NomsHotes "google.com", "microsoft.com" -RepertoireLogs "C:\Logs" -DelaiEntrePings 1 -NumeroDossier "12345" -DureeArretSecondes 3600
     
.NOTES
    Version : 2.7 - Beta
    Auteur : V.ROSIQUE
    Date : 01/01/2022
#>
param (
    [Parameter(Mandatory = $true)]
    [string[]] $NomsHotes,
    [string] $RepertoireLogs = "Logs",
    [int] $DelaiEntrePings = 1
)

if (-not (Test-Path -Path $RepertoireLogs)) {
    New-Item -ItemType Directory -Path $RepertoireLogs | Out-Null
}

$donneesHotes = @{}
$nomPoste = $env:COMPUTERNAME
$numeroDossier = Read-Host -Prompt "Entrez le numéro de dossier"

function Generate-RandomString {
    param (
        [int] $Length
    )
    
    return [System.Guid]::NewGuid().ToString("N").Substring(0, $Length).ToUpper()
}

$nombreAleatoire = Generate-RandomString -Length 6
$nombreAleatoire = $nombreAleatoire -replace "_", "-"

$fichierLog = Join-Path -Path $RepertoireLogs -ChildPath "${nomPoste}-${numeroDossier}-${nombreAleatoire}.json"

$donneesHotes = New-Object 'System.Collections.Generic.Dictionary[string,psobject]'

foreach ($NomHote in $NomsHotes) {
    $donneesHotes[$NomHote] = [PSCustomObject]@{
        "LatenceMax" = 0
        "NombreErreurs" = 0
        "LatenceTotale" = 0
        "NombrePings" = 0
        "Resultats" = New-Object 'System.Collections.Generic.List[psobject]'
        "NomPoste" = $nomPoste
        "NumeroDossier" = $numeroDossier
        "LatenceMoyenne" = 0
    }
}

$dureeArretSecondes = Read-Host -Prompt "Entrez la durée en secondes après laquelle le script doit s'arrêter (0 pour une exécution indéfinie)"

$heureDebut = Get-Date

while (($dureeArretSecondes -eq 0) -or ((Get-Date) - $heureDebut).TotalSeconds -lt $dureeArretSecondes) {
    foreach ($NomHote in $NomsHotes) {
        try {
            $resultat = Test-Connection -ComputerName $NomHote -Count 1 -ErrorAction Stop
            $statut = "Success"
            $tempsAllerRetour = $resultat.ResponseTime
        } catch {
            $statut = "Failed"
            $tempsAllerRetour = 0
            Write-Host "Erreur lors de la connexion à $NomHote : $_"
        }

        $resultatPing = [PSCustomObject]@{
            "Statut" = $statut
            "Adresse" = $NomHote
            "TempsAllerRetour" = $tempsAllerRetour
            "Date" = (Get-Date -Format o)
        }

        $donneesHote = $donneesHotes[$NomHote]
        $donneesHote.Resultats.Add($resultatPing)

        if ($statut -eq "Success") {
            $donneesHote.LatenceTotale += $tempsAllerRetour
            $donneesHote.LatenceMax = [Math]::Max($donneesHote.LatenceMax, $tempsAllerRetour)
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

    $donneesHotes.Values | ConvertTo-Json -Depth 100 | Set-Content -Path $fichierLog

    Start-Sleep -Seconds $DelaiEntrePings
}