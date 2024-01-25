// Fonction pour récupérer les données de suivi et mettre à jour la page
function fetchAndUpdateSuivis() {
    fetch('/api/data')
        .then(response => response.json())
        .then(suivis => {
            const suivisContainer = document.getElementById('suivis');
            suivisContainer.innerHTML = ''; // Effacer le contenu existant

            Object.keys(suivis).forEach(id => {
                const suivi = suivis[id];
                const suiviDiv = document.createElement('div');
                suiviDiv.className = 'suivi';
                suiviDiv.innerHTML = `
                    <h2>Suivi ID: ${id}</h2>
                    <p>Nom du Poste: ${suivi.NomDuPoste}</p>
                    <p>Date Début: ${suivi.DateDebut}</p>
                    <p>Date Fin Théorique: ${suivi.DateFinTheorique}</p>
                    <p>Statut: ${suivi.Statut}</p>
                `;
                suivisContainer.appendChild(suiviDiv);
            });
        })
        .catch(error => console.error('Erreur lors de la récupération des suivis:', error));
}

// Appel initial pour charger les données
fetchAndUpdateSuivis();

// Mise à jour périodique des données
setInterval(fetchAndUpdateSuivis, 5000); // Mise à jour toutes les 5 secondes, par exemple
