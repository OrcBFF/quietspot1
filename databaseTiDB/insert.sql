CREATE DATABASE quietspot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE quietspot;

-- QuietSpot Schema Setup for TiDB Cloud
-- INSTRUCTIONS:
-- 1. First, select database 'quietspot' from the dropdown in TiDB SQL Editor
--    (If it doesn't exist, create it in TiDB Cloud console first)
-- 2. Then paste and run this entire file

-- Create all tables
-- Drop tables if they exist (for clean reinstall)
DROP TABLE IF EXISTS favorites;
DROP TABLE IF EXISTS noise_measurements;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS users;

-- Users table
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Locations table (cafeterias)
CREATE TABLE locations (
    location_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    address TEXT,
    created_by_user_id BIGINT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_location_creator 
        FOREIGN KEY (created_by_user_id) 
        REFERENCES users(user_id)
        ON DELETE SET NULL,
    
    INDEX idx_coordinates (latitude, longitude),
    INDEX idx_created_by (created_by_user_id),
    INDEX idx_last_updated (last_updated)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Noise measurements table
CREATE TABLE noise_measurements (
    measurement_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    location_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    db_value DECIMAL(5, 2) NOT NULL,
    measured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_measurement_location 
        FOREIGN KEY (location_id) 
        REFERENCES locations(location_id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_measurement_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(user_id)
        ON DELETE CASCADE,
    
    CONSTRAINT chk_db_value 
        CHECK (db_value >= 0 AND db_value <= 200),
    
    INDEX idx_location_time (location_id, measured_at),
    INDEX idx_user_measurements (user_id, measured_at),
    INDEX idx_measured_at (measured_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Favorites table
CREATE TABLE favorites (
    user_id BIGINT NOT NULL,
    location_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (user_id, location_id),
    
    CONSTRAINT fk_favorite_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(user_id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_favorite_location 
        FOREIGN KEY (location_id) 
        REFERENCES locations(location_id)
        ON DELETE CASCADE,
    
    INDEX idx_location_favorites (location_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Views for analytics
CREATE VIEW location_stats AS
SELECT 
    l.location_id,
    l.name,
    l.latitude,
    l.longitude,
    l.address,
    l.created_at,
    l.last_updated,
    COUNT(nm.measurement_id) AS measurement_count,
    AVG(nm.db_value) AS avg_noise_level,
    MIN(nm.db_value) AS min_noise_level,
    MAX(nm.db_value) AS max_noise_level,
    MAX(nm.measured_at) AS latest_measurement_time
FROM locations l
LEFT JOIN noise_measurements nm ON l.location_id = nm.location_id
GROUP BY l.location_id, l.name, l.latitude, l.longitude, l.address, l.created_at, l.last_updated;

CREATE VIEW recent_measurements AS
SELECT 
    nm.*,
    l.name AS location_name,
    u.username
FROM noise_measurements nm
JOIN locations l ON nm.location_id = l.location_id
JOIN users u ON nm.user_id = u.user_id
WHERE nm.measured_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY nm.measured_at DESC;

-- Verification
SELECT 'Schema created successfully!' AS status;
SHOW TABLES;

-- QuietSpot Minimal Demo Data
-- Demonstrates Data Trust Policy with Strategic Measurements
-- Copy and paste this ENTIRE file into TiDB SQL Editor

-- Step 1: Insert 10 Users
INSERT INTO users (username, email, password, created_at) VALUES
('Alice_123', 'alice@test.com', 'pass1', '2025-12-01 10:00:00'),
('Bob_456', 'bob@test.com', 'pass2', '2025-12-05 11:30:00'),
('Carol_789', 'carol@test.com', 'pass3', '2025-12-10 14:20:00'),
('David_321', 'david@test.com', 'pass4', '2025-12-15 16:45:00'),
('Eve_654', 'eve@test.com', 'pass5', '2025-12-20 09:15:00'),
('Frank_987', 'frank@test.com', 'pass6', '2026-01-01 12:00:00'),
('Grace_147', 'grace@test.com', 'pass7', '2026-01-05 13:30:00'),
('Henry_258', 'henry@test.com', 'pass8', '2026-01-10 15:00:00'),
('Iris_369', 'iris@test.com', 'pass9', '2026-01-15 10:30:00'),
('Jack_741', 'jack@test.com', 'pass10', '2026-01-20 11:45:00');

-- Step 2: Insert 10 Cafes (from OpenStreetMap)
INSERT INTO locations (name, latitude, longitude, address, created_by_user_id, created_at) VALUES
('Starbucks', 37.975789, 23.7521193, 'Μιχαλακοπούλου 27, Athens', 1, '2025-12-01 10:00:00'),
('Maroco Cafe', 37.9874641, 23.7575969, 'Αλεξάνδρας 197, Athens', 2, '2025-12-05 11:00:00'),
('Coffee Stand', 37.9902251, 23.7339231, 'Μπουμπουλίνας 46, Athens', 3, '2025-12-10 12:00:00'),
('Veranda', 37.980178, 23.7441196, 'Athens Street, Athens', 4, '2025-12-15 13:00:00'),
('Μελίνα', 37.9733184, 23.7286656, 'Λυσίου 22, Athens', 5, '2025-12-20 14:00:00'),
('Κλεψύδρα', 37.9735505, 23.7266576, 'Θρασυβούλου 9, Athens', 6, '2026-01-01 15:00:00'),
('Λώρας', 37.9827503, 23.7561675, 'Δημητρίου Σούτσου 7, Athens', 7, '2026-01-05 16:00:00'),
('Mokka', 37.9808198, 23.7273601, 'Αθηνάς 44, Athens', 8, '2026-01-10 17:00:00'),
('Cusco cafe', 37.9846607, 23.7343611, 'Κωλέττη 8, Athens', 9, '2026-01-15 18:00:00'),
('Il Toto', 37.9920167, 23.7268136, 'Ιουλιανού 60, Athens', 10, '2026-01-20 19:00:00');

-- Step 3: Insert Noise Measurements (Demonstrating Data Trust Policy)

-- ==================================================
-- TIER 4: Limited Data (< 20 measurements)
-- ==================================================

-- Location 1 (Starbucks): 5 measurements - LIMITED DATA
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
(1, 1, 68.5, '2026-01-20 09:00:00'),
(1, 2, 72.0, '2026-01-21 10:30:00'),
(1, 3, 65.5, '2026-01-22 14:00:00'),
(1, 4, 70.0, '2026-01-23 16:00:00'),
(1, 5, 67.5, '2026-01-24 11:00:00');

-- Location 2 (Maroco Cafe): 15 measurements - LIMITED DATA
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
(2, 1, 55.0, '2026-01-10 08:00:00'),
(2, 2, 58.5, '2026-01-11 09:00:00'),
(2, 3, 52.0, '2026-01-12 10:00:00'),
(2, 4, 60.0, '2026-01-13 11:00:00'),
(2, 5, 57.5, '2026-01-14 12:00:00'),
(2, 6, 54.0, '2026-01-15 13:00:00'),
(2, 7, 59.0, '2026-01-16 14:00:00'),
(2, 8, 56.5, '2026-01-17 15:00:00'),
(2, 9, 53.0, '2026-01-18 16:00:00'),
(2, 10, 61.0, '2026-01-19 17:00:00'),
(2, 1, 55.5, '2026-01-20 08:30:00'),
(2, 2, 58.0, '2026-01-21 09:30:00'),
(2, 3, 54.5, '2026-01-22 10:30:00'),
(2, 4, 59.5, '2026-01-23 11:30:00'),
(2, 5, 56.0, '2026-01-24 12:30:00');

-- ==================================================
-- TIER 3: Moderate Confidence (20-39 measurements)
-- ==================================================

-- Location 3 (Coffee Stand): 25 measurements - MODERATE CONFIDENCE
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
(3, 1, 75.0, '2026-01-01 08:00:00'),
(3, 2, 78.5, '2026-01-02 09:00:00'),
(3, 3, 72.0, '2026-01-03 10:00:00'),
(3, 4, 76.5, '2026-01-04 11:00:00'),
(3, 5, 74.0, '2026-01-05 12:00:00'),
(3, 6, 79.0, '2026-01-06 13:00:00'),
(3, 7, 73.5, '2026-01-07 14:00:00'),
(3, 8, 77.0, '2026-01-08 15:00:00'),
(3, 9, 71.5, '2026-01-09 16:00:00'),
(3, 10, 80.0, '2026-01-10 17:00:00'),
(3, 1, 75.5, '2026-01-11 08:30:00'),
(3, 2, 78.0, '2026-01-12 09:30:00'),
(3, 3, 72.5, '2026-01-13 10:30:00'),
(3, 4, 76.0, '2026-01-14 11:30:00'),
(3, 5, 74.5, '2026-01-15 12:30:00'),
(3, 6, 79.5, '2026-01-16 13:30:00'),
(3, 7, 73.0, '2026-01-17 14:30:00'),
(3, 8, 77.5, '2026-01-18 15:30:00'),
(3, 9, 71.0, '2026-01-19 16:30:00'),
(3, 10, 80.5, '2026-01-20 17:30:00'),
(3, 1, 75.0, '2026-01-21 08:00:00'),
(3, 2, 78.0, '2026-01-22 09:00:00'),
(3, 3, 72.0, '2026-01-23 10:00:00'),
(3, 4, 76.0, '2026-01-24 11:00:00'),
(3, 5, 74.0, '2026-01-25 12:00:00');

-- Location 4 (Veranda): 30 measurements - MODERATE CONFIDENCE
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
(4, 1, 45.0, '2025-12-27 08:00:00'),
(4, 2, 48.5, '2025-12-28 09:00:00'),
(4, 3, 42.0, '2025-12-29 10:00:00'),
(4, 4, 46.5, '2025-12-30 11:00:00'),
(4, 5, 44.0, '2025-12-31 12:00:00'),
(4, 6, 49.0, '2026-01-01 13:00:00'),
(4, 7, 43.5, '2026-01-02 14:00:00'),
(4, 8, 47.0, '2026-01-03 15:00:00'),
(4, 9, 41.5, '2026-01-04 16:00:00'),
(4, 10, 50.0, '2026-01-05 17:00:00'),
(4, 1, 45.5, '2026-01-06 08:30:00'),
(4, 2, 48.0, '2026-01-07 09:30:00'),
(4, 3, 42.5, '2026-01-08 10:30:00'),
(4, 4, 46.0, '2026-01-09 11:30:00'),
(4, 5, 44.5, '2026-01-10 12:30:00'),
(4, 6, 49.5, '2026-01-11 13:30:00'),
(4, 7, 43.0, '2026-01-12 14:30:00'),
(4, 8, 47.5, '2026-01-13 15:30:00'),
(4, 9, 41.0, '2026-01-14 16:30:00'),
(4, 10, 50.5, '2026-01-15 17:30:00'),
(4, 1, 45.0, '2026-01-16 08:00:00'),
(4, 2, 48.0, '2026-01-17 09:00:00'),
(4, 3, 42.0, '2026-01-18 10:00:00'),
(4, 4, 46.0, '2026-01-19 11:00:00'),
(4, 5, 44.0, '2026-01-20 12:00:00'),
(4, 6, 49.0, '2026-01-21 13:00:00'),
(4, 7, 43.0, '2026-01-22 14:00:00'),
(4, 8, 47.0, '2026-01-23 15:00:00'),
(4, 9, 41.0, '2026-01-24 16:00:00'),
(4, 10, 50.0, '2026-01-25 17:00:00');

-- ==================================================
-- TIER 2: Confident Prediction (40+ measurements)
-- ==================================================

-- Location 5 (Μελίνα): 45 measurements - CONFIDENT PREDICTION
-- Showing temporal patterns (weekday mornings busy, afternoons quiet)
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
-- Week 1
(5, 1, 82.0, '2025-12-09 08:00:00'), -- Monday morning (busy)
(5, 2, 80.5, '2025-12-09 09:00:00'),
(5, 3, 52.0, '2025-12-09 15:00:00'), -- Monday afternoon (quiet)
(5, 4, 83.5, '2025-12-10 08:30:00'), -- Tuesday morning (busy)
(5, 5, 81.0, '2025-12-10 09:30:00'),
(5, 6, 54.5, '2025-12-10 15:30:00'), -- Tuesday afternoon (quiet)
(5, 7, 84.0, '2025-12-11 08:00:00'), -- Wednesday morning
(5, 8, 82.5, '2025-12-11 09:00:00'),
(5, 9, 51.5, '2025-12-11 15:00:00'), -- Wednesday afternoon
(5, 10, 85.0, '2025-12-12 08:30:00'), -- Thursday morning
(5, 1, 83.0, '2025-12-12 09:30:00'),
(5, 2, 53.0, '2025-12-12 15:30:00'), -- Thursday afternoon
(5, 3, 86.5, '2025-12-13 08:00:00'), -- Friday morning
(5, 4, 84.5, '2025-12-13 09:00:00'),
(5, 5, 55.0, '2025-12-13 15:00:00'), -- Friday afternoon
-- Weekend (different pattern)
(5, 6, 65.0, '2025-12-14 10:00:00'), -- Saturday (moderate)
(5, 7, 67.5, '2025-12-14 11:00:00'),
(5, 8, 64.0, '2025-12-15 10:00:00'), -- Sunday (moderate)
(5, 9, 66.0, '2025-12-15 11:00:00'),
-- Week 2
(5, 10, 81.5, '2025-12-16 08:00:00'), -- Monday morning
(5, 1, 79.5, '2025-12-16 09:00:00'),
(5, 2, 51.0, '2025-12-16 15:00:00'),
(5, 3, 82.5, '2025-12-17 08:30:00'),
(5, 4, 80.0, '2025-12-17 09:30:00'),
(5, 5, 53.5, '2025-12-17 15:30:00'),
(5, 6, 83.5, '2025-12-18 08:00:00'),
(5, 7, 81.5, '2025-12-18 09:00:00'),
(5, 8, 52.5, '2025-12-18 15:00:00'),
(5, 9, 84.5, '2025-12-19 08:30:00'),
(5, 10, 82.0, '2025-12-19 09:30:00'),
(5, 1, 54.0, '2025-12-19 15:30:00'),
(5, 2, 85.5, '2025-12-20 08:00:00'),
(5, 3, 83.5, '2025-12-20 09:00:00'),
(5, 4, 55.5, '2025-12-20 15:00:00'),
-- Recent week
(5, 5, 80.0, '2026-01-20 08:00:00'),
(5, 6, 78.5, '2026-01-20 09:00:00'),
(5, 7, 50.5, '2026-01-20 15:00:00'),
(5, 8, 81.0, '2026-01-21 08:30:00'),
(5, 9, 79.0, '2026-01-21 09:30:00'),
(5, 10, 52.0, '2026-01-21 15:30:00'),
(5, 1, 82.0, '2026-01-22 08:00:00'),
(5, 2, 80.0, '2026-01-22 09:00:00'),
(5, 3, 51.0, '2026-01-22 15:00:00'),
(5, 4, 83.0, '2026-01-23 08:30:00'),
(5, 5, 81.0, '2026-01-23 09:30:00');

-- Location 6 (Κλεψύδρα): 50 measurements - CONFIDENT PREDICTION
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
(6, 1, 62.0, '2025-12-05 08:00:00'),
(6, 2, 64.5, '2025-12-06 09:00:00'),
(6, 3, 58.0, '2025-12-07 10:00:00'),
(6, 4, 66.0, '2025-12-08 11:00:00'),
(6, 5, 60.5, '2025-12-09 12:00:00'),
(6, 6, 67.5, '2025-12-10 13:00:00'),
(6, 7, 59.0, '2025-12-11 14:00:00'),
(6, 8, 65.0, '2025-12-12 15:00:00'),
(6, 9, 61.5, '2025-12-13 16:00:00'),
(6, 10, 68.0, '2025-12-14 17:00:00'),
(6, 1, 63.0, '2025-12-15 08:30:00'),
(6, 2, 65.5, '2025-12-16 09:30:00'),
(6, 3, 59.5, '2025-12-17 10:30:00'),
(6, 4, 67.0, '2025-12-18 11:30:00'),
(6, 5, 62.5, '2025-12-19 12:30:00'),
(6, 6, 68.5, '2025-12-20 13:30:00'),
(6, 7, 60.0, '2025-12-21 14:30:00'),
(6, 8, 66.0, '2025-12-22 15:30:00'),
(6, 9, 62.0, '2025-12-23 16:30:00'),
(6, 10, 69.0, '2025-12-24 17:30:00'),
(6, 1, 63.5, '2025-12-25 08:00:00'),
(6, 2, 66.0, '2025-12-26 09:00:00'),
(6, 3, 60.0, '2025-12-27 10:00:00'),
(6, 4, 67.5, '2025-12-28 11:00:00'),
(6, 5, 63.0, '2025-12-29 12:00:00'),
(6, 6, 69.5, '2025-12-30 13:00:00'),
(6, 7, 60.5, '2025-12-31 14:00:00'),
(6, 8, 66.5, '2026-01-01 15:00:00'),
(6, 9, 62.5, '2026-01-02 16:00:00'),
(6, 10, 69.5, '2026-01-03 17:00:00'),
(6, 1, 64.0, '2026-01-04 08:30:00'),
(6, 2, 66.5, '2026-01-05 09:30:00'),
(6, 3, 60.5, '2026-01-06 10:30:00'),
(6, 4, 68.0, '2026-01-07 11:30:00'),
(6, 5, 63.5, '2026-01-08 12:30:00'),
(6, 6, 70.0, '2026-01-09 13:30:00'),
(6, 7, 61.0, '2026-01-10 14:30:00'),
(6, 8, 67.0, '2026-01-11 15:30:00'),
(6, 9, 63.0, '2026-01-12 16:30:00'),
(6, 10, 70.5, '2026-01-13 17:30:00'),
(6, 1, 64.5, '2026-01-14 08:00:00'),
(6, 2, 67.0, '2026-01-15 09:00:00'),
(6, 3, 61.0, '2026-01-16 10:00:00'),
(6, 4, 68.5, '2026-01-17 11:00:00'),
(6, 5, 64.0, '2026-01-18 12:00:00'),
(6, 6, 71.0, '2026-01-19 13:00:00'),
(6, 7, 61.5, '2026-01-20 14:00:00'),
(6, 8, 67.5, '2026-01-21 15:00:00'),
(6, 9, 63.5, '2026-01-22 16:00:00'),
(6, 10, 71.5, '2026-01-23 17:00:00');

-- ==================================================
-- TIER 1: Fresh Data (< 60 minutes old)
-- ==================================================

-- Location 7 (Λώρας): Fresh measurement taken 30 minutes ago
-- NOTE: This assumes current time is 2026-01-26 18:00:00
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
(7, 1, 70.5, '2026-01-26 17:30:00'); -- 30 minutes ago = FRESH DATA

-- Location 8 (Mokka): Fresh measurement taken 45 minutes ago
INSERT INTO noise_measurements (location_id, user_id, db_value, measured_at) VALUES
(8, 2, 58.0, '2026-01-26 17:15:00'); -- 45 minutes ago = FRESH DATA

-- ==================================================
-- NEW CAFE: No measurements yet
-- ==================================================
-- Location 9 (Cusco cafe): 0 measurements - NEW CAFE
-- Location 10 (Il Toto): 0 measurements - NEW CAFE


-- Step 4: Add some favorites
INSERT INTO favorites (user_id, location_id, created_at) VALUES
(1, 5, '2026-01-01 10:00:00'), -- Alice favorites Μελίνα (lots of data)
(1, 7, '2026-01-10 11:00:00'), -- Alice favorites Λώρας (fresh data)
(2, 3, '2026-01-05 12:00:00'), -- Bob favorites Coffee Stand
(2, 6, '2026-01-08 13:00:00'), -- Bob favorites Κλεψύδρα
(3, 4, '2026-01-12 14:00:00'), -- Carol favorites Veranda
(4, 5, '2026-01-15 15:00:00'), -- David favorites Μελίνα
(5, 1, '2026-01-18 16:00:00'), -- Eve favorites Starbucks
(6, 2, '2026-01-20 17:00:00'); -- Frank favorites Maroco Cafe

-- Verification queries
SELECT 'Import Complete!' AS status;
SELECT COUNT(*) AS total_users FROM users;
SELECT COUNT(*) AS total_locations FROM locations;
SELECT COUNT(*) AS total_measurements FROM noise_measurements;
SELECT COUNT(*) AS total_favorites FROM favorites;

-- Show data trust tiers
SELECT 
    l.name AS cafe_name,
    COUNT(nm.measurement_id) AS measurement_count,
    CASE 
        WHEN COUNT(nm.measurement_id) = 0 THEN 'NEW CAFE - No data'
        WHEN COUNT(nm.measurement_id) < 20 THEN 'LIMITED DATA - Simple average'
        WHEN COUNT(nm.measurement_id) BETWEEN 20 AND 39 THEN 'MODERATE CONFIDENCE - Time filtering'
        WHEN COUNT(nm.measurement_id) >= 40 THEN 'CONFIDENT PREDICTION - Full temporal analysis'
    END AS trust_tier,
    MAX(nm.measured_at) AS latest_measurement
FROM locations l
LEFT JOIN noise_measurements nm ON l.location_id = nm.location_id
GROUP BY l.location_id, l.name
ORDER BY measurement_count DESC;
