#!/usr/bin/perl

###############################################################################
# Theme Detection Test Script for PACCompat
# Tests theme detection functionality across different desktop environments
# Part of task 3.2: Implement simple theme detection via PACCompat
###############################################################################

use strict;
use warnings;
use utf8;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";

# Test framework
use Test::More;
use Data::Dumper;

# Import PACCompat
BEGIN {
    eval { require PACCompat; PACCompat->import(); };
    if ($@) {
        plan skip_all => "PACCompat not available: $@";
    }
}

# Test configuration
my $VERBOSE = $ENV{ASBRU_DEBUG} || $ENV{VERBOSE} || 0;
my $TEST_COUNT = 0;

# Test helper functions
sub test_log {
    my ($message) = @_;
    print STDERR "TEST: $message\n" if $VERBOSE;
}

sub test_theme_detection_basic {
    test_log("Testing basic theme detection...");
    
    my ($theme_name, $prefer_dark, $theme_info) = PACCompat::_detectSystemTheme();
    
    ok(defined $theme_name, "Theme name is defined");
    ok(defined $prefer_dark, "Dark preference is defined");
    ok(ref($theme_info) eq 'HASH', "Theme info is a hash reference");
    
    test_log("Theme name: $theme_name");
    test_log("Prefer dark: $prefer_dark");
    test_log("Theme info keys: " . join(", ", keys %$theme_info)) if $VERBOSE;
    
    $TEST_COUNT += 3;
}

sub test_theme_caching {
    test_log("Testing theme caching mechanism...");
    
    # Clear cache first
    PACCompat::clear_theme_cache();
    
    # First call should be a cache miss
    my %theme1 = PACCompat::get_cached_theme_info();
    ok(%theme1, "First theme info call returns data");
    
    # Second call should be a cache hit
    my %theme2 = PACCompat::get_cached_theme_info();
    ok(%theme2, "Second theme info call returns data");
    
    # Compare cache contents
    is($theme1{name}, $theme2{name}, "Cached theme name matches");
    is($theme1{prefer_dark}, $theme2{prefer_dark}, "Cached dark preference matches");
    
    # Test cache statistics
    my %stats = PACCompat::get_theme_cache_stats();
    ok($stats{hits} >= 1, "Cache has at least one hit");
    ok($stats{misses} >= 1, "Cache has at least one miss");
    ok($stats{hit_ratio} >= 0 && $stats{hit_ratio} <= 1, "Hit ratio is valid");
    
    test_log("Cache stats: hits=$stats{hits}, misses=$stats{misses}, ratio=$stats{hit_ratio}");
    
    $TEST_COUNT += 6;
}

sub test_theme_change_monitoring {
    test_log("Testing theme change monitoring...");
    
    my $callback_called = 0;
    my $last_event = '';
    
    # Set up monitoring callback
    my $callback = sub {
        my ($event, $theme_name, $prefer_dark, $theme_info) = @_;
        $callback_called++;
        $last_event = $event;
        test_log("Theme change callback: event=$event, theme=$theme_name, dark=$prefer_dark");
    };
    
    # Register callback
    my @signal_ids = PACCompat::monitor_theme_changes($callback);
    ok(@signal_ids > 0, "Theme monitoring signals registered");
    
    # Test cleanup
    my $cleanup_result = PACCompat::cleanup_theme_monitoring();
    ok($cleanup_result, "Theme monitoring cleanup successful");
    
    $TEST_COUNT += 2;
}

sub test_desktop_environment_detection {
    test_log("Testing desktop environment detection...");
    
    my $desktop_env = PACCompat::detect_desktop_environment();
    ok(defined $desktop_env, "Desktop environment is detected");
    test_log("Detected desktop environment: $desktop_env");
    
    # Test specific desktop environment checks
    my $is_cosmic = PACCompat::is_cosmic_desktop();
    my $is_gnome = PACCompat::is_gnome_desktop();
    
    ok(defined $is_cosmic, "Cosmic desktop check returns defined value");
    ok(defined $is_gnome, "GNOME desktop check returns defined value");
    
    test_log("Is Cosmic: " . ($is_cosmic ? "yes" : "no"));
    test_log("Is GNOME: " . ($is_gnome ? "yes" : "no"));
    
    $TEST_COUNT += 3;
}

sub test_display_server_detection {
    test_log("Testing display server detection...");
    
    my $display_server = PACCompat::detect_display_server();
    ok(defined $display_server, "Display server is detected");
    test_log("Detected display server: $display_server");
    
    # Test specific display server checks
    my $is_wayland = PACCompat::is_wayland();
    my $is_x11 = PACCompat::is_x11();
    
    ok(defined $is_wayland, "Wayland check returns defined value");
    ok(defined $is_x11, "X11 check returns defined value");
    
    test_log("Is Wayland: " . ($is_wayland ? "yes" : "no"));
    test_log("Is X11: " . ($is_x11 ? "yes" : "no"));
    
    $TEST_COUNT += 3;
}

