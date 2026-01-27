const express = require('express');
const router = express.Router();
const db = require('../db');

/**
 * QuietSpot Data Trust Policy Implementation
 * ==========================================
 * 
 * Tier 1: Fresh Data (< 60 minutes) - Use actual measurement
 * Tier 2: Confident Prediction (40+ measurements) - Advanced temporal filtering
 * Tier 3: Moderate Confidence (20-39 measurements) - Time period filtering
 * Tier 4: Limited Data (<20 measurements) - Simple average
 */

// Helper function to calculate predicted noise level based on Data Trust Policy
async function calculateNoiseLevel(locationId) {
    try {
        // Get all measurements for this location
        const [measurements] = await db.execute(`
      SELECT 
        db_value,
        measured_at,
        TIMESTAMPDIFF(MINUTE, measured_at, NOW()) as minutes_ago
      FROM noise_measurements
      WHERE location_id = ?
      ORDER BY measured_at DESC
    `, [locationId]);

        const count = measurements.length;

        // NEW CAFE - No data
        if (count === 0) {
            return {
                noiseDb: null,
                trustTier: 'NEW_CAFE',
                confidence: 'none',
                measurementCount: 0
            };
        }

        // TIER 1: Fresh Data (< 60 minutes old)
        const latestMeasurement = measurements[0];
        if (latestMeasurement.minutes_ago < 60) {
            return {
                noiseDb: parseFloat(latestMeasurement.db_value),
                trustTier: 'FRESH_DATA',
                confidence: 'highest',
                measurementCount: count,
                minutesAgo: latestMeasurement.minutes_ago
            };
        }

        // TIER 2: Confident Prediction (40+ measurements)
        if (count >= 40) {
            const prediction = await advancedTemporalPrediction(measurements);
            return {
                noiseDb: prediction,
                trustTier: 'CONFIDENT_PREDICTION',
                confidence: 'high',
                measurementCount: count
            };
        }

        // TIER 3: Moderate Confidence (20-39 measurements)
        if (count >= 20) {
            const prediction = await moderateTemporalPrediction(measurements);
            return {
                noiseDb: prediction,
                trustTier: 'MODERATE_CONFIDENCE',
                confidence: 'medium',
                measurementCount: count
            };
        }

        // TIER 4: Limited Data (<20 measurements)
        const simpleAvg = measurements.reduce((sum, m) => sum + parseFloat(m.db_value), 0) / count;
        return {
            noiseDb: simpleAvg,
            trustTier: 'LIMITED_DATA',
            confidence: 'low',
            measurementCount: count
        };

    } catch (error) {
        console.error('Error calculating noise level:', error);
        return { noiseDb: null, trustTier: 'ERROR', confidence: 'none', measurementCount: 0 };
    }
}

// Advanced temporal filtering with exponential decay (Tier 2)
async function advancedTemporalPrediction(measurements) {
    const now = new Date();
    const currentHour = now.getHours();
    const currentDay = now.getDay(); // 0=Sunday, 6=Saturday
    const isWeekend = currentDay === 0 || currentDay === 6;

    let totalWeight = 0;
    let weightedSum = 0;

    for (const m of measurements) {
        const measuredDate = new Date(m.measured_at);
        const daysAgo = (now - measuredDate) / (1000 * 60 * 60 * 24);

        // Skip measurements older than 30 days
        if (daysAgo > 30) continue;

        const measuredHour = measuredDate.getHours();
        const measuredDay = measuredDate.getDay();
        const wasWeekend = measuredDay === 0 || measuredDay === 6;

        // Time-of-day matching (within 2 hours)
        const hourDiff = Math.abs(currentHour - measuredHour);
        if (hourDiff > 2) continue;

        // Weekday vs weekend matching
        if (isWeekend !== wasWeekend) continue;

        // Exponential time decay
        let weight = Math.exp(-daysAgo / 10);

        // Recent 14 days boost (2x weight)
        if (daysAgo <= 14) {
            weight *= 2;
        }

        weightedSum += parseFloat(m.db_value) * weight;
        totalWeight += weight;
    }

    // Fallback to simple average if no matching measurements
    if (totalWeight === 0) {
        const recentMeasurements = measurements.filter(m => {
            const daysAgo = (now - new Date(m.measured_at)) / (1000 * 60 * 60 * 24);
            return daysAgo <= 30;
        });
        if (recentMeasurements.length > 0) {
            return recentMeasurements.reduce((sum, m) => sum + parseFloat(m.db_value), 0) / recentMeasurements.length;
        }
        return measurements.reduce((sum, m) => sum + parseFloat(m.db_value), 0) / measurements.length;
    }

    return weightedSum / totalWeight;
}

