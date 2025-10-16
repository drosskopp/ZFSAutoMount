#!/bin/bash

# Script to add DiskTypeDetector.swift to Xcode project
# This is a helper - you still need to manually add the file in Xcode UI

echo "⚠️  DiskTypeDetector.swift needs to be added to the Xcode project"
echo ""
echo "Steps to add the file:"
echo "1. Open Xcode project (already opened)"
echo "2. In the Project Navigator (left sidebar), right-click on 'ZFSAutoMount' folder"
echo "3. Select 'Add Files to \"ZFSAutoMount\"...'"
echo "4. Navigate to and select: ZFSAutoMount/DiskTypeDetector.swift"
echo "5. Make sure 'ZFSAutoMount' target is checked"
echo "6. Click 'Add'"
echo ""
echo "OR simply drag DiskTypeDetector.swift from Finder into the Xcode project navigator"
echo ""
echo "File location: $(pwd)/ZFSAutoMount/DiskTypeDetector.swift"
