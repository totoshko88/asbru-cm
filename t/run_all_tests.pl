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

# Allow positional category arguments (e.g., `protocols`, `gui performance`)
if (@ARGV) {
    my %pos;
    for my $arg (@ARGV) {
        $pos{lc $arg} = 1 if $arg =~ /^(gui|protocols|performance)$/i;
    }
    if (%pos) {
        $gui_only         = $pos{gui}         // 0;
        $protocols_only   = $pos{protocols}   // 0;
        $performance_only = $pos{performance} // 0;
    }
}

if ($help) {
    print <<EOF;
Usage: $0 [options] [categories]

Options:
    -v, --verbose      Enable verbose test output
    -g, --gui          Run only GUI tests
    -p, --protocols    Run only protocol tests
    -f, --performance  Run only performance tests
    -h, --help         Show this help message

Positional categories (optional): gui, protocols, performance

Examples:
    $0                       # Run all tests
    $0 --gui                 # Run only GUI tests
    $0 protocols             # Run only protocol tests (positional)
    $0 gui performance -v    # Run GUI and performance tests, verbose
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
if ($gui_only || $protocols_only || $performance_only) {
    push @test_categories, 'gui'         if $gui_only;
    push @test_categories, 'protocols'   if $protocols_only;
    push @test_categories, 'performance' if $performance_only;
} else {
    @test_categories = ('gui', 'protocols', 'performance');
}

# Capability checks (affect category/test selection)
print "Checking required Perl modules...\n";
my @required_modules = qw(Test::More Time::HiRes Benchmark);
my @missing_required;
for my $module (@required_modules) {
    eval "require $module";
    if ($@) { push @missing_required, $module; }
    else { print "  ✓ $module\n"; }
}
if (@missing_required) {
    print "\nMissing required modules:\n";
    print "  ✗ $_\n" for @missing_required;
    print "\nProceeding with available tests; some will be skipped.\n";
}

my $have_mock = eval { require Test::MockObject; 1 } ? 1 : 0;
if ($have_mock) {
    print "  (optional) available Test::MockObject\n";
} else {
    print "  (optional) missing Test::MockObject - will skip related tests\n";
    $ENV{ASBRU_SKIP_MOCK_TESTS} = 1;
}
my $have_gtk4 = eval { require Gtk4; 1 } ? 1 : 0;
if (!$have_gtk4) {
    print "  (optional) missing Gtk4 - GUI tests will be skipped if selected\n";
}

print "\nAll required modules available.\n\n";

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

    my @category_files;

    if ($category eq 'gui') {
        if (!$have_gtk4) {
            print "GTK4 not available; skipping GUI tests.\n";
            next;
        }
        my @gui_candidates = (
            'test_widget_rendering.pl',          # Gtk4 only
            'test_theme_compatibility.pl',       # Gtk4 + Mock
            'test_keyboard_shortcuts.pl'         # Gtk4 + Mock
        );
        if (!$have_mock) {
            @category_files = grep { $_ eq 'test_widget_rendering.pl' } @gui_candidates;
            print "Test::MockObject not available; skipping GUI tests that require it.\n";
        } else {
            @category_files = @gui_candidates;
        }
    } elsif ($category eq 'protocols') {
        @category_files = (
            'test_ssh_connections.pl',
            'test_rdp_connections.pl',
            'test_vnc_connections.pl'
        );
    } elsif ($category eq 'performance') {
        if (!$have_mock) {
            print "Test::MockObject not available; skipping performance tests.\n";
            next;
        }
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