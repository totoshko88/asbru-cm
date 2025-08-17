#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use FindBin qw($Bin);
use File::Spec;
use Test::Harness;
use Getopt::Long;

# Command line options
my $verbose = 0;
my $gui_only = 0;
my $protocols_only = 0;
my $performance_only = 0;
my $help = 0;

GetOptions(
    'verbose|v'     => \$verbose,
    'gui|g'         => \$gui_only,
    'protocols|p'   => \$protocols_only,
    'performance|f' => \$performance_only,
    'help|h'        => \$help
) or die "Error in command line arguments\n";

if ($help) {
    print <<EOF;
Usage: $0 [options]

Options:
    -v, --verbose      Enable verbose test output
    -g, --gui          Run only GUI tests
    -p, --protocols    Run only protocol tests
    -f, --performance  Run only performance tests
    -h, --help         Show this help message

Examples:
    $0                 # Run all tests
    $0 --gui           # Run only GUI tests
    $0 --verbose       # Run all tests with verbose output
EOF
    exit 0;
}

# Set up test environment
$ENV{ASBRU_TEST_MODE} = 1;
$ENV{HARNESS_VERBOSE} = 1 if $verbose;

print "Ásbrú Connection Manager Comprehensive Test Suite\n";
print "================================================\n\n";

print "AI-Assisted Modernization Test Suite for Ásbrú Connection Manager 7.0.0\n";
print "This test suite was developed with AI assistance as part of the GTK4 migration.\n\n";

# Determine which tests to run
my @test_categories;

if ($gui_only) {
    @test_categories = ('gui');
} elsif ($protocols_only) {
    @test_categories = ('protocols');
} elsif ($performance_only) {
    @test_categories = ('performance');
} else {
    @test_categories = ('gui', 'protocols', 'performance');
}

my @all_test_files;
my $total_tests = 0;

# Collect test files from each category
for my $category (@test_categories) {
    my $category_dir = File::Spec->catdir($Bin, $category);
    
    unless (-d $category_dir) {
        warn "Test category directory not found: $category_dir\n";
        next;
    }
    
    print "Collecting $category tests...\n";
    
    # Get test files for this category
    my @category_files;
    
    if ($category eq 'gui') {
        @category_files = (
            'test_widget_rendering.pl',
            'test_theme_compatibility.pl',
            'test_keyboard_shortcuts.pl'
        );
    } elsif ($category eq 'protocols') {
        @category_files = (
            'test_ssh_connections.pl',
            'test_rdp_connections.pl',
            'test_vnc_connections.pl'
        );
    } elsif ($category eq 'performance') {
        @category_files = (
            'test_startup_performance.pl',
            'test_integration.pl'
        );
    }
    
    # Convert to full paths and verify existence
    for my $test_file (@category_files) {
        my $full_path = File::Spec->catfile($category_dir, $test_file);
        if (-f $full_path) {
            push @all_test_files, $full_path;
            $total_tests++;
        } else {
            warn "Test file not found: $full_path\n";
        }
    }
}

if (@all_test_files == 0) {
    die "No test files found to run!\n";
}

print "Found $total_tests test files across " . scalar(@test_categories) . " categories\n\n";

# Display test environment information
print "Test Environment Information:\n";
print "  Perl Version: $]\n";
print "  Test Mode: " . ($ENV{ASBRU_TEST_MODE} ? 'Enabled' : 'Disabled') . "\n";
print "  Verbose Output: " . ($verbose ? 'Enabled' : 'Disabled') . "\n";
print "  Desktop Environment: " . ($ENV{XDG_CURRENT_DESKTOP} || 'Unknown') . "\n";
print "  Display Server: " . ($ENV{WAYLAND_DISPLAY} ? 'Wayland' : ($ENV{DISPLAY} ? 'X11' : 'Unknown')) . "\n";
print "\n";

# Check for required Perl modules
print "Checking required Perl modules...\n";
my @required_modules = qw(Test::More Test::MockObject Time::HiRes Benchmark);
my @missing_modules;

for my $module (@required_modules) {
    eval "require $module";
    if ($@) {
        push @missing_modules, $module;
    } else {
        print "  ✓ $module\n";
    }
}

if (@missing_modules) {
    print "\nMissing required modules:\n";
    for my $module (@missing_modules) {
        print "  ✗ $module\n";
    }
    print "\nPlease install missing modules before running tests.\n";
    exit 1;
}

print "\nAll required modules available.\n\n";

# Run the tests
print "Starting test execution...\n";
print "=" x 50 . "\n\n";

my $start_time = time();

eval {
    runtests(@all_test_files);
};

my $end_time = time();
my $total_time = $end_time - $start_time;

if ($@) {
    print STDERR "\nError running tests: $@\n";
    exit 1;
}

print "\n" . "=" x 50 . "\n";
print "Test Suite Completed Successfully!\n\n";

print "Execution Summary:\n";
print "  Total Test Files: $total_tests\n";
print "  Categories Tested: " . join(', ', @test_categories) . "\n";
print "  Total Execution Time: " . sprintf("%.2f seconds", $total_time) . "\n";
print "  Average Time per File: " . sprintf("%.2f seconds", $total_time / $total_tests) . "\n";

print "\nTest Categories Summary:\n";
for my $category (@test_categories) {
    my $description = {
        'gui' => 'GUI functionality, theme compatibility, and keyboard shortcuts',
        'protocols' => 'SSH, RDP, and VNC connection protocol validation',
        'performance' => 'Startup performance, memory usage, and system integration'
    };
    
    print "  $category: " . ($description->{$category} || 'Unknown category') . "\n";
}

print "\nAI Assistance Disclosure:\n";
print "This comprehensive test suite was developed with AI assistance as part of\n";
print "the Ásbrú Connection Manager modernization project (version 7.0.0).\n";
print "All tests follow established Perl testing best practices and ensure\n";
print "compatibility with the GTK4 migration and modern Linux distributions.\n";

exit 0;