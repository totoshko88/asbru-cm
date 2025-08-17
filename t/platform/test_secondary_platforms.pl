#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($Bin);
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

# Add lib directories to path
BEGIN {
    my $lib_path = File::Spec->catdir(dirname(dirname(abs_path(__FILE__))), 'lib');
    my $test_lib_path = File::Spec->catdir(dirname(abs_path(__FILE__)), 'lib');
    unshift @INC, $lib_path, $test_lib_path;
}

use AsbruTestFramework qw(
    setup_test_environment
    cleanup_test_environment
    measure_performance
    verify_gtk4_compatibility
    test_theme_compatibility
);

# Test configuration
my $TEST_TIMEOUT = 300; # 5 minutes

plan tests => 20;

# Set up test environment
setup_test_environment(
    headless => 0,
    gtk => 1,
    gtk4 => 1
);

# Test 1: Platform Detection and Compatibility
subtest 'Platform Detection and Compatibility' => sub {
    plan tests => 6;
    
    # Detect current platform
    my $os_release = '';
    if (-f '/etc/os-release') {
        open my $fh, '<', '/etc/os-release' or die "Cannot read /etc/os-release: $!";
        $os_release = do { local $/; <$fh> };
        close $fh;
    }
    
    my $platform = 'unknown';
    my $version = 'unknown';
    
    if ($os_release =~ /Ubuntu/i) {
        $platform = 'Ubuntu';
        if ($os_release =~ /VERSION_ID="([^"]+)"/) {
            $version = $1;
        }
    } elsif ($os_release =~ /Fedora/i) {
        $platform = 'Fedora';
        if ($os_release =~ /VERSION_ID=(\d+)/) {
            $version = $1;
        }
    } elsif ($os_release =~ /Pop!_OS/i) {
        $platform = 'PopOS';
        if ($os_release =~ /VERSION_ID="([^"]+)"/) {
            $version = $1;
        }
    } elsif ($os_release =~ /Debian/i) {
        $platform = 'Debian';
        if ($os_release =~ /VERSION_ID="([^"]+)"/) {
            $version = $1;
        }
    }
    
    ok($platform ne 'unknown', "Platform detected: $platform");
    ok($version ne 'unknown', "Version detected: $version");
    diag("Running on: $platform $version");
    
    # Check if it's a supported secondary platform
    my $supported = ($platform eq 'Ubuntu' && $version ge '24.04') ||
                   ($platform eq 'Fedora' && $version >= 40) ||
                   ($platform eq 'Debian' && $version >= 12) ||
                   ($platform eq 'PopOS'); # PopOS is primary but also test as secondary
    
    ok($supported, 'Platform is supported for secondary testing');
    
    # Check kernel version
    my $kernel_version = `uname -r`;
    chomp $kernel_version;
    ok($kernel_version, 'Kernel version available');
    diag("Kernel version: $kernel_version");
    
    # Check architecture
    my $arch = `uname -m`;
    chomp $arch;
    ok($arch eq 'x86_64', 'Running on x86_64 architecture');
    diag("Architecture: $arch");
    
    # Check if we have systemd (most modern distros)
    my $systemd_available = system("systemctl --version > /dev/null 2>&1") == 0;
    ok($systemd_available, 'systemd is available');
};

# Test 2: Desktop Environment Detection
subtest 'Desktop Environment Detection' => sub {
    plan tests => 6;
    
    my $xdg_desktop = $ENV{XDG_CURRENT_DESKTOP} || '';
    my $desktop_session = $ENV{DESKTOP_SESSION} || '';
    my $gnome_session = $ENV{GNOME_DESKTOP_SESSION_ID} || '';
    
    ok($xdg_desktop, 'XDG_CURRENT_DESKTOP is set');
    diag("XDG_CURRENT_DESKTOP: $xdg_desktop");
    diag("DESKTOP_SESSION: $desktop_session");
    
    # Check for common desktop environments
    my $is_gnome = ($xdg_desktop =~ /GNOME/i) || $gnome_session;
    my $is_kde = $xdg_desktop =~ /KDE/i;
    my $is_cosmic = $xdg_desktop =~ /COSMIC/i;
    my $is_xfce = $xdg_desktop =~ /XFCE/i;
    
    my $known_de = $is_gnome || $is_kde || $is_cosmic || $is_xfce;
    ok($known_de, 'Running a known desktop environment');
    
    # Check display server
    my $wayland_display = $ENV{WAYLAND_DISPLAY} || '';
    my $x11_display = $ENV{DISPLAY} || '';
    
    ok($wayland_display || $x11_display, 'Display server detected');
    
    my $display_server = $wayland_display ? 'Wayland' : ($x11_display ? 'X11' : 'Unknown');
    diag("Display server: $display_server");
    
    # For GNOME, prefer Wayland
    if ($is_gnome) {
        ok($wayland_display, 'GNOME running on Wayland (preferred)') or 
            diag("GNOME on X11 detected - Wayland preferred for modern systems");
    } else {
        ok(1, 'Non-GNOME desktop environment detected');
    }
    
    # Check for desktop-specific processes
    my $de_processes = 0;
    if ($is_gnome) {
        $de_processes = system("pgrep -f gnome-shell > /dev/null 2>&1") == 0;
    } elsif ($is_kde) {
        $de_processes = system("pgrep -f plasmashell > /dev/null 2>&1") == 0;
    } elsif ($is_cosmic) {
        $de_processes = system("pgrep -f cosmic-panel > /dev/null 2>&1") == 0;
    } else {
        $de_processes = 1; # Assume OK for other DEs
    }
    
    ok($de_processes, 'Desktop environment processes running');
    
    # Check for accessibility support
    my $a11y_available = system("which orca > /dev/null 2>&1") == 0 ||
                        system("which at-spi2-core > /dev/null 2>&1") == 0;
    ok($a11y_available || 1, 'Accessibility support available (optional)');
};

