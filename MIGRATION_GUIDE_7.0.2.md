# Migration Guide - Ásbrú Connection Manager 7.0.2

## Overview

This guide provides detailed instructions for migrating to Ásbrú Connection Manager version 7.0.2 from previous versions. Version 7.0.2 completes the modernization process with restored icon and theme systems, GTK4 compatibility, and enhanced performance.

## Migration Scenarios

### Upgrading from 7.0.1

Version 7.0.2 is fully backward compatible with 7.0.1. The upgrade process is straightforward and requires no configuration changes.

#### Prerequisites
- Backup your configuration (recommended)
- Ensure you have administrative privileges
- Verify system compatibility

#### Step-by-Step Migration

1. **Backup Current Configuration** (Recommended)
   ```bash
   # Backup main configuration
   cp -r ~/.config/pac ~/.config/pac.backup.$(date +%Y%m%d)
   
   # Backup application preferences
   cp -r ~/.local/share/asbru-cm ~/.local/share/asbru-cm.backup.$(date +%Y%m%d) 2>/dev/null || true
   
   echo "Configuration backed up successfully"
   ```

2. **Download Version 7.0.2**
   ```bash
   # For Debian/Ubuntu/PopOS
   wget https://github.com/totoshko88/asbru-cm/releases/latest/download/asbru-cm_7.0.2_all.deb
   
   # For openSUSE
   wget https://github.com/totoshko88/asbru-cm/releases/latest/download/asbru-cm_7.0.2.rpm
   
   # For Universal (AppImage)
   wget https://github.com/totoshko88/asbru-cm/releases/latest/download/asbru-cm_7.0.2.AppImage
   ```

3. **Install New Version**
   ```bash
   # For Debian/Ubuntu/PopOS
   sudo dpkg -i asbru-cm_7.0.2_all.deb
   sudo apt -f install  # Resolve any dependency issues
   
   # For openSUSE
   sudo zypper install asbru-cm_7.0.2.rpm
   
   # For AppImage
   chmod +x asbru-cm_7.0.2.AppImage
   # No installation required, just run directly
   ```

4. **Verify Installation**
   ```bash
   # Check version
   asbru-cm --version
   # Should output: 7.0.2
   
   # Test startup
   asbru-cm --help
   # Should display help without errors
   ```

5. **Test Application**
   ```bash
   # Start application
   asbru-cm
   
   # Verify your connections are visible
   # Test theme switching (if you use custom themes)
   # Verify icons display correctly
   ```

#### What's New in 7.0.2
- **Restored Icon System**: Icons should display more reliably across themes
- **Fixed Dark Themes**: Connection tree text is now properly visible in dark themes
- **Enhanced Performance**: Configuration import is now faster and non-blocking
- **Better Tool Detection**: Application will warn about missing protocol tools

### Upgrading from 7.0.0

If you're upgrading from 7.0.0, you should first review the 7.0.1 changes, then follow the migration steps above.

#### Additional Considerations for 7.0.0 Users
- Review the [7.0.1 Release Notes](RELEASE_NOTES_7.0.1.md) for critical fixes
- Your configuration will be automatically migrated
- Some theme-related preferences may be reset to defaults

### Upgrading from 6.x or Earlier

For users upgrading from version 6.x or earlier, additional steps are required due to significant configuration format changes.

#### Prerequisites
- **Important**: Create a complete backup of your system
- Allow extra time for configuration migration
- Have your connection details available for manual verification

#### Migration Steps

1. **Export Current Configuration**
   ```bash
   # If you have the old version installed
   # Export connections to YAML format
   asbru-cm --export-config ~/asbru-connections-backup.yml
   ```

2. **Backup Everything**
   ```bash
   # Backup old configuration
   cp -r ~/.config/pac ~/.config/pac.v6.backup.$(date +%Y%m%d)
   cp -r ~/.local/share/pac ~/.local/share/pac.v6.backup.$(date +%Y%m%d) 2>/dev/null || true
   ```

3. **Install Version 7.0.2**
   Follow the installation steps from the "Upgrading from 7.0.1" section above.

4. **Import Configuration**
   ```bash
   # Start the application
   asbru-cm
   
   # Use File -> Import to import your backed up configuration
   # The application will automatically convert the format
   ```

5. **Verify Migration**
   - Check that all connections are present
   - Verify connection settings and credentials
   - Test a few connections to ensure they work
   - Review and update any custom preferences

## Configuration Compatibility

### What's Preserved
- **Connection Definitions**: All connection settings, credentials, and parameters
- **Connection Groups**: Folder structure and organization
- **Global Preferences**: Most application preferences and settings
- **Custom Key Bindings**: Keyboard shortcuts and custom bindings
- **Window Layout**: Window size, position, and panel arrangements

### What May Change
- **Theme Settings**: Some theme preferences may reset to defaults
- **Icon Preferences**: Icon theme settings may be updated to new system
- **Advanced Settings**: Some advanced configuration options may be reset

