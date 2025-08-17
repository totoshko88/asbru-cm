#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use FindBin qw($Bin);
use File::Spec;
use Test::Harness;

# Set up test environment
$ENV{ASBRU_TEST_MODE} = 1;
$ENV{HARNESS_VERBOSE} = 1 if $ENV{VERBOSE};

print "Running Ásbrú Connection Manager GUI Tests\n";
print "==========================================\n\n";

# List of GUI test files
my @test_files = (
    'test_widget_rendering.pl',
    'test_theme_compatibility.pl', 
    'test_keyboard_shortcuts.pl'
);

# Convert to full paths
@test_files = map { File::Spec->catfile($Bin, $_) } @test_files;

# Check if all test files exist
for my $test_file (@test_files) {
    unless (-f $test_file) {
        die "Test file not found: $test_file\n";
    }
}

print "Found " . scalar(@test_files) . " GUI test files\n";
print "Tests will run in headless mode using Xvfb if available\n\n";

# Run the tests
eval {
    runtests(@test_files);
};

if ($@) {
    print STDERR "Error running GUI tests: $@\n";
    exit 1;
}

print "\nGUI tests completed successfully!\n";