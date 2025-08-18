package PACCompat;

###############################################################################
# This file is part of Ásbrú Connection Manager
#
# Copyright (C) 2017-2024 Ásbrú Connection Manager team (https://asbru-cm.net)
# Copyright (C) 2010-2016 David Torrejón Vaquerizas
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

# AI-ASSISTED MODERNIZATION: This entire module was created with AI assistance
# as part of the Ásbrú Connection Manager modernization project (v7.0.0).
# 
# AI Assistance Details:
# - Module architecture and design: AI-generated with human review
# - GTK3/GTK4 compatibility functions: AI-implemented based on GTK documentation
# - Environment detection logic: AI-developed with extensive testing validation
# - Widget creation wrappers: AI-generated to handle API differences between GTK versions
# - Display server detection: AI-implemented for Wayland/X11 compatibility
# - Desktop environment detection: AI-enhanced for modern DE support (Cosmic, etc.)
#
# Human Oversight:
# - All functions tested on PopOS 24.04, Ubuntu 24.04, and Fedora 40+
# - Code reviewed for security and performance implications
# - Integration tested with existing Ásbrú Connection Manager codebase
# - Documentation and comments added for maintainability
#
# Rationale: This compatibility layer enables seamless migration from GTK3 to GTK4
# while maintaining backward compatibility and supporting modern display servers.

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

use strict;
use warnings;
use Exporter 'import';

# Try to detect available GTK version
our $GTK_VERSION = 3;  # Default to GTK3
our $GTK_AVAILABLE = 0;

# Try to load GTK4 first, fallback to GTK3
eval {
    require Gtk4;
    Gtk4->import('-init');
    $GTK_VERSION = 4;
    $GTK_AVAILABLE = 1;
};

if (!$GTK_AVAILABLE) {
    eval {
        require Gtk3;
        Gtk3->import('-init');
        $GTK_VERSION = 3;
        $GTK_AVAILABLE = 1;
    };
}

if (!$GTK_AVAILABLE) {
    die "ERROR: Neither GTK3 nor GTK4 Perl bindings are available\n";
}

# Export functions and variables
our @EXPORT = qw(
    create_window
    create_box
    create_button
    create_toggle_button
    create_label
    create_entry
    create_text_view
    create_text_view_with_buffer
    create_scrolled_window
    create_notebook
    create_paned
    create_frame
    create_separator
    create_menu_bar
    create_menu
    create_menu_item
    create_check_button
    create_radio_button
    create_combo_box_text
    create_tree_view
    create_list_store
    create_tree_store
    set_widget_size_request
    set_widget_sensitive
    set_widget_visible
    connect_signal
    show_widget
    hide_widget
    destroy_widget
    get_gtk_version
    is_gtk4
    detect_display_server
    detect_desktop_environment
    get_environment_info
    is_wayland
    is_x11
    is_cosmic_desktop
    is_gnome_desktop
    get_display_server_capabilities
    $GTK_VERSION
);

###################################################################
# Widget Creation Functions

# Window creation
sub create_window {
    my ($type, $title) = @_;
    $type //= 'toplevel';
    
    my $window;
    if ($GTK_VERSION >= 4) {
        $window = Gtk4::Window->new();
        $window->set_title($title) if defined $title;
    } else {
        $window = Gtk3::Window->new($type);
        $window->set_title($title) if defined $title;
    }
    
    return $window;
}

# Box creation (replaces VBox/HBox)
sub create_box {
    my ($orientation, $spacing) = @_;
    $orientation //= 'vertical';
    $spacing //= 0;
    
    my $box;
    if ($GTK_VERSION >= 4) {
        $box = Gtk4::Box->new($orientation, $spacing);
    } else {
        if ($orientation eq 'vertical') {
            $box = Gtk3::VBox->new(0, $spacing);
        } else {
            $box = Gtk3::HBox->new(0, $spacing);
        }
    }
    
    return $box;
}

