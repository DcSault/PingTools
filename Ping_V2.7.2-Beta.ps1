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

.PARAMETER NumeroDossier
    Le numéro de dossier à utiliser pour les fichiers de logs. Ce paramètre est facultatif.

.PARAMETER DureeArretSecondes
    La durée en secondes après laquelle le script doit s'arrêter. Par défaut, le script s'exécute indéfiniment.

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


# SIG # Begin signature block
# MIIFYQYJKoZIhvcNAQcCoIIFUjCCBU4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0Y5Zi2j5VU5X8+a7FIrPPzhH
# X5WgggMGMIIDAjCCAeqgAwIBAgIQTKtr6ON9MoZCMpLCwj+cCjANBgkqhkiG9w0B
# AQsFADAQMQ4wDAYDVQQDDAVuZXlsaTAeFw0yNDAxMzAxNTQxMDdaFw0yNTAxMzAx
# NjAxMDdaMBAxDjAMBgNVBAMMBW5leWxpMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEA1CSbXRxi+q3mU0kC1amVnfOOjBKpbY+dDn+fTD/ndbqLxzkLPSYb
# wI6Dx/WQZy0Pp8tr+AJGGWKUrYZwVV8OVvvtp7Ji4VOwc9hvx9JIYdoM+LUEBtKO
# zKaT+z01TxzayKw7MbWJAdskFYK1IzARyMkHpnMok/BQ1A2MHD1zAWgvJkCxXDrB
# KK+snLBPCQ8vtFQF0QDx+457O3AL4AOziMCxUwHP9BKAI++jw7bdkEdvttgm803E
# FIKEiOYuuW2o4RSdm6E0LlAl1fu0R01FwcS1bcNGYWuwO1HA3DgSVkljTymCP9/4
# sgUnIqGZkJFA8g1ElL93yMzCluPDXj35EQIDAQABo1gwVjAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEAYDVR0RBAkwB4IFbmV5bGkwHQYDVR0O
# BBYEFPbtH1eAdvytXuxs4uwKkfOez6ZJMA0GCSqGSIb3DQEBCwUAA4IBAQB9eJsz
# eNNMyhw9UcmavnqhngwbR9VPw0z4Vn7RO9Owsd1Y1g+GMtmbl0L9+Y4iqY3R/SfO
# ODNCe5hmWjFPGGXgcy7Df13bGKqQ9RGHs/HKHgS47rwwFpHidWcapsYWBHtqvOuZ
# H6E5+U0ZsOcLpYWohwJKjH6Xgv2NgcZm2ewDXnIUXrbVUaNoKX36rD2CN5ZXpN9n
# 7fVt3I68h8LZc99o/RC4AY1dye5zkR4m+IGurOvITOkPgcrC8De2+ZlxYBL4V5/I
# MHLCMfm3EdjBjYL/8JYtRQN3VwmbpGYED1DPHhMp248QulXDkdJL1AxVMDDHcjTD
# gP4P50DRyU7blpGvMYIBxTCCAcECAQEwJDAQMQ4wDAYDVQQDDAVuZXlsaQIQTKtr
# 6ON9MoZCMpLCwj+cCjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU00qlWLdxlVXtc30JlzKPQqKv
# diwwDQYJKoZIhvcNAQEBBQAEggEAyYRr5GZTrpDpBMeN/FK1ZblXirr+8Mg+8BBX
# vRk6Jcd1FpL0t9bQXbSWuA6mbt6SQtboiS7sC7HS4CuWfwNti8yaydUfDUU3fv45
# adK37Lnj0MmpqOYCTqbIK7E/FWv/cMobjKRetKxb191Ckfkx3dXywPsyy5Jiyb6J
# Qt49oKyJ4nr3ohJfkFohVkkkYbXZlIS39tF7OoFp44rFIaqpR6lfbDy80JG+y49a
# HZ3nradGCRkN5rbLe0ZAhDvUloxE4DZuiFWNKZFfRxmFXdPwYW+VFAwdYeAwwZB7
# bS0zFhaNAYagjffno1rDrGCYcTxLKjyxnpzcvAMfWbBx4dei+Q==
# SIG # End signature block