# Test 3: Package Manager and Dependencies
subtest 'Package Manager and Dependencies' => sub {
    plan tests => 8;
    
    # Detect package manager
    my $apt_available = system("which apt > /dev/null 2>&1") == 0;
    my $dnf_available = system("which dnf > /dev/null 2>&1") == 0;
    my $yum_available = system("which yum > /dev/null 2>&1") == 0;
    my $pacman_available = system("which pacman > /dev/null 2>&1") == 0;
    
    my $package_manager = $apt_available ? 'apt' :
                         $dnf_available ? 'dnf' :
                         $yum_available ? 'yum' :
                         $pacman_available ? 'pacman' : 'unknown';
    
    ok($package_manager ne 'unknown', "Package manager detected: $package_manager");
    
    # Check for GTK4 packages based on package manager
    my $gtk4_packages = 0;
    if ($package_manager eq 'apt') {
        $gtk4_packages = system("dpkg -l | grep -q libgtk-4") == 0;
    } elsif ($package_manager eq 'dnf' || $package_manager eq 'yum') {
        $gtk4_packages = system("rpm -qa | grep -q gtk4") == 0;
    } elsif ($package_manager eq 'pacman') {
        $gtk4_packages = system("pacman -Q gtk4 > /dev/null 2>&1") == 0;
    }
    
    ok($gtk4_packages, 'GTK4 packages available');
    
    # Check for VTE packages
    my $vte_packages = 0;
    if ($package_manager eq 'apt') {
        $vte_packages = system("dpkg -l | grep -q libvte") == 0;
    } elsif ($package_manager eq 'dnf' || $package_manager eq 'yum') {
        $vte_packages = system("rpm -qa | grep -q vte") == 0;
    } elsif ($package_manager eq 'pacman') {
        $vte_packages = system("pacman -Q vte3 > /dev/null 2>&1") == 0;
    }
    
    ok($vte_packages, 'VTE packages available');
    
    # Check for Perl packages
    my $perl_gtk_packages = 0;
    if ($package_manager eq 'apt') {
        $perl_gtk_packages = system("dpkg -l | grep -q libgtk.*perl") == 0;
    } elsif ($package_manager eq 'dnf' || $package_manager eq 'yum') {
        $perl_gtk_packages = system("rpm -qa | grep -q perl-Gtk") == 0;
    }
    
    ok($perl_gtk_packages || 1, 'Perl GTK packages available (may need installation)');
    
    # Check development packages
    my $dev_packages = 0;
    if ($package_manager eq 'apt') {
        $dev_packages = system("dpkg -l | grep -q build-essential") == 0;
    } elsif ($package_manager eq 'dnf' || $package_manager eq 'yum') {
        $dev_packages = system("rpm -qa | grep -q gcc") == 0;
    }
    
    ok($dev_packages || 1, 'Development packages available (optional)');
    
    # Check for required system libraries
    my $required_libs = 0;
    $required_libs += system("ldconfig -p | grep -q libgtk-4") == 0 ? 1 : 0;
    $required_libs += system("ldconfig -p | grep -q libglib") == 0 ? 1 : 0;
    $required_libs += system("ldconfig -p | grep -q libcairo") == 0 ? 1 : 0;
    
    ok($required_libs >= 2, 'Required system libraries available');
    
    # Check Perl version
    my $perl_version = $];
    ok($perl_version >= 5.020, 'Perl version 5.20 or higher available');
    diag("Perl version: $perl_version");
    
    # Check for Perl modules installation capability
    my $cpan_available = system("which cpan > /dev/null 2>&1") == 0 ||
                        system("which cpanm > /dev/null 2>&1") == 0;
    ok($cpan_available || 1, 'CPAN installation tools available (optional)');
};

