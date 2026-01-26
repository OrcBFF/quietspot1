const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all measurements for a location
router.get('/location/:locationId', async (req, res) => {
    try {
        const [rows] = await db.execute(`
      SELECT 
        measurement_id as id,
        location_id as spotId,
        user_id as userId,
        db_value as noiseDb,
        measured_at as timestamp
      FROM noise_measurements
      WHERE location_id = ?
      ORDER BY measured_at DESC
    `, [req.params.locationId]);

        res.json(rows);
    } catch (error) {
        console.error('Error fetching measurements:', error);
        res.status(500).json({ error: 'Failed to fetch measurements' });
    }
});

// Create new measurement
router.post('/', async (req, res) => {
    try {
        const { locationId, userId, noiseDb } = req.body;

        if (!locationId || noiseDb === undefined) {
            return res.status(400).json({ error: 'locationId and noiseDb are required' });
        }

        // Use default user_id = NULL if not valid integer (Guest)
        let finalUserId = userId;
        if (!Number.isInteger(finalUserId)) {
            finalUserId = null;
        } else if (finalUserId) {
            // Verify user exists
            const [userCheck] = await db.execute('SELECT user_id FROM users WHERE user_id = ?', [finalUserId]);
            if (userCheck.length === 0) {
                finalUserId = null;
            }
        }

        const [result] = await db.execute(`
      INSERT INTO noise_measurements (location_id, user_id, db_value)
      VALUES (?, ?, ?)
    `, [locationId, finalUserId, noiseDb]);

        // Fetch the created measurement
        const [rows] = await db.execute(`
      SELECT 
        measurement_id as id,
        location_id as spotId,
        user_id as userId,
        db_value as noiseDb,
        measured_at as timestamp
      FROM noise_measurements
      WHERE measurement_id = ?
    `, [result.insertId]);

        res.status(201).json(rows[0]);
    } catch (error) {
        console.error('Error creating measurement:', error);
        res.status(500).json({ error: 'Failed to create measurement' });
    }
});

// Get measurements for validation (nearby locations)
router.get('/nearby', async (req, res) => {
    try {
        const { latitude, longitude, radiusMeters = 100 } = req.query;

        if (!latitude || !longitude) {
            return res.status(400).json({ error: 'latitude and longitude are required' });
        }

        // Get nearby locations and their average measurements
        const [rows] = await db.execute(`
      SELECT 
        l.location_id,
        l.latitude,
        l.longitude,
        AVG(nm.db_value) as avgDb,
        COUNT(nm.measurement_id) as measurementCount
      FROM locations l
      LEFT JOIN noise_measurements nm ON l.location_id = nm.location_id
      WHERE (
        6371000 * acos(
          cos(radians(?)) * cos(radians(l.latitude)) *
          cos(radians(l.longitude) - radians(?)) +
          sin(radians(?)) * sin(radians(l.latitude))
        )
      ) <= ?
      GROUP BY l.location_id, l.latitude, l.longitude
      HAVING measurementCount > 0
    `, [latitude, longitude, latitude, radiusMeters]);

        res.json(rows);
    } catch (error) {
        console.error('Error fetching nearby measurements:', error);
        res.status(500).json({ error: 'Failed to fetch nearby measurements' });
    }
});

module.exports = router;
