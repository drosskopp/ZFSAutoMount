# ZFS AutoMount - Usage Guide

Complete guide for using ZFS AutoMount on your Mac mini with your specific ZFS configuration.

## Your Current ZFS Setup

```
media         3.43T  3.71T     2M  /Volumes/media
media/enc2    3.43T  3.71T  3.43T  /Volumes/media/enc2   [ENCRYPTED]
tank          8.21T  2.23T  2.16M  /Volumes/tank
tank/airback  2.21T  2.55T  1.90T  -
tank/enc1     6.00T  2.23T  6.00T  /Volumes/tank/enc1    [ENCRYPTED]
```

### Encrypted Datasets
- **media/enc2**: 3.43T encrypted dataset with keyfile
- **tank/enc1**: 6.00T encrypted dataset with keyfile

## Installation

### 1. Install OpenZFS (if not already)
```bash
brew install openzfs
```

### 2. Install ZFS AutoMount

#### Option A: From Build
```bash
cd /path/to/ZFSAutoMount
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build

sudo cp -R ./build/Build/Products/Release/ZFSAutoMount.app /Applications/
```

#### Option B: Via Homebrew (future)
```bash
brew install --cask zfs-automount
```

## First Launch

1. **Launch the app**
   ```bash
   open /Applications/ZFSAutoMount.app
   ```

2. **Check menu bar** - You should see a disk icon in the menu bar

3. **Install privileged helper**
   - Click menu bar icon → Preferences
   - Go to General tab
   - Click "Install/Update Helper"
   - Enter your admin password

## Setting Up Encryption Keys

### Option 1: Using Keyfiles (Recommended for your setup)

1. **Create config file**
   ```bash
   sudo mkdir -p /etc/zfs
   sudo nano /etc/zfs/automount.conf
   ```

2. **Add your encrypted datasets**
   ```
   # Your encrypted datasets
   media/enc2 keylocation=file:///path/to/media-enc2.key
   tank/enc1 keylocation=file:///path/to/tank-enc1.key
   ```

   Replace `/path/to/` with actual path to your keyfiles.

3. **Secure keyfiles**
   ```bash
   sudo chmod 600 /path/to/*.key
   sudo chown root:wheel /path/to/*.key
   ```

### Option 2: Using Keychain (Interactive)

1. **Mount a dataset manually first time**
   - Click menu bar icon → "Mount All Datasets"
   - You'll be prompted for the encryption key
   - Check "Save to Keychain"
   - Enter your keyfile content or passphrase

2. **Keys are saved** - Next mount will use Keychain automatically

### Option 3: Manual ZFS KeyLocation

```bash
# Set keylocation in ZFS property
sudo zfs set keylocation=file:///path/to/keyfile.key media/enc2
sudo zfs set keylocation=file:///path/to/keyfile.key tank/enc1
```

## Daily Usage

### Menu Bar Interface

Click the ZFS icon in menu bar to see:

```
┌─ media
│  └─ Health: ONLINE
│     Used: 3.43T / 7.14T
├─ tank
│  └─ Health: ONLINE
│     Used: 8.21T / 10.44T
├─────────────────────
├─ Refresh Pools        ⌘R
├─ Mount All Datasets   ⌘M
├─────────────────────
├─ Preferences...       ⌘,
├─────────────────────
└─ Quit ZFSAutoMount    ⌘Q
```

### Common Operations

#### Manually Refresh Pool Status
```
Menu Bar Icon → Refresh Pools
```
or press **⌘R** while menu is open

#### Mount All Datasets
```
Menu Bar Icon → Mount All Datasets
```
or press **⌘M** while menu is open

This will:
1. Import any pools that aren't imported
2. Load encryption keys (from config/keychain)
3. Mount all datasets

#### Check Saved Keys
```
Menu Bar Icon → Preferences → Encryption tab
```

You'll see:
- List of datasets with saved keys
- Delete button for each key

## Boot-Time Auto-Mounting

### Enable Auto-Mount on Boot

1. **Install LaunchDaemon**
   ```bash
   sudo cp org.openzfs.automount.daemon.plist /Library/LaunchDaemons/
   sudo launchctl load /Library/LaunchDaemons/org.openzfs.automount.daemon.plist
   ```

2. **Verify it's loaded**
   ```bash
   sudo launchctl list | grep openzfs
   ```

3. **Test it**
   ```bash
   # Unmount and unload keys
   sudo zfs unmount -a
   sudo zfs unload-key media/enc2
   sudo zfs unload-key tank/enc1

   # Trigger boot-mount manually
   /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount
   ```

4. **Check logs**
   ```bash
   tail -f /var/log/zfs-automount.log
   ```

### What Happens on Boot

1. System starts
2. LaunchDaemon runs before login
3. App imports pools: `zpool import -a`
4. App loads keys from config or Keychain
5. App mounts datasets: `zfs mount -a`
6. Pools are ready when you log in

## Configuration File

### Location
```
/etc/zfs/automount.conf
```

### Example for Your Setup

```bash
sudo nano /etc/zfs/automount.conf
```

