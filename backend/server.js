const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/locations', require('./routes/locations'));
app.use('/api/measurements', require('./routes/measurements'));
app.use('/api/favorites', require('./routes/favorites'));
app.use('/api/users', require('./routes/users'));
app.use('/api/auth', require('./routes/auth'));

// Health check
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', message: 'QuietSpot API is running on TiDB Cloud' });
});

// Start server - listen on 0.0.0.0 to allow connections from network
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 QuietSpot API server running on port ${PORT}`);
    console.log(`📡 API endpoints available at /api`);
    console.log(`☁️  Connected to TiDB Cloud database`);
});
