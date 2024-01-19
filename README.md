# Documentation du Script PowerShell 📄

## Description 📝
Ce script PowerShell est conçu pour effectuer des pings sur une liste d'hôtes spécifiés, enregistrer les résultats dans des fichiers logs, et envoyer les informations de synthèse à une API à la fin de l'exécution.

## Paramètres du Script 🛠️
- **$NomsHotes** (Obligatoire): Liste des noms d'hôtes à pinger.
- **$RepertoireLogs** (Optionnel): Répertoire où les logs seront enregistrés. Par défaut, il s'agit de "Logs".
- **$DelaiEntrePings** (Optionnel): Délai en secondes entre chaque ping. La valeur par défaut est 1.

## Fonctionnalités Clés 🔑
1. **Génération d'une Chaîne Aléatoire**: Le script génère une chaîne aléatoire pour identifier de manière unique chaque session de ping.
2. **Ping en Parallèle**: Les hôtes spécifiés sont pingés en parallèle pour une efficacité accrue.
3. **Enregistrement des Résultats**: Les résultats de chaque ping sont enregistrés dans un fichier log au format JSON.
4. **Envoi des Informations à l'API**: À la fin de l'exécution, le script envoie des informations récapitulatives à une API spécifiée.

## Utilisation 🚀
1. **Exécuter le Script**: Lancez le script en PowerShell en fournissant les noms d'hôtes requis.
2. **Entrer les Informations**: Le script demande le numéro de dossier et la durée d'exécution.
3. **Vérification des Résultats**: Consultez le fichier log généré dans le répertoire spécifié pour les résultats.
4. **Réponse de l'API**: À la fin de l'exécution, vérifiez la réponse de l'API pour confirmer le succès de l'envoi des données.

## Points d'Attention ⚠️
- Assurez-vous que l'URL de l'API est correctement configurée dans le script.
- Vérifiez que les hôtes spécifiés sont accessibles et peuvent répondre aux pings.

## Exemple d'Invocation 🧙‍♂️
```powershell
.\NomDuScript.ps1 -NomsHotes "host1", "host2" -RepertoireLogs "MesLogs" -DelaiEntrePings 2
