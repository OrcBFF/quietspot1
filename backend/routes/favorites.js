const express = require('express');
const router = express.Router();
const db = require('../db');

// Get favorites for a user
router.get('/user/:userId', async (req, res) => {
    try {
        const [rows] = await db.execute(`
      SELECT 
        l.location_id as id,
        l.name,
        l.latitude,
        l.longitude,
        l.address as location,
        f.created_at as favoritedAt
      FROM favorites f
      JOIN locations l ON f.location_id = l.location_id
      WHERE f.user_id = ?
      ORDER BY f.created_at DESC
    `, [req.params.userId]);

        // Convert to QuietSpot format
        const spots = rows.map(row => ({
            id: row.id.toString(),
            name: row.name,
            location: row.location || `${row.latitude}, ${row.longitude}`,
            latitude: parseFloat(row.latitude),
            longitude: parseFloat(row.longitude),
            favoritedAt: row.favoritedAt
        }));

        res.json(spots);
    } catch (error) {
        console.error('Error fetching favorites:', error);
        res.status(500).json({ error: 'Failed to fetch favorites' });
    }
});

// Add favorite
router.post('/', async (req, res) => {
    try {
        const { userId, locationId } = req.body;

        if (!userId || !locationId) {
            return res.status(400).json({ error: 'userId and locationId are required' });
        }

        // Check if already favorited
        const [existing] = await db.execute(`
      SELECT * FROM favorites
      WHERE user_id = ? AND location_id = ?
    `, [userId, locationId]);

        if (existing.length > 0) {
            return res.status(409).json({ error: 'Location already favorited' });
        }

        await db.execute(`
      INSERT INTO favorites (user_id, location_id)
      VALUES (?, ?)
    `, [userId, locationId]);

        res.status(201).json({ message: 'Favorite added successfully' });
    } catch (error) {
        console.error('Error adding favorite:', error);
        res.status(500).json({ error: 'Failed to add favorite' });
    }
});

// Remove favorite
router.delete('/:userId/:locationId', async (req, res) => {
    try {
        const [result] = await db.execute(`
      DELETE FROM favorites
      WHERE user_id = ? AND location_id = ?
    `, [req.params.userId, req.params.locationId]);

        if (result.affectedRows === 0) {
            return res.status(404).json({ error: 'Favorite not found' });
        }

        res.json({ message: 'Favorite removed successfully' });
    } catch (error) {
        console.error('Error removing favorite:', error);
        res.status(500).json({ error: 'Failed to remove favorite' });
    }
});

// Check if location is favorited
router.get('/check/:userId/:locationId', async (req, res) => {
    try {
        const [rows] = await db.execute(`
      SELECT * FROM favorites
      WHERE user_id = ? AND location_id = ?
    `, [req.params.userId, req.params.locationId]);

        res.json({ isFavorited: rows.length > 0 });
    } catch (error) {
        console.error('Error checking favorite:', error);
        res.status(500).json({ error: 'Failed to check favorite' });
    }
});

module.exports = router;
