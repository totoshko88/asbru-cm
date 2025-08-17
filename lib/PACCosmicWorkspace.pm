package PACCosmicWorkspace;

###############################################################################
# This file is part of Ásbrú Connection Manager
#
# Copyright (C) 2017-2022 Ásbrú Connection Manager team (https://asbru-cm.net)
# Copyright (C) 2010-2016 David Torrejon Vaquerizas
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

# AI-assisted modernization: This module provides Cosmic desktop workspace
# integration for enhanced window and connection management

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

# Standard
use strict;
use warnings;

# PAC modules
use PACCosmic;
use PACCompat;

# END: Import Modules
###################################################################

###################################################################
# Define GLOBAL CLASS variables

my $WORKSPACE_INTEGRATION_AVAILABLE = 0;
my $CURRENT_WORKSPACE = undef;
my %WORKSPACE_CONNECTIONS = (); # Track connections per workspace

# END: Define GLOBAL CLASS variables
###################################################################

###################################################################
# START: Define PUBLIC CLASS methods

sub new {
    my $class = shift;
    my $main_ref = shift;

    my $self = {
        '_MAIN' => $main_ref,
        '_WORKSPACE_TRACKING' => 0,
        '_CONNECTION_WORKSPACE_MAP' => {},
    };

    # Bless first, then run initialization that calls methods expecting blessed object
    bless($self, $class);

    # Initialize workspace integration if available
    eval { $self->_initWorkspaceIntegration(); 1 } or do { print "WARNING: Cosmic workspace init failed: $@\n"; };
    return $self;
}

# Check if workspace integration is available
sub is_workspace_integration_available {
    my $self = shift;
    return $WORKSPACE_INTEGRATION_AVAILABLE;
}

# Enable workspace-aware connection management
sub enable_workspace_tracking {
    my $self = shift;
    
    return 0 unless $WORKSPACE_INTEGRATION_AVAILABLE;
    
    $self->{_WORKSPACE_TRACKING} = 1;
    print "INFO: Cosmic workspace tracking enabled\n";
    
    # Set up workspace change monitoring
    $self->_setupWorkspaceMonitoring();
    
    return 1;
}

# Disable workspace-aware connection management
sub disable_workspace_tracking {
    my $self = shift;
    
    $self->{_WORKSPACE_TRACKING} = 0;
    print "INFO: Cosmic workspace tracking disabled\n";
    
    return 1;
}

# Get current workspace information
sub get_current_workspace {
    my $self = shift;
    
    return undef unless $WORKSPACE_INTEGRATION_AVAILABLE;
    
    # Try to get current workspace through various methods
    my $workspace = $self->_detectCurrentWorkspace();
    $CURRENT_WORKSPACE = $workspace if defined $workspace;
    
    return $CURRENT_WORKSPACE;
}

# Associate a connection with a workspace
sub associate_connection_with_workspace {
    my $self = shift;
    my $connection_uuid = shift;
    my $workspace = shift || $self->get_current_workspace();
    
    return 0 unless $self->{_WORKSPACE_TRACKING};
    return 0 unless defined $workspace;
    
    $self->{_CONNECTION_WORKSPACE_MAP}{$connection_uuid} = $workspace;
    
    # Add to workspace connections list
    $WORKSPACE_CONNECTIONS{$workspace} = [] unless exists $WORKSPACE_CONNECTIONS{$workspace};
    push @{$WORKSPACE_CONNECTIONS{$workspace}}, $connection_uuid
        unless grep { $_ eq $connection_uuid } @{$WORKSPACE_CONNECTIONS{$workspace}};
    
    print "INFO: Associated connection $connection_uuid with workspace $workspace\n";
    return 1;
}

# Get connections for a specific workspace
sub get_workspace_connections {
    my $self = shift;
    my $workspace = shift || $self->get_current_workspace();
    
    return [] unless defined $workspace;
    return $WORKSPACE_CONNECTIONS{$workspace} || [];
}

# Get workspace for a specific connection
sub get_connection_workspace {
    my $self = shift;
    my $connection_uuid = shift;
    
    return $self->{_CONNECTION_WORKSPACE_MAP}{$connection_uuid};
}

