# Hum Catcher — native iOS app

Listens for humming and sounds an alarm after a configurable number of seconds.
Unlike the web version, this one **keeps listening in the background** (lock the
phone or switch apps — the orange mic indicator stays on).

## Install on your iPhone (from the MacBook Air)

1. **Install Xcode** from the Mac App Store (free, large download).
2. **Get this folder** on the Mac:
   ```
   git clone -b ios-app https://github.com/tauzinger/allocate1 humcatcher
   open humcatcher/HumCatcherIOS/HumCatcher.xcodeproj
   ```
3. In Xcode, click the **HumCatcher** project (blue icon, left sidebar) →
   **Signing & Capabilities** tab:
   - Check **Automatically manage signing**
   - **Team**: choose your Apple ID ("Personal Team"). If none is listed:
     Xcode → Settings → Accounts → **+** → sign in with your Apple ID.
4. **Enable Developer Mode on the iPhone**: Settings → Privacy & Security →
   Developer Mode → on → restart phone.
5. **Connect the iPhone to the Mac with a cable** (tap "Trust" on the phone).
6. In Xcode's top toolbar, select your iPhone as the run destination,
   then press **▶ Run** (Cmd-R).
7. First launch is blocked: on the phone go to Settings → General →
   VPN & Device Management → your Apple ID → **Trust**. Launch the app again.
8. In the app: **Start listening** → **Allow** microphone → allow notifications.
   Lock the phone — it keeps listening.

## Notes

- With a **free** Apple ID, the install expires after **7 days**; just press
  Run in Xcode again to reinstall (settings and counts are kept).
  A paid developer account ($99/yr) removes the limit.
- Background listening uses real power — expect meaningful battery drain
  during long sessions. Plug in for all-day use.
- The orange dot in the status bar is iOS telling you the mic is live;
  it is always shown while the app listens. Tap **Pause** in the app to stop.
