# Ásbrú Connection Manager v7.0.1 - Troubleshooting Guide

## Quick Diagnostic Commands

### System Information
```bash
# Check system compatibility
echo "OS: $(lsb_release -d | cut -f2)"
echo "Desktop: $XDG_CURRENT_DESKTOP"
echo "Display Server: $([ -n "$WAYLAND_DISPLAY" ] && echo "Wayland" || echo "X11")"
echo "GTK4 Available: $(pkg-config --exists gtk4 && echo "Yes" || echo "No")"
```

### Package Status
```bash
# Verify installation
dpkg -l | grep asbru-cm
apt-cache policy asbru-cm

# Check file integrity
dpkg -V asbru-cm
```

### Application Status
```bash
# Test basic functionality
asbru-cm --version
asbru-cm --help

# Check dependencies
ldd /opt/asbru/asbru-cm | grep "not found"
```

## Installation Issues

### Problem: Package Installation Fails

#### Symptom
```
dpkg: dependency problems prevent configuration of asbru-cm
```

#### Solution
```bash
# Method 1: Fix dependencies
sudo apt update
sudo apt install -f

# Method 2: Force installation (use with caution)
sudo dpkg -i --force-depends asbru-cm_7.0.0-1_all.deb
sudo apt install -f

# Method 3: Clean and retry
sudo apt autoremove
sudo apt autoclean
sudo dpkg -i asbru-cm_7.0.0-1_all.deb
```

### Problem: GTK4 Dependencies Missing

#### Symptom
```
Package libgtk4-perl is not available
```

#### Solution
```bash
# For PopOS 24.04
sudo apt update
sudo apt install libgtk-4-1 libgtk4-perl

# For older systems (fallback to GTK3)
sudo apt install libgtk3-perl libgtk3-simplelist-perl

# Enable universe repository if needed
sudo add-apt-repository universe
sudo apt update
```

### Problem: VTE Terminal Library Issues

#### Symptom
```
Can't locate Vte.pm in @INC
```

#### Solution
```bash
# Install VTE bindings
sudo apt install gir1.2-vte-2.91 libvte-2.91-0

# For GTK4 VTE (if available)
sudo apt install libvte-2.91-gtk4-0

# Verify installation
perl -MGlib::Object::Introspection -e "print 'VTE OK\n'"
```

## Application Launch Issues

### Problem: Application Won't Start

#### Symptom
```bash
$ asbru-cm
bash: asbru-cm: command not found
```

#### Solution
```bash
# Check if binary exists
ls -la /opt/asbru/asbru-cm

# Add to PATH if needed
export PATH="/opt/asbru:$PATH"

# Or create symlink
sudo ln -sf /opt/asbru/asbru-cm /usr/local/bin/asbru-cm

# Update desktop database
sudo update-desktop-database
```

### Problem: Perl Module Errors

#### Symptom
```
Can't locate Gtk4.pm in @INC
```

#### Solution
```bash
# Install missing Perl modules
sudo apt install libgtk4-perl libglib-perl libcairo-perl

# For GTK3 fallback
sudo apt install libgtk3-perl

# Check Perl module path
perl -V | grep @INC

# Install via CPAN if needed (last resort)
sudo cpan install Gtk4
```

### Problem: Permission Errors

#### Symptom
```
Permission denied: /opt/asbru/asbru-cm
```

#### Solution
```bash
# Fix permissions
sudo chmod +x /opt/asbru/asbru-cm
sudo chown root:root /opt/asbru/asbru-cm

# Check file permissions
ls -la /opt/asbru/asbru-cm

# Reinstall if permissions are corrupted
sudo dpkg --purge asbru-cm
sudo dpkg -i asbru-cm_7.0.0-1_all.deb
```

## Display and GUI Issues

### Problem: Application Appears Blank or Corrupted

#### Symptom
- Window opens but shows no content
- Garbled or missing interface elements

#### Solution
```bash
# Method 1: Force X11 backend
export GDK_BACKEND=x11
asbru-cm

# Method 2: Reset GTK settings
rm -rf ~/.config/gtk-4.0/
rm -rf ~/.config/gtk-3.0/

# Method 3: Disable hardware acceleration
export GDK_RENDERING=software
asbru-cm

# Method 4: Check theme compatibility
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
```

### Problem: Wayland Compatibility Issues

#### Symptom
- Window management problems
- Clipboard not working
- File dialogs not appearing

#### Solution
```bash
# Install Wayland portal support
sudo apt install xdg-desktop-portal xdg-desktop-portal-gtk

# For Cosmic desktop
sudo apt install xdg-desktop-portal-cosmic

# Force Wayland backend
export GDK_BACKEND=wayland
asbru-cm

# Check portal status
systemctl --user status xdg-desktop-portal
```

