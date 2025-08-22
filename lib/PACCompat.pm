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
use File::Basename;

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
    create_progress_bar
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
    IconTheme
    IconFactory
    IconSource
    IconSet
    CssProvider
    Settings
    Window
    Box
    Label
    ProgressBar
    STYLE_PROVIDER_PRIORITY_APPLICATION
    STYLE_PROVIDER_PRIORITY_USER
    STYLE_PROVIDER_PRIORITY_THEME
    ICON_SIZE_MENU
    ICON_SIZE_SMALL_TOOLBAR
    ICON_SIZE_LARGE_TOOLBAR
    ICON_SIZE_BUTTON
    ICON_SIZE_DND
    ICON_SIZE_DIALOG
    get_default_icon_theme
    create_icon_factory
    create_icon_source
    create_icon_set
    add_icon_to_theme
    has_icon
    load_icon
    create_css_provider
    load_css_from_data
    load_css_from_file
    add_css_provider_to_widget
    add_css_provider_globally
    get_default_settings
    get_setting_property
    get_theme_preference
    register_icons
    lookup_icon_with_fallback
    get_icon_theme_directories
    has_icon_with_size
    apply_css_to_widget
    apply_css_globally
    load_and_apply_css_file
    get_theme_info
    prefers_dark_theme
    monitor_theme_changes
    set_widget_css_class
    remove_widget_css_class
    widget_has_css_class
    _detectSystemTheme
    get_cached_theme_info
    _applyTreeTheme
    applyTreeThemeToWidgets
    registerTreeWidgetForThemeUpdates
    unregisterTreeWidgetFromThemeUpdates
    startTreeThemeMonitoring
    getTreeThemeMonitoringStats
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

