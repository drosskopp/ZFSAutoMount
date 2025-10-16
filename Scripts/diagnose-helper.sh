#!/bin/bash

# Diagnostic script for privileged helper issues
# Run this WITHOUT sudo - it will ask for password only when needed

echo "=================================================="
echo "Privileged Helper Diagnostic"
echo "=================================================="
echo ""

# Check if helper binary is installed
echo "1. Checking if helper is installed..."
if [ -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper ]; then
    echo "✅ Helper binary found"
    ls -la /Library/PrivilegedHelperTools/org.openzfs.automount.helper
else
    echo "❌ Helper binary NOT installed"
    echo "   Expected: /Library/PrivilegedHelperTools/org.openzfs.automount.helper"
fi
echo ""

# Check if helper plist is installed
echo "2. Checking if helper plist is installed..."
if [ -f /Library/LaunchDaemons/org.openzfs.automount.helper.plist ]; then
    echo "✅ Helper plist found"
    ls -la /Library/LaunchDaemons/org.openzfs.automount.helper.plist
else
    echo "❌ Helper plist NOT installed"
    echo "   Expected: /Library/LaunchDaemons/org.openzfs.automount.helper.plist"
fi
echo ""

# Check if helper is loaded in launchd
echo "3. Checking if helper is loaded in launchd..."
echo "(You may be prompted for your password)"
LOADED=$(sudo launchctl list | grep openzfs || echo "")
if [ -n "$LOADED" ]; then
    echo "✅ Helper is loaded:"
    echo "$LOADED"
else
    echo "❌ Helper NOT loaded in launchd"
fi
echo ""

# Check app code signing
echo "4. Checking app code signing..."
if [ -d /Applications/ZFSAutoMount.app ]; then
    codesign -dv /Applications/ZFSAutoMount.app 2>&1 | grep -E "(Authority|Identifier|Signature)"

    if [ $? -eq 0 ]; then
        echo "✅ App is code signed"
    else
        echo "⚠️  App may not be properly code signed"
    fi
else
    echo "❌ App not found at /Applications/ZFSAutoMount.app"
fi
echo ""

# Check helper code signing (if it exists)
echo "5. Checking helper code signing..."
if [ -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper ]; then
    sudo codesign -dv /Library/PrivilegedHelperTools/org.openzfs.automount.helper 2>&1 | grep -E "(Authority|Identifier|Signature)"

    if [ $? -eq 0 ]; then
        echo "✅ Helper is code signed"
    else
        echo "⚠️  Helper may not be properly code signed"
    fi
else
    echo "⏭️  Skipping (helper not installed)"
fi
echo ""

# Check for any launchd errors
echo "6. Checking for recent launchd errors..."
sudo log show --predicate 'subsystem == "com.apple.xpc.launchd"' --last 5m --info 2>/dev/null | grep -i "openzfs\|error\|denied" | tail -10

echo ""
echo "=================================================="
echo "Summary"
echo "=================================================="
echo ""

if [ ! -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper ]; then
    echo "❌ ISSUE: Helper is NOT installed"
    echo ""
    echo "This is the root cause of the error:"
    echo "  'CFErrorDomainLaunchd error 2'"
    echo ""
    echo "The helper failed to install. Possible causes:"
    echo ""
    echo "1. Code signing issue"
    echo "   - App or helper not properly signed"
    echo "   - Entitlements missing or incorrect"
    echo ""
    echo "2. SMJobBless failure"
    echo "   - Info.plist mismatch"
    echo "   - Bundle identifier mismatch"
    echo ""
    echo "3. Permission issue"
    echo "   - User doesn't have admin rights"
    echo "   - Security settings blocking installation"
    echo ""
    echo "------------------------------------------------"
    echo "Next Steps:"
    echo "------------------------------------------------"
    echo ""
    echo "Option 1: Try Manual Helper Installation"
    echo ""
    echo "  Run this script:"
    echo "  ./Scripts/manual-install-helper.sh"
    echo ""
    echo "Option 2: Check Build Settings"
    echo ""
    echo "  Open Xcode and verify:"
    echo "  1. Code signing identity is set"
    echo "  2. Entitlements file is correct"
    echo "  3. Info.plist has SMPrivilegedExecutables"
    echo "  4. Build succeeds without warnings"
    echo ""
else
    echo "✅ Helper appears to be installed"
    echo ""
    echo "If you're still getting errors, try:"
    echo ""
    echo "1. Restart the helper:"
    echo "   sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.helper.plist"
    echo "   sudo launchctl load /Library/LaunchDaemons/org.openzfs.automount.helper.plist"
    echo ""
    echo "2. Check helper logs:"
    echo "   sudo log show --predicate 'process == \"org.openzfs.automount.helper\"' --last 5m --info"
    echo ""
fi

echo ""
