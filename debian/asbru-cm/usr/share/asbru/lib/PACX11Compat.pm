package PACX11Compat;

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

# AI-ASSISTED MODERNIZATION: This module was created with AI assistance to provide
# X11 compatibility layer and replacement for deprecated X11-specific calls

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

use strict;
use warnings;
use Exporter 'import';
use PACCompat;

# Export functions
our @EXPORT = qw(
    x11_get_window_manager
    x11_set_window_hints
    x11_create_system_tray
    x11_handle_window_operations
    x11_get_screen_info
    x11_set_window_properties
    replace_x11_window_calls
    migrate_wnck_functionality
);

###################################################################
# X11 Window Manager Detection

# Get X11 window manager information
sub x11_get_window_manager {
    my %wm_info = (
        name => 'unknown',
        version => 'unknown',
        supports_ewmh => 0,
        supports_icccm => 1,  # Assume basic ICCCM support
    );
    
    # Try to detect window manager
    if ($ENV{DESKTOP_SESSION}) {
        my $session = lc($ENV{DESKTOP_SESSION});
        if ($session =~ /gnome/) {
            $wm_info{name} = 'mutter';
        } elsif ($session =~ /kde/) {
            $wm_info{name} = 'kwin';
        } elsif ($session =~ /xfce/) {
            $wm_info{name} = 'xfwm4';
        }
    }
    
    # Check for window manager via X11 properties (simplified)
    # In a full implementation, this would query X11 properties
    
    return %wm_info;
}

###################################################################
# Window Hints and Properties

# Set X11 window hints (compatibility wrapper)
sub x11_set_window_hints {
    my ($window, $hints) = @_;
    
    # This replaces direct X11/Wnck calls with GTK equivalents
    
    if ($hints->{skip_taskbar}) {
        if (is_gtk4()) {
            # GTK4 method
            $window->set_decorated(0) if exists $hints->{skip_taskbar};
        } else {
            # GTK3 method
            $window->set_skip_taskbar_hint($hints->{skip_taskbar});
        }
    }
    
    if ($hints->{skip_pager}) {
        if (!is_gtk4()) {  # GTK4 doesn't have this concept
            $window->set_skip_pager_hint($hints->{skip_pager});
        }
    }
    
    if ($hints->{window_type}) {
        if (!is_gtk4()) {  # GTK4 handles this differently
            my $type_hint = $hints->{window_type};
            $window->set_type_hint($type_hint);
        }
    }
    
    if ($hints->{urgency}) {
        $window->set_urgency_hint($hints->{urgency});
    }
    
    return 1;
}

# Set window properties (X11 compatible)
sub x11_set_window_properties {
    my ($window, $properties) = @_;
    
    # Basic window properties that work in both X11 and Wayland
    if ($properties->{title}) {
        $window->set_title($properties->{title});
    }
    
    if ($properties->{icon}) {
        if (is_gtk4()) {
            # GTK4 icon setting
            $window->set_icon_name($properties->{icon});
        } else {
            # GTK3 icon setting
            if (ref($properties->{icon}) eq 'Gtk3::Gdk::Pixbuf') {
                $window->set_icon($properties->{icon});
            } else {
                $window->set_icon_name($properties->{icon});
            }
        }
    }
    
    if ($properties->{resizable}) {
        $window->set_resizable($properties->{resizable});
    }
    
    if ($properties->{modal}) {
        $window->set_modal($properties->{modal});
    }
    
    return 1;
}

###################################################################
# System Tray Compatibility

# Create system tray (X11 compatible)
sub x11_create_system_tray {
    my ($app_name, $icon_name, $tooltip) = @_;
    
    my %tray_info = (
        available => 0,
        type => 'none',
        widget => undef,
        error => '',
    );
    
    # Check if we're actually on X11
    if (detect_display_server() ne 'x11') {
        $tray_info{error} = 'Not running on X11';
        return \%tray_info;
    }
    
    # Try to create system tray icon
    eval {
        if (is_gtk4()) {
            # GTK4 doesn't have traditional system tray
            # This is a limitation we need to handle
            $tray_info{error} = 'GTK4 does not support traditional system tray';
        } else {
            # GTK3 system tray
            my $status_icon = Gtk3::StatusIcon->new();
            
            if ($icon_name) {
                if (-f $icon_name) {
                    $status_icon->set_from_file($icon_name);
                } else {
                    $status_icon->set_from_icon_name($icon_name);
                }
            }
            
            if ($tooltip) {
                $status_icon->set_tooltip_text($tooltip);
            }
            
            $tray_info{available} = 1;
            $tray_info{type} = 'gtk3_status_icon';
            $tray_info{widget} = $status_icon;
        }
    };
    
    if ($@) {
        $tray_info{error} = "Failed to create system tray: $@";
    }
    
    return \%tray_info;
}

###################################################################
# Window Operations

# Handle X11 window operations
sub x11_handle_window_operations {
    my ($window, $operation, $params) = @_;
    
    $params //= {};
    
    if ($operation eq 'minimize') {
        if (is_gtk4()) {
            $window->minimize();
        } else {
            $window->iconify();
        }
        return 1;
    } elsif ($operation eq 'maximize') {
        $window->maximize();
        return 1;
    } elsif ($operation eq 'unmaximize') {
        $window->unmaximize();
        return 1;
    } elsif ($operation eq 'fullscreen') {
        $window->fullscreen();
        return 1;
    } elsif ($operation eq 'unfullscreen') {
        $window->unfullscreen();
        return 1;
    } elsif ($operation eq 'present') {
        $window->present();
        return 1;
    } elsif ($operation eq 'stick') {
        if (!is_gtk4()) {  # GTK4 doesn't have stick/unstick
            $window->stick();
        }
        return 1;
    } elsif ($operation eq 'unstick') {
        if (!is_gtk4()) {
            $window->unstick();
        }
        return 1;
    }
    
    return 0;
}