### Problem: System Tray Not Working

#### Symptom
- No system tray icon appears
- Cannot minimize to tray

#### Solution for Cosmic Desktop
```bash
# Cosmic uses different panel system
# Application automatically falls back to menu bar
# This is expected behavior - no action needed
```

#### Solution for Other Desktops
```bash
# Install system tray support
sudo apt install gnome-shell-extension-appindicator

# For KDE
sudo apt install plasma-workspace

# Check if tray is available
ps aux | grep -i tray
```

## Connection and Protocol Issues

### Problem: SSH Connections Fail

#### Symptom
```
Connection refused or timeout errors
```

#### Solution
```bash
# Check SSH client
which ssh
ssh -V

# Install OpenSSH client if missing
sudo apt install openssh-client

# Test direct SSH connection
ssh -v user@hostname

# Check network connectivity
ping hostname
telnet hostname 22
```

### Problem: RDP Connections Not Working

#### Symptom
```
RDP client not found or connection fails
```

#### Solution
```bash
# Install RDP client for Wayland
sudo apt install freerdp2-wayland

# For X11 systems
sudo apt install freerdp2-x11 rdesktop

# Test RDP client directly
xfreerdp /v:hostname /u:username

# Check available RDP clients
which xfreerdp rdesktop
```

### Problem: VNC Connections Fail

#### Symptom
```
VNC viewer not available
```

#### Solution
```bash
# Install VNC viewer
sudo apt install tigervnc-viewer

# Alternative viewers
sudo apt install xtightvncviewer vinagre

# Test VNC connection
vncviewer hostname:5901
```

## Configuration and Data Issues

### Problem: Configuration Migration Fails

#### Symptom
- Settings not preserved from v6.x
- Connection list empty after upgrade

#### Solution
```bash
# Check configuration directory
ls -la ~/.config/asbru/

# Backup current config
cp -r ~/.config/asbru/ ~/.config/asbru.backup

# Force configuration migration
asbru-cm --migrate-config

# Manual migration if needed
cp ~/.config/pac/ ~/.config/asbru/ 2>/dev/null || true
```

### Problem: Encrypted Passwords Not Working

#### Symptom
- Cannot decrypt saved passwords
- Authentication failures

#### Solution
```bash
# Run encryption migration utility
/opt/asbru/utils/migrate_encryption.pl

# Check crypto modules
perl -MCrypt::Cipher::AES -e "print 'AES OK\n'"
perl -MCrypt::PBKDF2 -e "print 'PBKDF2 OK\n'"

# Install missing crypto modules
sudo apt install libcrypt-cipher-aes-perl libcrypt-pbkdf2-perl
```

### Problem: Keyring Integration Issues

#### Symptom
- Cannot access system keyring
- Password storage errors

#### Solution
```bash
# For GNOME keyring
sudo apt install gnome-keyring libsecret-1-0

# For KDE wallet
sudo apt install kwalletmanager

# Check keyring status
systemctl --user status gnome-keyring-daemon

# Test keyring access
secret-tool store --label="test" service test username test
secret-tool lookup service test username test
```

## Performance Issues

### Problem: Slow Startup

#### Symptom
- Application takes long time to start
- High CPU usage during startup

#### Solution
```bash
# Check system resources
free -h
df -h

# Profile startup time
time asbru-cm --version

# Clear cache
rm -rf ~/.cache/asbru/

# Disable unnecessary features
# Edit ~/.config/asbru/asbru.yml and disable:
# - statistics collection
# - automatic updates
# - theme detection
```

### Problem: High Memory Usage

#### Symptom
- Excessive RAM consumption
- System becomes slow

#### Solution
```bash
# Monitor memory usage
ps aux | grep asbru-cm
top -p $(pgrep asbru-cm)

# Reduce memory usage
# In application preferences:
# - Reduce connection history
# - Disable screenshots
# - Limit concurrent connections

# Check for memory leaks
valgrind --tool=memcheck asbru-cm
```

## Desktop Environment Specific Issues

### Cosmic Desktop

#### Problem: Panel Integration Not Working
```bash
# Check Cosmic version
cosmic-panel --version

# Restart panel
systemctl --user restart cosmic-panel

# Use fallback menu integration
# This is automatic - no action needed
```

### GNOME/Wayland

#### Problem: File Dialogs Not Appearing
```bash
# Install portal backend
sudo apt install xdg-desktop-portal-gnome

# Restart portal service
systemctl --user restart xdg-desktop-portal
```

### KDE Plasma