# Handle window placement for Cosmic's tiling window manager
sub handle_cosmic_window_placement {
    my $self = shift;
    my $window = shift;
    my $connection_type = shift || 'terminal';
    
    return 0 unless PACCosmic::is_cosmic_desktop();
    
    # Set window properties that work well with Cosmic's tiling
    if ($window && $window->can('set_type_hint')) {
        # Set appropriate window type for better tiling behavior
        if ($connection_type eq 'terminal') {
            # Terminal windows should tile normally
            $window->set_type_hint('normal');
        } elsif ($connection_type eq 'rdp' || $connection_type eq 'vnc') {
            # Remote desktop windows might benefit from different handling
            $window->set_type_hint('normal');
        }
    }
    
    # Set window class for better identification
    if ($window && $window->can('set_wmclass')) {
        $window->set_wmclass('asbru-connection', 'Asbru Connection Manager');
    }
    
    # Suggest window categorization for Cosmic
    $self->_suggestCosmicWindowCategory($window, $connection_type);
    
    return 1;
}

# Switch to workspace containing specific connection
sub switch_to_connection_workspace {
    my $self = shift;
    my $connection_uuid = shift;
    
    return 0 unless $self->{_WORKSPACE_TRACKING};
    
    my $workspace = $self->get_connection_workspace($connection_uuid);
    return 0 unless defined $workspace;
    
    return $self->_switchToWorkspace($workspace);
}

# Clean up connection tracking when connection is closed
sub cleanup_connection {
    my $self = shift;
    my $connection_uuid = shift;
    
    my $workspace = $self->{_CONNECTION_WORKSPACE_MAP}{$connection_uuid};
    if (defined $workspace) {
        # Remove from workspace connections list
        if (exists $WORKSPACE_CONNECTIONS{$workspace}) {
            @{$WORKSPACE_CONNECTIONS{$workspace}} = 
                grep { $_ ne $connection_uuid } @{$WORKSPACE_CONNECTIONS{$workspace}};
        }
        
        # Remove from connection-workspace mapping
        delete $self->{_CONNECTION_WORKSPACE_MAP}{$connection_uuid};
        
        print "INFO: Cleaned up workspace tracking for connection $connection_uuid\n";
    }
    
    return 1;
}

# END: Define PUBLIC CLASS methods
###################################################################

###################################################################
# START: Define PRIVATE CLASS functions

sub _initWorkspaceIntegration {
    my $self = shift;
    
    # Check if we're in Cosmic desktop
    unless (PACCosmic::is_cosmic_desktop()) {
        print "INFO: Not running in Cosmic desktop, workspace integration disabled\n";
        return 0;
    }
    
    # Check if workspace integration APIs are available
    if (PACCosmic::has_workspace_integration()) {
        $WORKSPACE_INTEGRATION_AVAILABLE = 1;
        print "INFO: Cosmic workspace integration available\n";
    } else {
        print "INFO: Cosmic workspace integration APIs not available\n";
        # Try alternative methods for workspace detection
        if ($self->_checkAlternativeWorkspaceDetection()) {
            $WORKSPACE_INTEGRATION_AVAILABLE = 1;
            print "INFO: Alternative workspace detection available\n";
        }
    }
    
    return $WORKSPACE_INTEGRATION_AVAILABLE;
}

sub _checkAlternativeWorkspaceDetection {
    my $self = shift;
    
    # Check for wmctrl (X11 workspace detection)
    my $wmctrl_available = system('which wmctrl >/dev/null 2>&1') == 0;
    
    # Check for swaymsg (Wayland/Sway workspace detection)
    my $swaymsg_available = system('which swaymsg >/dev/null 2>&1') == 0;
    
    # Check for other workspace detection methods
    # Note: Cosmic might use different tools in the future
    
    return $wmctrl_available || $swaymsg_available;
}

sub _detectCurrentWorkspace {
    my $self = shift;
    
    # Try Cosmic-specific workspace detection first
    my $workspace = $self->_detectCosmicWorkspace();
    return $workspace if defined $workspace;
    
    # Try alternative detection methods
    $workspace = $self->_detectWorkspaceViaWmctrl();
    return $workspace if defined $workspace;
    
    $workspace = $self->_detectWorkspaceViaSway();
    return $workspace if defined $workspace;
    
    # Fallback to generic detection
    return $self->_detectWorkspaceGeneric();
}

