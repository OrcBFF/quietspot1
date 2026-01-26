# 📱 Flutter App - USB Debugging Guide

## Setup for Testing with Physical Device

Your backend is running on `http://192.168.53.97:3000` and ready to accept connections from your phone!

---

## 🔧 Step 1: Configure API URL (Already Done! ✅)

I've updated `lib/services/api_service.dart` to use your machine's IP:
```dart
defaultValue: 'http://192.168.53.97:3000'
```

This means your phone can connect to the backend running on your laptop!

---

## 🗺️ Step 2: Add Mapbox Access Token

You need to provide your Mapbox token when running the app.

### Option A: Using flutter run (Command Line)

```bash
cd /home/aragorn/projects/hci/QuietSpot/quietspot

flutter run \
  --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_TOKEN_HERE \
  --dart-define=API_BASE_URL=http://192.168.53.97:3000
```

### Option B: Using VS Code (launch.json)

Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "QuietSpot (Debug)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_TOKEN_HERE",
        "--dart-define=API_BASE_URL=http://192.168.53.97:3000"
      ]
    }
  ]
}
```

### Get Your Mapbox Token

1. Go to https://account.mapbox.com/access-tokens/
2. Create a new token or copy your existing token
3. Replace `YOUR_MAPBOX_TOKEN_HERE` with your actual token

---

## 📱 Step 3: Connect Phone via USB

### 1. Enable Developer Mode on Your Phone

**Android:**
1. Go to Settings → About Phone
2. Tap "Build Number" 7 times
3. Go back → Developer Options
4. Enable "USB Debugging"

### 2. Connect Phone to Computer

1. Connect via USB cable
2. On phone, select "Transfer files" (MTP mode)
3. Allow USB debugging when prompted

### 3. Verify Connection

```bash
flutter devices
```

You should see your device listed!

---

## 🚀 Step 4: Run the App

### Full Command (Replace YOUR_MAPBOX_TOKEN):

```bash
cd /home/aragorn/projects/hci/QuietSpot/quietspot

flutter run \
  --dart-define=MAPBOX_ACCESS_TOKEN=sk.ey... \
  --dart-define=API_BASE_URL=http://192.168.53.97:3000
```

### What This Does:
1. Builds the Flutter app
2. Installs it on your connected phone  
3. Runs it with:
   - Mapbox maps enabled
   - Backend URL pointing to your local server (192.168.53.97:3000)

---

## 🔍 Step 5: Test the Connection

### 1. Make sure backend is running:
```bash
# In another terminal
cd /home/aragorn/projects/hci/QuietSpot/backend
npm start
```

### 2. Check both devices are on same network:
- Your laptop and phone must be on the **same WiFi network**
- Firewall shouldn't block port 3000

### 3. Test from phone browser first:
- Open browser on phone
- Go to: `http://192.168.53.97:3000/api/health`
- Should see: `{"status":"ok","message":"QuietSpot API is running on TiDB Cloud"}`

---

## 🐛 Debugging Tips

### Problem: "Failed to connect to backend"

**Solution 1: Check firewall**
```bash
# Allow port 3000 on your firewall
sudo ufw allow 3000
```

**Solution 2: Verify IP address**
```bash
# Get current IP (in case it changed)
hostname -I
```

**Solution 3: Test connection from phone**
- Open phone browser
- Visit: `http://192.168.53.97:3000/api/locations`
- Should see JSON with all cafes

### Problem: "Map not loading"

**Cause**: Mapbox token missing or invalid

**Solution**: Make sure you're running with `--dart-define=MAPBOX_ACCESS_TOKEN=...`

### Problem: "Device not found"

```bash
# Check USB connection
flutter devices

# If not showing:
# 1. Unplug and replug USB cable
# 2. Check USB debugging is enabled
# 3. Try: adb devices
```

---

## 📁 Project Structure

```
QuietSpot/
├── backend/                    ← Backend (already running ✅)
│   └── (npm start on port 3000)
│
└── quietspot/                  ← Flutter app
    ├── lib/
    │   ├── services/
    │   │   └── api_service.dart    ← API URL configured ✅
    │   └── screens/
    │       └── map_screen.dart     ← Mapbox token needed
    └── (flutter run here)
```

---

## ⚡ Quick Start (TL;DR)

```bash
# 1. Make sure backend is running
cd /home/aragorn/projects/hci/QuietSpot/backend
npm start

# 2. Connect phone via USB and enable USB debugging

# 3. Run Flutter app (in new terminal)
cd /home/aragorn/projects/hci/QuietSpot/quietspot
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_TOKEN_HERE

# 4. Test on phone - you should see 10 cafes on the map!
```

---

## 🎯 Expected Result

When the app runs successfully on your phone:
1. ✅ Map loads (Mapbox)
2. ✅ 10 cafes appear as pins
3. ✅ Clicking a cafe shows noise level with trust tier
4. ✅ You can add measurements
5. ✅ Data Trust Policy working:
   - Fresh data (green badge)
   - High confidence (blue badge)
   - Moderate confidence (yellow badge)
   - Limited data (orange badge)

---

## 🚀 Next: Build for Render Later

After testing locally works:
1. Deploy backend to Render (we'll do this together)
2. Update `API_BASE_URL` to Render URL
3. Build release APK
4. Submit!

**For now, focus on USB debugging to test everything works!**
