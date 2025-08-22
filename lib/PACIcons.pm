package PACIcons;

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

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

use strict;
use warnings;
use Exporter 'import';
use FindBin qw($RealBin);
use File::Spec;
use Gtk3 '-init';

# Export functions
our @EXPORT = qw(
    icon_image
    clear_cache
    get_icon_theme
    has_icon
    load_icon_from_theme
    get_fallback_icon
);

###################################################################
# Global Variables

our $ICON_CACHE = {};
our $THEME_CACHE = {};
our $ICON_THEME = undef;

# Icon mappings - logical name to system icon name
our %ICON_MAP = (
    # Application icons
    'asbru-app-big' => 'asbru-cm',
    'asbru-app' => 'asbru-cm',
    'asbru-tray' => 'asbru-cm',
    'asbru-tray-bw' => 'asbru-cm',
    
    # Connection method icons
    'ssh' => 'network-server',
    'telnet' => 'network-server',
    'rdp' => 'network-workgroup',
    'vnc' => 'network-workgroup',
    'ftp' => 'folder-remote',
    'sftp' => 'folder-remote',
    'xfreerdp' => 'network-workgroup',
    'rdesktop' => 'network-workgroup',
    
    # Action icons
    'connect' => 'network-connect',
    'disconnect' => 'network-disconnect',
    'refresh' => 'view-refresh',
    'save' => 'document-save',
    'save_as' => 'document-save-as',
    'open' => 'document-open',
    'close' => 'window-close',
    'delete' => 'edit-delete',
    'edit' => 'document-edit',
    'copy' => 'edit-copy',
    'paste' => 'edit-paste',
    'cut' => 'edit-cut',
    'undo' => 'edit-undo',
    'redo' => 'edit-redo',
    'clear' => 'edit-clear',
    'find' => 'edit-find',
    'replace' => 'edit-find-replace',
    'select_all' => 'edit-select-all',
    
    # Status icons
    'status_connected' => 'network-transmit-receive',
    'status_disconnected' => 'network-offline',
    'status_connecting' => 'network-idle',
    'status_error' => 'dialog-error',
    'status_warning' => 'dialog-warning',
    'status_info' => 'dialog-information',
    
    # UI icons
    'treelist' => 'view-list',
    'folder' => 'folder',
    'favourite_start' => 'starred',
    'history_start' => 'document-open-recent',
    'cluster_start' => 'applications-system',
    'cluster' => 'applications-system',
    'help_link' => 'help-browser',
    'protected' => 'changes-prevent',
    'lock_off' => 'changes-allow',
    'lock_on' => 'changes-prevent',
    'keepass' => 'dialog-password',
    'kpx' => 'dialog-password',
    'buttonbar_show' => 'view-list',
    'buttonbar_hide' => 'view-restore',
    
    # Execution icons
    'exec_run' => 'media-playback-start',
    'execute' => 'system-run',
    'quick' => 'system-run',
    'selection' => 'edit-select-all',
    
    # Reset and defaults
    'reset_defaults' => 'edit-undo',
    
    # View icons
    'view-fullscreen' => 'view-fullscreen',
    'view-restore' => 'view-restore',
    
    # Format icons
    'format-indent-more' => 'format-indent-more',
);

# Fallback icon sizes
our %ICON_SIZES = (
    'menu' => 16,
    'small-toolbar' => 18,
    'large-toolbar' => 24,
    'button' => 20,
    'dnd' => 32,
    'dialog' => 48,
);

###################################################################
# Public Functions

=head2 icon_image($logical_name, $fallback_name, $size)

Returns a Gtk3::Image for the specified logical icon name.
Falls back to system icon if logical name not found.

=cut

sub icon_image {
    my ($logical_name, $fallback_name, $size) = @_;
    
    $logical_name ||= '';
    $fallback_name ||= 'image-missing';
    $size ||= 'button';
    
    # Cache pixbufs instead of GTK images to avoid parent issues
    my $cache_key = "$logical_name:$fallback_name:$size";
    my $pixbuf;
    
    if (exists $ICON_CACHE->{$cache_key}) {
        $pixbuf = $ICON_CACHE->{$cache_key};
    } else {
        $pixbuf = _create_icon_pixbuf($logical_name, $fallback_name, $size);
        $ICON_CACHE->{$cache_key} = $pixbuf;
    }
    
    # Always create a new GTK image to avoid parent conflicts
    my $image;
    if ($pixbuf) {
        $image = Gtk3::Image->new_from_pixbuf($pixbuf);
    } else {
        $image = Gtk3::Image->new();
    }
    
    return $image;
}

=head2 clear_cache()

Clears the icon cache to force reloading of icons.

=cut

sub clear_cache {
    $ICON_CACHE = {};
    $THEME_CACHE = {};
    $ICON_THEME = undef;
}

=head2 get_icon_theme()

Returns the current GTK icon theme.

=cut

sub get_icon_theme {
    return $ICON_THEME if defined $ICON_THEME;
    
    eval {
        $ICON_THEME = Gtk3::IconTheme::get_default();
    };
    
    if ($@) {
        warn "PACIcons: Failed to get icon theme: $@";
        $ICON_THEME = undef;
    }
    
    return $ICON_THEME;
}

=head2 has_icon($icon_name, $size)

Checks if an icon exists in the current theme.

=cut

sub has_icon {
    my ($icon_name, $size) = @_;
    
    return 0 unless $icon_name;
    
    my $theme = get_icon_theme();
    return 0 unless $theme;
    
    $size ||= $ICON_SIZES{'button'};
    $size = $ICON_SIZES{$size} if exists $ICON_SIZES{$size};
    
    eval {
        return $theme->has_icon($icon_name);
    };
    
    if ($@) {
        warn "PACIcons: Error checking icon '$icon_name': $@" if $ENV{ASBRU_DEBUG};
        return 0;
    }
}

