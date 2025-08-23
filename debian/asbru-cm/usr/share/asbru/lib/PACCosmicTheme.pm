package PACCosmicTheme;

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

# AI-assisted modernization: This module provides Cosmic desktop theme
# integration for consistent visual appearance and dark/light mode support

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

# Standard
use strict;
use warnings;

# GTK: try Gtk4 then fall back to Gtk3 (Cosmic theming optional)
my $HAVE_GTK4 = 0;
# Safe dual-GTK init: try Gtk4, else fall back to Gtk3; avoid illegal 'use ... unless' syntax
BEGIN {
    eval { require Gtk4; Gtk4->import('-init'); $HAVE_GTK4 = 1; };
    if (!$HAVE_GTK4) {
        require Gtk3; Gtk3->import('-init');
    }
}

# PAC modules
use PACCosmic;
use PACCompat;

# END: Import Modules
###################################################################

###################################################################
# Define GLOBAL CLASS variables

my $THEME_MONITORING_ACTIVE = 0;
my $CURRENT_THEME_VARIANT = 'light';
my $COSMIC_ACCENT_COLOR = undef;
my %COSMIC_THEME_COLORS = ();

# END: Define GLOBAL CLASS variables
###################################################################

###################################################################
# START: Define PUBLIC CLASS methods

sub new {
    my $class = shift;
    my $main_ref = shift;

    my $self = {
        '_MAIN' => $main_ref,
        '_THEME_CALLBACKS' => [],
        '_CSS_PROVIDER' => undef,
    };
    # Bless early so that subsequent method calls (like _initCosmicTheme) have a proper object
    bless($self, $class);

    # Initialize theme integration only if Gtk4 present; otherwise silently skip (avoid noisy warnings on Gtk3-only systems)
    if ($HAVE_GTK4) {
        eval { $self->_initCosmicTheme(); 1 } or do { print "WARNING: Cosmic theme init failed (pre-bless stage): $@\n" if $@; };
    } else {
        print "INFO: Skipping Cosmic theme integration (Gtk4 not available)\n" if $ENV{ASBRU_DEBUG};
    }

    # Ensure CSS provider exists (Gtk3 vs Gtk4)
    eval {
        if (!$self->{_CSS_PROVIDER}) {
            if ($HAVE_GTK4) {
                require Gtk4::CssProvider; # may already be loaded
                $self->{_CSS_PROVIDER} = Gtk4::CssProvider->new();
            } else {
                # Gtk3::CssProvider may not be packaged; skip quietly unless debugging
                eval { require Gtk3::CssProvider; $self->{_CSS_PROVIDER} = Gtk3::CssProvider->new(); 1 } or do {
                    print "INFO: Gtk3::CssProvider not available (theme CSS skipped)\n" if $ENV{ASBRU_DEBUG};
                };
            }
        }
    };
    print "WARNING: Failed to create CSS provider: $@\n" if $@ && $ENV{ASBRU_DEBUG};

    return $self;
}

# Check if Cosmic theme integration is available
sub is_cosmic_theme_available {
    my $self = shift;
    return 0 unless $HAVE_GTK4; # only attempt if Gtk4 present
    return PACCosmic::is_cosmic_desktop();
}

# Get current theme variant (light/dark)
sub get_theme_variant {
    my $self = shift;
    
    return $CURRENT_THEME_VARIANT unless $self->is_cosmic_theme_available();
    
    # Update current theme variant
    $CURRENT_THEME_VARIANT = $self->_detectThemeVariant();
    return $CURRENT_THEME_VARIANT;
}

# Get Cosmic accent color
sub get_accent_color {
    my $self = shift;
    
    return $COSMIC_ACCENT_COLOR unless $self->is_cosmic_theme_available();
    
    # Update accent color
    $COSMIC_ACCENT_COLOR = $self->_detectAccentColor();
    return $COSMIC_ACCENT_COLOR;
}

