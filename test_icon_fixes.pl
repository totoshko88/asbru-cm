#!/usr/bin/perl

###############################################################################
# Test script for icon and tree theme fixes
# Tests all the improvements made to icons and dark theme support
###############################################################################

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

print "=== Ásbrú Connection Manager Icon & Theme Test ===\n";

# Test 1: Check theme directories have all required icons
print "\n--- Testing Icon Synchronization ---\n";

my @themes = qw(default asbru-color asbru-dark system);
my @required_method_icons = qw(
    asbru_method_ssh.svg
    asbru_method_rdesktop.svg
    asbru_method_vncviewer.svg
    asbru_method_telnet.svg
    asbru_method_ftp.svg
    asbru_method_sftp.svg
    asbru_method_mosh.svg
    asbru_method_generic.svg
);

for my $theme (@themes) {
    my $theme_dir = "$RealBin/res/themes/$theme";
    print "Checking theme: $theme\n";
    
    my $missing_count = 0;
    for my $icon (@required_method_icons) {
        my $icon_path = "$theme_dir/$icon";
        unless (-f $icon_path) {
            print "  MISSING: $icon\n";
            $missing_count++;
        }
    }
    
    if ($missing_count == 0) {
        print "  ✓ All method icons present\n";
    } else {
        print "  ✗ $missing_count method icons missing\n";
    }
}

# Test 2: Check SVG preference over PNG
print "\n--- Testing SVG Preference ---\n";

my @test_icons = qw(
    asbru_method_ssh
    asbru_method_rdesktop
    asbru_method_vncviewer
    asbru_method_telnet
    asbru_method_ftp
);

for my $theme (@themes) {
    my $theme_dir = "$RealBin/res/themes/$theme";
    print "Checking SVG preference in $theme:\n";
    
    for my $icon (@test_icons) {
        my $svg_path = "$theme_dir/$icon.svg";
        my $png_path = "$theme_dir/$icon.png";
        
        if (-f $svg_path) {
            print "  ✓ $icon.svg available\n";
        } elsif (-f $png_path) {
            print "  ~ $icon.png available (SVG preferred)\n";
        } else {
            print "  ✗ $icon not found\n";
        }
    }
}

# Test 3: Verify PACCompat theme detection
print "\n--- Testing Theme Detection ---\n";

eval {
    require PACCompat;
    
    my ($theme_name, $prefer_dark, $theme_info) = PACCompat::_detectSystemTheme();
    print "Current system theme: $theme_name\n";
    print "Prefers dark theme: " . ($prefer_dark ? "Yes" : "No") . "\n";
    print "Theme detection: ✓ Working\n";
} or do {
    print "Theme detection: ✗ Error: $@\n";
};

# Test 4: Check tree CSS generation
print "\n--- Testing Tree CSS Generation ---\n";

eval {
    require PACCompat;
    
    my $light_css = PACCompat::_generateTreeCSS(0);
    my $dark_css = PACCompat::_generateTreeCSS(1);
    
    if ($light_css =~ /asbru-connection-tree/ && $light_css =~ /color:\s*#1a1a1a/) {
        print "Light theme CSS: ✓ Contains proper styling\n";
    } else {
        print "Light theme CSS: ✗ Missing expected styling\n";
    }
    
    if ($dark_css =~ /asbru-connection-tree/ && $dark_css =~ /color:\s*#e6e6e6/) {
        print "Dark theme CSS: ✓ Contains proper styling\n";
    } else {
        print "Dark theme CSS: ✗ Missing expected styling\n";
    }
} or do {
    print "CSS generation: ✗ Error: $@\n";
};

# Test 5: System information
print "\n--- System Information ---\n";
print "OS: " . `uname -s` . "\n";
print "Desktop Environment: " . ($ENV{XDG_CURRENT_DESKTOP} || "Unknown") . "\n";
print "Display Server: " . (defined $ENV{WAYLAND_DISPLAY} ? "Wayland" : "X11") . "\n";

print "\n=== Test Complete ===\n";
print "If all tests show ✓, the icon and theme fixes are working correctly.\n";
