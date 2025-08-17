#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use FindBin qw($Bin);
use File::Spec;
use Test::Harness;

# Set up test environment
$ENV{ASBRU_TEST_MODE} = 1;
$ENV{ASBRU_TEST_SIMULATE_DELAY} = 1;  # Enable timing simulation
$ENV{HARNESS_VERBOSE} = 1 if $ENV{VERBOSE};

print "Running Ásbrú Connection Manager Performance Tests\n";
print "==================================================\n\n";

# List of performance test files
my @test_files = (
    'test_startup_performance.pl',
    'test_integration.pl'
);

# Convert to full paths
@test_files = map { File::Spec->catfile($Bin, $_) } @test_files;

# Check if all test files exist
for my $test_file (@test_files) {
    unless (-f $test_file) {
        die "Test file not found: $test_file\n";
    }
}

print "Found " . scalar(@test_files) . " performance test files\n";
print "Performance tests include timing simulation for realistic measurements\n\n";

# Run the tests
eval {
    runtests(@test_files);
};

if ($@) {
    print STDERR "Error running performance tests: $@\n";
    exit 1;
}

print "\nPerformance tests completed successfully!\n";
print "Check test output for detailed performance metrics and benchmarks.\n";