// Time period filtering with recency weighting (Tier 3)
async function moderateTemporalPrediction(measurements) {
    const now = new Date();
    const currentHour = now.getHours();

    let totalWeight = 0;
    let weightedSum = 0;

    for (const m of measurements) {
        const measuredDate = new Date(m.measured_at);
        const daysAgo = (now - measuredDate) / (1000 * 60 * 60 * 24);

        // Skip measurements older than 30 days
        if (daysAgo > 30) continue;

        const measuredHour = measuredDate.getHours();

        // Broader time window (within 3 hours)
        const hourDiff = Math.abs(currentHour - measuredHour);
        if (hourDiff > 3) continue;

        // Simple recency weighting
        const weight = 1 / (1 + daysAgo / 7); // Decay over weeks

        weightedSum += parseFloat(m.db_value) * weight;
        totalWeight += weight;
    }

    // Fallback to simple average if no matching measurements
    if (totalWeight === 0) {
        const recentMeasurements = measurements.filter(m => {
            const daysAgo = (now - new Date(m.measured_at)) / (1000 * 60 * 60 * 24);
            return daysAgo <= 30;
        });
        if (recentMeasurements.length > 0) {
            return recentMeasurements.reduce((sum, m) => sum + parseFloat(m.db_value), 0) / recentMeasurements.length;
        }
        return measurements.reduce((sum, m) => sum + parseFloat(m.db_value), 0) / measurements.length;
    }

    return weightedSum / totalWeight;
}

// Get all locations with predicted noise levels
router.get('/', async (req, res) => {
    try {
        const [rows] = await db.execute(`
      SELECT 
        l.location_id as id,
        l.name,
        l.latitude,
        l.longitude,
        l.address as location,
        l.created_by_user_id,
        l.created_at,
        l.last_updated,
        COUNT(nm.measurement_id) as measurement_count,
        MAX(nm.measured_at) as latest_measurement
      FROM locations l
      LEFT JOIN noise_measurements nm ON l.location_id = nm.location_id
      GROUP BY l.location_id, l.name, l.latitude, l.longitude, l.address, 
               l.created_by_user_id, l.created_at, l.last_updated
      ORDER BY l.created_at DESC
    `);

        // Calculate noise predictions for each location
        const spots = await Promise.all(rows.map(async (row) => {
            const prediction = await calculateNoiseLevel(row.id);

            return {
                id: row.id.toString(),
                name: row.name,
                location: row.location || `${row.latitude}, ${row.longitude}`,
                latitude: parseFloat(row.latitude),
                longitude: parseFloat(row.longitude),
                noiseDb: prediction.noiseDb,
                trustTier: prediction.trustTier,
                confidence: prediction.confidence,
                measurementCount: row.measurement_count,
                lastUpdated: row.latest_measurement ? row.latest_measurement.toISOString() : null,
            };
        }));

        res.json(spots);
    } catch (error) {
        console.error('Error fetching locations:', error);
        res.status(500).json({ error: 'Failed to fetch locations' });
    }
});

// Get single location by ID with prediction
router.get('/:id', async (req, res) => {
    try {
        const [rows] = await db.execute(`
      SELECT 
        location_id as id,
        name,
        latitude,
        longitude,
        address as location,
        created_by_user_id,
        created_at
      FROM locations
      WHERE location_id = ?
    `, [req.params.id]);

        if (rows.length === 0) {
            return res.status(404).json({ error: 'Location not found' });
        }

        const row = rows[0];
        const prediction = await calculateNoiseLevel(row.id);

        const spot = {
            id: row.id.toString(),
            name: row.name,
            location: row.location || `${row.latitude}, ${row.longitude}`,
            latitude: parseFloat(row.latitude),
            longitude: parseFloat(row.longitude),
            noiseDb: prediction.noiseDb,
            trustTier: prediction.trustTier,
            confidence: prediction.confidence,
            measurementCount: prediction.measurementCount,
        };

        res.json(spot);
    } catch (error) {
        console.error('Error fetching location:', error);
        res.status(500).json({ error: 'Failed to fetch location' });
    }
});

