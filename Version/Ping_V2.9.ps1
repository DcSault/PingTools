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