# Apply Cosmic theme to the application
sub apply_cosmic_theme {
    my $self = shift;
    my $force_update = shift || 0;
    
    return 0 unless $self->is_cosmic_theme_available();
    
    print "INFO: Applying Cosmic theme integration\n";
    
    # Update theme information
    my $theme_info = PACCosmic::get_theme_info();
    if ($theme_info) {
        $CURRENT_THEME_VARIANT = $theme_info->{'variant'} || 'light';
        $COSMIC_ACCENT_COLOR = $theme_info->{'accent_color'};
    }
    
    # Apply CSS styling
    $self->_applyCosmicCSS();
    
    # Update application colors
    $self->_updateApplicationColors();
    
    # Notify callbacks about theme change
    $self->_notifyThemeCallbacks();
    
    return 1;
}

# Register callback for theme changes
sub register_theme_callback {
    my $self = shift;
    my $callback = shift;
    
    return 0 unless ref($callback) eq 'CODE';
    
    push @{$self->{_THEME_CALLBACKS}}, $callback;
    return 1;
}

# Enable automatic theme monitoring
sub enable_theme_monitoring {
    my $self = shift;
    
    return 0 unless $self->is_cosmic_theme_available();
    
    $THEME_MONITORING_ACTIVE = 1;
    print "INFO: Cosmic theme monitoring enabled\n";
    
    # Set up theme change monitoring
    $self->_setupThemeMonitoring();
    
    return 1;
}

# Disable automatic theme monitoring
sub disable_theme_monitoring {
    my $self = shift;
    
    $THEME_MONITORING_ACTIVE = 0;
    print "INFO: Cosmic theme monitoring disabled\n";
    
    return 1;
}

# Get recommended theme settings for Cosmic
sub get_cosmic_theme_settings {
    my $self = shift;
    
    return undef unless $self->is_cosmic_theme_available();
    
    my %settings = (
        'use_system_theme' => 1,
        'follow_system_dark_mode' => 1,
        'theme_variant' => $self->get_theme_variant(),
        'accent_color' => $self->get_accent_color(),
        'prefer_cosmic_icons' => 1,
        'use_cosmic_fonts' => 1,
    );
    
    return \%settings;
}

# Update application theme based on system changes
sub update_theme_from_system {
    my $self = shift;
    
    return 0 unless $self->is_cosmic_theme_available();
    
    my $old_variant = $CURRENT_THEME_VARIANT;
    my $new_variant = $self->_detectThemeVariant();
    
    if ($old_variant ne $new_variant) {
        print "INFO: Theme variant changed from $old_variant to $new_variant\n";
        $self->apply_cosmic_theme(1);
        return 1;
    }
    
    return 0;
}

# END: Define PUBLIC CLASS methods
###################################################################

###################################################################
# START: Define PRIVATE CLASS functions

sub _initCosmicTheme {
    my $self = shift;
    # Require Gtk4 to proceed
    return 0 unless $self->is_cosmic_theme_available();
    
    print "INFO: Initializing Cosmic theme integration\n";
    
    # Detect initial theme state
    $CURRENT_THEME_VARIANT = $self->_detectThemeVariant();
    $COSMIC_ACCENT_COLOR = $self->_detectAccentColor();
    
    # Create CSS provider for custom styling
    eval { $self->{_CSS_PROVIDER} = Gtk4::CssProvider->new(); };
    if ($@ || !$self->{_CSS_PROVIDER}) { print "WARNING: Failed to initialize Gtk4::CssProvider ($@)\n" if $@; return 0; }
    
    # Apply initial theme
    $self->apply_cosmic_theme();
    
    return 1;
}

sub _detectThemeVariant {
    my $self = shift;
    
    # Method 1: Check GTK theme preference
    my $gtk_theme = $ENV{GTK_THEME} || '';
    return 'dark' if $gtk_theme =~ /dark/i;
    
    # Method 2: Check gsettings for color scheme
    my ($color_scheme) = PACUtils::run_cmd({ argv => ['gsettings', 'get', 'org.gnome.desktop.interface', 'color-scheme'] });
    chomp $color_scheme if $color_scheme;
    if ($color_scheme && $color_scheme =~ /prefer-dark/) {
        return 'dark';
    }
    
    # Method 3: Check for Cosmic-specific theme settings
    # TODO: Implement when Cosmic provides theme detection APIs
    
    # Method 4: Check system theme through other means
    my $system_theme = $self->_detectSystemTheme();
    return $system_theme if $system_theme;
    
    # Default to light theme
    return 'light';
}