```
# ZFS AutoMount Configuration

# Encrypted datasets with keyfiles
media/enc2 keylocation=file:///Volumes/external/keys/media-enc2.key
tank/enc1 keylocation=file:///Volumes/external/keys/tank-enc1.key

# Optional: Make tank/airback not auto-mount
# tank/airback canmount=noauto

# Optional: Mount media/enc2 readonly
# media/enc2 readonly=on
```

### Configuration Options

- `keylocation=file:///path` - Path to keyfile
- `readonly=on` - Mount read-only
- `canmount=noauto` - Don't auto-mount this dataset
- `mountpoint=/custom/path` - Custom mount point

## Troubleshooting

### Pools Not Showing Up

```bash
# Check if OpenZFS is loaded
kextstat | grep zfs

# Check if pools are imported
zpool list

# Manually import pools
sudo zpool import -a

# Check pool status
zpool status
```

### Encrypted Dataset Won't Mount

```bash
# Check if key is loaded
zfs get keystatus media/enc2

# Manually load key
sudo zfs load-key media/enc2
# Enter key when prompted

# Then mount
sudo zfs mount media/enc2

# Check if mounted
df -h | grep media/enc2
```

### Menu Bar Icon Not Showing

1. Check if app is running:
   ```bash
   ps aux | grep ZFSAutoMount
   ```

2. Check console for errors:
   ```bash
   log show --predicate 'process == "ZFSAutoMount"' --last 5m
   ```

3. Restart the app:
   ```bash
   killall ZFSAutoMount
   open /Applications/ZFSAutoMount.app
   ```

### Boot-Time Mount Not Working

```bash
# Check LaunchDaemon is loaded
sudo launchctl list | grep openzfs

# Check daemon logs
cat /var/log/zfs-automount.log
cat /var/log/zfs-automount-error.log

# Manually reload daemon
sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.daemon.plist
sudo launchctl load /Library/LaunchDaemons/org.openzfs.automount.daemon.plist
```

### Keychain Access Denied

If the app can't access Keychain:

1. Open **Keychain Access** app
2. Search for "openzfs"
3. Right-click the entry → Get Info
4. Access Control tab
5. Add `/Applications/ZFSAutoMount.app`

### Helper Tool Issues

```bash
# Check helper status
sudo launchctl list | grep org.openzfs.automount.helper

# Reinstall helper
# Open app → Preferences → General → "Install/Update Helper"

# Manually uninstall helper
sudo launchctl unload /Library/LaunchServices/org.openzfs.automount.helper
sudo rm /Library/LaunchServices/org.openzfs.automount.helper
```

## Working with Your Specific Pools

### Mount media/enc2 with Keyfile

```bash
# If keyfile is at /Volumes/external/keys/media.key
sudo zfs load-key -L file:///Volumes/external/keys/media.key media/enc2
sudo zfs mount media/enc2
```

### Mount tank/enc1 with Keyfile

```bash
# If keyfile is at /Volumes/external/keys/tank.key
sudo zfs load-key -L file:///Volumes/external/keys/tank.key tank/enc1
sudo zfs mount tank/enc1
```

### Unmount Everything

```bash
sudo zfs unmount -a
sudo zpool export tank
sudo zpool export media
```

### Re-import and Auto-Mount

```bash
# Using the app
open /Applications/ZFSAutoMount.app
# Click "Mount All Datasets"

# Or manually
sudo zpool import -a
/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount
```

## Advanced Usage

### Check Pool Health from Terminal

```bash
# Detailed pool status
zpool status -v

# I/O statistics
zpool iostat -v 1

# List all datasets
zfs list -r tank
zfs list -r media
```

### Check Encryption Status

```bash
# Check which datasets are encrypted
zfs get encryption,keystatus,keylocation

# Just your encrypted datasets
zfs get encryption,keystatus,keylocation media/enc2
zfs get encryption,keystatus,keylocation tank/enc1
```

### Manual Key Management

```bash
# Change keylocation
sudo zfs set keylocation=file:///new/path/key.key media/enc2

# Unload key
sudo zfs unload-key media/enc2

# Load key from prompt
sudo zfs load-key media/enc2

# Load key from file
sudo zfs load-key -L file:///path/to/key.key media/enc2
```

## Best Practices

1. **Keep keyfiles secure**
   - Store on external drive or encrypted volume
   - Backup keyfiles separately
   - Set proper permissions (600 or 400)

2. **Regular health checks**
   - Check `zpool status` weekly
   - Run scrubs monthly: `sudo zpool scrub tank`

3. **Monitor space**
   - Keep pools under 80% full
   - Use `zfs list -o space` to check

4. **Backup configuration**
   ```bash
   sudo cp /etc/zfs/automount.conf ~/Documents/zfs-automount-backup.conf
   ```

5. **Test disaster recovery**
   - Export pools
   - Delete app config
   - Re-import and verify recovery works

## Getting Help

If you need assistance:

1. Check logs:
   ```bash
   tail -f /var/log/zfs-automount.log
   log show --predicate 'process == "ZFSAutoMount"' --last 1h
   ```

2. Check ZFS status:
   ```bash
   zpool status
   zfs list
   ```

3. Check app status:
   ```bash
   ps aux | grep ZFSAutoMount
   sudo launchctl list | grep openzfs
   ```

4. Open an issue on GitHub with logs and error messages
