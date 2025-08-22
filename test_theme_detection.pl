#!/usr/bin/env perl

# Test script for theme detection functionality
# This tests the PACCompat theme detection functions

use strict;
use warnings;
use lib 'lib';

# Test PACCompat theme detection
use PACCompat;

print "=== PACCompat Theme Detection Test ===\n";
print "GTK Version: " . PACCompat::get_gtk_version() . "\n";
print "Display Server: " . PACCompat::detect_display_server() . "\n";
print "Desktop Environment: " . PACCompat::detect_desktop_environment() . "\n";

print "\n=== Theme Detection ===\n";
my ($theme_name, $prefer_dark) = PACCompat::_detectSystemTheme();
print "Theme Name: $theme_name\n";
print "Prefer Dark: " . ($prefer_dark ? "Yes" : "No") . "\n";
print "Is Dark Theme: " . (PACCompat::prefers_dark_theme() ? "Yes" : "No") . "\n";

print "\n=== Cached Theme Info ===\n";
my %theme_info = PACCompat::get_cached_theme_info();
for my $key (sort keys %theme_info) {
    print "$key: $theme_info{$key}\n";
}

print "\n=== Settings Test ===\n";
my $settings = PACCompat::get_default_settings();
if ($settings) {
    print "Settings object: Available\n";
    
    # Test some common properties
    my @properties = qw(
        gtk-theme-name
        gtk-application-prefer-dark-theme
        gtk-icon-theme-name
        gtk-font-name
    );
    
    for my $prop (@properties) {
        my $value = eval { $settings->get_property($prop) };
        if ($@) {
            print "$prop: Error - $@\n";
        } else {
            print "$prop: " . (defined $value ? $value : "undefined") . "\n";
        }
    }
} else {
    print "Settings object: Not available\n";
}

print "\n=== Theme Change Monitoring Test ===\n";
my $monitor_result = PACCompat::monitor_theme_changes(sub {
    my ($theme, $dark) = @_;
    print "Theme changed: $theme (dark: $dark)\n";
});

print "Theme monitoring setup: " . ($monitor_result ? "Success" : "Failed") . "\n";

print "\nTest completed successfully!\n";