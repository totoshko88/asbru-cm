package PACCompatConfig;

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
# configuration management for display server and desktop environment preferences

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
    get_display_server_preference
    set_display_server_preference
    get_desktop_environment_preference
    set_desktop_environment_preference
    get_compatibility_settings
    set_compatibility_settings
    load_compatibility_config
    save_compatibility_config
    get_default_compatibility_config
    apply_display_server_overrides
);

###################################################################
# Configuration Management

# Default compatibility configuration
sub get_default_compatibility_config {
    return {
        # Display server preferences
        display_server => {
            preference => 'auto',  # auto, wayland, x11, force_wayland, force_x11
            fallback_order => ['wayland', 'x11'],
            wayland_enable => 1,
            x11_enable => 1,
        },
        
        # Desktop environment preferences
        desktop_environment => {
            preference => 'auto',  # auto, cosmic, gnome, kde, etc.
            cosmic_integration => 1,
            gnome_integration => 1,
            kde_integration => 1,
        },
        
        # GTK preferences
        gtk => {
            version_preference => 'auto',  # auto, gtk4, gtk3
            theme_integration => 1,
            dark_mode_detection => 1,
        },
        
        # Wayland-specific settings
        wayland => {
            use_portals => 1,
            portal_file_dialogs => 1,
            portal_screen_capture => 1,
            clipboard_integration => 1,
            window_decorations => 'auto',  # auto, client, server
        },
        
        # X11-specific settings
        x11 => {
            system_tray => 1,
            window_manager_hints => 1,
            global_shortcuts => 1,
            composite_manager => 'auto',
        },
        
        # Cosmic desktop specific settings
        cosmic => {
            panel_integration => 1,
            workspace_integration => 1,
            tiling_support => 1,
            notification_integration => 1,
            theme_following => 1,
        },
        
        # Compatibility and fallback options
        compatibility => {
            enable_fallbacks => 1,
            strict_mode => 0,
            debug_environment => 0,
            log_detection => 0,
        },
        
        # Version information for migration
        version => {
            config_version => '7.0.0',
            created_by => 'ai_assisted_modernization',
            created_date => '',
            last_updated => '',
        }
    };
}

# Get display server preference
sub get_display_server_preference {
    my ($config) = @_;
    $config //= load_compatibility_config();
    
    my $preference = $config->{display_server}->{preference} || 'auto';
    
    if ($preference eq 'auto') {
        return detect_display_server();
    } elsif ($preference eq 'force_wayland') {
        return 'wayland';
    } elsif ($preference eq 'force_x11') {
        return 'x11';
    } else {
        return $preference;
    }
}

# Set display server preference
sub set_display_server_preference {
    my ($preference, $config) = @_;
    $config //= load_compatibility_config();
    
    $config->{display_server}->{preference} = $preference;
    $config->{version}->{last_updated} = scalar(localtime());
    
    return save_compatibility_config($config);
}

# Get desktop environment preference
sub get_desktop_environment_preference {
    my ($config) = @_;
    $config //= load_compatibility_config();
    
    my $preference = $config->{desktop_environment}->{preference} || 'auto';
    
    if ($preference eq 'auto') {
        return detect_desktop_environment();
    } else {
        return $preference;
    }
}

# Set desktop environment preference
sub set_desktop_environment_preference {
    my ($preference, $config) = @_;
    $config //= load_compatibility_config();
    
    $config->{desktop_environment}->{preference} = $preference;
    $config->{version}->{last_updated} = scalar(localtime());
    
    return save_compatibility_config($config);
}

# Get compatibility settings for a specific component
sub get_compatibility_settings {
    my ($component, $config) = @_;
    $config //= load_compatibility_config();
    
    return $config->{$component} || {};
}

# Set compatibility settings for a specific component
sub set_compatibility_settings {
    my ($component, $settings, $config) = @_;
    $config //= load_compatibility_config();
    
    $config->{$component} = { %{$config->{$component} || {}}, %$settings };
    $config->{version}->{last_updated} = scalar(localtime());
    
    return save_compatibility_config($config);
}

# Load compatibility configuration
sub load_compatibility_config {
    my $config_file = get_compatibility_config_file();
    
    # Return default config if file doesn't exist
    if (!-f $config_file) {
        return get_default_compatibility_config();
    }
    
    # Try to load existing config
    eval {
        require YAML::XS;
        my $config = YAML::XS::LoadFile($config_file);
        
        # Merge with defaults to ensure all keys exist
        my $default_config = get_default_compatibility_config();
        return merge_config($default_config, $config);
    };
    
    if ($@) {
        warn "Failed to load compatibility config: $@\n";
        return get_default_compatibility_config();
    }
}

# Save compatibility configuration
sub save_compatibility_config {
    my ($config) = @_;
    
    my $config_file = get_compatibility_config_file();
    my $config_dir = $config_file;
    $config_dir =~ s|/[^/]+$||;
    
    # Create config directory if it doesn't exist
    if (!-d $config_dir) {
        require File::Path;
        File::Path::make_path($config_dir);
    }
    
    # Update version info
    $config->{version}->{last_updated} = scalar(localtime());
    if (!$config->{version}->{created_date}) {
        $config->{version}->{created_date} = scalar(localtime());
    }
    
    # Save config
    eval {
        require YAML::XS;
        YAML::XS::DumpFile($config_file, $config);
        return 1;
    };
    
    if ($@) {
        warn "Failed to save compatibility config: $@\n";
        return 0;
    }
    
    return 1;
}

