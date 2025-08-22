package PACVte;

###############################################################################
# This file is part of Ásbrú Connection Manager
#
# Copyright (C) 2017-2024 Ásbrú Connection Manager team (https://asbru-cm.net)
#
# Ásbrú Connection Manager is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ásbrú Connection Manager is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License version 3
# along with Ásbrú Connection Manager.
# If not, see <http://www.gnu.org/licenses/gpl-3.0.html>.
###############################################################################

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

use strict;
use warnings;
use Exporter 'import';
use Glib::Object::Introspection;

###################################################################
# VTE Modern Binding Support

our $HAVE_VTE = 0;
our $VTE_VERSION = '0.0';
our @EXPORT = qw(init_vte get_vte_capabilities);

# Try to initialize VTE with GObject Introspection
sub init_vte {
    my $vte_version = '3.91';  # Default to 3.91 (VTE 0.72+)
    
    # Try VTE 3.91 first (modern VTE)
    eval {
        Glib::Object::Introspection->setup(
            basename => 'Vte',
            version => '3.91',
            package => 'Vte391'
        );
        $HAVE_VTE = 1;
        $VTE_VERSION = '3.91';
        print "INFO: VTE 3.91 binding initialized successfully\n" if $ENV{ASBRU_DEBUG};
    };
    
    if ($@) {
        # Fallback to VTE 2.91 (older but more widely available)
        eval {
            Glib::Object::Introspection->setup(
                basename => 'Vte',
                version => '2.91',
                package => 'Vte291'
            );
            $HAVE_VTE = 1;
            $VTE_VERSION = '2.91';
            $vte_version = '2.91';
            print "INFO: VTE 2.91 binding initialized (fallback)\n" if $ENV{ASBRU_DEBUG};
        };
        
        if ($@) {
            # Final fallback: try old Perl VTE bindings
            eval {
                require Vte;
                Vte->import();
                $HAVE_VTE = 1;
                $VTE_VERSION = 'legacy';
                print "INFO: Legacy VTE Perl binding initialized\n" if $ENV{ASBRU_DEBUG};
            };
            
            if ($@) {
                warn "WARNING: No VTE bindings available. Terminal functionality will be limited.\n";
                warn "Error details: $@\n" if $ENV{ASBRU_DEBUG};
                $HAVE_VTE = 0;
            }
        }
    }
    
    return $HAVE_VTE;
}

# Create VTE Terminal with version compatibility
sub new_terminal {
    return undef unless $HAVE_VTE;
    
    if ($VTE_VERSION eq '3.91') {
        return Vte391::Terminal->new();
    } elsif ($VTE_VERSION eq '2.91') {
        return Vte291::Terminal->new();
    } elsif ($VTE_VERSION eq 'legacy') {
        return Vte::Terminal->new();
    }
    
    return undef;
}

# Get VTE version information
sub get_vte_capabilities {
    my $capabilities = {
        available => $HAVE_VTE,
        version => $VTE_VERSION,
        binding_version => 'unknown',
        major_version => 0,
        minor_version => 0,
        gtk4_compatible => 0,
        is_legacy => 0,
        has_bright => 0,
        vte_feed_binary => 0,
        vte_feed_child => 0
    };
    
    return $capabilities unless $HAVE_VTE;
    
    eval {
        if ($VTE_VERSION eq '3.91') {
            $capabilities->{binding_version} = '3.91';
            $capabilities->{major_version} = Vte391::get_major_version() if Vte391->can('get_major_version');
            $capabilities->{minor_version} = Vte391::get_minor_version() if Vte391->can('get_minor_version');
            $capabilities->{gtk4_compatible} = 1;
            $capabilities->{has_bright} = 1;
            $capabilities->{vte_feed_binary} = 1;
            $capabilities->{vte_feed_child} = 1;
        } elsif ($VTE_VERSION eq '2.91') {
            $capabilities->{binding_version} = '2.91';
            $capabilities->{major_version} = Vte291::get_major_version() if Vte291->can('get_major_version');
            $capabilities->{minor_version} = Vte291::get_minor_version() if Vte291->can('get_minor_version');
            $capabilities->{gtk4_compatible} = 0;
            $capabilities->{has_bright} = 1;
            $capabilities->{vte_feed_binary} = 1;
            $capabilities->{vte_feed_child} = 1;
        } elsif ($VTE_VERSION eq 'legacy') {
            $capabilities->{binding_version} = Vte::get_vte_version() if Vte->can('get_vte_version');
            $capabilities->{major_version} = Vte::get_major_version() if Vte->can('get_major_version');
            $capabilities->{minor_version} = Vte::get_minor_version() if Vte->can('get_minor_version');
            $capabilities->{is_legacy} = 1;
            $capabilities->{has_bright} = Vte->can('set_color_bold') ? 1 : 0;
        }
    };
    
    if ($@) {
        warn "Warning getting VTE capabilities: $@\n" if $ENV{ASBRU_DEBUG};
    }
    
    return $capabilities;
}

# Initialize VTE on module load
init_vte();

1;

__END__

=head1 NAME

PACVte - VTE Terminal Emulator Compatibility Layer for Ásbrú Connection Manager

=head1 SYNOPSIS

    use PACVte;
    
    # Initialize VTE bindings
    my $vte_available = PACVte::init_vte();
    
    # Create terminal
    my $terminal = PACVte::new_terminal();
    
    # Get capabilities
    my $caps = PACVte::get_vte_capabilities();

=head1 DESCRIPTION

This module provides a compatibility layer for VTE (Virtual Terminal Emulator) 
bindings, supporting both modern GObject Introspection based bindings (VTE 3.91, 2.91)
and legacy Perl VTE bindings.

=head1 FUNCTIONS

=head2 init_vte()

Initializes VTE bindings, trying modern versions first, then falling back to legacy.
Returns 1 if successful, 0 if VTE is not available.

=head2 new_terminal()

Creates a new VTE Terminal object using the best available binding.
Returns undef if VTE is not available.

=head2 get_vte_capabilities()

Returns a hashref containing VTE version and capability information.

=head1 AUTHOR

Ásbrú Connection Manager team

=head1 LICENSE

GNU General Public License version 3

=cut