###################################################################
# Screen Information

# Get screen information (X11 compatible)
sub x11_get_screen_info {
    my %screen_info = (
        width => 0,
        height => 0,
        monitors => [],
        primary_monitor => 0,
    );
    
    eval {
        if (is_gtk4()) {
            # GTK4 screen information
            my $display = Gtk4::Display::get_default();
            if ($display) {
                my $monitor = $display->get_primary_monitor();
                if ($monitor) {
                    my $geometry = $monitor->get_geometry();
                    $screen_info{width} = $geometry->{width};
                    $screen_info{height} = $geometry->{height};
                }
                
                # Get all monitors
                my $n_monitors = $display->get_n_monitors();
                for my $i (0 .. $n_monitors - 1) {
                    my $mon = $display->get_monitor($i);
                    my $geom = $mon->get_geometry();
                    push @{$screen_info{monitors}}, {
                        x => $geom->{x},
                        y => $geom->{y},
                        width => $geom->{width},
                        height => $geom->{height},
                        is_primary => ($mon == $monitor),
                    };
                }
            }
        } else {
            # GTK3 screen information
            my $screen = eval { Gtk3::Gdk::Screen::get_default() };
            if ($screen) {
                $screen_info{width} = $screen->get_width();
                $screen_info{height} = $screen->get_height();
                
                # Get monitor information
                my $n_monitors = $screen->get_n_monitors();
                for my $i (0 .. $n_monitors - 1) {
                    my $geometry = $screen->get_monitor_geometry($i);
                    push @{$screen_info{monitors}}, {
                        x => $geometry->{x},
                        y => $geometry->{y},
                        width => $geometry->{width},
                        height => $geometry->{height},
                        is_primary => ($i == $screen->get_primary_monitor()),
                    };
                }
                $screen_info{primary_monitor} = $screen->get_primary_monitor();
            }
        }
    };
    
    return %screen_info;
}

###################################################################
# Migration Helpers

# Replace X11-specific window calls with compatible alternatives
sub replace_x11_window_calls {
    my ($code_ref) = @_;
    
    # This function would help migrate X11-specific calls
    # For now, it's a placeholder for the migration process
    
    my %replacements = (
        'Wnck::Window' => 'GTK window operations',
        'Wnck::Screen' => 'GTK screen operations',
        'X11::Protocol' => 'GTK/GDK operations',
    );
    
    return \%replacements;
}

# Migrate Wnck functionality to GTK equivalents
sub migrate_wnck_functionality {
    my ($wnck_operation, $params) = @_;
    
    # Map Wnck operations to GTK equivalents
    my %wnck_to_gtk = (
        'get_windows' => sub {
            # Would return list of application windows
            return [];
        },
        'get_active_window' => sub {
            # Would return currently active window
            return undef;
        },
        'get_workspace' => sub {
            # Workspace information is limited in Wayland
            return { number => 0, name => 'Desktop' };
        },
    );
    
    if (exists $wnck_to_gtk{$wnck_operation}) {
        return $wnck_to_gtk{$wnck_operation}->($params);
    }
    
    return undef;
}

###################################################################
# Module initialization

if ($ENV{ASBRU_DEBUG}) {
    print STDERR "PACX11Compat: Module loaded\n";
    if (detect_display_server() eq 'x11') {
        my %wm_info = x11_get_window_manager();
        print STDERR "PACX11Compat: Window manager: $wm_info{name}\n";
    }
}

1;

__END__

=head1 NAME

PACX11Compat - X11 Compatibility Layer for Ásbrú Connection Manager

=head1 SYNOPSIS

    use PACX11Compat;
    
    # Get window manager information
    my %wm_info = x11_get_window_manager();
    
    # Set window hints
    x11_set_window_hints($window, {
        skip_taskbar => 1,
        window_type => 'dialog'
    });
    
    # Create system tray
    my $tray = x11_create_system_tray('Asbru', 'asbru-icon', 'Connection Manager');
    
    # Handle window operations
    x11_handle_window_operations($window, 'maximize');

=head1 DESCRIPTION

PACX11Compat provides X11 compatibility functions and migration helpers for 
the modernized Ásbrú Connection Manager. It replaces deprecated X11-specific 
calls with GTK equivalents that work in both X11 and Wayland environments.

This module helps migrate away from:
- Direct X11 protocol calls
- Wnck library dependencies
- X11-specific window management

=head1 FUNCTIONS

=head2 Window Management

=over 4

=item x11_get_window_manager()

Returns information about the current window manager.

=item x11_set_window_hints($window, $hints)

Sets window hints using GTK methods instead of direct X11 calls.

=item x11_handle_window_operations($window, $operation, $params)

Handles window operations (minimize, maximize, etc.) in a compatible way.

=back

=head2 System Integration

=over 4

=item x11_create_system_tray($app_name, $icon, $tooltip)

Creates system tray icon with fallback for environments that don't support it.

=item x11_get_screen_info()

Gets screen and monitor information using GTK methods.

=back

=head1 AUTHOR

Ásbrú Connection Manager team (https://asbru-cm.net)

=head1 COPYRIGHT

Copyright (C) 2017-2024 Ásbrú Connection Manager team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut