# Charger les assemblys nécessaires
Add-Type -AssemblyName System.Windows.Forms

# Créer une boîte de dialogue de sélection de fichier
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.Filter = "PowerShell Script (*.ps1)|*.ps1"

# Afficher la boîte de dialogue et obtenir le chemin du fichier sélectionné
if ($openFileDialog.ShowDialog() -eq "OK") {
    $scriptPath = $openFileDialog.FileName
}

# Création d'un certificat auto-signé
$domain = Read-Host "Entrez le nom de domaine"
$cert = New-SelfSignedCertificate -DnsName $domain -CertStoreLocation Cert:\CurrentUser\My -Type CodeSigning

# Obtenir le certificat
$cert = @(Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert)[0]

# Signature du script
Set-AuthenticodeSignature -FilePath $scriptPath -Certificate $cert