const express = require('express');
const router = express.Router();
const db = require('../db');

// Signup endpoint - creates user and auto-verifies (no email verification needed)
router.post('/signup', async (req, res) => {
    try {
        const { username, email, password } = req.body;

        if (!username || !email || !password) {
            return res.status(400).json({ error: 'Username, email, and password are required' });
        }

        // Check if email already exists
        const [existingEmail] = await db.execute(
            'SELECT user_id FROM users WHERE email = ?',
            [email]
        );
        if (existingEmail.length > 0) {
            return res.status(409).json({ error: 'Email already registered' });
        }

        // Check if username already exists
        const [existingUsername] = await db.execute(
            'SELECT user_id FROM users WHERE username = ?',
            [username]
        );
        if (existingUsername.length > 0) {
            return res.status(409).json({ error: 'Username already taken' });
        }

        // Create user (plaintext password as per your policy)
        const [result] = await db.execute(`
            INSERT INTO users (username, email, password)
            VALUES (?, ?, ?)
        `, [username, email, password]);

        // Get the created user
        const [rows] = await db.execute(`
            SELECT user_id as id, username, email FROM users WHERE user_id = ?
        `, [result.insertId]);

        const user = rows[0];
        console.log(`✅ User created and auto-verified: ${username} (${email})`);

        // Return user info for immediate login
        res.status(201).json({
            id: user.id,
            username: user.username,
            email: user.email
        });

    } catch (error) {
        console.error('Signup error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Login endpoint
router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password are required' });
        }

        // Query user by username
        const [rows] = await db.execute(`
      SELECT user_id as id, username, email, password
      FROM users
      WHERE username = ?
    `, [username]);

        if (rows.length === 0) {
            return res.status(401).json({ error: 'Invalid username or password' });
        }

        const user = rows[0];

        // Check password (PLAINTEXT as per your policy)
        if (user.password !== password) {
            return res.status(401).json({ error: 'Invalid username or password' });
        }

        // Return user info (excluding password)
        res.json({
            id: user.id,
            username: user.username,
            email: user.email
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Change Password endpoint
router.post('/change-password', async (req, res) => {
    try {
        const { userId, oldPassword, newPassword } = req.body;

        if (!userId || !oldPassword || !newPassword) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // Get current password
        const [rows] = await db.execute(`
            SELECT password FROM users WHERE user_id = ?
        `, [userId]);

        if (rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const user = rows[0];

        // Verify old password
        if (user.password !== oldPassword) {
            return res.status(401).json({ error: 'Incorrect old password' });
        }

        // Update password
        await db.execute(`
            UPDATE users SET password = ? WHERE user_id = ?
        `, [newPassword, userId]);

        res.json({ message: 'Password updated successfully' });

    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
