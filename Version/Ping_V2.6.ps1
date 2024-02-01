param (
    [Parameter(Mandatory = $true)]
    [string[]] $NomsHotes,
    [string] $RepertoireLogs = "Logs",
    [int] $DelaiEntrePings = 1
)

$ping = New-Object System.Net.NetworkInformation.Ping

if (-not (Test-Path -Path $RepertoireLogs)) {
    New-Item -ItemType Directory -Path $RepertoireLogs | Out-Null
}

$donneesHotes = @{}
$nomPoste = $env:COMPUTERNAME

# Demande le numéro de dossier
$numeroDossier = Read-Host -Prompt "Entrez le numéro de dossier"

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

$fichierLog = Join-Path -Path $RepertoireLogs -ChildPath "${nomPoste}-${numeroDossier}-${nombreAleatoire}.json"

foreach ($NomHote in $NomsHotes) {
    $donneesHotes[$NomHote] = @{
        "LatenceMax" = 0
        "NombreErreurs" = 0
        "LatenceTotale" = 0
        "NombrePings" = 0
        "Resultats" = @()
        "NomPoste" = $nomPoste  # Ajoute le nom du poste au fichier JSON
        "NumeroDossier" = $numeroDossier  # Ajoute le numéro de dossier au fichier JSON
    }
}

$dureeArretSecondes = Read-Host -Prompt "Entrez la durée en secondes après laquelle le script doit s'arrêter (0 pour une exécution indéfinie)"

$heureDebut = Get-Date

while (($dureeArretSecondes -eq 0) -or ((Get-Date) - $heureDebut).TotalSeconds -lt $dureeArretSecondes) {
    foreach ($NomHote in $NomsHotes) {
        $resultat = $ping.Send($NomHote)

        $messageResultat = @{
            "Statut" = $resultat.Status.ToString()
            "Adresse" = $resultat.Address.IPAddressToString
            "TempsAllerRetour" = $resultat.RoundtripTime
            "Date" = (Get-Date -Format o)
        }

        if ($resultat.Status -eq [System.Net.NetworkInformation.IPStatus]::TimedOut) {
            $donneesHotes[$NomHote]["NombreErreurs"]++
        } else {
            $donneesHotes[$NomHote]["LatenceTotale"] += $messageResultat.TempsAllerRetour
            $donneesHotes[$NomHote]["LatenceMax"] = [Math]::Max($donneesHotes[$NomHote]["LatenceMax"], $messageResultat.TempsAllerRetour)
            $donneesHotes[$NomHote]["NombrePings"]++
        }

        if ($donneesHotes[$NomHote]["NombrePings"] -gt 0) {
            $latenceMoyenne = [Math]::Round($donneesHotes[$NomHote]["LatenceTotale"] / $donneesHotes[$NomHote]["NombrePings"])
        } else {
            $latenceMoyenne = 0
        }

        $donneesHotes[$NomHote]["LatenceMoyenne"] = $latenceMoyenne

        $donneesHotes[$NomHote]["Resultats"] += $messageResultat
    }

    $donneesHotes | ConvertTo-Json -Depth 100 | Set-Content -Path $fichierLog

    Start-Sleep -Seconds $DelaiEntrePings
}