sub _detectAccentColor {
    my $self = shift;
    
    # Try to detect Cosmic accent color
    # TODO: Implement when Cosmic provides accent color APIs
    
    # For now, return a default Cosmic-like accent color
    return '#3584e4'; # Default blue accent
}

sub _detectSystemTheme {
    my $self = shift;
    
    # Try to detect system theme through various methods
    
    # Check XDG portal for theme preference
    my $portal_theme = $self->_checkXDGPortalTheme();
    return $portal_theme if $portal_theme;
    
    # Check D-Bus for theme information
    my $dbus_theme = $self->_checkDBusTheme();
    return $dbus_theme if $dbus_theme;
    
    return undef;
}

sub _checkXDGPortalTheme {
    my $self = shift;
    
    # Try to get theme information through XDG desktop portal
    # This is a placeholder for when portal APIs are available
    
    return undef;
}

sub _checkDBusTheme {
    my $self = shift;
    
    # Try to get theme information through D-Bus
    # This would query desktop environment specific interfaces
    
    return undef;
}

sub _applyCosmicCSS {
    my $self = shift;
    
    return 0 unless $self->{_CSS_PROVIDER};
    
    # Create CSS for Cosmic theme integration
    my $css = $self->_generateCosmicCSS();
    
    # Load CSS into provider
    eval {
        $self->{_CSS_PROVIDER}->load_from_data($css);
        if ($HAVE_GTK4) {
            # Gtk4 path
            my $display = Gtk4::Gdk::Display::get_default();
            if ($display) {
                my $priority = eval { no strict 'refs'; ${'Gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION'} } || 600;
                Gtk4::StyleContext::add_provider_for_display($display, $self->{_CSS_PROVIDER}, $priority);
            }
        } else {
            # Gtk3 fallback
            eval {
                my $screen = Gtk3::Gdk::Screen::get_default(); # may be undef
                if ($screen) {
                    my $priority = defined &Gtk3::STYLE_PROVIDER_PRIORITY_APPLICATION ? Gtk3::STYLE_PROVIDER_PRIORITY_APPLICATION : 600;
                    Gtk3::StyleContext::add_provider_for_screen($screen, $self->{_CSS_PROVIDER}, $priority);
                }
                1;
            };
        }
    };
    
    if ($@) {
        print "WARNING: Failed to apply Cosmic CSS: $@\n";
        return 0;
    }
    
    print "INFO: Cosmic CSS applied successfully\n";
    return 1;
}

sub _generateCosmicCSS {
    my $self = shift;
    
    my $variant = $CURRENT_THEME_VARIANT;
    my $accent_color = $COSMIC_ACCENT_COLOR || '#3584e4';
    
    # Generate CSS based on current theme variant
    my $css = '';
    
    if ($variant eq 'dark') {
        $css .= $self->_generateDarkThemeCSS($accent_color);
    } else {
        $css .= $self->_generateLightThemeCSS($accent_color);
    }
    
    # Add common Cosmic-specific styling
    $css .= $self->_generateCosmicCommonCSS($accent_color);
    
    return $css;
}

sub _generateDarkThemeCSS {
    my $self = shift;
    my $accent_color = shift;
    
    return qq{
        /* Cosmic Dark Theme Integration */
        window {
            background-color: #1e1e1e;
            color: #ffffff;
        }
        
        .asbru-main-window {
            background-color: #2d2d2d;
        }
        
        .asbru-sidebar {
            background-color: #252525;
            border-right: 1px solid #404040;
        }
        
        .asbru-connection-list {
            background-color: #2d2d2d;
        }
        
        .asbru-connection-item:selected {
            background-color: $accent_color;
        }
        
        button {
            background-color: #404040;
            border: 1px solid #606060;
            color: #ffffff;
        }
        
        button:hover {
            background-color: #505050;
        }
        
        button:active {
            background-color: $accent_color;
        }
    };
}

