#!/usr/bin/perl

# Test runtime theme switching functionality

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

require PACMain;
require PACIcons;

# Create a test PACMain instance 
my $main = PACMain->new();

# Initialize minimal config for testing
$main->{_CFG} = {
    defaults => {
        theme => 'asbru-color',
        force_internal_icons => 0,
    }
};

print "Testing theme switching functionality...\n";

# Test internal theme switching
print "1. Testing asbru-color -> asbru-dark switch:\n";
my $result1 = $main->_apply_internal_theme('asbru-dark');
print "   Result: " . ($result1 ? "SUCCESS" : "FAILED") . "\n";

print "2. Testing asbru-dark -> asbru-color switch:\n";
my $result2 = $main->_apply_internal_theme('asbru-color');
print "   Result: " . ($result2 ? "SUCCESS" : "FAILED") . "\n";

print "3. Testing invalid theme handling:\n";
my $result3 = $main->_apply_internal_theme('invalid-theme');
print "   Result: " . ($result3 ? "FAILED (should reject)" : "SUCCESS (correctly rejected)") . "\n";

print "4. Testing system theme application:\n";
my $result4 = $main->_apply_system_icon_theme('Adwaita');
print "   Result: " . ($result4 ? "SUCCESS" : "FAILED") . "\n";

print "\nTheme switching test completed.\n";