# Button creation
sub create_button {
    my ($label) = @_;
    
    my $button;
    if ($GTK_VERSION >= 4) {
        if (defined $label) {
            $button = Gtk4::Button->new_with_label($label);
        } else {
            $button = Gtk4::Button->new();
        }
    } else {
        if (defined $label) {
            $button = Gtk3::Button->new_with_label($label);
        } else {
            $button = Gtk3::Button->new();
        }
    }
    
    return $button;
}

# ToggleButton creation
sub create_toggle_button {
    my ($label) = @_;
    
    my $button;
    if ($GTK_VERSION >= 4) {
        $button = Gtk4::ToggleButton->new();
        $button->set_label($label) if defined $label;
    } else {
        if (defined $label) {
            $button = Gtk3::ToggleButton->new_with_label($label);
        } else {
            $button = Gtk3::ToggleButton->new();
        }
    }
    
    return $button;
}

# Label creation
sub create_label {
    my ($text) = @_;
    
    my $label;
    if ($GTK_VERSION >= 4) {
        $label = Gtk4::Label->new($text);
    } else {
        $label = Gtk3::Label->new($text);
    }
    
    return $label;
}

# Entry creation
sub create_entry {
    my $entry;
    if ($GTK_VERSION >= 4) {
        $entry = Gtk4::Entry->new();
    } else {
        $entry = Gtk3::Entry->new();
    }
    
    return $entry;
}

# TextView creation
sub create_text_view {
    my $text_view;
    if ($GTK_VERSION >= 4) {
        $text_view = Gtk4::TextView->new();
    } else {
        $text_view = Gtk3::TextView->new();
    }
    
    return $text_view;
}

# TextView creation with buffer
sub create_text_view_with_buffer {
    my ($buffer) = @_;
    
    my $text_view;
    if ($GTK_VERSION >= 4) {
        $text_view = Gtk4::TextView->new_with_buffer($buffer);
    } else {
        $text_view = Gtk3::TextView->new_with_buffer($buffer);
    }
    
    return $text_view;
}

# ScrolledWindow creation
sub create_scrolled_window {
    my $scrolled;
    if ($GTK_VERSION >= 4) {
        $scrolled = Gtk4::ScrolledWindow->new();
    } else {
        $scrolled = Gtk3::ScrolledWindow->new();
    }
    
    return $scrolled;
}

# Notebook creation
sub create_notebook {
    my $notebook;
    if ($GTK_VERSION >= 4) {
        $notebook = Gtk4::Notebook->new();
    } else {
        $notebook = Gtk3::Notebook->new();
    }
    
    return $notebook;
}

# Paned creation
sub create_paned {
    my ($orientation) = @_;
    $orientation //= 'horizontal';
    
    my $paned;
    if ($GTK_VERSION >= 4) {
        $paned = Gtk4::Paned->new($orientation);
    } else {
        if ($orientation eq 'horizontal') {
            $paned = Gtk3::HPaned->new();
        } else {
            $paned = Gtk3::VPaned->new();
        }
    }
    
    return $paned;
}

# Frame creation
sub create_frame {
    my ($label) = @_;
    
    my $frame;
    if ($GTK_VERSION >= 4) {
        $frame = Gtk4::Frame->new($label);
    } else {
        $frame = Gtk3::Frame->new($label);
    }
    
    return $frame;
}

# Separator creation
sub create_separator {
    my ($orientation) = @_;
    $orientation //= 'horizontal';
    
    my $separator;
    if ($GTK_VERSION >= 4) {
        $separator = Gtk4::Separator->new($orientation);
    } else {
        if ($orientation eq 'horizontal') {
            $separator = Gtk3::HSeparator->new();
        } else {
            $separator = Gtk3::VSeparator->new();
        }
    }
    
    return $separator;
}

# MenuBar creation
sub create_menu_bar {
    my $menu_bar;
    if ($GTK_VERSION >= 4) {
        # GTK4 uses different menu system, but provide basic compatibility
        $menu_bar = Gtk4::Box->new('horizontal', 0);
        # Note: GTK4 menus work differently, this is a basic fallback
    } else {
        $menu_bar = Gtk3::MenuBar->new();
    }
    
    return $menu_bar;
}

