#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use FindBin qw($Bin);
use File::Spec;
use Test::Harness;
use Getopt::Long;
use Time::HiRes qw(time);

# Command line options
my $primary_only = 0;
my $secondary_only = 0;
my $performance_only = 0;
my $verbose = 0;
my $help = 0;

GetOptions(
    'primary|p'     => \$primary_only,
    'secondary|s'   => \$secondary_only,
    'performance|f' => \$performance_only,
    'verbose|v'     => \$verbose,
    'help|h'        => \$help
) or die "Error in command line arguments\n";

if ($help) {
    print <<EOF;
Usage: $0 [options]

Platform Testing Suite for Ásbrú Connection Manager 7.0.0

Options:
    -p, --primary      Run only primary platform tests (PopOS 24.04 + Cosmic)
    -s, --secondary    Run only secondary platform tests (Ubuntu, Fedora, etc.)
    -f, --performance  Run only performance and stability tests
    -v, --verbose      Enable verbose test output
    -h, --help         Show this help message

Examples:
    $0                 # Run all platform tests
    $0 --primary       # Test PopOS 24.04 + Cosmic only
    $0 --secondary     # Test secondary platform compatibility
    $0 --performance   # Run performance and stability tests only
    $0 --verbose       # Run all tests with verbose output

This comprehensive platform testing suite was developed with AI assistance
as part of the Ásbrú Connection Manager modernization project.
EOF
    exit 0;
}

# Set up test environment
$ENV{ASBRU_TEST_MODE} = 1;
$ENV{HARNESS_VERBOSE} = 1 if $verbose;

print "Ásbrú Connection Manager Platform Testing Suite\n";
print "=" x 50 . "\n\n";

print "AI-Assisted Platform Testing for Ásbrú Connection Manager 7.0.0\n";
print "This comprehensive testing suite validates the modernized application\n";
print "across multiple platforms and desktop environments.\n\n";

# Determine which tests to run
my @test_files;

if ($primary_only) {
    @test_files = ('test_popos_cosmic.pl');
    print "Running PRIMARY PLATFORM tests (PopOS 24.04 + Cosmic)...\n";
} elsif ($secondary_only) {
    @test_files = ('test_secondary_platforms.pl');
    print "Running SECONDARY PLATFORM compatibility tests...\n";
} elsif ($performance_only) {
    @test_files = ('test_performance_stability.pl');
    print "Running PERFORMANCE AND STABILITY tests...\n";
} else {
    @test_files = (
        'test_popos_cosmic.pl',
        'test_secondary_platforms.pl', 
        'test_performance_stability.pl'
    );
    print "Running ALL PLATFORM tests...\n";
}

print "\n";

# Display test environment information
print "Test Environment Information:\n";
print "  Perl Version: $]\n";
print "  Test Mode: " . ($ENV{ASBRU_TEST_MODE} ? 'Enabled' : 'Disabled') . "\n";
print "  Verbose Output: " . ($verbose ? 'Enabled' : 'Disabled') . "\n";
print "  Platform: " . detect_platform() . "\n";
print "  Desktop Environment: " . ($ENV{XDG_CURRENT_DESKTOP} || 'Unknown') . "\n";
print "  Display Server: " . detect_display_server() . "\n";
print "  Architecture: " . `uname -m` . "\n";
print "\n";

# Convert to full paths and verify existence
my @full_test_paths;
for my $test_file (@test_files) {
    my $full_path = File::Spec->catfile($Bin, $test_file);
    if (-f $full_path) {
        push @full_test_paths, $full_path;
    } else {
        warn "Test file not found: $full_path\n";
    }
}

if (@full_test_paths == 0) {
    die "No test files found to run!\n";
}

print "Found " . scalar(@full_test_paths) . " test files to execute\n\n";

# Run the tests
print "Starting platform test execution...\n";
print "=" x 50 . "\n\n";

my $start_time = time();