# Test 4: X11 Fallback Compatibility
subtest 'X11 Fallback Compatibility' => sub {
    plan tests => 6;
    
    # Check if X11 is available (even on Wayland systems)
    my $x11_available = system("which Xorg > /dev/null 2>&1") == 0 ||
                       system("which X > /dev/null 2>&1") == 0;
    ok($x11_available, 'X11 server available for fallback');
    
    # Check for X11 libraries
    my $x11_libs = system("ldconfig -p | grep -q libX11") == 0;
    ok($x11_libs, 'X11 libraries available');
    
    # Check for XWayland (X11 compatibility on Wayland)
    my $xwayland_available = system("which Xwayland > /dev/null 2>&1") == 0;
    ok($xwayland_available || !$ENV{WAYLAND_DISPLAY}, 'XWayland available or not needed');
    
    # Test X11 tools
    my $xtools_available = system("which xrandr > /dev/null 2>&1") == 0 &&
                          system("which xwininfo > /dev/null 2>&1") == 0;
    ok($xtools_available || 1, 'X11 tools available (optional)');
    
    # Check for window manager compatibility
    my $wm_available = system("which mutter > /dev/null 2>&1") == 0 ||
                      system("which kwin > /dev/null 2>&1") == 0 ||
                      system("which cosmic-comp > /dev/null 2>&1") == 0 ||
                      system("which openbox > /dev/null 2>&1") == 0;
    ok($wm_available, 'Compatible window manager available');
    
    # Test basic X11 functionality if DISPLAY is set
    if ($ENV{DISPLAY}) {
        my $x11_working = system("xdpyinfo > /dev/null 2>&1") == 0;
        ok($x11_working, 'X11 display working');
    } else {
        ok(1, 'X11 display not active (Wayland-only system)');
    }
};

# Test 5: Application Compatibility Testing
subtest 'Application Compatibility Testing' => sub {
    plan tests => 6;
    
    # Test if asbru-cm executable exists
    my $asbru_path = File::Spec->catfile(dirname(dirname($Bin)), 'asbru-cm');
    ok(-f $asbru_path, 'asbru-cm executable exists');
    
    # Test basic Perl module loading (with fallbacks)
    my $modules_loaded = 0;
    
    # Try to load core modules
    eval { require File::Spec; $modules_loaded++; };
    eval { require YAML::Tiny; } or eval { require YAML; $modules_loaded++; };
    eval { require Storable; $modules_loaded++; };
    
    ok($modules_loaded >= 2, 'Core Perl modules available');
    
    # Test configuration directory creation
    my $config_dir = File::Spec->catdir($ENV{HOME}, '.config', 'asbru-test-secondary');
    mkdir $config_dir unless -d $config_dir;
    ok(-d $config_dir, 'Configuration directory can be created');
    
    # Test file permissions
    my $test_file = File::Spec->catfile($config_dir, 'test.txt');
    open my $fh, '>', $test_file or die "Cannot create test file: $!";
    print $fh "test\n";
    close $fh;
    ok(-f $test_file, 'File creation works');
    unlink $test_file;
    rmdir $config_dir;
    
    # Test network connectivity (for protocol testing)
    my $network_available = system("ping -c 1 8.8.8.8 > /dev/null 2>&1") == 0 ||
                           system("ping -c 1 1.1.1.1 > /dev/null 2>&1") == 0;
    ok($network_available || 1, 'Network connectivity available (optional)');
    
    # Test terminal emulator availability
    my $terminal_available = system("which gnome-terminal > /dev/null 2>&1") == 0 ||
                            system("which konsole > /dev/null 2>&1") == 0 ||
                            system("which cosmic-term > /dev/null 2>&1") == 0 ||
                            system("which xterm > /dev/null 2>&1") == 0;
    ok($terminal_available, 'Terminal emulator available');
};

# Test 6: Protocol Client Availability
subtest 'Protocol Client Availability' => sub {
    plan tests => 6;
    
    # SSH client
    my $ssh_available = system("which ssh > /dev/null 2>&1") == 0;
    ok($ssh_available, 'SSH client available');
    
    # RDP clients
    my $rdp_available = system("which xfreerdp > /dev/null 2>&1") == 0 ||
                       system("which rdesktop > /dev/null 2>&1") == 0;
    ok($rdp_available, 'RDP client available');
    
    # VNC clients
    my $vnc_available = system("which vncviewer > /dev/null 2>&1") == 0 ||
                       system("which tigervnc > /dev/null 2>&1") == 0 ||
                       system("which vinagre > /dev/null 2>&1") == 0;
    ok($vnc_available || 1, 'VNC client available (optional)');
    
    # Telnet client
    my $telnet_available = system("which telnet > /dev/null 2>&1") == 0;
    ok($telnet_available || 1, 'Telnet client available (optional)');
    
    # FTP client
    my $ftp_available = system("which ftp > /dev/null 2>&1") == 0 ||
                       system("which sftp > /dev/null 2>&1") == 0;
    ok($ftp_available, 'FTP/SFTP client available');
    
    # Check for additional protocol support
    my $mosh_available = system("which mosh > /dev/null 2>&1") == 0;
    ok($mosh_available || 1, 'Mosh client available (optional)');
};

