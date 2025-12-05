# Internal Player Testing Checklist

This document provides step-by-step instructions for manually testing the Electron-based internal player integration with the Electric Slideshow macOS app.

## Prerequisites

Before you begin, ensure you have:
- Xcode installed with the Electric Slideshow project
- Node.js and npm installed
- The `electric-slideshow-internal-player` repository cloned locally
- Valid Spotify Developer credentials configured

---

## 1. Electron Repository Setup (One-Time)

### 1.1 Navigate to the Electron Player Repository

```bash
cd /Users/joshlevy/Desktop/electric-slideshow-internal-player
```

### 1.2 Install Dependencies

```bash
npm install
```

Wait for all dependencies to install. This may take a few minutes.

### 1.3 Verify Manual Launch (Optional but Recommended)

Test that the Electron app can run independently:

```bash
npm run dev
```

**Expected Result:**
- An Electron window should open
- The internal player UI should be visible
- Check the console for any errors

Press `Cmd+Q` or close the window to stop.

---

## 2. Swift App Configuration (One-Time)

### 2.1 Set the Development Repository Path

1. Open the Electric Slideshow project in Xcode
2. Navigate to [`InternalPlayerManager.swift`](Electric%20Slideshow/Services/InternalPlayerManager.swift)
3. Locate the `defaultDevRepoPath` constant (around line 44)
4. Update it with the absolute path to your local Electron repo:

```swift
static let defaultDevRepoPath = "/Users/joshlevy/Desktop/electric-slideshow-internal-player"
```

5. Save the file

### 2.2 Verify Spotify Credentials

Ensure your Spotify app credentials are properly configured in [`SpotifyConfig.swift`](Electric%20Slideshow/Config/SpotifyConfig.swift):
- `clientId` should match your Spotify Developer Dashboard app
- `redirectURI` should be `com.electricslideshow://callback`
- Redirect URI must be registered in your Spotify app settings

### 2.3 Build the Project

1. In Xcode, select the Electric Slideshow target
2. Press `Cmd+B` to build
3. Verify there are no compilation errors

---

## 3. Running the Integrated Stack

### 3.1 Launch Electric Slideshow

1. In Xcode, press `Cmd+R` to run the app in Debug mode
2. The app should launch and display the main window

### 3.2 Authenticate with Spotify

If not already logged in:
1. Navigate to the appropriate section that requires Spotify auth
2. Log in with your Spotify credentials
3. Grant the requested permissions
4. Verify successful authentication (you should see user info or playlists)

### 3.3 Navigate to Internal Player Debug UI

1. Click on "Settings" in the app navigation
2. Look for the "Internal Player (Dev)" tile
3. Click on it to open the debug sheet

**Expected Result:**
- A sheet/modal should appear
- Status should show "Not Running" with a gray circle
- "Start Internal Player" button should be enabled
- "Stop Internal Player" button should be disabled

---

## 4. Testing Start/Stop Functionality

### 4.1 Start the Internal Player

1. In the Internal Player Debug sheet, click **"Start Internal Player"**
2. Watch the Xcode console for logs

**Expected Console Logs (in order):**
```
[InternalPlayerManager] Using token prefix: BQDxxxxx…
[InternalPlayerManager] Starting internal player in dev mode at /Users/joshlevy/Desktop/electric-slideshow-internal-player
[InternalPlayerManager] Process launched with PID <some_number>
```

**Expected Visual Changes:**
- An Electron window should appear (from the `npm run dev` command)
- The internal player UI should load in the Electron window
- Status in the debug sheet should change to "Running" with a green circle
- "Start" button should become disabled
- "Stop" button should become enabled

**If Errors Occur:**
- Check that the repo path is correct
- Verify `npm install` was run in the Electron repo
- Look for error messages in the debug sheet or Xcode console

### 4.2 Verify Spotify Device Registration

1. Open the Spotify desktop app or mobile app
2. Start playing any track
3. Click on the "Connect to a device" icon (speaker with waves)
4. Look for a device named **"Electric Slideshow Internal Player"** in the device list

**Expected Result:**
- The device should appear in the list (may take 5-10 seconds)
- Device type should be shown as a web player or computer

### 4.3 Transfer Playback to Internal Player

1. In the Spotify app device list, select "Electric Slideshow Internal Player"
2. Playback should transfer to the internal player

