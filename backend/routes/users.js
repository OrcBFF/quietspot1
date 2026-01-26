const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all users
router.get('/', async (req, res) => {
    try {
        const [rows] = await db.execute(`
      SELECT user_id as id, username, email, created_at
      FROM users
      ORDER BY created_at DESC
    `);

        res.json(rows);
    } catch (error) {
        console.error('Error fetching users:', error);
        res.status(500).json({ error: 'Failed to fetch users' });
    }
});

// Get single user
router.get('/:id', async (req, res) => {
    try {
        const [rows] = await db.execute(`
      SELECT user_id as id, username, email, created_at
      FROM users
      WHERE user_id = ?
    `, [req.params.id]);

        if (rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json(rows[0]);
    } catch (error) {
        console.error('Error fetching user:', error);
        res.status(500).json({ error: 'Failed to fetch user' });
    }
});

// Delete user (as per userDeletion.txt policy)
router.delete('/:id', async (req, res) => {
    try {
        const userId = req.params.id;

        // Check if user exists
        const [check] = await db.execute('SELECT user_id FROM users WHERE user_id = ?', [userId]);
        if (check.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Delete user (CASCADE constraints will handle related data)
        await db.execute('DELETE FROM users WHERE user_id = ?', [userId]);

        res.json({ message: 'User deleted successfully' });
    } catch (error) {
        console.error('Error deleting user:', error);
        res.status(500).json({ error: 'Failed to delete user' });
    }
});

// Get user stats
router.get('/:id/stats', async (req, res) => {
    try {
        const userId = req.params.id;

        // Get measurements count
        const [measurements] = await db.execute(`
      SELECT COUNT(*) as count FROM noise_measurements WHERE user_id = ?
    `, [userId]);

        // Get spots count
        const [spots] = await db.execute(`
      SELECT COUNT(*) as count FROM locations WHERE created_by_user_id = ?
    `, [userId]);

        res.json({
            measurements: measurements[0].count,
            spots: spots[0].count,
        });
    } catch (error) {
        console.error('Error fetching user stats:', error);
        res.status(500).json({ error: 'Failed to fetch user stats' });
    }
});

module.exports = router;
