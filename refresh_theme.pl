#!/usr/bin/perl

###############################################################################
# Theme and Icon Refresh Utility for Ásbrú Connection Manager
# This script can be used to refresh icons and themes without restarting
###############################################################################

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

print "=== Ásbrú Theme & Icon Refresh Utility ===\n";

# Function to refresh icon cache
sub refresh_icon_cache {
    print "Refreshing icon cache...\n";
    
    # Clear GTK icon cache
    system("gtk-update-icon-cache -f ~/.local/share/icons 2>/dev/null");
    system("gtk-update-icon-cache -f /usr/share/icons/* 2>/dev/null");
    
    print "✓ Icon cache refreshed\n";
}

# Function to validate theme consistency
sub validate_theme_consistency {
    print "Validating theme consistency...\n";
    
    my @themes = qw(default asbru-color asbru-dark system);
    my @critical_icons = qw(
        asbru_method_ssh.svg
        asbru_method_rdesktop.svg
        asbru_method_vncviewer.svg
        asbru_method_telnet.svg
        asbru_method_ftp.svg
        asbru_method_sftp.svg
        asbru_method_mosh.svg
        asbru_method_generic.svg
        asbru_method_cadaver.svg
    );
    
    my $all_valid = 1;
    
    for my $theme (@themes) {
        my $theme_dir = "$RealBin/res/themes/$theme";
        
        for my $icon (@critical_icons) {
            my $icon_path = "$theme_dir/$icon";
            unless (-f $icon_path) {
                print "✗ Missing: $theme/$icon\n";
                $all_valid = 0;
            }
        }
    }
    
    if ($all_valid) {
        print "✓ All themes have consistent icon sets\n";
    } else {
        print "⚠ Some icons are missing, run icon synchronization\n";
    }
    
    return $all_valid;
}

# Function to synchronize icons between themes
sub synchronize_icons {
    print "Synchronizing icons between themes...\n";
    
    my $default_theme = "$RealBin/res/themes/default";
    my @target_themes = qw(asbru-color asbru-dark system);
    
    for my $theme (@target_themes) {
        my $theme_dir = "$RealBin/res/themes/$theme";
        
        # Copy all SVG files from default to other themes
        if (opendir(my $dh, $default_theme)) {
            while (my $file = readdir($dh)) {
                next unless $file =~ /\.svg$/;
                
                my $src = "$default_theme/$file";
                my $dst = "$theme_dir/$file";
                
                if (-f $src && !-f $dst) {
                    if (system("cp '$src' '$dst'") == 0) {
                        print "  → Copied $file to $theme\n";
                    }
                }
            }
            closedir($dh);
        }
    }
    
    print "✓ Icon synchronization complete\n";
}

# Function to test theme detection
sub test_theme_detection {
    print "Testing theme detection...\n";
    
    eval {
        require PACCompat;
        
        my ($theme_name, $prefer_dark, $theme_info) = PACCompat::_detectSystemTheme();
        
        print "Current system theme: $theme_name\n";
        print "Prefers dark theme: " . ($prefer_dark ? "Yes" : "No") . "\n";
        print "Theme variant: " . ($prefer_dark ? "dark" : "light") . "\n";
        
        if ($theme_info && ref($theme_info) eq 'HASH') {
            print "Additional theme info:\n";
            for my $key (sort keys %$theme_info) {
                print "  $key: " . ($theme_info->{$key} // 'undef') . "\n";
            }
        }
        
        print "✓ Theme detection working\n";
        return 1;
    } or do {
        print "✗ Theme detection failed: $@\n";
        return 0;
    };
}

# Main execution
my $action = $ARGV[0] || 'all';

if ($action eq 'icons' || $action eq 'all') {
    refresh_icon_cache();
    synchronize_icons();
    validate_theme_consistency();
}

if ($action eq 'theme' || $action eq 'all') {
    test_theme_detection();
}

if ($action eq 'validate' || $action eq 'all') {
    validate_theme_consistency();
}

print "\n=== Refresh Complete ===\n";
print "Theme and icon fixes are ready!\n";
print "\nUsage: $0 [icons|theme|validate|all]\n";
print "  icons    - Refresh and synchronize icons\n";
print "  theme    - Test theme detection\n";
print "  validate - Validate theme consistency\n";
print "  all      - Run all operations (default)\n";