// Create new location
router.post('/', async (req, res) => {
    try {
        const { name, latitude, longitude, location, noiseDb } = req.body;

        if (!name || latitude === undefined || longitude === undefined) {
            return res.status(400).json({ error: 'Name, latitude, and longitude are required' });
        }

        // Use default user_id = NULL if not valid integer (Guest)
        let userId = req.body.userId;
        if (!Number.isInteger(userId)) {
            userId = null;
        } else {
            // Verify user exists
            const [userCheck] = await db.execute('SELECT user_id FROM users WHERE user_id = ?', [userId]);
            if (userCheck.length === 0) {
                userId = null;
            }
        }

        let newId;

        // Check for existing location within 20m
        const [existingCoords] = await db.execute(`
      SELECT location_id 
      FROM locations 
      WHERE (
        6371000 * acos(
          cos(radians(?)) * cos(radians(latitude)) *
          cos(radians(longitude) - radians(?)) +
          sin(radians(?)) * sin(radians(latitude))
        )
      ) <= 20
      LIMIT 1
    `, [latitude, longitude, latitude]);

        if (existingCoords.length > 0) {
            newId = existingCoords[0].location_id;
        } else {
            // Create NEW location
            const [result] = await db.execute(`
        INSERT INTO locations (name, latitude, longitude, address, created_by_user_id)
        VALUES (?, ?, ?, ?, ?)
      `, [name, latitude, longitude, location || '', userId]);
            newId = result.insertId;
        }

        // If noise measurement provided, add it
        if (noiseDb !== null && noiseDb !== undefined) {
            await db.execute(`
        INSERT INTO noise_measurements (location_id, user_id, db_value)
        VALUES (?, ?, ?)
      `, [newId, userId, noiseDb]);
        }

        // Fetch the location
        const [rows] = await db.execute(`
      SELECT 
        location_id as id,
        name,
        latitude,
        longitude,
        address as location,
        created_by_user_id
      FROM locations
      WHERE location_id = ?
    `, [newId]);

        const row = rows[0];
        const prediction = await calculateNoiseLevel(newId);

        const spot = {
            id: row.id.toString(),
            name: row.name,
            location: row.location || `${row.latitude}, ${row.longitude}`,
            latitude: parseFloat(row.latitude),
            longitude: parseFloat(row.longitude),
            noiseDb: prediction.noiseDb,
            trustTier: prediction.trustTier,
            confidence: prediction.confidence,
        };

        res.json(spot);
    } catch (error) {
        console.error('Error creating location:', error);
        res.status(500).json({ error: 'Failed to create location' });
    }
});

// Update location (primarily for basic info like name, description, etc.)
// NOTE: avg_db and measurements_count are computed dynamically from measurements
// and should NOT be updated directly here
router.put('/:id', async (req, res) => {
    try {
        const { name, latitude, longitude, address } = req.body;

        // Build dynamic update query (only for actual database columns)
        const updates = [];
        const values = [];

        if (name !== undefined) { updates.push('name = ?'); values.push(name); }
        if (latitude !== undefined) { updates.push('latitude = ?'); values.push(latitude); }
        if (longitude !== undefined) { updates.push('longitude = ?'); values.push(longitude); }
        if (address !== undefined) { updates.push('address = ?'); values.push(address); }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        values.push(req.params.id);

        const [result] = await db.execute(`
            UPDATE locations 
            SET ${updates.join(', ')}
            WHERE location_id = ?
        `, values);

        if (result.affectedRows === 0) {
            return res.status(404).json({ error: 'Location not found' });
        }

        // Fetch updated location with computed noise stats
        const noiseData = await calculateNoiseLevel(req.params.id);

        const [rows] = await db.execute(`
            SELECT 
                l.location_id as id,
                l.name,
                l.latitude,
                l.longitude,
                l.address as location,
                l.created_at,
                l.last_updated as updated_at
            FROM locations l
            WHERE l.location_id = ?
        `, [req.params.id]);

        // Merge database data with computed noise data
        // Convert DECIMAL values to numbers (MySQL returns them as strings)
        const locationData = {
            ...rows[0],
            latitude: parseFloat(rows[0].latitude),
            longitude: parseFloat(rows[0].longitude),
            noiseDb: noiseData.noiseDb,
            measurements_count: noiseData.measurementCount,
            trustTier: noiseData.trustTier,
            confidence: noiseData.confidence
        };

        res.json(locationData);
    } catch (error) {
        console.error('Error updating location:', error);
        res.status(500).json({ error: 'Failed to update location' });
    }
});

// Delete location
router.delete('/:id', async (req, res) => {
    try {
        const [result] = await db.execute(`
      DELETE FROM locations
      WHERE location_id = ?
    `, [req.params.id]);

        if (result.affectedRows === 0) {
            return res.status(404).json({ error: 'Location not found' });
        }

        res.json({ message: 'Location deleted successfully' });
    } catch (error) {
        console.error('Error deleting location:', error);
        res.status(500).json({ error: 'Failed to delete location' });
    }
});

module.exports = router;