#### Problem: Theme Integration Issues
```bash
# Install Qt/GTK theme bridge
sudo apt install kde-config-gtk-style

# Configure GTK themes in KDE
systemsettings5
```

## Network and Firewall Issues

### Problem: Connection Blocked by Firewall

#### Symptom
- Connections timeout
- "Connection refused" errors

#### Solution
```bash
# Check firewall status
sudo ufw status

# Allow SSH port
sudo ufw allow 22

# Allow RDP port
sudo ufw allow 3389

# Allow VNC ports
sudo ufw allow 5900:5910/tcp

# Check iptables rules
sudo iptables -L
```

### Problem: DNS Resolution Issues

#### Symptom
- Cannot connect to hostnames
- IP addresses work but hostnames don't

#### Solution
```bash
# Test DNS resolution
nslookup hostname
dig hostname

# Check DNS configuration
cat /etc/resolv.conf

# Flush DNS cache
sudo systemd-resolve --flush-caches

# Use alternative DNS
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
```

## Advanced Troubleshooting

### Debug Mode

#### Enable Debug Output
```bash
# Set debug environment
export ASBRU_DEBUG=1
export GTK_DEBUG=interactive

# Run with verbose output
asbru-cm --debug 2>&1 | tee debug.log
```

#### Analyze Debug Log
```bash
# Check for common errors
grep -i error debug.log
grep -i warning debug.log
grep -i fail debug.log

# Check module loading
grep -i "loading\|module" debug.log
```

### System Compatibility Check

#### Create Compatibility Report
```bash
#!/bin/bash
echo "=== Ásbrú CM Compatibility Report ===" > compatibility_report.txt
echo "Date: $(date)" >> compatibility_report.txt
echo "" >> compatibility_report.txt

echo "System Information:" >> compatibility_report.txt
lsb_release -a >> compatibility_report.txt
uname -a >> compatibility_report.txt
echo "" >> compatibility_report.txt

echo "Desktop Environment:" >> compatibility_report.txt
echo "XDG_CURRENT_DESKTOP: $XDG_CURRENT_DESKTOP" >> compatibility_report.txt
echo "WAYLAND_DISPLAY: $WAYLAND_DISPLAY" >> compatibility_report.txt
echo "DISPLAY: $DISPLAY" >> compatibility_report.txt
echo "" >> compatibility_report.txt

echo "GTK Information:" >> compatibility_report.txt
pkg-config --modversion gtk4 2>/dev/null >> compatibility_report.txt || echo "GTK4 not found" >> compatibility_report.txt
pkg-config --modversion gtk+-3.0 2>/dev/null >> compatibility_report.txt || echo "GTK3 not found" >> compatibility_report.txt
echo "" >> compatibility_report.txt

echo "Package Status:" >> compatibility_report.txt
dpkg -l | grep asbru-cm >> compatibility_report.txt
echo "" >> compatibility_report.txt

echo "Dependencies:" >> compatibility_report.txt
ldd /opt/asbru/asbru-cm >> compatibility_report.txt 2>&1

cat compatibility_report.txt
```

### Recovery Procedures

#### Complete Reset
```bash
# Backup current configuration
mkdir -p ~/asbru-backup
cp -r ~/.config/asbru/ ~/asbru-backup/ 2>/dev/null || true

# Remove application
sudo apt purge asbru-cm

# Clean configuration
rm -rf ~/.config/asbru/
rm -rf ~/.local/share/asbru/
rm -rf ~/.cache/asbru/

# Reinstall
sudo dpkg -i asbru-cm_7.0.0-1_all.deb
sudo apt install -f

# Restore configuration if needed
cp -r ~/asbru-backup/asbru/ ~/.config/ 2>/dev/null || true
```

## Getting Help

### Before Reporting Issues

1. Check this troubleshooting guide
2. Search existing GitHub issues
3. Run compatibility check script
4. Collect debug logs

### Information to Include in Bug Reports

```bash
# System information
lsb_release -a
uname -a
echo $XDG_CURRENT_DESKTOP

# Package information
dpkg -l | grep asbru-cm
apt-cache policy asbru-cm

# Error logs
asbru-cm --debug 2>&1 | tail -50

# Dependency check
ldd /opt/asbru/asbru-cm | grep "not found"
```

### Contact Information

- **GitHub Issues**: https://github.com/your-repo/asbru-cm/issues
- **Community Forum**: https://community.asbru-cm.net/
- **IRC Channel**: #asbru-cm on Libera.Chat
- **Email Support**: support@asbru-cm.net

---

This troubleshooting guide covers the most common issues encountered with Ásbrú Connection Manager v7.0.0. For additional help, please consult the project documentation or contact the development team.