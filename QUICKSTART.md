# ZFS AutoMount - Quick Start Guide

Get up and running in 15 minutes.

## Prerequisites Check

```bash
# Check macOS version (need 26.0+)
sw_vers | grep ProductVersion
# Should show: 26.x

# Check if OpenZFS is installed
which zpool && which zfs
# Should show: /usr/local/bin/zpool and /usr/local/bin/zfs

# Check your ZFS pools
zpool list
# Should show: media and tank

# If OpenZFS is not installed:
brew install openzfs
```

## Step 1: Install Xcode (15 minutes)

```bash
# Download Xcode from Mac App Store
# Search for "Xcode" and install
# Size: ~15GB download, 40GB installed

# After install, accept license
sudo xcodebuild -license accept

# Verify
xcodebuild -version
# Should show: Xcode 16.0 or later
```

## Step 2: Build the App (2 minutes)

```bash
# Navigate to project directory
cd /path/to/ZFSAutoMount

# Build release version
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-"

# Should complete with "BUILD SUCCEEDED"
```

## Step 3: Install the App (1 minute)

```bash
# Copy to Applications
sudo cp -R ./build/Build/Products/Release/ZFSAutoMount.app /Applications/

# Remove quarantine flag
sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app

# Launch
open /Applications/ZFSAutoMount.app
```

You should see a disk icon in your menu bar!

## Step 4: Install Privileged Helper (1 minute)

1. Click the disk icon in menu bar
2. Click **Preferences...**
3. Go to **General** tab
4. Click **Install/Update Helper**
5. Enter your admin password when prompted
6. You should see "Installed" in green

## Step 5: Test Basic Functionality (2 minutes)

```bash
# Unmount one of your encrypted datasets
sudo zfs unmount media/enc2
sudo zfs unload-key media/enc2

# Verify it's unmounted
df -h | grep enc2
# Should show nothing
```

Now use the app:

1. Click menu bar icon
2. Click **Mount All Datasets**
3. You'll be prompted for the encryption key
4. Enter your key
5. Check **"Save to Keychain"**
6. Click OK

Verify it mounted:
```bash
df -h | grep enc2
# Should show: /Volumes/media/enc2
```

## Step 6: Set Up Boot-Time Mounting (3 minutes)

### Option A: Using Config File (Recommended)

```bash
# Create config directory
sudo mkdir -p /etc/zfs

# Create config file
sudo nano /etc/zfs/automount.conf
```

Add your keyfile locations:
```
# Your encrypted datasets
media/enc2 keylocation=file:///path/to/your/media-enc2.key
tank/enc1 keylocation=file:///path/to/your/tank-enc1.key
```

Replace `/path/to/your/` with actual paths to your keyfiles.

Save and exit (Ctrl+O, Enter, Ctrl+X).

### Option B: Using Keychain Only

Skip the config file. The app will use keys saved in Keychain (from Step 5).

### Install LaunchDaemon

```bash
# Install daemon
sudo cp org.openzfs.automount.daemon.plist /Library/LaunchDaemons/

# Load it
sudo launchctl load /Library/LaunchDaemons/org.openzfs.automount.daemon.plist

# Verify it's loaded
sudo launchctl list | grep openzfs.automount.daemon
# Should show the daemon
```

## Step 7: Test Boot Mounting (1 minute)

```bash
# Unmount everything
sudo zfs unmount -a

# Unload keys
sudo zfs unload-key media/enc2
sudo zfs unload-key tank/enc1

# Test boot mount
/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount

# Check if mounted
df -h | grep -E "(enc1|enc2)"
# Should show both datasets mounted
```

## Step 8: Reboot Test (2 minutes)

```bash
# Reboot your Mac
sudo reboot
```

After reboot and login:

```bash
# Check if pools are imported and mounted
zpool list
df -h | grep Volumes

# Check logs
cat /var/log/zfs-automount.log
```

Everything should be mounted automatically!

## Daily Usage

### Menu Bar Actions

Click the disk icon to:
- **View pool status** - Health and capacity
- **Refresh Pools** (⌘R) - Update status
- **Mount All Datasets** (⌘M) - Mount everything
- **Preferences** (⌘,) - Settings
- **Quit** (⌘Q) - Exit app

### Common Tasks

**Check pool health:**
```bash
zpool status
```

**Check saved keys:**
Menu Bar → Preferences → Encryption tab

**View logs:**
```bash
tail -f /var/log/zfs-automount.log
```

**Restart app:**
```bash
killall ZFSAutoMount
open /Applications/ZFSAutoMount.app
```

## Troubleshooting

### App won't launch
```bash
sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app
```

### Helper won't install
Check Console.app for errors, or reinstall helper via Preferences.

### Keys not loading at boot
- Check config file: `cat /etc/zfs/automount.conf`
- Check keyfile paths exist
- Check logs: `cat /var/log/zfs-automount-error.log`

### Datasets won't mount
```bash
# Check if OpenZFS is loaded
kextstat | grep zfs

# Manually test
sudo zpool import -a
sudo zfs mount -a
```

## What's Next?

### Immediate
- Test with your real data
- Try rebooting a few times
- Experiment with the menu bar features

### This Week
- Set up config file properly
- Test all encrypted datasets
- Verify boot mounting is reliable

### Later
- Set up Homebrew tap for easy distribution
- Consider getting Apple Developer account for code signing
- Plan Phase 2 features (monitoring, scrubbing, etc.)

## Need Help?

1. **Check logs first:**
   ```bash
   cat /var/log/zfs-automount.log
   log show --predicate 'process == "ZFSAutoMount"' --last 30m
   ```

2. **Read detailed docs:**
   - [README.md](README.md) - Overview
   - [BUILD.md](BUILD.md) - Building
   - [USAGE.md](USAGE.md) - Detailed usage
   - [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Architecture

3. **Check ZFS status:**
   ```bash
   zpool status
   zfs list
   ```

4. **Reset and retry:**
   ```bash
   # Unload daemon
   sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.daemon.plist

   # Quit app
   killall ZFSAutoMount

   # Restart from Step 3
   ```

## Success Checklist

After completing all steps, you should have:

- ✅ App installed in /Applications
- ✅ Disk icon in menu bar
- ✅ Privileged helper installed
- ✅ Pools visible in menu bar
- ✅ Encryption keys work
- ✅ LaunchDaemon loaded
- ✅ Auto-mount on boot works
- ✅ Logs show no errors

## Your Setup

Pools that should appear:
- **media** (3.43T / 7.14T) - ONLINE
  - media/enc2 (encrypted)
- **tank** (8.21T / 10.44T) - ONLINE
  - tank/airback
  - tank/enc1 (encrypted)

---

**Time to complete:** ~15-25 minutes (mostly Xcode download time)

**Next:** Start using it daily and note any issues or improvements you'd like!