# Menu creation
sub create_menu {
    my $menu;
    if ($GTK_VERSION >= 4) {
        # GTK4 uses GMenu, but provide basic compatibility
        $menu = Gtk4::PopoverMenu->new();
    } else {
        $menu = Gtk3::Menu->new();
    }
    
    return $menu;
}

# MenuItem creation
sub create_menu_item {
    my ($label) = @_;
    
    my $menu_item;
    if ($GTK_VERSION >= 4) {
        # GTK4 uses different menu system
        $menu_item = Gtk4::Button->new_with_label($label);
    } else {
        if (defined $label) {
            $menu_item = Gtk3::MenuItem->new_with_label($label);
        } else {
            $menu_item = Gtk3::MenuItem->new();
        }
    }
    
    return $menu_item;
}

# CheckButton creation
sub create_check_button {
    my ($label) = @_;
    
    my $check_button;
    if ($GTK_VERSION >= 4) {
        $check_button = Gtk4::CheckButton->new_with_label($label);
    } else {
        $check_button = Gtk3::CheckButton->new_with_label($label);
    }
    
    return $check_button;
}

# RadioButton creation
sub create_radio_button {
    my ($group, $label) = @_;
    
    my $radio_button;
    if ($GTK_VERSION >= 4) {
        $radio_button = Gtk4::CheckButton->new_with_label($label);
        # GTK4 uses CheckButton with grouping for radio behavior
        if (defined $group) {
            $radio_button->set_group($group);
        }
    } else {
        if (defined $group) {
            $radio_button = Gtk3::RadioButton->new_with_label($group, $label);
        } else {
            $radio_button = Gtk3::RadioButton->new_with_label(undef, $label);
        }
    }
    
    return $radio_button;
}

# ComboBoxText creation
sub create_combo_box_text {
    my $combo;
    if ($GTK_VERSION >= 4) {
        $combo = Gtk4::ComboBoxText->new();
    } else {
        $combo = Gtk3::ComboBoxText->new();
    }
    
    return $combo;
}

# TreeView creation
sub create_tree_view {
    my ($model) = @_;
    
    my $tree_view;
    if ($GTK_VERSION >= 4) {
        # GTK4 uses different tree/list widgets
        $tree_view = Gtk4::ListView->new();
    } else {
        $tree_view = Gtk3::TreeView->new($model);
    }
    
    return $tree_view;
}

# ListStore creation
sub create_list_store {
    my (@types) = @_;
    
    my $list_store;
    if ($GTK_VERSION >= 4) {
        # GTK4 uses different model system
        # This is a simplified compatibility layer
        $list_store = Gtk4::ListStore->new(@types);
    } else {
        $list_store = Gtk3::ListStore->new(@types);
    }
    
    return $list_store;
}

# TreeStore creation
sub create_tree_store {
    my (@types) = @_;
    
    my $tree_store;
    if ($GTK_VERSION >= 4) {
        $tree_store = Gtk4::TreeStore->new(@types);
    } else {
        $tree_store = Gtk3::TreeStore->new(@types);
    }
    
    return $tree_store;
}

###################################################################
# Widget Property Functions

# Set widget size request
sub set_widget_size_request {
    my ($widget, $width, $height) = @_;
    
    if ($GTK_VERSION >= 4) {
        $widget->set_size_request($width, $height);
    } else {
        $widget->set_size_request($width, $height);
    }
}

# Set widget sensitivity
sub set_widget_sensitive {
    my ($widget, $sensitive) = @_;
    
    if ($GTK_VERSION >= 4) {
        $widget->set_sensitive($sensitive);
    } else {
        $widget->set_sensitive($sensitive);
    }
}

# Set widget visibility
sub set_widget_visible {
    my ($widget, $visible) = @_;
    
    if ($GTK_VERSION >= 4) {
        $widget->set_visible($visible);
    } else {
        $widget->set_visible($visible);
    }
}

# Connect signal
sub connect_signal {
    my ($widget, $signal, $callback, @data) = @_;
    
    return $widget->signal_connect($signal, $callback, @data);
}

