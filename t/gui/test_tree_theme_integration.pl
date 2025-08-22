#!/usr/bin/perl

###############################################################################
# Integration test for tree theme functionality with actual TreeView widgets
# Tests the complete tree theme application workflow
###############################################################################

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";

# Load required modules
use PACCompat;

print "=== Tree Theme Integration Test ===\n";

# Initialize GTK
eval {
    if ($PACCompat::GTK_VERSION >= 4) {
        require Gtk4;
        Gtk4->import('-init');
    } else {
        require Gtk3;
        Gtk3->import('-init');
    }
};

if ($@) {
    print "SKIP: GTK initialization failed: $@\n";
    exit 0;
}

print "GTK Version: $PACCompat::GTK_VERSION\n";

# Test theme detection
my ($theme_name, $prefer_dark, $theme_info) = PACCompat::_detectSystemTheme();
print "Current Theme: $theme_name\n";
print "Prefers Dark: " . ($prefer_dark ? "Yes" : "No") . "\n";

# Create a test TreeView widget with proper model
my $tree_view;
my $tree_store;
eval {
    # Create a TreeStore model first
    $tree_store = PACCompat::create_tree_store('Glib::String', 'Glib::String');
    
    # Create TreeView with the model
    if ($PACCompat::GTK_VERSION >= 4) {
        # GTK4 uses different approach
        $tree_view = Gtk4::TreeView->new();
        $tree_view->set_model($tree_store) if $tree_store;
    } else {
        # GTK3 approach
        $tree_view = Gtk3::TreeView->new($tree_store);
    }
};

if ($@) {
    print "ERROR: Failed to create TreeView: $@\n";
    exit 1;
}

print "TreeView created successfully\n";

# Test applying tree theme
my $theme_result = PACCompat::_applyTreeTheme($tree_view);
print "Tree theme application: " . ($theme_result ? "SUCCESS" : "FAILED") . "\n";

# Test registering for automatic theme updates
my $register_result = PACCompat::registerTreeWidgetForThemeUpdates($tree_view);
print "Tree widget registration: " . ($register_result ? "SUCCESS" : "FAILED") . "\n";

# Check monitoring statistics
my $stats = PACCompat::getTreeThemeMonitoringStats();
print "Registered widgets: $stats->{total_registered}\n";
print "Valid widgets: $stats->{valid_widgets}\n";

# Test theme monitoring startup
my @signal_ids = PACCompat::startTreeThemeMonitoring();
print "Theme monitoring signals: " . scalar(@signal_ids) . "\n";

# Test theme cache
my %cache_info = PACCompat::get_cached_theme_info();
print "Theme cache entries: " . scalar(keys %cache_info) . "\n";

# Test CSS generation for both themes
print "\n=== CSS Generation Test ===\n";
my $light_css = PACCompat::_generateTreeCSS(0);
my $dark_css = PACCompat::_generateTreeCSS(1);

print "Light theme CSS length: " . length($light_css) . " characters\n";
print "Dark theme CSS length: " . length($dark_css) . " characters\n";

# Verify CSS contains expected elements
my $light_has_colors = ($light_css =~ /color:\s*#000000/ && $light_css =~ /background-color:\s*#ffffff/);
my $dark_has_colors = ($dark_css =~ /color:\s*#ffffff/ && $dark_css =~ /background-color:\s*#2d2d2d/);

print "Light CSS has correct colors: " . ($light_has_colors ? "YES" : "NO") . "\n";
print "Dark CSS has correct colors: " . ($dark_has_colors ? "YES" : "NO") . "\n";

# Test unregistering widget
PACCompat::unregisterTreeWidgetFromThemeUpdates($tree_view);
my $final_stats = PACCompat::getTreeThemeMonitoringStats();
print "Widgets after unregister: $final_stats->{total_registered}\n";

print "\n=== Integration Test Complete ===\n";

# Summary
my $success = $theme_result && $register_result && $light_has_colors && $dark_has_colors;
print "Overall Result: " . ($success ? "SUCCESS" : "FAILED") . "\n";

exit($success ? 0 : 1);