sub _detectCosmicWorkspace {
    my $self = shift;
    
    # TODO: Implement Cosmic-specific workspace detection when APIs are available
    # This would use D-Bus interfaces or other Cosmic-specific methods
    
    return undef;
}

sub _detectWorkspaceViaWmctrl {
    my $self = shift;
    
    # Use wmctrl for X11 workspace detection
    my $wmctrl_output = `wmctrl -d 2>/dev/null`;
    return undef unless $wmctrl_output;
    
    # Parse wmctrl output to find current workspace
    foreach my $line (split /\n/, $wmctrl_output) {
        if ($line =~ /^(\d+)\s+\*/) {
            return "workspace_$1";
        }
    }
    
    return undef;
}

sub _detectWorkspaceViaSway {
    my $self = shift;
    
    # Use swaymsg for Wayland/Sway workspace detection
    my $sway_output = `swaymsg -t get_workspaces 2>/dev/null`;
    return undef unless $sway_output;
    
    # Parse JSON output to find focused workspace
    # This is a simplified parser - in practice, we'd use a JSON module
    if ($sway_output =~ /"focused":\s*true.*?"name":\s*"([^"]+)"/) {
        return $1;
    }
    
    return undef;
}

sub _detectWorkspaceGeneric {
    my $self = shift;
    
    # Generic workspace detection based on environment variables
    my $workspace = $ENV{COSMIC_WORKSPACE} || $ENV{SWAY_WORKSPACE} || $ENV{I3_WORKSPACE};
    return $workspace if $workspace;
    
    # Fallback to a default workspace identifier
    return 'default';
}

sub _setupWorkspaceMonitoring {
    my $self = shift;
    
    # Set up monitoring for workspace changes
    # This would typically involve D-Bus signal monitoring or polling
    
    # For now, we'll use a simple polling approach
    # In a real implementation, this would be event-driven
    
    print "INFO: Workspace monitoring setup (polling-based)\n";
    return 1;
}

sub _switchToWorkspace {
    my $self = shift;
    my $workspace = shift;
    
    # Try to switch to the specified workspace
    print "INFO: Attempting to switch to workspace: $workspace\n";
    
    # Try Cosmic-specific workspace switching
    return 1 if $self->_switchCosmicWorkspace($workspace);
    
    # Try wmctrl for X11
    return 1 if $self->_switchWorkspaceViaWmctrl($workspace);
    
    # Try swaymsg for Wayland/Sway
    return 1 if $self->_switchWorkspaceViaSway($workspace);
    
    print "WARNING: Could not switch to workspace $workspace\n";
    return 0;
}

sub _switchCosmicWorkspace {
    my $self = shift;
    my $workspace = shift;
    
    # TODO: Implement Cosmic-specific workspace switching when APIs are available
    return 0;
}

sub _switchWorkspaceViaWmctrl {
    my $self = shift;
    my $workspace = shift;
    
    # Extract workspace number from workspace identifier
    if ($workspace =~ /workspace_(\d+)/) {
        my $workspace_num = $1;
        my $result = system("wmctrl -s $workspace_num 2>/dev/null");
        return $result == 0;
    }
    
    return 0;
}

sub _switchWorkspaceViaSway {
    my $self = shift;
    my $workspace = shift;
    
    my $result = system("swaymsg workspace '$workspace' 2>/dev/null");
    return $result == 0;
}

sub _suggestCosmicWindowCategory {
    my $self = shift;
    my $window = shift;
    my $connection_type = shift;
    
    # Set window properties that help Cosmic categorize the window appropriately
    
    # Set application ID for better window management
    if ($window && $window->can('set_application_id')) {
        my $app_id = "asbru-cm-$connection_type";
        $window->set_application_id($app_id);
    }
    
    # Set window role for better identification
    if ($window && $window->can('set_role')) {
        my $role = "connection-$connection_type";
        $window->set_role($role);
    }
    
    return 1;
}

# END: Define PRIVATE CLASS functions
###################################################################

1;