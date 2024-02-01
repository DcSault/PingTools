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
    $NomsHotes | ForEach-Object {
        $NomHote = $_

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