sub _generateLightThemeCSS {
    my $self = shift;
    my $accent_color = shift;
    
    return qq{
        /* Cosmic Light Theme Integration */
        window {
            background-color: #ffffff;
            color: #2e2e2e;
        }
        
        .asbru-main-window {
            background-color: #fafafa;
        }
        
        .asbru-sidebar {
            background-color: #f5f5f5;
            border-right: 1px solid #e0e0e0;
        }
        
        .asbru-connection-list {
            background-color: #ffffff;
        }
        
        .asbru-connection-item:selected {
            background-color: $accent_color;
            color: #ffffff;
        }
        
        button {
            background-color: #f0f0f0;
            border: 1px solid #d0d0d0;
            color: #2e2e2e;
        }
        
        button:hover {
            background-color: #e8e8e8;
        }
        
        button:active {
            background-color: $accent_color;
            color: #ffffff;
        }
    };
}

sub _generateCosmicCommonCSS {
    my $self = shift;
    my $accent_color = shift;
    
    return qq{
        /* Common Cosmic Theme Elements */
        .asbru-cosmic-menubar {
            padding: 4px 8px;
            border-bottom: 1px solid rgba(0, 0, 0, 0.1);
        }
        
        .asbru-cosmic-button {
            border-radius: 6px;
            padding: 6px 12px;
            transition: all 0.2s ease;
        }
        
        .asbru-cosmic-accent {
            color: $accent_color;
        }
        
        .asbru-cosmic-accent-bg {
            background-color: $accent_color;
        }
        
        /* Terminal styling for Cosmic integration */
        .asbru-terminal {
            border-radius: 8px;
            margin: 4px;
        }
        
        /* Connection tree styling */
        .asbru-tree-view {
            border-radius: 6px;
        }
        
        .asbru-tree-view row:selected {
            background-color: $accent_color;
            border-radius: 4px;
        }
    };
}

sub _updateApplicationColors {
    my $self = shift;
    
    # Update application-wide color scheme
    my $variant = $CURRENT_THEME_VARIANT;
    
    # Store theme colors for use throughout the application
    if ($variant eq 'dark') {
        %COSMIC_THEME_COLORS = (
            'window_bg' => '#1e1e1e',
            'window_fg' => '#ffffff',
            'sidebar_bg' => '#252525',
            'sidebar_fg' => '#ffffff',
            'button_bg' => '#404040',
            'button_fg' => '#ffffff',
            'accent' => $COSMIC_ACCENT_COLOR || '#3584e4',
        );
    } else {
        %COSMIC_THEME_COLORS = (
            'window_bg' => '#ffffff',
            'window_fg' => '#2e2e2e',
            'sidebar_bg' => '#f5f5f5',
            'sidebar_fg' => '#2e2e2e',
            'button_bg' => '#f0f0f0',
            'button_fg' => '#2e2e2e',
            'accent' => $COSMIC_ACCENT_COLOR || '#3584e4',
        );
    }
    
    print "INFO: Updated application colors for $variant theme\n";
}

sub _setupThemeMonitoring {
    my $self = shift;
    
    # Set up monitoring for theme changes
    # This would typically involve D-Bus signal monitoring
    
    # For now, we'll use a simple polling approach
    # In a real implementation, this would be event-driven
    
    print "INFO: Theme monitoring setup (polling-based)\n";
    
    # TODO: Implement proper D-Bus monitoring when Cosmic APIs are available
    
    return 1;
}

sub _notifyThemeCallbacks {
    my $self = shift;
    
    # Notify all registered callbacks about theme change
    foreach my $callback (@{$self->{_THEME_CALLBACKS}}) {
        eval {
            $callback->($CURRENT_THEME_VARIANT, $COSMIC_ACCENT_COLOR, \%COSMIC_THEME_COLORS);
        };
        if ($@) {
            print "WARNING: Theme callback failed: $@\n";
        }
    }
}

# Get current theme colors for use by other modules
sub get_theme_colors {
    my $self = shift;
    return \%COSMIC_THEME_COLORS;
}

# END: Define PRIVATE CLASS functions
###################################################################

1;