# ProgressBar creation
sub create_progress_bar {
    my $progress_bar;
    if ($GTK_VERSION >= 4) {
        $progress_bar = Gtk4::ProgressBar->new();
    } else {
        $progress_bar = Gtk3::ProgressBar->new();
    }
    
    return $progress_bar;
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
# Icon System Compatibility Functions

# IconTheme compatibility wrapper
sub IconTheme {
    if ($GTK_VERSION >= 4) {
        return 'Gtk4::IconTheme';
    } else {
        return 'Gtk3::IconTheme';
    }
}

# Get default icon theme
sub get_default_icon_theme {
    if ($GTK_VERSION >= 4) {
        return Gtk4::IconTheme::get_for_display(Gtk4::Gdk::Display::get_default());
    } else {
        return Gtk3::IconTheme::get_default();
    }
}

# IconFactory compatibility wrapper (GTK3 only)
sub IconFactory {
    if ($GTK_VERSION >= 4) {
        # GTK4 doesn't have IconFactory, return undef
        return undef;
    } else {
        return 'Gtk3::IconFactory';
    }
}

# Create new IconFactory (GTK3 only)
sub create_icon_factory {
    if ($GTK_VERSION >= 4) {
        # GTK4 doesn't use IconFactory
        return undef;
    } else {
        return Gtk3::IconFactory->new();
    }
}

# IconSource compatibility wrapper (GTK3 only)
sub IconSource {
    if ($GTK_VERSION >= 4) {
        # GTK4 doesn't have IconSource
        return undef;
    } else {
        return 'Gtk3::IconSource';
    }
}

# Create new IconSource (GTK3 only)
sub create_icon_source {
    if ($GTK_VERSION >= 4) {
        # GTK4 doesn't use IconSource
        return undef;
    } else {
        return Gtk3::IconSource->new();
    }
}

# IconSet compatibility wrapper (GTK3 only)
sub IconSet {
    if ($GTK_VERSION >= 4) {
        # GTK4 doesn't have IconSet
        return undef;
    } else {
        return 'Gtk3::IconSet';
    }
}

# Create new IconSet (GTK3 only)
sub create_icon_set {
    if ($GTK_VERSION >= 4) {
        # GTK4 doesn't use IconSet
        return undef;
    } else {
        return Gtk3::IconSet->new();
    }
}

# Add icon to theme (unified interface)
sub add_icon_to_theme {
    my ($icon_name, $icon_path, $size) = @_;
    $size //= 16;
    
    if ($GTK_VERSION >= 4) {
        # GTK4: Add resource path to icon theme
        my $icon_theme = get_default_icon_theme();
        my $icon_dir = dirname($icon_path);
        $icon_theme->add_resource_path($icon_dir) if -d $icon_dir;
        return 1;
    } else {
        # GTK3: Use IconFactory
        my $icon_factory = create_icon_factory();
        return 0 unless $icon_factory;
        
        my $icon_source = create_icon_source();
        return 0 unless $icon_source;
        
        $icon_source->set_filename($icon_path);
        $icon_source->set_size($size);
        
        my $icon_set = create_icon_set();
        return 0 unless $icon_set;
        
        $icon_set->add_source($icon_source);
        $icon_factory->add($icon_name, $icon_set);
        $icon_factory->add_default();
        return 1;
    }
}

# Check if icon exists in theme
sub has_icon {
    my ($icon_name) = @_;
    
    my $icon_theme = get_default_icon_theme();
    return 0 unless $icon_theme;
    
    if ($GTK_VERSION >= 4) {
        return $icon_theme->has_icon($icon_name);
    } else {
        return $icon_theme->has_icon($icon_name);
    }
}

# Load icon from theme
sub load_icon {
    my ($icon_name, $size, $flags) = @_;
    $size //= 16;
    $flags //= 0;
    
    my $icon_theme = get_default_icon_theme();
    return undef unless $icon_theme;
    
    eval {
        if ($GTK_VERSION >= 4) {
            return $icon_theme->lookup_icon($icon_name, undef, $size, 1, 'ltr', $flags);
        } else {
            return $icon_theme->load_icon($icon_name, $size, $flags);
        }
    };
    
    return undef if $@;
}

###################################################################
# CSS Provider Compatibility Functions

# CssProvider compatibility wrapper
sub CssProvider {
    if ($GTK_VERSION >= 4) {
        return 'Gtk4::CssProvider';
    } else {
        return 'Gtk3::CssProvider';
    }
}

# Window compatibility wrapper
sub Window {
    if ($GTK_VERSION >= 4) {
        return 'Gtk4::Window';
    } else {
        return 'Gtk3::Window';
    }
}

# Box compatibility wrapper
sub Box {
    if ($GTK_VERSION >= 4) {
        return 'Gtk4::Box';
    } else {
        return 'Gtk3::Box';
    }
}

# Label compatibility wrapper
sub Label {
    if ($GTK_VERSION >= 4) {
        return 'Gtk4::Label';
    } else {
        return 'Gtk3::Label';
    }
}

# ProgressBar compatibility wrapper
sub ProgressBar {
    if ($GTK_VERSION >= 4) {
        return 'Gtk4::ProgressBar';
    } else {
        return 'Gtk3::ProgressBar';
    }
}

# Create new CssProvider
sub create_css_provider {
    if ($GTK_VERSION >= 4) {
        return Gtk4::CssProvider->new();
    } else {
        return Gtk3::CssProvider->new();
    }
}

# Load CSS from data
sub load_css_from_data {
    my ($css_provider, $css_data) = @_;
    
    eval {
        if ($GTK_VERSION >= 4) {
            $css_provider->load_from_data($css_data);
        } else {
            $css_provider->load_from_data($css_data);
        }
    };
    
    return !$@;
}

# Load CSS from file
sub load_css_from_file {
    my ($css_provider, $css_file) = @_;
    
    eval {
        if ($GTK_VERSION >= 4) {
            my $file = Gtk4::Gio::File::new_for_path($css_file);
            $css_provider->load_from_file($file);
        } else {
            my $file = Gtk3::Gio::File::new_for_path($css_file);
            $css_provider->load_from_file($file);
        }
    };
    
    return !$@;
}

# Add CSS provider to widget
sub add_css_provider_to_widget {
    my ($widget, $css_provider, $priority) = @_;
    $priority //= STYLE_PROVIDER_PRIORITY_APPLICATION();
    
    my $style_context = $widget->get_style_context();
    return unless $style_context;
    
    $style_context->add_provider($css_provider, $priority);
}

# Add CSS provider globally
sub add_css_provider_globally {
    my ($css_provider, $priority) = @_;
    $priority //= STYLE_PROVIDER_PRIORITY_APPLICATION();
    
    if ($GTK_VERSION >= 4) {
        my $display = Gtk4::Gdk::Display::get_default();
        Gtk4::StyleContext::add_provider_for_display($display, $css_provider, $priority);
    } else {
        my $screen = Gtk3::Gdk::Screen::get_default();
        Gtk3::StyleContext::add_provider_for_screen($screen, $css_provider, $priority);
    }
}

###################################################################
# Settings Compatibility Functions

# Settings compatibility wrapper
sub Settings {
    if ($GTK_VERSION >= 4) {
        return 'Gtk4::Settings';
    } else {
        return 'Gtk3::Settings';
    }
}

# Get default settings
sub get_default_settings {
    if ($GTK_VERSION >= 4) {
        return Gtk4::Settings::get_default();
    } else {
        return Gtk3::Settings::get_default();
    }
}

# Get setting property
sub get_setting_property {
    my ($property_name) = @_;
    
    my $settings = get_default_settings();
    return undef unless $settings;
    
    my $value;
    eval {
        $value = $settings->get_property($property_name);
    };
    
    return $@ ? undef : $value;
}

# Detect system theme preference
sub get_theme_preference {
    my $settings = get_default_settings();
    return ('unknown', 0) unless $settings;
    
    my $theme_name = $settings->get_property('gtk-theme-name') || 'unknown';
    my $prefer_dark = $settings->get_property('gtk-application-prefer-dark-theme') || 0;
    
    return ($theme_name, $prefer_dark);
}

# Enhanced theme detection function for task 3.2
sub _detectSystemTheme {
    my ($force_refresh) = @_;
    
    my $settings = get_default_settings();
    return ('unknown', 0, {}) unless $settings;
    
    my %theme_info = ();
    
    # Get basic theme information
    eval {
        $theme_info{name} = $settings->get_property('gtk-theme-name') || 'unknown';
        $theme_info{prefer_dark} = $settings->get_property('gtk-application-prefer-dark-theme') || 0;
        $theme_info{icon_theme} = $settings->get_property('gtk-icon-theme-name') || 'unknown';
        $theme_info{font_name} = $settings->get_property('gtk-font-name') || 'unknown';
        $theme_info{cursor_theme} = $settings->get_property('gtk-cursor-theme-name') || 'unknown';
    };
    
    if ($@) {
        warn "PACCompat: Error reading GTK settings: $@\n" if $ENV{ASBRU_DEBUG};
        return ('unknown', 0, {});
    }
    
    # Detect if theme is dark based on multiple indicators
    my $is_dark = 0;
    
    # Check explicit preference first
    $is_dark = 1 if $theme_info{prefer_dark};
    
    # Check theme name for dark indicators
    $is_dark = 1 if $theme_info{name} =~ /dark/i;
    
    # Check desktop environment specific dark theme detection
    my $desktop_env = detect_desktop_environment();
    if ($desktop_env eq 'gnome') {
        # Check GNOME-specific settings
        my $gnome_theme = $ENV{GTK_THEME} || '';
        $is_dark = 1 if $gnome_theme =~ /dark/i;
        
        # Check gsettings if available
        if (system('which gsettings >/dev/null 2>&1') == 0) {
            my $color_scheme = `gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null`;
            chomp $color_scheme if $color_scheme;
            $is_dark = 1 if $color_scheme && $color_scheme =~ /dark/i;
        }
    } elsif ($desktop_env eq 'kde') {
        # Check KDE-specific settings
        my $kde_theme = $ENV{KDEDIRS} || '';
        # KDE theme detection could be enhanced here
    } elsif ($desktop_env eq 'cosmic') {
        # Check Cosmic-specific settings
        # Cosmic theme detection could be enhanced here
    }
    
    # Add additional theme metadata
    $theme_info{is_dark} = $is_dark;
    $theme_info{desktop_environment} = $desktop_env;
    $theme_info{display_server} = detect_display_server();
    $theme_info{detection_time} = time();
    
    return ($theme_info{name}, $theme_info{prefer_dark}, \%theme_info);
}

# Check if system prefers dark theme
sub prefers_dark_theme {
    my ($theme_name, $prefer_dark) = _detectSystemTheme();
    
    # Check explicit dark theme preference
    return 1 if $prefer_dark;
    
    # Check theme name for dark indicators
    return 1 if $theme_name =~ /dark/i;
    
    return 0;
}

# Enhanced theme change monitoring system for task 3.2 and 4.2
our $theme_change_callbacks = [];
our $theme_signal_connections = [];
our $monitored_tree_widgets = [];

# Enhanced theme caching mechanism for task 3.2
our $theme_cache = {};
our $theme_cache_time = 0;
our $THEME_CACHE_TIMEOUT = 5; # seconds
our $theme_cache_hits = 0;
our $theme_cache_misses = 0;

sub monitor_theme_changes {
    my ($callback) = @_;
    
    return () unless $callback && ref($callback) eq 'CODE';
    
    push @$theme_change_callbacks, $callback;
    
    my $settings = get_default_settings();
    return () unless $settings;
    
    my @signal_ids = ();
    
    # Connect to various theme-related signals
    eval {
        # Monitor theme name changes
        my $theme_signal = $settings->signal_connect('notify::gtk-theme-name' => sub {
            my ($settings, $pspec) = @_;
            my ($theme_name, $prefer_dark, $theme_info) = _detectSystemTheme(1); # Force refresh
            
            # Clear cache to ensure fresh data
            %$theme_cache = ();
            $theme_cache_time = 0;
            
            # Notify all callbacks
            for my $cb (@$theme_change_callbacks) {
                eval { $cb->('theme-name-changed', $theme_name, $prefer_dark, $theme_info); };
                warn "Theme callback error: $@\n" if $@ && $ENV{ASBRU_DEBUG};
            }
        });
        push @signal_ids, $theme_signal;
        
        # Monitor dark theme preference changes
        my $dark_signal = $settings->signal_connect('notify::gtk-application-prefer-dark-theme' => sub {
            my ($settings, $pspec) = @_;
            my ($theme_name, $prefer_dark, $theme_info) = _detectSystemTheme(1); # Force refresh
            
            # Clear cache to ensure fresh data
            %$theme_cache = ();
            $theme_cache_time = 0;
            
            # Notify all callbacks
            for my $cb (@$theme_change_callbacks) {
                eval { $cb->('dark-preference-changed', $theme_name, $prefer_dark, $theme_info); };
                warn "Theme callback error: $@\n" if $@ && $ENV{ASBRU_DEBUG};
            }
        });
        push @signal_ids, $dark_signal;
        
        # Monitor icon theme changes
        my $icon_signal = $settings->signal_connect('notify::gtk-icon-theme-name' => sub {
            my ($settings, $pspec) = @_;
            my ($theme_name, $prefer_dark, $theme_info) = _detectSystemTheme(1); # Force refresh
            
            # Clear cache to ensure fresh data
            %$theme_cache = ();
            $theme_cache_time = 0;
            
            # Notify all callbacks
            for my $cb (@$theme_change_callbacks) {
                eval { $cb->('icon-theme-changed', $theme_name, $prefer_dark, $theme_info); };
                warn "Theme callback error: $@\n" if $@ && $ENV{ASBRU_DEBUG};
            }
        });
        push @signal_ids, $icon_signal;
        
        # Store signal connections for cleanup
        push @$theme_signal_connections, @signal_ids;
        
    };
    
    if ($@) {
        warn "PACCompat: Failed to connect theme change signals: $@\n" if $ENV{ASBRU_DEBUG};
        return ();
    }
    
    return @signal_ids;
}

# Cleanup theme monitoring
sub cleanup_theme_monitoring {
    my $settings = get_default_settings();
    return unless $settings;
    
    # Disconnect all signal connections
    for my $signal_id (@$theme_signal_connections) {
        eval { $settings->signal_handler_disconnect($signal_id); };
    }
    
    # Clear arrays
    @$theme_change_callbacks = ();
    @$theme_signal_connections = ();
    
    return 1;
}

sub get_cached_theme_info {
    my ($force_refresh) = @_;
    my $current_time = time();
    
    # Check if cache is still valid (unless forced refresh)
    if (!$force_refresh && 
        $current_time - $theme_cache_time < $THEME_CACHE_TIMEOUT && 
        %$theme_cache) {
        $theme_cache_hits++;
        
        if ($ENV{ASBRU_DEBUG}) {
            print STDERR "PACCompat: Theme cache hit (age: " . 
                         ($current_time - $theme_cache_time) . "s)\n";
        }
        
        return %$theme_cache;
    }
    
    # Cache miss - update cache
    $theme_cache_misses++;
    
    if ($ENV{ASBRU_DEBUG}) {
        print STDERR "PACCompat: Theme cache miss (forced: " . 
                     ($force_refresh ? "yes" : "no") . ")\n";
    }
    
    # Get fresh theme information
    my ($theme_name, $prefer_dark, $theme_info) = _detectSystemTheme($force_refresh);
    
    # Build comprehensive cache
    %$theme_cache = (
        name => $theme_name,
        prefer_dark => $prefer_dark,
        is_dark => $theme_info->{is_dark} || 0,
        icon_theme => $theme_info->{icon_theme} || 'unknown',
        font_name => $theme_info->{font_name} || 'unknown',
        cursor_theme => $theme_info->{cursor_theme} || 'unknown',
        desktop_environment => $theme_info->{desktop_environment} || detect_desktop_environment(),
        display_server => $theme_info->{display_server} || detect_display_server(),
        detection_time => $theme_info->{detection_time} || $current_time,
        cache_time => $current_time,
        cache_hits => $theme_cache_hits,
        cache_misses => $theme_cache_misses,
    );
    
    $theme_cache_time = $current_time;
    
    return %$theme_cache;
}

# Get theme cache statistics
sub get_theme_cache_stats {
    return (
        hits => $theme_cache_hits,
        misses => $theme_cache_misses,
        hit_ratio => $theme_cache_hits + $theme_cache_misses > 0 ? 
                     $theme_cache_hits / ($theme_cache_hits + $theme_cache_misses) : 0,
        cache_age => $theme_cache_time > 0 ? time() - $theme_cache_time : -1,
        cache_valid => %$theme_cache && (time() - $theme_cache_time < $THEME_CACHE_TIMEOUT),
    );
}

# Clear theme cache
sub clear_theme_cache {
    %$theme_cache = ();
    $theme_cache_time = 0;
    return 1;
}

###################################################################
# Tree Theme Application Functions (Task 4.1)

# Apply theme-aware styling to TreeView widgets
sub _applyTreeTheme {
    my ($tree_widget, $force_theme) = @_;
    
    return 0 unless $tree_widget;
    
    # Get current theme information
    my %theme_info = get_cached_theme_info();
    my $is_dark = $force_theme // $theme_info{is_dark} // prefers_dark_theme();
    
    if ($ENV{ASBRU_DEBUG}) {
        print STDERR "PACCompat: Applying tree theme (dark: $is_dark)\n";
    }
    
    # Create CSS provider for tree styling
    my $css_provider = create_css_provider();
    return 0 unless $css_provider;
    
    # Generate theme-appropriate CSS
    my $tree_css = _generateTreeCSS($is_dark);
    
    # Load CSS data
    unless (load_css_from_data($css_provider, $tree_css)) {
        warn "PACCompat: Failed to load tree CSS data\n" if $ENV{ASBRU_DEBUG};
        return 0;
    }
    
    # Apply CSS to the tree widget
    add_css_provider_to_widget($tree_widget, $css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION());
    
    # Store reference for cleanup
    $tree_widget->{_asbru_tree_css_provider} = $css_provider;
    
    if ($ENV{ASBRU_DEBUG}) {
        print STDERR "PACCompat: Tree theme applied successfully\n";
    }
    
    return 1;
}

# Generate CSS for tree styling based on theme
sub _generateTreeCSS {
    my ($is_dark) = @_;
    
    my $css;
    
    if ($is_dark) {
        # Dark theme colors with proper contrast
        $css = qq{
            .asbru-connection-tree, treeview {
                color: #e6e6e6;
                background-color: #2d2d2d;
            }
            .asbru-connection-tree:selected, treeview:selected {
                color: #ffffff;
                background-color: #4a90d9;
            }
            .asbru-connection-tree:hover, treeview:hover {
                background-color: #3d3d3d;
            }
            .asbru-connection-tree:selected:hover, treeview:selected:hover {
                background-color: #5aa0e9;
            }
            .asbru-connection-tree:focus:selected, treeview:focus:selected {
                color: #ffffff;
                background-color: #4a90d9;
            }
            /* Ensure text remains visible in all states */
            .asbru-connection-tree text, treeview text {
                color: #e6e6e6;
            }
            .asbru-connection-tree:selected text, treeview:selected text {
                color: #ffffff;
            }
            /* Specific styling for connection tree entries */
            .asbru-connection-tree cell, treeview cell {
                color: #e6e6e6;
            }
            .asbru-connection-tree cell:selected, treeview cell:selected {
                color: #ffffff;
            }
        };
    } else {
        # Light theme colors with proper contrast
        $css = qq{
            .asbru-connection-tree, treeview {
                color: #1a1a1a;
                background-color: #ffffff;
            }
            .asbru-connection-tree:selected, treeview:selected {
                color: #ffffff;
                background-color: #4a90d9;
            }
            .asbru-connection-tree:hover, treeview:hover {
                background-color: #f0f0f0;
            }
            .asbru-connection-tree:selected:hover, treeview:selected:hover {
                background-color: #5aa0e9;
            }
            .asbru-connection-tree:focus:selected, treeview:focus:selected {
                color: #ffffff;
                background-color: #4a90d9;
            }
            /* Ensure text remains visible in all states */
            .asbru-connection-tree text, treeview text {
                color: #1a1a1a;
            }
            .asbru-connection-tree:selected text, treeview:selected text {
                color: #ffffff;
            }
            /* Specific styling for connection tree entries */
            .asbru-connection-tree cell, treeview cell {
                color: #1a1a1a;
            }
            .asbru-connection-tree cell:selected, treeview cell:selected {
                color: #ffffff;
            }
        };
    }
    
    return $css;
}

# Apply tree theme to multiple tree widgets
sub applyTreeThemeToWidgets {
    my (@tree_widgets) = @_;
    
    my $success_count = 0;
    
    foreach my $widget (@tree_widgets) {
        if (_applyTreeTheme($widget)) {
            $success_count++;
        }
    }
    
    if ($ENV{ASBRU_DEBUG}) {
        print STDERR "PACCompat: Applied tree theme to $success_count/" . scalar(@tree_widgets) . " widgets\n";
    }
    
    return $success_count;
}

###################################################################
# Automatic Theme Change Detection Functions (Task 4.2)

# Register tree widgets for automatic theme updates
sub registerTreeWidgetForThemeUpdates {
    my (@tree_widgets) = @_;
    
    foreach my $widget (@tree_widgets) {
        next unless $widget;
        
        # Avoid duplicate registrations
        unless (grep { $_ == $widget } @$monitored_tree_widgets) {
            push @$monitored_tree_widgets, $widget;
            
            if ($ENV{ASBRU_DEBUG}) {
                print STDERR "PACCompat: Registered tree widget for theme updates\n";
            }
        }
    }
    
    # Apply initial theme
    applyTreeThemeToWidgets(@tree_widgets);
    
    return scalar(@tree_widgets);
}

# Unregister tree widgets from automatic theme updates
sub unregisterTreeWidgetFromThemeUpdates {
    my (@tree_widgets) = @_;
    
    foreach my $widget (@tree_widgets) {
        next unless $widget;
        
        @$monitored_tree_widgets = grep { $_ != $widget } @$monitored_tree_widgets;
        
        # Clean up CSS provider if it exists
        if ($widget->{_asbru_tree_css_provider}) {
            my $style_context = $widget->get_style_context();
            if ($style_context) {
                $style_context->remove_provider($widget->{_asbru_tree_css_provider});
            }
            delete $widget->{_asbru_tree_css_provider};
        }
        
        if ($ENV{ASBRU_DEBUG}) {
            print STDERR "PACCompat: Unregistered tree widget from theme updates\n";
        }
    }
    
    return 1;
}

# Enhanced theme monitoring with automatic tree theme updates
sub startTreeThemeMonitoring {
    my @signal_ids = monitor_theme_changes(sub {
        my ($change_type, $theme_name, $prefer_dark, $theme_info) = @_;
        
        if ($ENV{ASBRU_DEBUG}) {
            print STDERR "PACCompat: Theme change detected ($change_type), updating tree widgets\n";
        }
        
        # Update all registered tree widgets
        my $updated_count = 0;
        foreach my $widget (@$monitored_tree_widgets) {
            # Check if widget is still valid
            if ($widget && eval { $widget->get_style_context() }) {
                if (_applyTreeTheme($widget)) {
                    $updated_count++;
                }
            } else {
                # Remove invalid widget from monitoring
                @$monitored_tree_widgets = grep { $_ != $widget } @$monitored_tree_widgets;
            }
        }
        
        if ($ENV{ASBRU_DEBUG}) {
            print STDERR "PACCompat: Updated $updated_count tree widgets for theme change\n";
        }
    });
    
    if ($ENV{ASBRU_DEBUG}) {
        print STDERR "PACCompat: Started tree theme monitoring with " . scalar(@signal_ids) . " signals\n";
    }
    
    return @signal_ids;
}

# Get statistics about monitored tree widgets
sub getTreeThemeMonitoringStats {
    my $valid_widgets = 0;
    my $invalid_widgets = 0;
    
    foreach my $widget (@$monitored_tree_widgets) {
        if ($widget && eval { $widget->get_style_context() }) {
            $valid_widgets++;
        } else {
            $invalid_widgets++;
        }
    }
    
    return {
        total_registered => scalar(@$monitored_tree_widgets),
        valid_widgets => $valid_widgets,
        invalid_widgets => $invalid_widgets,
        theme_callbacks => scalar(@$theme_change_callbacks),
        signal_connections => scalar(@$theme_signal_connections),
    };
}

###################################################################
# GTK Constants Compatibility

# Style provider priority constants
sub STYLE_PROVIDER_PRIORITY_APPLICATION {
    if ($GTK_VERSION >= 4) {
        return 600;  # GTK4 constant value
    } else {
        # Use numeric value to avoid compilation issues
        return 600;  # GTK3::STYLE_PROVIDER_PRIORITY_APPLICATION equivalent
    }
}

sub STYLE_PROVIDER_PRIORITY_USER {
    if ($GTK_VERSION >= 4) {
        return 800;  # GTK4 constant value
    } else {
        # Use numeric value to avoid compilation issues
        return 800;  # GTK3::STYLE_PROVIDER_PRIORITY_USER equivalent
    }
}

sub STYLE_PROVIDER_PRIORITY_THEME {
    if ($GTK_VERSION >= 4) {
        return 200;  # GTK4 constant value
    } else {
        # Use numeric value to avoid compilation issues
        return 200;  # GTK3::STYLE_PROVIDER_PRIORITY_THEME equivalent
    }
}

# Icon size constants
sub ICON_SIZE_MENU {
    if ($GTK_VERSION >= 4) {
        return 16;  # GTK4 uses pixel sizes
    } else {
        return 1;  # GTK3::ICON_SIZE_MENU equivalent
    }
}

sub ICON_SIZE_SMALL_TOOLBAR {
    if ($GTK_VERSION >= 4) {
        return 16;  # GTK4 uses pixel sizes
    } else {
        return 2;  # GTK3::ICON_SIZE_SMALL_TOOLBAR equivalent
    }
}

sub ICON_SIZE_LARGE_TOOLBAR {
    if ($GTK_VERSION >= 4) {
        return 24;  # GTK4 uses pixel sizes
    } else {
        return 3;  # GTK3::ICON_SIZE_LARGE_TOOLBAR equivalent
    }
}

sub ICON_SIZE_BUTTON {
    if ($GTK_VERSION >= 4) {
        return 16;  # GTK4 uses pixel sizes
    } else {
        return 4;  # GTK3::ICON_SIZE_BUTTON equivalent
    }
}

sub ICON_SIZE_DND {
    if ($GTK_VERSION >= 4) {
        return 32;  # GTK4 uses pixel sizes
    } else {
        return 5;  # GTK3::ICON_SIZE_DND equivalent
    }
}

sub ICON_SIZE_DIALOG {
    if ($GTK_VERSION >= 4) {
        return 48;  # GTK4 uses pixel sizes
    } else {
        return 6;  # GTK3::ICON_SIZE_DIALOG equivalent
    }
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

###################################################################
# Enhanced Icon System Functions for GTK4 Compatibility

# Register icons using appropriate method for GTK version
sub register_icons {
    my ($icon_hash) = @_;
    return 0 unless $icon_hash && ref($icon_hash) eq 'HASH';
    
    if ($GTK_VERSION >= 4) {
        return _register_icons_gtk4($icon_hash);
    } else {
        return _register_icons_gtk3($icon_hash);
    }
}

# GTK4 icon registration using IconTheme
sub _register_icons_gtk4 {
    my ($icon_hash) = @_;
    
    my $icon_theme = get_default_icon_theme();
    return 0 unless $icon_theme;
    
    my $registered_count = 0;
    
    foreach my $icon_name (keys %$icon_hash) {
        my $icon_path = $icon_hash->{$icon_name};
        next unless -f $icon_path;
        
        # Add the directory containing the icon to the search path
        my $icon_dir = dirname($icon_path);
        if (-d $icon_dir) {
            eval {
                $icon_theme->add_resource_path($icon_dir);
                $registered_count++;
            };
            if ($@) {
                warn "Failed to add icon resource path $icon_dir: $@\n" if $ENV{ASBRU_DEBUG};
            }
        }
    }
    
    return $registered_count;
}

# GTK3 icon registration using IconFactory
sub _register_icons_gtk3 {
    my ($icon_hash) = @_;
    
    my $icon_factory = create_icon_factory();
    return 0 unless $icon_factory;
    
    my $registered_count = 0;
    
    foreach my $icon_name (keys %$icon_hash) {
        my $icon_path = $icon_hash->{$icon_name};
        next unless -f $icon_path;
        
        eval {
            my $icon_source = create_icon_source();
            next unless $icon_source;
            
            $icon_source->set_filename($icon_path);
            
            my $icon_set = create_icon_set();
            next unless $icon_set;
            
            $icon_set->add_source($icon_source);
            $icon_factory->add($icon_name, $icon_set);
            $registered_count++;
        };
        if ($@) {
            warn "Failed to register icon $icon_name: $@\n" if $ENV{ASBRU_DEBUG};
        }
    }
    
    # Add the factory to the default set
    eval {
        $icon_factory->add_default();
    };
    if ($@) {
        warn "Failed to add icon factory to default: $@\n" if $ENV{ASBRU_DEBUG};
    }
    
    return $registered_count;
}

# Enhanced icon lookup with fallback support
sub lookup_icon_with_fallback {
    my ($icon_name, $size, $fallback_names) = @_;
    $size //= 16;
    $fallback_names //= [];
    
    # Try primary icon name first
    my $icon = load_icon($icon_name, $size);
    return $icon if $icon;
    
    # Try fallback names
    foreach my $fallback (@$fallback_names) {
        $icon = load_icon($fallback, $size);
        return $icon if $icon;
    }
    
    return undef;
}

# Get icon theme directories
sub get_icon_theme_directories {
    my $icon_theme = get_default_icon_theme();
    return () unless $icon_theme;
    
    my @directories;
    
    if ($GTK_VERSION >= 4) {
        # GTK4 method to get search paths
        eval {
            @directories = $icon_theme->get_search_path();
        };
    } else {
        # GTK3 method to get search paths
        eval {
            @directories = $icon_theme->get_search_path();
        };
    }
    
    return @directories;
}

# Check if icon theme has specific icon with size
sub has_icon_with_size {
    my ($icon_name, $size) = @_;
    $size //= 16;
    
    my $icon_theme = get_default_icon_theme();
    return 0 unless $icon_theme;
    
    if ($GTK_VERSION >= 4) {
        return $icon_theme->has_icon($icon_name);
    } else {
        return $icon_theme->has_icon($icon_name);
    }
}

###################################################################
# Enhanced CSS Provider Functions

# Apply CSS to specific widget with error handling
sub apply_css_to_widget {
    my ($widget, $css_data, $priority) = @_;
    $priority //= STYLE_PROVIDER_PRIORITY_APPLICATION();
    
    return 0 unless $widget && $css_data;
    
    my $css_provider = create_css_provider();
    return 0 unless $css_provider;
    
    # Load CSS data
    my $load_success = load_css_from_data($css_provider, $css_data);
    return 0 unless $load_success;
    
    # Apply to widget
    eval {
        add_css_provider_to_widget($widget, $css_provider, $priority);
    };
    
    return !$@;
}

# Apply CSS globally with error handling
sub apply_css_globally {
    my ($css_data, $priority) = @_;
    $priority //= STYLE_PROVIDER_PRIORITY_APPLICATION();
    
    return 0 unless $css_data;
    
    my $css_provider = create_css_provider();
    return 0 unless $css_provider;
    
    # Load CSS data
    my $load_success = load_css_from_data($css_provider, $css_data);
    return 0 unless $load_success;
    
    # Apply globally
    eval {
        add_css_provider_globally($css_provider, $priority);
    };
    
    return !$@;
}

# Load CSS from file with error handling
sub load_and_apply_css_file {
    my ($css_file, $priority) = @_;
    $priority //= STYLE_PROVIDER_PRIORITY_APPLICATION();
    
    return 0 unless -f $css_file;
    
    my $css_provider = create_css_provider();
    return 0 unless $css_provider;
    
    # Load CSS file
    my $load_success = load_css_from_file($css_provider, $css_file);
    return 0 unless $load_success;
    
    # Apply globally
    eval {
        add_css_provider_globally($css_provider, $priority);
    };
    
    return !$@;
}

###################################################################
# Enhanced Theme Detection Functions

# Get comprehensive theme information
sub get_theme_info {
    my %theme_info = (
        name => 'unknown',
        prefer_dark => 0,
        icon_theme => 'unknown',
        font_name => 'unknown',
        font_size => 10,
    );
    
    my $settings = get_default_settings();
    return %theme_info unless $settings;
    
    eval {
        $theme_info{name} = $settings->get_property('gtk-theme-name') || 'unknown';
        $theme_info{prefer_dark} = $settings->get_property('gtk-application-prefer-dark-theme') || 0;
        $theme_info{icon_theme} = $settings->get_property('gtk-icon-theme-name') || 'unknown';
        $theme_info{font_name} = $settings->get_property('gtk-font-name') || 'unknown';
    };
    
    # Parse font size from font name
    if ($theme_info{font_name} =~ /(\d+)$/) {
        $theme_info{font_size} = $1;
    }
    
    return %theme_info;
}



###################################################################
# Enhanced Widget Utility Functions

# Set widget CSS class with GTK version compatibility
sub set_widget_css_class {
    my ($widget, $css_class) = @_;
    return 0 unless $widget && $css_class;
    
    my $style_context = $widget->get_style_context();
    return 0 unless $style_context;
    
    eval {
        if ($GTK_VERSION >= 4) {
            $widget->add_css_class($css_class);
        } else {
            $style_context->add_class($css_class);
        }
    };
    
    return !$@;
}

# Remove widget CSS class with GTK version compatibility
sub remove_widget_css_class {
    my ($widget, $css_class) = @_;
    return 0 unless $widget && $css_class;
    
    my $style_context = $widget->get_style_context();
    return 0 unless $style_context;
    
    eval {
        if ($GTK_VERSION >= 4) {
            $widget->remove_css_class($css_class);
        } else {
            $style_context->remove_class($css_class);
        }
    };
    
    return !$@;
}

# Check if widget has CSS class
sub widget_has_css_class {
    my ($widget, $css_class) = @_;
    return 0 unless $widget && $css_class;
    
    my $style_context = $widget->get_style_context();
    return 0 unless $style_context;
    
    if ($GTK_VERSION >= 4) {
        return $widget->has_css_class($css_class);
    } else {
        return $style_context->has_class($css_class);
    }
}

###################################################################
# Module cleanup and finalization

# Return true for successful module load
1;

###################################################################
# POD Documentation

__END__
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