# Get compatibility config file path
sub get_compatibility_config_file {
    my $cfg_dir = $ENV{ASBRU_CFG} || "$ENV{HOME}/.config/asbru";
    return "$cfg_dir/compatibility.yml";
}

# Merge configuration with defaults
sub merge_config {
    my ($default, $user) = @_;
    
    my $merged = {};
    
    # Copy all default values
    for my $key (keys %$default) {
        if (ref($default->{$key}) eq 'HASH') {
            $merged->{$key} = merge_config($default->{$key}, $user->{$key} || {});
        } else {
            $merged->{$key} = $default->{$key};
        }
    }
    
    # Override with user values
    for my $key (keys %$user) {
        if (ref($user->{$key}) eq 'HASH' && ref($merged->{$key}) eq 'HASH') {
            $merged->{$key} = merge_config($merged->{$key}, $user->{$key});
        } else {
            $merged->{$key} = $user->{$key};
        }
    }
    
    return $merged;
}

# Apply display server overrides based on configuration
sub apply_display_server_overrides {
    my ($config) = @_;
    $config //= load_compatibility_config();
    
    my $preference = $config->{display_server}->{preference} || 'auto';
    
    # Apply GDK backend overrides if needed
    if ($preference eq 'force_wayland') {
        $ENV{GDK_BACKEND} = 'wayland';
        $ENV{ASBRU_FORCE_WAYLAND} = '1';
    } elsif ($preference eq 'force_x11') {
        $ENV{GDK_BACKEND} = 'x11';
        $ENV{ASBRU_FORCE_X11} = '1';
    }
    
    # Apply Wayland-specific overrides
    if (is_wayland() && $config->{wayland}) {
        if (!$config->{wayland}->{use_portals}) {
            $ENV{ASBRU_NO_PORTALS} = '1';
        }
        
        if ($config->{wayland}->{window_decorations} eq 'client') {
            $ENV{ASBRU_CLIENT_DECORATIONS} = '1';
        } elsif ($config->{wayland}->{window_decorations} eq 'server') {
            $ENV{ASBRU_SERVER_DECORATIONS} = '1';
        }
    }
    
    # Apply X11-specific overrides
    if (is_x11() && $config->{x11}) {
        if (!$config->{x11}->{system_tray}) {
            $ENV{ASBRU_NO_SYSTEM_TRAY} = '1';
        }
        
        if (!$config->{x11}->{window_manager_hints}) {
            $ENV{ASBRU_NO_WM_HINTS} = '1';
        }
    }
    
    # Apply Cosmic desktop overrides
    if (is_cosmic_desktop() && $config->{cosmic}) {
        if ($config->{cosmic}->{panel_integration}) {
            $ENV{ASBRU_COSMIC_PANEL} = '1';
        }
        
        if ($config->{cosmic}->{tiling_support}) {
            $ENV{ASBRU_COSMIC_TILING} = '1';
        }
    }
    
    return 1;
}

# Initialize compatibility configuration on module load
sub initialize_compatibility_config {
    my $config = load_compatibility_config();
    
    # Apply any necessary overrides
    apply_display_server_overrides($config);
    
    # Log environment information if debug is enabled
    if ($config->{compatibility}->{debug_environment} || $ENV{ASBRU_DEBUG}) {
        my %env_info = get_environment_info();
        print STDERR "PACCompatConfig: Environment Information:\n";
        for my $key (sort keys %env_info) {
            print STDERR "  $key: $env_info{$key}\n";
        }
    }
    
    return $config;
}

###################################################################
# Module initialization

# Initialize on module load
our $COMPAT_CONFIG = initialize_compatibility_config();

1;

__END__

=head1 NAME

PACCompatConfig - Configuration Management for Display Server and Desktop Environment Compatibility

=head1 SYNOPSIS

    use PACCompatConfig;
    
    # Get current display server preference
    my $display_server = get_display_server_preference();
    
    # Set display server preference
    set_display_server_preference('wayland');
    
    # Get desktop environment settings
    my $de_settings = get_compatibility_settings('desktop_environment');
    
    # Load and modify configuration
    my $config = load_compatibility_config();
    $config->{wayland}->{use_portals} = 1;
    save_compatibility_config($config);

=head1 DESCRIPTION

PACCompatConfig provides configuration management for display server and desktop 
environment compatibility settings in the modernized Ásbrú Connection Manager.

This module allows users to configure preferences for:
- Display server selection (Wayland vs X11)
- Desktop environment integration
- GTK version preferences
- Wayland-specific features
- X11 compatibility options
- Cosmic desktop integration

=head1 FUNCTIONS

=head2 Configuration Management

=over 4

=item get_display_server_preference($config)

Returns the configured display server preference.

=item set_display_server_preference($preference, $config)

Sets the display server preference (auto, wayland, x11, force_wayland, force_x11).

=item load_compatibility_config()

Loads the compatibility configuration from file, returns defaults if not found.

=item save_compatibility_config($config)

Saves the compatibility configuration to file.

=back

=head1 CONFIGURATION FILE

The configuration is stored in ~/.config/asbru/compatibility.yml and includes:

- Display server preferences
- Desktop environment settings
- GTK version preferences
- Wayland and X11 specific options
- Cosmic desktop integration settings

=head1 AUTHOR

Ásbrú Connection Manager team (https://asbru-cm.net)

=head1 COPYRIGHT

Copyright (C) 2017-2024 Ásbrú Connection Manager team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut