# Troubleshooting Scrub & TRIM "Run Now" Buttons

## Issue: "Run Now" Button Does Nothing

If clicking "Run Now" for scrub or TRIM doesn't show any visible change, here's how to diagnose the issue:

### Step 1: Check if Alert Shows

**With the updated build**, when you click "Run Now", you should see an alert dialog:
- **Success**: "Scrub Started" with instructions
- **Failure**: "Scrub Failed" with error message

**If no alert shows:**
- The button handler isn't being called
- Rebuild and restart the app

**If you see an error alert:**
- Read the error message - it will tell you what failed
- Most likely: Privileged helper not installed

### Step 2: Check Privileged Helper

The privileged helper must be installed for scrub/TRIM to work.

**Check if installed:**
```bash
sudo ls -la /Library/PrivilegedHelperTools/org.openzfs.automount.helper
```

**Should see:**
```
-rwxr-xr-x  1 root  wheel  ... org.openzfs.automount.helper
```

**If not installed:**
The helper installs automatically on first use. Try:
1. Click "Mount All Datasets" from menu bar (triggers helper install)
2. Enter admin password when prompted
3. Then try "Run Now" again

**Check helper log:**
```bash
sudo log show --predicate 'process == "org.openzfs.automount.helper"' --last 5m --info
```

### Step 3: Test Scrub Manually

Run the diagnostic script to test if scrub works at all:

```bash
cd /Users/sysop/src/github.com/drosskopp/ZFSAutoMount/Scripts
sudo ./test-scrub-trim.sh
```

This will:
1. List your pools
2. Let you select one
3. Start a scrub
4. Show before/after status

**If manual scrub works:**
- The issue is with the app → helper communication
- Check helper logs (see Step 2)

**If manual scrub fails:**
- ZFS issue, not app issue
- Check: `sudo zpool status <pool>` for errors

### Step 4: Check Pool Status

Small pools scrub very quickly (seconds). You might be missing it!

**Check if scrub actually ran:**
```bash
# Replace 'tank' with your pool name
sudo zpool status tank | grep -E "(scan:|scrub:)"
```

**Possible outputs:**

1. **Never run:**
   ```
   scan: none requested
   ```
   Scrub didn't start - check helper

2. **In progress:**
   ```
   scan: scrub in progress since Wed Oct 16 15:30:00 2025
   ```
   It's working! Wait for completion

3. **Completed:**
   ```
   scan: scrub repaired 0B in 00:00:03 with 0 errors on Wed Oct 16 15:30:03 2025
   ```
   It worked! Pool is small, completed instantly

4. **Errors:**
   ```
   scan: scrub repaired 1.5M in 00:05:00 with 5 errors on Wed Oct 16 15:35:00 2025
   ```
   Scrub found errors - check pool health

### Step 5: Check App Logs

See what the app is doing:

**Terminal 1 - Start log stream:**
```bash
log stream --predicate 'process == "ZFSAutoMount"' --level debug
```

**Terminal 2 - Click "Run Now"**

**Look for:**
```
🔍 Running scrub on pool: tank
✅ Scrub started on tank
```

OR:
```
🔍 Running scrub on pool: tank
❌ Failed to start scrub: <error message>
```

### Step 6: Force Refresh

The menu bar updates automatically, but you can force it:

1. Click "Refresh" button in Maintenance tab
2. Or close/reopen Preferences window
3. Or check menu bar - it refreshes every 30 seconds

### Step 7: Check Refresh is Working

The `refreshPools()` method should update the scrub status. Test if it's working:

**Watch menu bar:**
1. Start a manual scrub: `sudo zpool scrub <pool>`
2. Wait 30 seconds (auto-refresh interval)
3. Click on pool in menu bar
4. Check if "Last Scrub" updated

**If menu doesn't update:**
- Refresh logic issue
- Check if pools are being detected at all
- See if "No pools found" shows in menu

## Common Issues & Solutions

### Issue: "Helper installation failed"

