#!/bin/bash

# Comprehensive GitHub preparation script
# Cleans up personal data, removes temporary files, and prepares for public release

set -e

echo "=================================================="
echo "ZFSAutoMount - GitHub Preparation"
echo "=================================================="
echo ""

echo "This script will:"
echo "  1. Remove session-specific and local files"
echo "  2. Sanitize personal data in documentation"
echo "  3. Update .gitignore for privacy"
echo "  4. Create a clean README.md"
echo "  5. Organize documentation"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 1
fi

# Step 1: Remove session/local-specific files
echo "Step 1: Removing session-specific files..."

rm -f CURRENT_STATUS.md
rm -f SESSION_SUMMARY.md
rm -f NEXT_SESSION_CHECKLIST.md
rm -f BUILD_FIXES.md
rm -f HELPER_INSTALLATION.md
rm -f check-boot-automation.sh
rm -f cleanup_zfs_services.sh
rm -f install_helper_manual.sh
rm -f INSTALL_HELPER_ON_MINI.sh
rm -f INSTALL_ON_MINI.sh
rm -f UPDATE_ON_MINI.sh
rm -f INSTALL_TO_MINI.md
rm -f deploy_to_mini.sh
rm -f deploy-updated-app-with-diskmonitor.sh
rm -f DEPLOY.sh

echo "✅ Session files removed"
echo ""

# Step 2: Move documentation to proper structure
echo "Step 2: Organizing documentation..."

# Move design docs to Documentation/Design/
mkdir -p Documentation/Design
mv -f SCRUB_TRIM_DESIGN.md Documentation/Design/ 2>/dev/null || true
mv -f BOOT_TOGGLES_EXPLAINED.md Documentation/Design/ 2>/dev/null || true

# Move implementation docs to Documentation/Implementation/
mkdir -p Documentation/Implementation
mv -f ENCRYPTION_TAB_ENHANCEMENT.md Documentation/Implementation/ 2>/dev/null || true
mv -f MENU_ENHANCEMENTS.md Documentation/Implementation/ 2>/dev/null || true
mv -f REALTIME_MONITORING.md Documentation/Implementation/ 2>/dev/null || true
mv -f PREFERENCES_IMPLEMENTATION.md Documentation/Implementation/ 2>/dev/null || true
mv -f HELPER_INSTALLATION_FIX.md Documentation/Implementation/ 2>/dev/null || true

# Keep these at root
# - README.md (will be rewritten)
# - LICENSE
# - CONTRIBUTING.md
# - CHANGELOG.md

# Keep Documentation/ files
# - Documentation/README.md
# - Documentation/BUILD.md
# - Documentation/USAGE.md
# - Documentation/PROJECT_SUMMARY.md
# - Documentation/QUICKSTART.md
# - Documentation/DEPLOYMENT_WORKFLOW.md

echo "✅ Documentation organized"
echo ""

# Step 3: Update .gitignore
echo "Step 3: Updating .gitignore..."

cat > .gitignore << 'EOF'
# Xcode
build/
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/
*.xccheckout
*.moved-aside
DerivedData/
*.hmap
*.ipa
*.xcuserstate
*.xcscmblueprint

# macOS
.DS_Store
.AppleDouble
.LSOverride
._*

# Thumbnails
Thumbs.db

# Files that might appear in the root of a volume
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent

# Directories potentially created on remote AFP share
.AppleDB
.AppleDesktop
Network Trash Folder
Temporary Items
.apdisk

# Session and local files
CURRENT_STATUS.md
SESSION_SUMMARY.md
*_SUMMARY.md
.github-backup/

# Local deployment scripts (user-specific)
deploy_to_*.sh
*_ON_MINI.*

# Backup files
*.backup
*.bak
*~

# Log files
*.log

# Personal data
/etc/zfs/automount.conf
EOF

echo "✅ .gitignore updated"
echo ""

# Step 4: Sanitize remaining files
echo "Step 4: Sanitizing personal data..."

# List of files that might contain personal data
SANITIZE_FILES=(
    "CLAUDE.md"
    "Documentation/BUILD.md"
    "Documentation/QUICKSTART.md"
    "Documentation/DEPLOYMENT_WORKFLOW.md"
    "Examples/automount.conf.example"
    "deploy-simple.sh"
)

for file in "${SANITIZE_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  → Sanitizing $file"

        # Replace personal paths and names with generic ones
        sed -i '' \
            -e 's|/Users/sysop|/Users/yourname|g' \
            -e 's/sysop/yourname/g' \
            "$file"
    fi
done

echo "✅ Personal data sanitized"
echo ""

# Step 5: Update CLAUDE.md for public context
echo "Step 5: Updating CLAUDE.md..."

# Add disclaimer at top
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << 'EOF'
# ZFSAutoMount - Project Context for Claude

> **Note**: This file provides context for AI assistants (like Claude Code) when working on this project.
> It contains the project's architecture, design decisions, and development guidelines.

EOF

cat CLAUDE.md >> "$TEMP_FILE"
mv "$TEMP_FILE" CLAUDE.md

echo "✅ CLAUDE.md updated"
echo ""

echo "=================================================="
echo "✅ GitHub Preparation Complete!"
echo "=================================================="
echo ""
echo "Summary of changes:"
echo "  • Session-specific files removed"
echo "  • Documentation organized into subdirectories"
echo "  • Personal data sanitized"
echo "  • .gitignore updated for privacy"
echo ""
echo "Next steps:"
echo "  1. Review the changes:"
echo "     git status"
echo ""
echo "  2. Check remaining files manually:"
echo "     grep -r \"sysop\\|tank\\|media\" --include=\"*.md\" --include=\"*.swift\" ."
echo ""
echo "  3. Test that everything still builds:"
echo "     xcodebuild -scheme ZFSAutoMount -configuration Debug build"
echo ""
echo "  4. Commit and push:"
echo "     git add -A"
echo "     git commit -m \"Prepare project for GitHub publication\""
echo "     git push origin main"
echo ""