eval {
    runtests(@full_test_paths);
};

my $end_time = time();
my $total_time = $end_time - $start_time;

if ($@) {
    print STDERR "\nError running platform tests: $@\n";
    exit 1;
}

print "\n" . "=" x 50 . "\n";
print "Platform Testing Suite Completed!\n\n";

print "Execution Summary:\n";
print "  Total Test Files: " . scalar(@full_test_paths) . "\n";
print "  Test Categories: " . get_test_categories(@test_files) . "\n";
print "  Total Execution Time: " . sprintf("%.2f seconds", $total_time) . "\n";
print "  Average Time per File: " . sprintf("%.2f seconds", $total_time / @full_test_paths) . "\n";

print "\nTest Results Summary:\n";
for my $test_file (@test_files) {
    my $description = get_test_description($test_file);
    print "  $test_file: $description\n";
}

print "\nPlatform Compatibility Status:\n";
print "  ✓ PopOS 24.04 + Cosmic: " . ($primary_only || !$primary_only && !$secondary_only && !$performance_only ? "TESTED" : "SKIPPED") . "\n";
print "  ✓ Secondary Platforms: " . ($secondary_only || !$primary_only && !$secondary_only && !$performance_only ? "TESTED" : "SKIPPED") . "\n";
print "  ✓ Performance & Stability: " . ($performance_only || !$primary_only && !$secondary_only && !$performance_only ? "TESTED" : "SKIPPED") . "\n";

print "\nAI Assistance Disclosure:\n";
print "This comprehensive platform testing suite was developed with AI assistance\n";
print "as part of the Ásbrú Connection Manager modernization project (version 7.0.0).\n";
print "The tests validate GTK4 migration, Wayland compatibility, and modern Linux\n";
print "distribution support across multiple desktop environments.\n\n";

print "For detailed test results and troubleshooting information, run individual\n";
print "test files with the --verbose flag or review the test output above.\n";

exit 0;

# Helper functions
sub detect_platform {
    my $os_release = '';
    if (-f '/etc/os-release') {
        open my $fh, '<', '/etc/os-release' or return 'Unknown';
        $os_release = do { local $/; <$fh> };
        close $fh;
    }
    
    return 'Pop!_OS' if $os_release =~ /Pop!_OS/i;
    return 'Ubuntu' if $os_release =~ /Ubuntu/i;
    return 'Fedora' if $os_release =~ /Fedora/i;
    return 'Debian' if $os_release =~ /Debian/i;
    return 'Unknown';
}

sub detect_display_server {
    return 'Wayland' if $ENV{WAYLAND_DISPLAY};
    return 'X11' if $ENV{DISPLAY};
    return 'Unknown';
}

sub get_test_categories {
    my @files = @_;
    my @categories;
    
    push @categories, 'Primary Platform' if grep { /popos_cosmic/ } @files;
    push @categories, 'Secondary Platforms' if grep { /secondary_platforms/ } @files;
    push @categories, 'Performance & Stability' if grep { /performance_stability/ } @files;
    
    return join(', ', @categories);
}

sub get_test_description {
    my $test_file = shift;
    
    my %descriptions = (
        'test_popos_cosmic.pl' => 'PopOS 24.04 + Cosmic desktop environment validation',
        'test_secondary_platforms.pl' => 'Ubuntu, Fedora, and other Linux distribution compatibility',
        'test_performance_stability.pl' => 'Performance benchmarking and stability validation'
    );
    
    return $descriptions{$test_file} || 'Unknown test';
}

__END__

=head1 NAME

run_platform_tests.pl - Comprehensive Platform Testing Suite

=head1 DESCRIPTION

This script orchestrates comprehensive platform testing for the modernized
Ásbrú Connection Manager across multiple Linux distributions and desktop
environments.

=head1 AUTHOR

Ásbrú Connection Manager Development Team

This testing suite was developed with AI assistance as part of the modernization project.

=cut