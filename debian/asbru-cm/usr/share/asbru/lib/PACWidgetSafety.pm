#!/usr/bin/perl
use strict;
use warnings;

# Helper function to check if widget already has a parent before packing
sub safe_pack_start {
    my ($container, $widget, @args) = @_;
    
    # Check if widget already has a parent
    if ($widget && $widget->can('get_parent') && !$widget->get_parent()) {
        $container->pack_start($widget, @args);
    } elsif ($ENV{ASBRU_DEBUG}) {
        print STDERR "WARNING: Widget already has parent, skipping pack_start\n";
    }
}

# Export the function
1;