sub test_environment_info {
    test_log("Testing comprehensive environment info...");
    
    my %env_info = PACCompat::get_environment_info();
    ok(%env_info, "Environment info returns data");
    
    # Check required fields
    my @required_fields = qw(display_server desktop_environment gtk_version);
    for my $field (@required_fields) {
        ok(exists $env_info{$field}, "Environment info contains $field");
        $TEST_COUNT++;
    }
    
    if ($VERBOSE) {
        test_log("Environment info:");
        for my $key (sort keys %env_info) {
            test_log("  $key: $env_info{$key}");
        }
    }
    
    $TEST_COUNT += 1; # for the initial %env_info check
}

sub test_theme_preference_detection {
    test_log("Testing theme preference detection...");
    
    my ($theme_name, $prefer_dark) = PACCompat::get_theme_preference();
    ok(defined $theme_name, "Theme preference returns theme name");
    ok(defined $prefer_dark, "Theme preference returns dark preference");
    
    my $prefers_dark = PACCompat::prefers_dark_theme();
    ok(defined $prefers_dark, "Dark theme preference detection works");
    
    test_log("Theme preference: name=$theme_name, prefer_dark=$prefer_dark, prefers_dark=$prefers_dark");
    
    $TEST_COUNT += 3;
}

sub test_forced_refresh {
    test_log("Testing forced theme detection refresh...");
    
    # Get initial theme info
    my %theme1 = PACCompat::get_cached_theme_info();
    
    # Force refresh
    my %theme2 = PACCompat::get_cached_theme_info(1);
    
    # Both should return valid data
    ok(%theme1, "Initial theme info is valid");
    ok(%theme2, "Forced refresh theme info is valid");
    
    # Content should be the same (unless theme actually changed)
    is($theme1{name}, $theme2{name}, "Theme name consistent after forced refresh");
    
    $TEST_COUNT += 3;
}

sub run_comprehensive_test {
    test_log("Running comprehensive theme detection test suite...");
    
    # Print environment information
    if ($VERBOSE) {
        test_log("Test environment:");
        test_log("  GTK Version: " . PACCompat::get_gtk_version());
        test_log("  Display Server: " . PACCompat::detect_display_server());
        test_log("  Desktop Environment: " . PACCompat::detect_desktop_environment());
        test_log("  XDG_CURRENT_DESKTOP: " . ($ENV{XDG_CURRENT_DESKTOP} || 'not set'));
        test_log("  XDG_SESSION_TYPE: " . ($ENV{XDG_SESSION_TYPE} || 'not set'));
        test_log("  WAYLAND_DISPLAY: " . ($ENV{WAYLAND_DISPLAY} || 'not set'));
        test_log("  DISPLAY: " . ($ENV{DISPLAY} || 'not set'));
    }
    
    # Run all tests
    test_theme_detection_basic();
    test_theme_caching();
    test_theme_change_monitoring();
    test_desktop_environment_detection();
    test_display_server_detection();
    test_environment_info();
    test_theme_preference_detection();
    test_forced_refresh();
    
    test_log("Completed $TEST_COUNT tests");
}

# Main execution
sub main {
    print "Theme Detection Test Suite for PACCompat\n";
    print "========================================\n\n";
    
    # Plan tests dynamically
    # We'll use done_testing() instead of planning ahead
    
    # Run tests
    eval {
        run_comprehensive_test();
    };
    
    if ($@) {
        diag("Test execution failed: $@");
        BAIL_OUT("Critical test failure");
    }
    
    # Final summary
    if ($VERBOSE) {
        print STDERR "\nTest Summary:\n";
        print STDERR "=============\n";
        print STDERR "Actual tests run: $TEST_COUNT\n";
        
        # Print final theme cache stats
        my %stats = PACCompat::get_theme_cache_stats();
        print STDERR "Final cache stats: hits=$stats{hits}, misses=$stats{misses}, ratio=$stats{hit_ratio}\n";
    }
    
    done_testing();
}

# Run if executed directly
if (!caller) {
    main();
}

1;

__END__

=head1 NAME

test_theme_detection.pl - Theme Detection Test Suite for PACCompat

=head1 SYNOPSIS

    perl t/lib/test_theme_detection.pl
    VERBOSE=1 perl t/lib/test_theme_detection.pl
    ASBRU_DEBUG=1 perl t/lib/test_theme_detection.pl

=head1 DESCRIPTION

This test script validates the theme detection functionality implemented in PACCompat
as part of task 3.2. It tests:

- Basic theme detection functionality
- Theme caching mechanism
- Theme change monitoring
- Desktop environment detection
- Display server detection
- Comprehensive environment information gathering

=head1 ENVIRONMENT VARIABLES

=over 4

=item VERBOSE

Enable verbose test output

=item ASBRU_DEBUG

Enable debug output from PACCompat

=back

=head1 AUTHOR

Ásbrú Connection Manager team

=cut