**Symptoms:** Alert says helper couldn't be installed

**Solutions:**
1. Check you're an admin user
2. Make sure app has correct entitlements
3. Try reinstalling the app
4. Check System Settings → Privacy & Security for blocks

### Issue: Scrub completes instantly

**Symptoms:** Status shows "Clean" immediately after clicking

**This is normal for:**
- Small pools (< 100GB)
- Pools with little data
- Fast SSDs

**Verify it actually ran:**
```bash
sudo zpool status <pool> | grep "scrub repaired"
```

Should show a recent timestamp.

### Issue: Scrub shows "In progress" forever

**Symptoms:** Status stuck on "In progress"

**Solutions:**
1. Large pools take hours/days
2. Check actual progress: `sudo zpool status <pool>`
3. Look for percentage complete
4. Wait longer, or cancel: `sudo zpool scrub -s <pool>`

### Issue: TRIM not available

**Symptoms:** No TRIM status shown for pool

**This is normal if:**
- Pool is on HDDs (not SSDs)
- Pool has mixed SSD/HDD
- USB external drives (may not support TRIM)

**Check disk type:**
```bash
diskutil info disk0 | grep "Solid State"
```

Should show "Yes" for SSDs.

### Issue: Permission denied

**Symptoms:** Alert shows "Permission denied" or similar

**Solutions:**
1. Helper not running as root
2. Reinstall helper
3. Check: `sudo launchctl list | grep openzfs`
4. Should show the helper service

## Debugging Checklist

Run through this checklist:

- [ ] App is running (check menu bar icon)
- [ ] Privileged helper is installed (`sudo ls /Library/PrivilegedHelperTools/`)
- [ ] Pools are visible in menu bar
- [ ] Clicking "Run Now" shows an alert (success or error)
- [ ] Alert shows specific error message (if failed)
- [ ] Manual scrub works (`sudo zpool scrub <pool>`)
- [ ] Pool status shows recent scrub (`zpool status <pool>`)
- [ ] Helper logs show scrub command (`sudo log show --predicate ...`)
- [ ] Menu bar refreshes after 30 seconds

## Still Not Working?

If scrub still doesn't work after all these steps:

1. **Collect logs:**
   ```bash
   # Helper log
   sudo log show --predicate 'process == "org.openzfs.automount.helper"' --last 30m > helper.log

   # App log
   log show --predicate 'process == "ZFSAutoMount"' --last 30m > app.log

   # ZFS status
   sudo zpool status > pool-status.txt
   ```

2. **Check build:**
   - Rebuild app in Xcode
   - Make sure no build errors
   - Deploy fresh copy to /Applications/

3. **Test with diagnostic script:**
   ```bash
   sudo ./Scripts/test-scrub-trim.sh
   ```

4. **Try manual privileged helper test:**
   - Use `PrivilegedHelperManager` directly
   - Call `executeCommand("scrub_pool:tank")`
   - Check callback results

## Quick Test Commands

```bash
# 1. List pools
sudo zpool list

# 2. Check pool status
sudo zpool status tank

# 3. Start scrub manually
sudo zpool scrub tank

# 4. Check scrub progress
watch -n 5 'sudo zpool status tank | grep scan'

# 5. Stop scrub
sudo zpool scrub -s tank

# 6. Check if helper installed
sudo ls -la /Library/PrivilegedHelperTools/org.openzfs.automount.helper

# 7. Check helper is running
sudo launchctl list | grep openzfs

# 8. View helper logs
sudo log show --predicate 'process == "org.openzfs.automount.helper"' --last 5m --info

# 9. View app logs
log stream --predicate 'process == "ZFSAutoMount"' --level debug
```

---

**Most Common Cause:** Small pools scrub instantly. The scrub IS working, it just finishes in < 1 second and you don't see "In progress" - you go straight to "Clean" with a timestamp.

**How to verify:** Check the timestamp on "Last Scrub" - if it updated to right now, the scrub worked!
