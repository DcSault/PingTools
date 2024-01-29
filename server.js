const express = require('express');
const fs = require('fs-extra');
const app = express();
const PORT = 3000;

app.set('view engine', 'ejs');
app.use(express.json());
app.use(express.static('public'));

let suivis = fs.readJsonSync('data.json', { throws: false }) || {};

// Route pour l'interface utilisateur
app.get('/', (req, res) => {
    res.render('index', { suivis });
});

// Route API pour recevoir et traiter les données
app.post('/api/data', (req, res) => {
    const { ChaineAleatoire, NomDuPoste, DateDebut, DateFinTheorique, DateFinReelle, Statut } = req.body;

    if (!suivis[ChaineAleatoire]) {
        suivis[ChaineAleatoire] = { NomDuPoste, DateDebut, DateFinTheorique, Statut: 'En Cours' };
    } else {
        suivis[ChaineAleatoire].DateFinReelle = DateFinReelle;
        suivis[ChaineAleatoire].Statut = Statut || 'Échec';
    }

    fs.writeJsonSync('data.json', suivis);

    res.status(200).json({ Status: "Success", Message: "Requête traitée avec succès" });
});

// Vérification périodique
setInterval(() => {
    const maintenant = new Date();
    Object.keys(suivis).forEach(id => {
        if (suivis[id].Statut === 'En Cours' && new Date(suivis[id].DateFinTheorique) < maintenant) {
            suivis[id].Statut = 'Échec';
        }
    });
    fs.writeJsonSync('data.json', suivis);
}, 60000);

app.listen(PORT, () => {
    console.log(`Serveur démarré sur le port ${PORT}`);
});