**Expected Result:**
- Audio should play from the internal player (through your Mac's speakers)
- The Electron window may show playback status/track info (if implemented)
- The Spotify app should show the track playing on the internal player device

### 4.4 Stop the Internal Player

1. Return to the Electric Slideshow app
2. In the Internal Player Debug sheet, click **"Stop Internal Player"**
3. Watch the Xcode console for logs

**Expected Console Logs:**
```
[InternalPlayerManager] Stopping internal player (PID: <number>)
[InternalPlayerManager] Process terminated with status: <number>
[InternalPlayerManager] Internal player stopped
```

**Expected Visual Changes:**
- The Electron window should close
- Status should change to "Not Running" with a gray circle
- "Start" button should become enabled
- "Stop" button should become disabled
- The device should disappear from Spotify's device list

---

## 5. App Lifecycle Testing

### 5.1 Test App Quit with Running Player

1. Start the internal player (see section 4.1)
2. Verify the Electron window is open
3. Quit Electric Slideshow entirely (`Cmd+Q`)

**Expected Result:**
- Both the Electric Slideshow app and Electron window should close
- No Electron or npm processes should remain running

### 5.2 Verify Process Cleanup

Open Terminal and check for stray processes:

```bash
ps aux | grep -i electron
ps aux | grep -i "npm run dev"
```

**Expected Result:**
- No Electron or npm-related processes for the internal player should be running
- If any processes are found, note their PIDs and kill them manually: `kill <PID>`

### 5.3 Re-launch and Restart Player

1. Launch Electric Slideshow again from Xcode
2. Navigate to Settings → Internal Player (Dev)
3. Click "Start Internal Player"

**Expected Result:**
- The player should start successfully
- A new Electron window should appear
- A new PID should be logged

---

## 6. Common Failure Modes

### 6.1 Invalid Repository Path

**Symptom:** Error message in debug sheet: "Invalid internal player path: ..."

**Resolution:**
1. Verify the path in `InternalPlayerManager.defaultDevRepoPath`
2. Ensure the path is absolute (starts with `/`)
3. Check that the directory exists: `ls -la /path/to/electric-slideshow-internal-player`
4. Rebuild the app after changing the path

**Expected Logs:**
```
[InternalPlayerManager] <path_error_message>
```

### 6.2 npm Not Found or Command Fails

**Symptom:** Process launch fails, no Electron window appears

**Resolution:**
1. Verify npm is installed: `which npm`
2. If not found, install Node.js from https://nodejs.org
3. Ensure `/usr/local/bin` is in your PATH
4. Try running manually: `cd <repo_path> && npm run dev`

**Expected Logs:**
```
[InternalPlayerManager] Failed to launch internal player: <error_description>
```

### 6.3 Spotify Authentication Fails

**Symptom:** Error about access token when starting player

**Resolution:**
1. In Electric Slideshow, log out of Spotify
2. Log back in and grant permissions
3. Verify token is valid by checking Spotify API calls work
4. Try starting the internal player again

**Expected Logs:**
```
[InternalPlayerDebugSheet] Error starting player: <auth_error>
```

### 6.4 Internal Player Crashes or Disappears

**Check Xcode Console:**
```
[InternalPlayerManager] Process terminated with status: <non-zero_number>
```

**Check Electron Logs:**
- Look for errors in the Electron window console (if it opens)
- Check Terminal output if npm is running in a separate window

**Resolution:**
1. Stop the player
2. Try running manually: `cd <repo_path> && npm run dev`
3. Look for JavaScript or Electron errors
4. Fix any issues in the Electron repo
5. Try starting from Electric Slideshow again

### 6.5 Device Not Appearing in Spotify

**Symptom:** Internal player starts but doesn't show in Spotify device list

**Resolution:**
1. Wait 10-15 seconds (device registration may be delayed)
2. Check that `SPOTIFY_ACCESS_TOKEN` is being passed (should see token prefix in logs)
3. Verify the token has `streaming` scope in Spotify Developer Dashboard
4. Check Electron window console for Web Playback SDK errors
5. Try restarting playback in Spotify app

---

## 7. Success Criteria

You've successfully tested the internal player integration if:

- ✅ The Electron app launches from the Swift app
- ✅ Console logs show correct token prefix (8 characters)
- ✅ Process PID is logged
- ✅ Electron window appears
- ✅ Device appears in Spotify device list
- ✅ Playback transfers successfully
- ✅ Audio plays through internal player
- ✅ Stop button closes Electron window
- ✅ Quitting Electric Slideshow also quits Electron
- ✅ No stray processes remain after quit
- ✅ Player can be restarted after stopping

---

## 8. Debugging Tips

### Enable Verbose Logging

Add more `print` statements in `InternalPlayerManager.swift` if needed.

### Check Environment Variables

In `startDevMode`, add:
```swift
print("[InternalPlayerManager] Environment: \(newProcess.environment ?? [:])")
```

### Monitor Process Status

Add periodic checks:
```swift
print("[InternalPlayerManager] Process running: \(process?.isRunning ?? false)")
```

### Inspect Electron Output

If the Electron app runs in a separate terminal window, watch that terminal for output and errors.

---

## Next Steps

Once basic functionality works:
- Test token refresh (leave player running for 1+ hour)
- Test network interruptions
- Test rapid start/stop cycles
- Prepare for bundled mode (.app packaging)

---

**Last Updated:** 2025-12-04  
**Maintained By:** Electric Slideshow Development Team