=head2 load_icon_from_theme($icon_name, $size)

Loads an icon from the current theme.

=cut

sub load_icon_from_theme {
    my ($icon_name, $size) = @_;
    
    return undef unless $icon_name;
    
    my $theme = get_icon_theme();
    return undef unless $theme;
    
    $size ||= $ICON_SIZES{'button'};
    $size = $ICON_SIZES{$size} if exists $ICON_SIZES{$size};
    
    my $pixbuf;
    eval {
        # First try to check if icon exists to avoid warnings
        if ($theme->has_icon($icon_name)) {
            $pixbuf = $theme->load_icon($icon_name, $size, 'GTK_ICON_LOOKUP_USE_BUILTIN');
        }
    };
    
    if ($@) {
        # Only show debug messages for actual errors, not missing icons
        warn "PACIcons: Error loading icon '$icon_name' at size $size: $@" if $ENV{ASBRU_DEBUG} && $@ !~ /not present in theme/;
        return undef;
    }
    
    return $pixbuf;
}

=head2 get_fallback_icon($size)

Returns a fallback icon when no other icon is available.

=cut

sub get_fallback_icon {
    my ($size) = @_;
    
    $size ||= $ICON_SIZES{'button'};
    $size = $ICON_SIZES{$size} if exists $ICON_SIZES{$size};
    
    # Try common fallback icons
    my @fallbacks = ('image-missing', 'gtk-missing-image', 'application-x-executable');
    
    my $theme = get_icon_theme();
    return undef unless $theme;
    
    foreach my $fallback (@fallbacks) {
        if (has_icon($fallback, $size)) {
            return load_icon_from_theme($fallback, $size);
        }
    }
    
    # Return undef if no fallback available
    return undef;
}

###################################################################
# Private Functions

sub _create_icon_pixbuf {
    my ($logical_name, $fallback_name, $size) = @_;
    
    # Convert size to numeric if it's a string
    my $icon_size = $size;
    if (exists $ICON_SIZES{$size}) {
        $icon_size = $ICON_SIZES{$size};
    } elsif ($size !~ /^\d+$/) {
        $icon_size = $ICON_SIZES{'button'};
    }
    
    # Enhanced fallback mechanism for better icon support
    my @icon_candidates;
    
    # Add logical name and its mapping
    push @icon_candidates, $logical_name if $logical_name;
    push @icon_candidates, $ICON_MAP{$logical_name} if $logical_name && $ICON_MAP{$logical_name};
    
    # Add fallback name
    push @icon_candidates, $fallback_name if $fallback_name;
    
    # Add generic system icon mappings for common names
    my %generic_fallbacks = (
        'add' => ['list-add', 'gtk-add', 'document-new'],
        'delete' => ['list-remove', 'gtk-delete', 'edit-delete'],
        'edit' => ['document-edit', 'gtk-edit', 'accessories-text-editor'],
        'folder' => ['folder', 'gtk-directory', 'inode-directory'],
        'settings' => ['preferences-system', 'gtk-preferences', 'configure'],
        'about' => ['help-about', 'gtk-about', 'dialog-information'],
        'quit' => ['application-exit', 'gtk-quit', 'system-log-out'],
        'help' => ['help-contents', 'gtk-help', 'system-help'],
        'previous' => ['go-previous', 'gtk-media-previous', 'media-skip-backward'],
        'next' => ['go-next', 'gtk-media-next', 'media-skip-forward'],
        'history' => ['document-open-recent', 'gtk-revert-to-saved', 'edit-undo'],
        'favourite_on' => ['bookmark-new', 'starred', 'emblem-favorite'],
        'favourite_off' => ['bookmark-new', 'non-starred', 'emblem-default'],
        'shell' => ['utilities-terminal', 'gnome-terminal', 'terminal'],
        'scripts' => ['text-x-script', 'application-x-shellscript', 'text-x-generic']
    );
    
    if ($logical_name && exists $generic_fallbacks{$logical_name}) {
        push @icon_candidates, @{$generic_fallbacks{$logical_name}};
    }
    
    # Try each candidate
    my $pixbuf;
    foreach my $candidate (@icon_candidates) {
        next unless $candidate;
        $pixbuf = load_icon_from_theme($candidate, $icon_size);
        last if $pixbuf;
    }
    
    # Try fallback icon if all candidates failed
    if (!$pixbuf) {
        $pixbuf = get_fallback_icon($icon_size);
    }
    
    return $pixbuf;
}

###################################################################
# Module Initialization

# Initialize icon theme on module load
eval {
    get_icon_theme();
};

if ($@) {
    warn "PACIcons: Failed to initialize icon theme: $@" if $ENV{ASBRU_DEBUG};
}

1;

__END__

=head1 NAME

PACIcons - Modern icon management system for Ásbrú Connection Manager

=head1 DESCRIPTION

This module provides a modern icon management system with fallback support
and theme integration. It maps logical icon names to system icon names and
provides caching for improved performance.

=head1 FUNCTIONS

=over 4

=item icon_image($logical_name, $fallback_name, $size)

Returns a Gtk3::Image for the specified logical icon name.

=item clear_cache()

Clears the icon cache to force reloading of icons.

=item get_icon_theme()

Returns the current GTK icon theme.

=item has_icon($icon_name, $size)

Checks if an icon exists in the current theme.

=item load_icon_from_theme($icon_name, $size)

Loads an icon from the current theme.

=item get_fallback_icon($size)

Returns a fallback icon when no other icon is available.

=back

=head1 AUTHOR

Ásbrú Connection Manager team

=head1 COPYRIGHT

Copyright (C) 2017-2024 Ásbrú Connection Manager team

=cut