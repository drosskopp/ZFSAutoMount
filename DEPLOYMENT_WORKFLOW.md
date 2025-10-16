# Deployment Workflow

## Quick Deploy (Use This Every Time)

**When you make ANY code changes:**

```bash
cd /Users/sysop/src/github.com/drosskopp/ZFSAutoMount
./deploy-simple.sh
```

This ONE script does EVERYTHING:
1. ✅ Rebuilds the app
2. ✅ Stops the running app
3. ✅ Removes the old privileged helper
4. ✅ Deploys to /Applications
5. ✅ **Installs the privileged helper** (bypassing SMJobBless)
6. ✅ Launches the app

**That's it!** No additional steps needed. The script handles helper installation automatically.

You only need to enter your sudo password once during the deployment.

## Why This Workflow?

### The Problem
The privileged helper is a **separate binary** that:
- Runs as root
- Is installed in `/Library/PrivilegedHelperTools/`
- Requires admin password to update
- Does NOT auto-update when you rebuild the app

### The Solution
The deploy script:
1. **Removes** the old helper (requires sudo password once)
2. **Deploys** the new app
3. The app **auto-reinstalls** the helper on first privileged operation

This ensures the helper is always in sync with your app code.

## What Changed in deploy-simple.sh

### Before (Old Script)
```bash
# Only deployed the app, didn't touch the helper
killall ZFSAutoMount
sudo cp -R DerivedData/.../ZFSAutoMount.app /Applications/
open /Applications/ZFSAutoMount.app
```

**Problem:** Old helper stayed installed, causing "Unknown command" errors

### After (New Script)
```bash
# 1. Rebuild
xcodebuild -scheme ZFSAutoMount build

# 2. Stop app
killall ZFSAutoMount

# 3. Remove old helper
sudo rm -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo rm -f /Library/LaunchDaemons/org.openzfs.automount.helper.plist

# 4. Deploy app
sudo cp -R DerivedData/.../ZFSAutoMount.app /Applications/

# 5. Launch app
open /Applications/ZFSAutoMount.app
```

**Result:** Clean slate every time, no stale helper

## When You Add New Privileged Commands

**If you add new commands to the helper** (like we did with `scrub_pool` and `trim_pool`):

1. Edit `PrivilegedHelper/HelperMain.swift`
2. Add your command to the switch statement
3. Run `./deploy-simple.sh`
4. Click "Mount All Datasets" to reinstall helper
5. Test your new command

**Example:**
```swift
// In HelperMain.swift
case "my_new_command":
    if parts.count >= 2 {
        let arg = parts[1]
        myNewCommand(arg: arg, reply: reply)
    }
```

Then deploy and reinstall helper as above.

## Common Scenarios

### Scenario 1: Changed UI Only
**Files changed:** PreferencesView.swift, MenuBarController.swift

**Deploy steps:**
```bash
./deploy-simple.sh
# Click "Mount All Datasets" to reinstall helper
```

Even though you didn't change the helper, reinstalling is good practice.

### Scenario 2: Changed Helper Only
**Files changed:** HelperMain.swift

**Deploy steps:**
```bash
./deploy-simple.sh
# Click "Mount All Datasets" to reinstall helper (REQUIRED!)
```

**Critical:** The helper MUST be reinstalled when you change it.

### Scenario 3: Changed Both
**Files changed:** PreferencesView.swift + HelperMain.swift

**Deploy steps:**
```bash
./deploy-simple.sh
# Click "Mount All Datasets" to reinstall helper (REQUIRED!)
```

### Scenario 4: Quick Test (No Helper Changes)
**Files changed:** Only UI or ZFSManager.swift

**Fast deploy (skip rebuild):**
```bash
killall ZFSAutoMount
sudo cp -R ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug/ZFSAutoMount.app /Applications/
open /Applications/ZFSAutoMount.app
```

**Skip helper reinstall** - not needed if helper unchanged.

## Troubleshooting

### "Unknown command" Error

**Symptom:** Clicking "Run Now" shows "Unknown command: scrub_pool:tank"

**Cause:** Old helper still installed

**Fix:**
```bash
./deploy-simple.sh
# Then click "Mount All Datasets" to reinstall helper
```

### "Helper installation failed"

**Symptom:** Can't install helper when clicking "Mount All Datasets"

**Fix:**
```bash
# Manually remove everything
sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.helper.plist
sudo rm -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo rm -f /Library/LaunchDaemons/org.openzfs.automount.helper.plist

# Rebuild and deploy
./deploy-simple.sh

# Try again
# Click "Mount All Datasets"
```

### Build Fails

**Symptom:** `deploy-simple.sh` shows "Build failed"

**Fix:**
1. Open Xcode
2. Build manually (Cmd+B)
3. Fix any errors
4. Run `./deploy-simple.sh` again

### Permission Denied

**Symptom:** Can't remove helper or deploy app

**Fix:**
```bash
# Make sure script is executable
chmod +x deploy-simple.sh

# Run it (you'll be prompted for password)
./deploy-simple.sh
```

## Verification

After deploying, verify everything is correct:

```bash
# 1. Check app is running
ps aux | grep ZFSAutoMount | grep -v grep

# 2. Check helper is REMOVED (before reinstall)
ls -la /Library/PrivilegedHelperTools/org.openzfs.automount.helper
# Should show: "No such file or directory"

# 3. Reinstall helper (click "Mount All Datasets")

# 4. Check helper is INSTALLED (after reinstall)
sudo ls -la /Library/PrivilegedHelperTools/org.openzfs.automount.helper
# Should show: "-rwxr-xr-x ... org.openzfs.automount.helper"

# 5. Check helper is loaded
sudo launchctl list | grep openzfs
# Should show: "- 0 org.openzfs.automount.helper"

# 6. Test scrub
# Preferences → Maintenance → Run Now
# Should show: "Scrub Started" alert
```

## Summary

**One command to rule them all:**
```bash
./deploy-simple.sh
```

**One action to activate it:**
- Click "Mount All Datasets" → Enter password

**Done!** Everything is updated and working.

---

**Pro Tip:** Add an alias to your shell:

```bash
# Add to ~/.zshrc or ~/.bashrc
alias zfs-deploy='cd /Users/sysop/src/github.com/drosskopp/ZFSAutoMount && ./deploy-simple.sh'
```

Then just run:
```bash
zfs-deploy
```

From anywhere! 🚀
