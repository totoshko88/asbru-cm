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

print "Running Ásbrú Connection Manager Protocol Tests\n";
print "===============================================\n\n";

# List of protocol test files
my @test_files = (
    'test_local_shell.pl',
    'test_ssh_connections.pl',
    'test_rdp_connections.pl',
    'test_vnc_connections.pl'
);

# Convert to full paths
@test_files = map { File::Spec->catfile($Bin, $_) } @test_files;

# Check if all test files exist
for my $test_file (@test_files) {
    unless (-f $test_file) {
        die "Test file not found: $test_file\n";
    }
}

print "Found " . scalar(@test_files) . " protocol test files\n";
print "Tests will simulate connection protocols without requiring actual servers\n\n";

# Run the tests
eval {
    runtests(@test_files);
};

if ($@) {
    print STDERR "Error running protocol tests: $@\n";
    exit 1;
}

print "\nProtocol tests completed successfully!\n";