# Show widget
sub show_widget {
    my ($widget) = @_;
    
    if ($GTK_VERSION >= 4) {
        $widget->show();
    } else {
        $widget->show();
    }
}

# Hide widget
sub hide_widget {
    my ($widget) = @_;
    
    if ($GTK_VERSION >= 4) {
        $widget->hide();
    } else {
        $widget->hide();
    }
}

# Destroy widget
sub destroy_widget {
    my ($widget) = @_;
    
    if ($GTK_VERSION >= 4) {
        # GTK4 uses different destruction model
        $widget->unparent() if $widget->can('unparent');
    } else {
        $widget->destroy();
    }
}

###################################################################
# Utility Functions

# Get GTK version
sub get_gtk_version {
    return $GTK_VERSION;
}

# Check if GTK4 is being used
sub is_gtk4 {
    return $GTK_VERSION >= 4;
}

# Detect display server (Wayland vs X11)
sub detect_display_server {
    my ($force_detection) = @_;
    
    # Check for forced detection (bypass cache)
    if (!$force_detection && defined $ENV{ASBRU_DISPLAY_SERVER}) {
        return $ENV{ASBRU_DISPLAY_SERVER};
    }
    
    my $detected_server = 'unknown';
    
    # Check if GDK_BACKEND is explicitly set to x11 (override Wayland detection)
    if ($ENV{GDK_BACKEND} && $ENV{GDK_BACKEND} eq 'x11') {
        $detected_server = 'x11';
        print STDERR "PACCompat: Display server: x11 (forced via GDK_BACKEND)\n" if $ENV{ASBRU_DEBUG};
    }
    # Check for Wayland (but only if not forced to x11)
    elsif ($ENV{WAYLAND_DISPLAY}) {
        $detected_server = 'wayland';
        
        # Additional Wayland compositor detection
        if ($ENV{XDG_SESSION_TYPE} && $ENV{XDG_SESSION_TYPE} eq 'wayland') {
            # Confirmed Wayland session
        } elsif ($ENV{GDK_BACKEND} && $ENV{GDK_BACKEND} eq 'wayland') {
            # GTK forced to Wayland
        }
    }
    # Check for X11
    elsif ($ENV{DISPLAY}) {
        $detected_server = 'x11';
        
        # Additional X11 validation
        if ($ENV{XDG_SESSION_TYPE} && $ENV{XDG_SESSION_TYPE} eq 'x11') {
            # Confirmed X11 session
        }
    }
    # Check for other display servers
    elsif ($ENV{MIR_SOCKET}) {
        $detected_server = 'mir';
    }
    
    # Cache the detection result
    $ENV{ASBRU_DISPLAY_SERVER} = $detected_server;
    
    return $detected_server;
}

