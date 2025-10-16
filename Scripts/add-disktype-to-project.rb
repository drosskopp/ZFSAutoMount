#!/usr/bin/env ruby

# Script to add DiskTypeDetector.swift to Xcode project programmatically
# Requires: gem install xcodeproj

begin
  require 'xcodeproj'
rescue LoadError
  puts "❌ Error: xcodeproj gem not installed"
  puts ""
  puts "To install it, run:"
  puts "  sudo gem install xcodeproj"
  puts ""
  puts "Then run this script again."
  exit 1
end

project_path = 'ZFSAutoMount.xcodeproj'
file_path = 'ZFSAutoMount/DiskTypeDetector.swift'

puts "Opening Xcode project..."
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'ZFSAutoMount' }
if target.nil?
  puts "❌ Error: Could not find 'ZFSAutoMount' target"
  exit 1
end

# Find the ZFSAutoMount group
group = project.main_group.find_subpath('ZFSAutoMount', true)
if group.nil?
  puts "❌ Error: Could not find 'ZFSAutoMount' group"
  exit 1
end

# Check if file is already in project
existing_file = group.files.find { |f| f.path == 'DiskTypeDetector.swift' }
if existing_file
  puts "✅ DiskTypeDetector.swift is already in the project"
  exit 0
end

puts "Adding DiskTypeDetector.swift to project..."
file_ref = group.new_file(file_path)

puts "Adding to ZFSAutoMount target..."
target.add_file_references([file_ref])

puts "Saving project..."
project.save

puts "✅ Successfully added DiskTypeDetector.swift to the project!"
puts ""
puts "Now you can build the project:"
puts "  xcodebuild -scheme ZFSAutoMount -configuration Debug build"
