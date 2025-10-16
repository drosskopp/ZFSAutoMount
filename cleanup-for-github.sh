#!/bin/bash

# Cleanup script to remove personal data before GitHub upload
# This script creates a sanitized version ready for public release

echo "=================================================="
echo "ZFSAutoMount - GitHub Cleanup"
echo "=================================================="
echo ""

# Replacements to make:
# /Users/sysop -> /Users/username (generic)
# sysop -> username (generic)
# tank, media, backup -> example pool names
# tank/enc1, media/enc2 -> example/dataset
# Your Mac mini -> your system (generic)

echo "This script will:"
echo "  1. Replace personal usernames with 'username'"
echo "  2. Replace specific pool names with examples"
echo "  3. Remove any personal file paths"
echo "  4. Update documentation to be generic"
echo ""
echo "The original files will be backed up to .github-backup/"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 1
fi

# Create backup
echo "Creating backup..."
mkdir -p .github-backup
cp -R . .github-backup/ 2>/dev/null || true
echo "✅ Backup created in .github-backup/"
echo ""

# Files to sanitize
FILES_TO_SANITIZE=(
    "CLAUDE.md"
    "Documentation/*.md"
    "Examples/*.conf"
    "Scripts/*.sh"
    "deploy-simple.sh"
    "deploy_to_mini.sh"
    "deploy-updated-app-with-diskmonitor.sh"
)

echo "Sanitizing files..."

# Function to sanitize a file
sanitize_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        return
    fi

    echo "  → $file"

    # Replace personal data
    sed -i '' \
        -e 's|/Users/sysop|/Users/username|g' \
        -e 's/sysop/username/g' \
        -e 's/tank\/enc1/mypool\/dataset1/g' \
        -e 's/media\/enc2/mypool\/dataset2/g' \
        -e 's/backup\/encrypted/mypool\/dataset3/g' \
        -e 's/tank/mypool/g' \
        -e 's/media/storage/g' \
        -e 's/backup/backup/g' \
        -e 's/Mac mini/your macOS system/g' \
        "$file"
}

# Sanitize each file type
for pattern in "${FILES_TO_SANITIZE[@]}"; do
    for file in $pattern; do
        if [ -f "$file" ]; then
            sanitize_file "$file"
        fi
    done
done

echo "✅ Files sanitized"
echo ""

echo "=================================================="
echo "Manual Review Needed"
echo "=================================================="
echo ""
echo "Please manually review these files for any"
echo "remaining personal information:"
echo ""
echo "  1. CLAUDE.md - Project context"
echo "  2. Documentation/PROJECT_SUMMARY.md"
echo "  3. Examples/automount.conf.example"
echo "  4. Any deployment scripts"
echo ""
echo "To restore from backup:"
echo "  cp -R .github-backup/* ."
echo ""
echo "When ready to commit:"
echo "  git add -A"
echo "  git commit -m 'Prepare for GitHub publication'"
echo "  git push origin main"
echo ""