# Detect desktop environment with comprehensive detection
sub detect_desktop_environment {
    my ($force_detection) = @_;
    
    # Check for forced detection (bypass cache)
    if (!$force_detection && defined $ENV{ASBRU_DESKTOP_ENV}) {
        return $ENV{ASBRU_DESKTOP_ENV};
    }
    
    my $detected_env = 'unknown';
    
    # Collect potential desktop indicators (highest priority first)
    my @candidates;
    push @candidates, $ENV{XDG_SESSION_DESKTOP} if $ENV{XDG_SESSION_DESKTOP};
    push @candidates, $ENV{ORIGINAL_XDG_CURRENT_DESKTOP} if $ENV{ORIGINAL_XDG_CURRENT_DESKTOP};
    push @candidates, $ENV{XDG_CURRENT_DESKTOP} if $ENV{XDG_CURRENT_DESKTOP};

    if (@candidates) {
        # Normalize and deduplicate while preserving order
        my %seen; @candidates = grep { defined $_ && !$seen{$_}++ } @candidates;
        my $joined = join(':', @candidates);
        my $desktop = lc($joined);
        # Split on ':' and evaluate tokens (left-to-right, cosmic wins early)
        my @tokens = split(/:/, $desktop);
        foreach my $tok (@tokens) {
            next unless length $tok;
            if ($tok =~ /cosmic/) { $detected_env = 'cosmic'; last; }
        }
        if ($detected_env eq 'unknown') {
            foreach my $tok (@tokens) {
                if ($tok =~ /gnome/) { $detected_env = 'gnome'; last; }
                elsif ($tok =~ /kde|plasma/) { $detected_env = 'kde'; last; }
                elsif ($tok =~ /xfce/) { $detected_env = 'xfce'; last; }
                elsif ($tok =~ /mate/) { $detected_env = 'mate'; last; }
                elsif ($tok =~ /cinnamon/) { $detected_env = 'cinnamon'; last; }
                elsif ($tok =~ /lxde/) { $detected_env = 'lxde'; last; }
                elsif ($tok =~ /lxqt/) { $detected_env = 'lxqt'; last; }
                elsif ($tok =~ /unity/) { $detected_env = 'unity'; last; }
                elsif ($tok =~ /budgie/) { $detected_env = 'budgie'; last; }
                elsif ($tok =~ /pantheon/) { $detected_env = 'pantheon'; last; }
            }
            # Fallback to first token if still unknown
            if ($detected_env eq 'unknown' && @tokens) { $detected_env = $tokens[0]; }
        }
        print STDERR "PACCompat: DE tokens=@tokens => $detected_env\n" if $ENV{ASBRU_DEBUG};
    }
    
    # Fallback detection methods if XDG_CURRENT_DESKTOP is not available
    if ($detected_env eq 'unknown') {
        # Check for Cosmic desktop (PopOS specific)
        if ($ENV{COSMIC_SESSION} || $ENV{POP_OS_COSMIC}) {
            $detected_env = 'cosmic';
        }
        # Check for GNOME
        elsif ($ENV{GNOME_DESKTOP_SESSION_ID} || $ENV{GNOME_SHELL_SESSION_MODE}) {
            $detected_env = 'gnome';
        }
        # Check for KDE
        elsif ($ENV{KDE_SESSION_VERSION} || $ENV{KDE_FULL_SESSION}) {
            $detected_env = 'kde';
        }
        # Check session-based detection
        elsif ($ENV{DESKTOP_SESSION}) {
            my $session = lc($ENV{DESKTOP_SESSION});
            if ($session =~ /gnome/) {
                $detected_env = 'gnome';
            } elsif ($session =~ /kde|plasma/) {
                $detected_env = 'kde';
            } elsif ($session =~ /xfce/) {
                $detected_env = 'xfce';
            } elsif ($session =~ /cosmic/) {
                $detected_env = 'cosmic';
            } else {
                $detected_env = $session;
            }
        }
        # Check GDM session
        elsif ($ENV{GDMSESSION}) {
            my $gdm_session = lc($ENV{GDMSESSION});
            if ($gdm_session =~ /gnome/) {
                $detected_env = 'gnome';
            } elsif ($gdm_session =~ /kde/) {
                $detected_env = 'kde';
            } elsif ($gdm_session =~ /cosmic/) {
                $detected_env = 'cosmic';
            } else {
                $detected_env = $gdm_session;
            }
        }
    }
    
    # Cache the detection result
    $ENV{ASBRU_DESKTOP_ENV} = $detected_env;
    
    return $detected_env;
}

# Get detailed environment information
sub get_environment_info {
    my %info = (
        display_server => detect_display_server(),
        desktop_environment => detect_desktop_environment(),
        session_type => $ENV{XDG_SESSION_TYPE} || 'unknown',
        session_desktop => $ENV{XDG_SESSION_DESKTOP} || 'unknown',
        current_desktop => $ENV{XDG_CURRENT_DESKTOP} || 'unknown',
        wayland_display => $ENV{WAYLAND_DISPLAY} || 'none',
        x11_display => $ENV{DISPLAY} || 'none',
        gtk_version => $GTK_VERSION,
        gdk_backend => $ENV{GDK_BACKEND} || 'auto',
    );
    
    return %info;
}

# Check if running under Wayland
sub is_wayland {
    return detect_display_server() eq 'wayland';
}

# Check if running under X11
sub is_x11 {
    return detect_display_server() eq 'x11';
}

