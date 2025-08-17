#!/usr/bin/perl

# Test runtime theme switching with CSS reloading

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

require PACMain;
require PACIcons;

print "Testing enhanced theme switching with CSS reloading...\n";

# Create a test PACMain instance 
my $main = PACMain->new();

# Initialize minimal config for testing
$main->{_CFG} = {
    defaults => {
        theme => 'asbru-color',
        force_internal_icons => 0,
    }
};

# Store the CSS provider reference for testing
$main->{_THEME_CSS_PROVIDER} = undef;

print "1. Testing asbru-color -> asbru-dark switch with CSS:\n";
my $result1 = $main->_apply_internal_theme('asbru-dark');
print "   Result: " . ($result1 ? "SUCCESS" : "FAILED") . "\n";
print "   CSS Provider stored: " . (defined $main->{_THEME_CSS_PROVIDER} ? "YES" : "NO") . "\n";

print "2. Testing asbru-dark -> asbru-color switch with CSS:\n";
my $result2 = $main->_apply_internal_theme('asbru-color');
print "   Result: " . ($result2 ? "SUCCESS" : "FAILED") . "\n";
print "   CSS Provider updated: " . (defined $main->{_THEME_CSS_PROVIDER} ? "YES" : "NO") . "\n";

print "3. Testing default theme switch:\n";
my $result3 = $main->_apply_internal_theme('default');
print "   Result: " . ($result3 ? "SUCCESS" : "FAILED") . "\n";

print "\nEnhanced theme switching test completed.\n";
