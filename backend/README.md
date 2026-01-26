# QuietSpot Backend

Backend API for QuietSpot application, powered by Node.js/Express and TiDB Cloud.

## Features

- ✅ RESTful API for locations, measurements, favorites, and user management
- ☁️ TiDB Cloud database integration with SSL
- 🎯 **Data Trust Policy Implementation** - 4-tier noise prediction system
- 🔐 User authentication (signup, login, password management)
- 📊 Real-time noise level predictions based on measurement history
- 🌐 Ready for Render deployment

## Data Trust Policy

QuietSpot uses a sophisticated 4-tier system to predict noise levels:

### Tier 1: Fresh Data (< 60 minutes)
- **Confidence**: Highest
- **Method**: Use actual measurement directly
- Example: Measurement from 30 minutes ago → Display exact value

### Tier 2: Confident Prediction (40+ measurements)
- **Confidence**: High
- **Method**: Advanced temporal filtering with exponential decay
- Features:
  - Time-of-day matching (morning vs afternoon)
  - Weekday vs weekend patterns
  - Last 30 days only
  - Recent data boost (2x weight for last 14 days)

### Tier 3: Moderate Confidence (20-39 measurements)
- **Confidence**: Medium
- **Method**: Time period filtering with recency weighting
- Simpler temporal analysis with broader time windows

### Tier 4: Limited Data (< 20 measurements)
- **Confidence**: Low
- **Method**: Simple average of all measurements
- For new cafes or rarely visited locations

## License

This project is for educational purposes.
