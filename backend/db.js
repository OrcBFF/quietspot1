const mysql = require('mysql2/promise');
require('dotenv').config();

// Create connection pool for TiDB Cloud
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'quietspot',
    port: process.env.DB_PORT || 4000,
    ssl: {
        minVersion: 'TLSv1.2',
        rejectUnauthorized: true
    },
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0
});

// Test connection
pool.getConnection()
    .then(connection => {
        console.log('✅ Connected to TiDB Cloud database');
        connection.release();
    })
    .catch(err => {
        console.error('❌ Database connection error:', err.message);
        console.log('💡 Make sure TiDB Cloud credentials are correct in .env file');
    });

module.exports = pool;