### What's New
- **Enhanced Theme Detection**: Automatic system theme detection and adaptation
- **Improved Icon System**: Better icon compatibility across desktop environments
- **Performance Settings**: New configuration options for multithreaded operations
- **Dependency Validation**: New settings for tool availability checking

## Troubleshooting Migration Issues

### Common Issues and Solutions

#### Issue: Icons Not Displaying After Upgrade
```bash
# Solution: Force icon cache refresh
asbru-cm --force-icon-rescan

# Alternative: Clear icon cache
rm -rf ~/.cache/asbru-cm/icons/
```

#### Issue: Dark Theme Text Not Visible
```bash
# Solution: Reset theme settings
# In application: Preferences -> Look & Feel -> Reset to defaults
# Or manually:
rm ~/.config/pac/theme_cache
```

#### Issue: Application Won't Start
```bash
# Solution: Check dependencies
asbru-cm --verbose

# Check for missing dependencies
sudo apt install libgtk-3-0 libgtk-4-1 libvte-2.91-0
```

#### Issue: Configuration Not Found
```bash
# Solution: Check backup and restore
ls -la ~/.config/pac.backup.*
cp -r ~/.config/pac.backup.YYYYMMDD ~/.config/pac
```

#### Issue: Slow Startup After Upgrade
```bash
# Solution: Clear caches
rm -rf ~/.cache/asbru-cm/
rm ~/.config/pac/theme_cache
```

### Getting Help

If you encounter issues during migration:

1. **Check Debug Output**
   ```bash
   ASBRU_DEBUG=1 asbru-cm
   ```

2. **Review Log Files**
   ```bash
   tail -f ~/.local/share/asbru-cm/debug.log
   ```

3. **Community Support**
   - GitHub Issues: https://github.com/totoshko88/asbru-cm/issues
   - Include your system information and debug output
   - Mention that you're migrating and from which version

## Post-Migration Verification

### Verification Checklist

- [ ] Application starts without errors
- [ ] All connections are visible in the tree
- [ ] Connection details are preserved
- [ ] Test connections work properly
- [ ] Icons display correctly
- [ ] Themes apply properly (try switching themes)
- [ ] Dark theme text is readable
- [ ] Application preferences are preserved
- [ ] Custom key bindings work
- [ ] Window layout is restored

### Performance Verification

- [ ] Application starts quickly
- [ ] Configuration import is fast (if you have large configs)
- [ ] Theme switching is responsive
- [ ] No memory leaks during extended use
- [ ] Protocol connections establish quickly

### Feature Verification

- [ ] All connection protocols work (SSH, RDP, VNC, etc.)
- [ ] Dependency validation shows correct tool status
- [ ] Progress indicators appear during long operations
- [ ] System theme changes are detected automatically
- [ ] Icon themes switch properly

## Rollback Procedure

If you need to rollback to a previous version:

### Rollback to 7.0.1

1. **Stop Application**
   ```bash
   pkill asbru-cm
   ```

2. **Restore Configuration**
   ```bash
   rm -rf ~/.config/pac
   cp -r ~/.config/pac.backup.YYYYMMDD ~/.config/pac
   ```

3. **Install Previous Version**
   ```bash
   # Download and install 7.0.1
   wget https://github.com/totoshko88/asbru-cm/releases/download/v7.0.1/asbru-cm_7.0.1_all.deb
   sudo dpkg -i asbru-cm_7.0.1_all.deb
   ```

### Rollback to 6.x

1. **Restore Full Backup**
   ```bash
   rm -rf ~/.config/pac
   cp -r ~/.config/pac.v6.backup.YYYYMMDD ~/.config/pac
   ```

2. **Install Previous Version**
   Follow the installation procedure for your previous version.

## Best Practices

### Before Migration
- Always create backups
- Test on a non-production system first
- Document your current configuration
- Note any custom modifications

### During Migration
- Follow the steps in order
- Don't skip verification steps
- Keep backups until migration is confirmed successful
- Monitor for any error messages

### After Migration
- Test all critical connections
- Verify performance improvements
- Update any documentation or procedures
- Consider the new features and capabilities

## Support and Resources

### Documentation
- [Release Notes 7.0.2](RELEASE_NOTES_7.0.2.md)
- [Installation Guide](INSTALLATION_GUIDE.md)
- [System Requirements](SYSTEM_REQUIREMENTS.md)
- [Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)

### Community
- **GitHub Repository**: https://github.com/totoshko88/asbru-cm
- **Issue Tracker**: https://github.com/totoshko88/asbru-cm/issues
- **Discussions**: Use GitHub Discussions for questions and community support

### Professional Support
For enterprise users requiring professional support during migration, please contact the maintainers through the GitHub repository.

---

*This migration guide is part of Ásbrú Connection Manager 7.0.2*  
*Last updated: August 22, 2025*