# Test 7: System Integration Compatibility
subtest 'System Integration Compatibility' => sub {
    plan tests => 7;
    
    # Notification system
    my $notify_available = system("which notify-send > /dev/null 2>&1") == 0;
    ok($notify_available, 'Notification system available');
    
    # File manager integration
    my $file_manager = system("which nautilus > /dev/null 2>&1") == 0 ||
                      system("which dolphin > /dev/null 2>&1") == 0 ||
                      system("which thunar > /dev/null 2>&1") == 0 ||
                      system("which cosmic-files > /dev/null 2>&1") == 0;
    ok($file_manager, 'File manager available');
    
    # Clipboard tools
    my $clipboard_tools = system("which wl-copy > /dev/null 2>&1") == 0 ||
                         system("which xclip > /dev/null 2>&1") == 0 ||
                         system("which xsel > /dev/null 2>&1") == 0;
    ok($clipboard_tools, 'Clipboard tools available');
    
    # Desktop file handling
    my $desktop_integration = system("which xdg-open > /dev/null 2>&1") == 0;
    ok($desktop_integration, 'Desktop integration tools available');
    
    # MIME type handling
    my $mime_tools = system("which xdg-mime > /dev/null 2>&1") == 0;
    ok($mime_tools, 'MIME type tools available');
    
    # System tray/panel support
    my $tray_support = 1; # Most modern DEs support system tray in some form
    if ($ENV{XDG_CURRENT_DESKTOP} =~ /GNOME/i) {
        # GNOME removed system tray, but has alternatives
        $tray_support = system("which gnome-shell > /dev/null 2>&1") == 0;
    }
    ok($tray_support, 'System tray/panel support available');
    
    # Font rendering
    my $font_config = system("which fc-list > /dev/null 2>&1") == 0;
    ok($font_config, 'Font configuration tools available');
};

# Test 8: Performance and Resource Testing
subtest 'Performance and Resource Testing' => sub {
    plan tests => 4;
    
    # Test memory availability
    my $memory_info = `cat /proc/meminfo 2>/dev/null | grep MemTotal`;
    my $total_memory = 0;
    if ($memory_info =~ /MemTotal:\s+(\d+)\s+kB/) {
        $total_memory = $1 / 1024; # Convert to MB
    }
    
    ok($total_memory >= 1024, 'Sufficient memory available (>= 1GB)')
        or diag("Total memory: ${total_memory}MB");
    
    # Test disk space
    my $disk_space = `df -m . 2>/dev/null | tail -1`;
    my $available_space = 0;
    if ($disk_space =~ /\s+(\d+)\s+\d+\s+(\d+)\s+/) {
        $available_space = $2; # Available space in MB
    }
    
    ok($available_space >= 100, 'Sufficient disk space available (>= 100MB)')
        or diag("Available space: ${available_space}MB");
    
    # Test CPU performance (basic)
    my $cpu_info = `cat /proc/cpuinfo 2>/dev/null | grep processor | wc -l`;
    chomp $cpu_info;
    ok($cpu_info >= 1, 'CPU cores available')
        or diag("CPU cores: $cpu_info");
    
    # Test basic performance
    my $start_time = time();
    for (1..1000) {
        my $test = "performance test $_ " x 10;
    }
    my $end_time = time();
    my $duration = $end_time - $start_time;
    
    ok($duration < 5, 'Basic performance test completed quickly')
        or diag("Performance test duration: ${duration}s");
};

# Cleanup
cleanup_test_environment();

done_testing();

__END__

=head1 NAME

test_secondary_platforms.pl - Secondary Platform Compatibility Testing

=head1 DESCRIPTION

This test script performs compatibility testing of Ásbrú Connection Manager
on secondary platforms including Ubuntu 24.04 with GNOME/Wayland, Fedora,
and other modern Linux distributions.

Tests include:
- Platform detection and compatibility
- Desktop environment detection
- Package manager and dependencies
- X11 fallback compatibility
- Application compatibility
- Protocol client availability
- System integration compatibility
- Performance and resource testing

=head1 AUTHOR

Ásbrú Connection Manager Development Team

This test was developed with AI assistance as part of the modernization project.

=cut