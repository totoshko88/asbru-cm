#!/usr/bin/perl

###############################################################################
# Test script for tree theme functionality (Task 4.1 and 4.2)
# Tests the _applyTreeTheme function and automatic theme change detection
###############################################################################

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";

# Test framework
use Test::More;

# Load required modules
use PACCompat;

# Test plan
plan tests => 13;

# Test 1: Check if PACCompat module loads correctly
ok(1, "PACCompat module loaded successfully");

# Test 2: Check if GTK is available
ok($PACCompat::GTK_AVAILABLE, "GTK is available");

# Test 3: Check if theme detection works
my ($theme_name, $prefer_dark, $theme_info) = PACCompat::_detectSystemTheme();
ok(defined $theme_name, "Theme detection returns theme name: $theme_name");

# Test 4: Check if theme cache works
my %cached_theme = PACCompat::get_cached_theme_info();
ok(exists $cached_theme{name}, "Theme cache contains theme name");

# Test 5: Check if dark theme preference detection works
my $is_dark = PACCompat::prefers_dark_theme();
ok(defined $is_dark, "Dark theme preference detected: " . ($is_dark ? "dark" : "light"));

# Test 6: Test CSS generation for light theme
my $light_css = PACCompat::_generateTreeCSS(0);
ok($light_css =~ /color:\s*#000000/, "Light theme CSS contains black text color");
ok($light_css =~ /background-color:\s*#ffffff/, "Light theme CSS contains white background");

# Test 7: Test CSS generation for dark theme
my $dark_css = PACCompat::_generateTreeCSS(1);
ok($dark_css =~ /color:\s*#ffffff/, "Dark theme CSS contains white text color");
ok($dark_css =~ /background-color:\s*#2d2d2d/, "Dark theme CSS contains dark background");

# Test 8: Test CSS provider creation
my $css_provider = PACCompat::create_css_provider();
ok(defined $css_provider, "CSS provider created successfully");

# Test 9: Test CSS loading
my $test_css = "treeview { color: #ff0000; }";
my $load_result = PACCompat::load_css_from_data($css_provider, $test_css);
ok($load_result, "CSS data loaded successfully");

# Test 10: Test theme monitoring statistics
my $stats = PACCompat::getTreeThemeMonitoringStats();
ok(ref($stats) eq 'HASH', "Theme monitoring statistics returned as hash");

print "\n=== Tree Theme Test Results ===\n";
print "GTK Version: $PACCompat::GTK_VERSION\n";
print "Current Theme: $theme_name\n";
print "Prefers Dark: " . ($is_dark ? "Yes" : "No") . "\n";
print "Theme Cache Valid: " . ($stats->{cache_valid} ? "Yes" : "No") . "\n";
print "Registered Tree Widgets: $stats->{total_registered}\n";
print "Theme Callbacks: $stats->{theme_callbacks}\n";

# Test 11: Test theme cache statistics
my %cache_stats = PACCompat::get_theme_cache_stats();
ok(exists $cache_stats{hits}, "Theme cache statistics available");

print "\nCache Statistics:\n";
print "  Hits: $cache_stats{hits}\n";
print "  Misses: $cache_stats{misses}\n";
print "  Hit Ratio: " . sprintf("%.2f", $cache_stats{hit_ratio}) . "\n";
print "  Cache Age: $cache_stats{cache_age}s\n";

print "\n=== Test Complete ===\n";

done_testing();