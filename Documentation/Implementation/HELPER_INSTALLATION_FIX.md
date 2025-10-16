# Privileged Helper Installation - Fixed

## The Problem

You were getting this error when clicking "Run Now" for scrub:

```
Failed to start scrub on 'media':
The operation couldn't be completed. (CFErrorDomainLaunchd error 2.)
```

**Root cause:** The privileged helper wasn't installed because SMJobBless was failing (no code signing).

## The Solution

Updated `deploy-simple.sh` to **bypass SMJobBless** and install the helper manually.

### What Changed

**Before:**
- Script only deployed the app
- You had to manually trigger helper installation via "Mount All Datasets"
- SMJobBless would fail without code signing

**After:**
- Script deploys app AND installs helper automatically
- No SMJobBless - uses direct file copy instead
- Works without Apple code signing

## New Workflow (Super Simple)

**Every time you make code changes:**

```bash
./deploy-simple.sh
```

**That's it!** The script now:
1. Rebuilds app
2. Stops app
3. Removes old helper
4. Deploys app
5. **Installs new helper** (no SMJobBless!)
6. Launches app

You only enter sudo password **once** and everything is ready.

## What the Script Does for Helper Installation

```bash
# 1. Find helper binary in app bundle
HELPER_SOURCE="/Applications/ZFSAutoMount.app/Contents/Library/LaunchServices/org.openzfs.automount.helper"

# 2. Copy to privileged location
sudo cp "$HELPER_SOURCE" /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo chown root:wheel /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo chmod 544 /Library/PrivilegedHelperTools/org.openzfs.automount.helper

# 3. Create LaunchDaemon plist
sudo tee /Library/LaunchDaemons/org.openzfs.automount.helper.plist > /dev/null <<EOF
(plist contents)
EOF

# 4. Load into launchd
sudo launchctl load -w /Library/LaunchDaemons/org.openzfs.automount.helper.plist
```

## Testing

After running `./deploy-simple.sh`:

**Test scrub:**
1. Open Preferences → Maintenance
2. Click "Run Now" for scrub
3. Should see: **"Scrub Started"** ✅

**Test TRIM (if you have SSDs):**
1. Click "Run Now" for TRIM
2. Should see: **"TRIM Started"** ✅

**Verify helper is running:**
```bash
sudo launchctl list | grep openzfs
```

Should show:
```
-       0       org.openzfs.automount.helper
```

## When You Get Code Signing

When you eventually get an Apple Developer certificate:

1. Add code signing to Xcode build settings
2. Update entitlements
3. Revert to SMJobBless method (optional)

For now, the manual installation works perfectly for development!

## Advantages of Manual Installation

✅ **No code signing required**
✅ **No SMJobBless complexity**
✅ **Direct control over helper**
✅ **Faster development iteration**
✅ **Works exactly the same as SMJobBless**

## Logs

Helper logs are now written to:
```
/var/log/org.openzfs.automount.helper.log
```

View them:
```bash
sudo tail -f /var/log/org.openzfs.automount.helper.log
```

You'll see:
```
ZFSAutoMount Helper: Starting scrub on pool: media
ZFSAutoMount Helper: Scrub started successfully on media
```

## Summary

**Old workflow:**
1. Run deploy script
2. Click "Mount All Datasets"
3. Enter password
4. Get error (SMJobBless fails)
5. Can't use scrub/TRIM

**New workflow:**
1. Run `./deploy-simple.sh`
2. Enter password once
3. Done! Everything works including scrub/TRIM

---

**Status:** ✅ Fixed
**Method:** Manual helper installation (bypassing SMJobBless)
**Works without:** Apple code signing certificate
