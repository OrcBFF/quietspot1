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

## Setup

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env` and fill in your TiDB Cloud credentials:

```bash
cp .env.example .env
```

Edit `.env` with your actual TiDB Cloud connection details:

```
DB_HOST=gateway01.your-region.prod.aws.tidbcloud.com
DB_PORT=4000
DB_USER=your_tidb_username
DB_PASSWORD=your_tidb_password
DB_NAME=quietspot
PORT=3000
```

### 3. Run Locally

```bash
npm start
```

Or for development with auto-reload:

```bash
npm run dev
```

The API will be available at `http://localhost:3000/api`

## API Endpoints

### Authentication
- `POST /api/auth/signup` - Create new user
- `POST /api/auth/login` - User login
- `POST /api/auth/change-password` - Change password

### Locations (Cafes)
- `GET /api/locations` - Get all locations with predicted noise levels
- `GET /api/locations/:id` - Get single location
- `POST /api/locations` - Create new location
- `DELETE /api/locations/:id` - Delete location

### Measurements
- `GET /api/measurements/location/:locationId` - Get measurements for location
- `POST /api/measurements` - Add new measurement
- `GET /api/measurements/nearby` - Get nearby measurements

### Favorites
- `GET /api/favorites/user/:userId` - Get user's favorites
- `POST /api/favorites` - Add favorite
- `DELETE /api/favorites/:userId/:locationId` - Remove favorite
- `GET /api/favorites/check/:userId/:locationId` - Check if favorited

### Users
- `GET /api/users` - Get all users
- `GET /api/users/:id` - Get single user
- `DELETE /api/users/:id` - Delete user
- `GET /api/users/:id/stats` - Get user statistics

### Health Check
- `GET /api/health` - Check if API is running

## Deploy to Render

### Prerequisites
- Push your code to a Git repository (GitHub, GitLab, or Bitbucket)
- Have a TiDB Cloud database set up and running

### Deployment Steps

1. **Create a Render Account** at https://render.com

2. **Create a New Web Service**
   - Click "New +" → "Web Service"
   - Connect your Git repository
   - Select `QuietSpot/backend` as the root directory

3. **Configure Build Settings**
   - **Environment**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: Free

4. **Add Environment Variables**
   Add these in Render dashboard:
   - `NODE_ENV` = `production`
   - `DB_HOST` = Your TiDB Cloud host
   - `DB_PORT` = `4000`
   - `DB_USER` = Your TiDB Cloud username
   - `DB_PASSWORD` = Your TiDB Cloud password
   - `DB_NAME` = `quietspot`

5. **Deploy**
   - Click "Create Web Service"
   - Render will automatically build and deploy your backend
   - You'll get a URL like: `https://quietspot-api.onrender.com`

6. **Test Your Deployment**
   ```bash
   curl https://your-app.onrender.com/api/health
   ```

## Project Structure

```
backend/
├── routes/
│   ├── auth.js          # Authentication endpoints
│   ├── locations.js     # Location/cafe management (with Data Trust Policy)
│   ├── measurements.js  # Noise measurements
│   ├── favorites.js     # User favorites
│   └── users.js         # User management
├── server.js            # Express server setup
├── db.js                # TiDB Cloud connection
├── package.json         # Dependencies
├── .env.example         # Environment template
├── .gitignore           # Git ignore rules
├── render.yaml          # Render deployment config
└── README.md            # This file
```

## Security Notes

⚠️ **Current Implementation**: Passwords are stored in plaintext as per project requirements. This is **NOT** recommended for production use.

For production deployment, you should:
- Use bcrypt for password hashing
- Implement JWT tokens for authentication
- Add rate limiting
- Enable CORS restrictions
- Use HTTPS only

## Troubleshooting

### Database Connection Issues
- Verify TiDB Cloud credentials in `.env`
- Check that TiDB Cloud cluster is running
- Ensure your IP is whitelisted in TiDB Cloud (or use public access)
- Verify SSL is enabled in `db.js`

### Render Deployment Issues
- Check Render logs for errors
- Verify environment variables are set correctly
- Ensure `PORT` environment variable is not hardcoded (Render provides it)
- Check that package.json has correct Node version

## License

This project is for educational purposes.
