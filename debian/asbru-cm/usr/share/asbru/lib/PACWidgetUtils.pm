#!/usr/bin/perl

package PACWidgetUtils;

use strict;
use warnings;

# Safe pack_start that checks for existing parent
sub safe_pack_start {
    my ($container, $widget, @args) = @_;
    
    return unless $container && $widget;
    
    # Check if widget already has a parent
    if ($widget->can('get_parent') && $widget->get_parent()) {
        if ($ENV{ASBRU_DEBUG}) {
            print STDERR "DEBUG: Widget already has parent, skipping pack_start\n";
        }
        return;
    }
    
    # Safe to pack
    eval { $container->pack_start($widget, @args); };
    if ($@) {
        warn "WARNING: Failed to pack widget: $@\n" if $ENV{ASBRU_DEBUG};
    }
}

# Safe remove widget from parent
sub safe_remove {
    my ($widget) = @_;
    
    return unless $widget;
    
    if ($widget->can('get_parent') && (my $parent = $widget->get_parent())) {
        eval { $parent->remove($widget); };
        if ($@) {
            warn "WARNING: Failed to remove widget: $@\n" if $ENV{ASBRU_DEBUG};
        }
    }
}

1;
