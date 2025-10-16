cask "zfs-automount" do
  version "0.1.0"
  sha256 :no_check

  url "file://#{Dir.pwd}/ZFSAutoMount.app.zip"
  name "ZFS AutoMount"
  desc "Automatic mounting and encryption key management for OpenZFS on macOS"
  homepage "https://github.com/yourusername/zfs-automount"

  depends_on formula: "openzfs"
  depends_on macos: ">= :tahoe"

  app "ZFSAutoMount.app"

  postflight do
    # Install LaunchDaemon for boot-time mounting
    system "/bin/cp", "#{staged_path}/org.openzfs.automount.daemon.plist",
           "/Library/LaunchDaemons/org.openzfs.automount.daemon.plist"
    system "/bin/launchctl", "load", "/Library/LaunchDaemons/org.openzfs.automount.daemon.plist"

    # Create configuration directory
    system "/bin/mkdir", "-p", "/etc/zfs"

    # Create default config if it doesn't exist
    unless File.exist?("/etc/zfs/automount.conf")
      File.write("/etc/zfs/automount.conf", <<~CONFIG)
        # ZFS AutoMount Configuration
        # Format: pool/dataset option=value

        # Example:
        # tank/enc1 keylocation=file:///path/to/keyfile
        # media/enc2 readonly=on
      CONFIG
    end

    puts "ZFS AutoMount installed successfully!"
    puts "The app will start automatically on boot."
    puts "You can also launch it from /Applications/ZFSAutoMount.app"
  end

  uninstall_preflight do
    system "/bin/launchctl", "unload", "/Library/LaunchDaemons/org.openzfs.automount.daemon.plist"
    system "/bin/rm", "-f", "/Library/LaunchDaemons/org.openzfs.automount.daemon.plist"
  end

  zap trash: [
    "~/Library/Preferences/org.openzfs.automount.plist",
    "~/Library/Caches/org.openzfs.automount",
    "/var/log/zfs-automount.log",
    "/var/log/zfs-automount-error.log",
  ]
end
