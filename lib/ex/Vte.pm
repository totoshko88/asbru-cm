package Vte;

# AI-ASSISTED MODERNIZATION: This VTE module was significantly modified with AI assistance
# to support both VTE 2.91 (GTK3) and VTE 3.91 (GTK4) for Ásbrú Connection Manager v7.0.0
#
# AI Assistance Details:
# - VTE version detection: AI-implemented automatic fallback mechanism
# - GTK4 compatibility: AI-researched VTE 3.91 API changes and requirements
# - Error handling: AI-enhanced with user-friendly installation guidance
# - Backward compatibility: AI-designed fallback to VTE 2.91 for older systems
# - Terminal integration: AI-optimized for modern terminal emulation features
#
# Human Validation:
# - Tested on PopOS 24.04 with VTE 3.91 and GTK4
# - Validated fallback behavior on Ubuntu 22.04 with VTE 2.91
# - Terminal functionality verified across SSH, RDP, and local connections
# - Performance tested with large scrollback buffers and Unicode content
#
# Technical Background:
# VTE (Virtual Terminal Emulator) library underwent significant changes between
# versions 2.91 and 3.91, particularly for GTK4 compatibility. This module
# provides automatic detection and graceful fallback to ensure terminal
# functionality works across different system configurations.

use strict;
use warnings;
use Glib::Object::Introspection;

# Global variable to track which VTE version is loaded
our $VTE_VERSION;
our $VTE_PACKAGE;

sub import {
    # Try VTE 3.91 first (GTK4 compatible), then fall back to 2.91
    my $vte_loaded = 0;
    
    # First try VTE 3.91 for GTK4 compatibility
    eval {
        Glib::Object::Introspection->setup(
            basename => 'Vte',
            version => '3.91',
            package => 'Vte'
        );
        $VTE_VERSION = '3.91';
        $VTE_PACKAGE = 'Vte';
        $vte_loaded = 1;
    };
    
    # If VTE 3.91 fails, fall back to VTE 2.91
    if (!$vte_loaded) {
        eval {
            Glib::Object::Introspection->setup(
                basename => 'Vte',
                version => '2.91',
                package => 'Vte'
            );
            $VTE_VERSION = '2.91';
            $VTE_PACKAGE = 'Vte';
            $vte_loaded = 1;
        };
    }
    
    # If neither version loads, die with helpful error
    if (!$vte_loaded) {
        die "Failed to load VTE library. Please ensure either VTE 3.91 (GTK4) or VTE 2.91 (GTK3) is installed.\n" .
            "On Ubuntu/PopOS: sudo apt install gir1.2-vte-3.91 libvte-2.91-gtk4-0\n" .
            "Or for GTK3 fallback: sudo apt install gir1.2-vte-2.91 libvte-2.91-0\n";
    }
}

# Helper function to get loaded VTE version
sub get_vte_version {
    return $VTE_VERSION;
}

# Helper function to check if we're using GTK4-compatible VTE
sub is_gtk4_compatible {
    return defined $VTE_VERSION && $VTE_VERSION eq '3.91';
}

# Helper function to check if we're using legacy VTE
sub is_legacy_vte {
    return defined $VTE_VERSION && $VTE_VERSION eq '2.91';
}

1;
