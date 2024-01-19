const express = require('express');
const app = express();
app.use(express.json()); // Permet à Express de traiter le JSON.

const PORT = 3000;

// Route POST pour recevoir les données
app.post('/api/data', (req, res) => {
    console.log('Données reçues:', req.body);

    // Envoi d'une réponse indiquant le succès
    res.status(200).json({ Status: "Success", Message: "Données reçues avec succès" });
});

// Démarrage du serveur
app.listen(PORT, () => {
    console.log(`Serveur démarré sur le port ${PORT}`);
});