# Check if running under Cosmic desktop
sub is_cosmic_desktop {
    return detect_desktop_environment() eq 'cosmic';
}

# Check if running under GNOME
sub is_gnome_desktop {
    my $de = detect_desktop_environment();
    return $de eq 'gnome' || $de eq 'ubuntu';  # Ubuntu uses GNOME
}

# Get display server capabilities
sub get_display_server_capabilities {
    my $server = detect_display_server();
    
    my %capabilities = (
        system_tray => 0,
        window_management => 0,
        global_shortcuts => 0,
        screen_capture => 0,
        clipboard_manager => 0,
        file_dialogs => 0,
    );
    
    if ($server eq 'x11') {
        %capabilities = (
            system_tray => 1,
            window_management => 1,
            global_shortcuts => 1,
            screen_capture => 1,
            clipboard_manager => 1,
            file_dialogs => 1,
        );
    } elsif ($server eq 'wayland') {
        %capabilities = (
            system_tray => 0,  # Depends on compositor
            window_management => 0,  # Limited
            global_shortcuts => 0,  # Compositor dependent
            screen_capture => 1,  # Via portals
            clipboard_manager => 1,  # Built-in
            file_dialogs => 1,  # Via portals
        );
        
        # Check for specific Wayland compositor capabilities
        my $de = detect_desktop_environment();
        if ($de eq 'gnome') {
            $capabilities{screen_capture} = 1;  # GNOME Shell supports portals
            $capabilities{file_dialogs} = 1;
        } elsif ($de eq 'cosmic') {
            # Cosmic desktop capabilities (may vary)
            $capabilities{screen_capture} = 1;
            $capabilities{file_dialogs} = 1;
        }
    }
    
    return %capabilities;
}

###################################################################
# Module initialization

# Initialize Wayland support if needed
if (detect_display_server() eq 'wayland') {
    eval {
        require PACWayland;
        PACWayland::wayland_init();
    };
    if ($@) {
        warn "Failed to initialize Wayland support: $@\n";
    }
}

# Print initialization info
if ($ENV{ASBRU_DEBUG} || $ENV{VERBOSE}) {
    print STDERR "PACCompat: Initialized with GTK$GTK_VERSION\n";
    print STDERR "PACCompat: Display server: " . detect_display_server() . "\n";
    print STDERR "PACCompat: Desktop environment: " . detect_desktop_environment() . "\n";
}

1;

__END__

=head1 NAME

PACCompat - GTK3/GTK4 Compatibility Layer for Ásbrú Connection Manager

=head1 SYNOPSIS

    use PACCompat;
    
    # Create widgets using compatibility functions
    my $window = create_window('toplevel', 'My Window');
    my $box = create_box('vertical', 5);
    my $button = create_button('Click Me');
    
    # Detect environment
    my $display_server = detect_display_server();
    my $desktop_env = detect_desktop_environment();
    
    # Check GTK version
    if (is_gtk4()) {
        print "Using GTK4\n";
    }

=head1 DESCRIPTION

PACCompat provides a compatibility layer between GTK3 and GTK4 for the 
modernization of Ásbrú Connection Manager. It automatically detects the 
available GTK version and provides unified functions for widget creation 
and management.

This module was created as part of the AI-assisted modernization effort 
to update Ásbrú Connection Manager for modern Linux distributions.

=head1 FUNCTIONS

=head2 Widget Creation

=over 4

=item create_window($type, $title)

Creates a window widget compatible with both GTK3 and GTK4.

=item create_box($orientation, $spacing)

Creates a box container. Replaces VBox/HBox with unified interface.

=item create_button($label)

Creates a button widget.

=item create_label($text)

Creates a label widget.

=back

=head2 Environment Detection

=over 4

=item detect_display_server()

Returns 'wayland', 'x11', or 'unknown' based on environment variables.

=item detect_desktop_environment()

Returns the detected desktop environment (cosmic, gnome, kde, etc.).

=item get_gtk_version()

Returns the GTK version number (3 or 4).

=item is_gtk4()

Returns true if GTK4 is being used.

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