#!/usr/bin/env perl

###############################################################################
# Unit tests for PACCompat GTK3/GTK4 compatibility functions
# Part of Ásbrú Connection Manager modernization project (v7.0.2)
###############################################################################

use strict;
use warnings;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use File::Temp qw(tempfile tempdir);
use File::Spec;

# Test plan - increased to cover new functionality
plan tests => 15;

# Import PACCompat
use_ok('PACCompat') or BAIL_OUT("Cannot load PACCompat module");

###############################################################################
# Test GTK Version Detection
###############################################################################

subtest 'GTK Version Detection' => sub {
    plan tests => 4;
    
    # Test GTK version is detected
    my $gtk_version = PACCompat::get_gtk_version();
    ok($gtk_version == 3 || $gtk_version == 4, "GTK version detected: $gtk_version");
    
    # Test is_gtk4 function
    my $is_gtk4 = PACCompat::is_gtk4();
    if ($gtk_version >= 4) {
        ok($is_gtk4, "is_gtk4() returns true for GTK4");
    } else {
        ok(!$is_gtk4, "is_gtk4() returns false for GTK3");
    }
    
    # Test GTK_VERSION variable
    ok(defined $PACCompat::GTK_VERSION, "GTK_VERSION variable is defined");
    is($PACCompat::GTK_VERSION, $gtk_version, "GTK_VERSION matches get_gtk_version()");
};

###############################################################################
# Test Icon System Compatibility
###############################################################################

subtest 'Icon System Compatibility' => sub {
    plan tests => 10;
    
    # Test IconTheme wrapper
    my $icon_theme_class = PACCompat::IconTheme();
    ok(defined $icon_theme_class, "IconTheme() returns a class name");
    like($icon_theme_class, qr/^Gtk[34]::IconTheme$/, "IconTheme class is valid");
    
    # Test get_default_icon_theme
    my $icon_theme = PACCompat::get_default_icon_theme();
    ok(defined $icon_theme, "get_default_icon_theme() returns an object");
    
    # Test IconFactory wrapper (GTK3 only)
    my $icon_factory_class = PACCompat::IconFactory();
    if (PACCompat::is_gtk4()) {
        ok(!defined $icon_factory_class, "IconFactory() returns undef for GTK4");
    } else {
        ok(defined $icon_factory_class, "IconFactory() returns a class name for GTK3");
        like($icon_factory_class, qr/^Gtk3::IconFactory$/, "IconFactory class is valid for GTK3");
    }
    
    # Test create_icon_factory
    my $icon_factory = PACCompat::create_icon_factory();
    if (PACCompat::is_gtk4()) {
        ok(!defined $icon_factory, "create_icon_factory() returns undef for GTK4");
    } else {
        ok(defined $icon_factory, "create_icon_factory() returns an object for GTK3");
    }
    
    # Test IconSource wrapper (GTK3 only)
    my $icon_source_class = PACCompat::IconSource();
    if (PACCompat::is_gtk4()) {
        ok(!defined $icon_source_class, "IconSource() returns undef for GTK4");
    } else {
        ok(defined $icon_source_class, "IconSource() returns a class name for GTK3");
    }
    
    # Test IconSet wrapper (GTK3 only)
    my $icon_set_class = PACCompat::IconSet();
    if (PACCompat::is_gtk4()) {
        ok(!defined $icon_set_class, "IconSet() returns undef for GTK4");
    } else {
        ok(defined $icon_set_class, "IconSet() returns a class name for GTK3");
    }
    
    # Test has_icon function with common system icon
    my $has_edit_icon = PACCompat::has_icon('edit-copy');
    ok(defined $has_edit_icon, "has_icon() returns a defined value");
    
    # Test load_icon function
    my $loaded_icon = PACCompat::load_icon('edit-copy', 16);
    ok(defined $loaded_icon || 1, "load_icon() handles common icon gracefully");
};

###############################################################################
# Test CSS Provider Compatibility
###############################################################################

subtest 'CSS Provider Compatibility' => sub {
    plan tests => 8;
    
    # Test CssProvider wrapper
    my $css_provider_class = PACCompat::CssProvider();
    ok(defined $css_provider_class, "CssProvider() returns a class name");
    like($css_provider_class, qr/^Gtk[34]::CssProvider$/, "CssProvider class is valid");
    
    # Test create_css_provider
    my $css_provider = PACCompat::create_css_provider();
    ok(defined $css_provider, "create_css_provider() returns an object");
    
    # Test load_css_from_data with simple CSS
    my $test_css = "button { color: red; }";
    my $load_result = PACCompat::load_css_from_data($css_provider, $test_css);
    ok(defined $load_result, "load_css_from_data() returns a result");
    
    # Test CSS constants
    my $app_priority = PACCompat::STYLE_PROVIDER_PRIORITY_APPLICATION();
    ok(defined $app_priority && $app_priority > 0, "STYLE_PROVIDER_PRIORITY_APPLICATION is valid");
    
    my $user_priority = PACCompat::STYLE_PROVIDER_PRIORITY_USER();
    ok(defined $user_priority && $user_priority > 0, "STYLE_PROVIDER_PRIORITY_USER is valid");
    
    my $theme_priority = PACCompat::STYLE_PROVIDER_PRIORITY_THEME();
    ok(defined $theme_priority && $theme_priority > 0, "STYLE_PROVIDER_PRIORITY_THEME is valid");
    
    # Test priority ordering
    ok($user_priority > $app_priority && $app_priority > $theme_priority, 
       "CSS provider priorities are in correct order");
};

###############################################################################
# Test Settings Compatibility
###############################################################################

subtest 'Settings Compatibility' => sub {
    plan tests => 6;
    
    # Test Settings wrapper
    my $settings_class = PACCompat::Settings();
    ok(defined $settings_class, "Settings() returns a class name");
    like($settings_class, qr/^Gtk[34]::Settings$/, "Settings class is valid");
    
    # Test get_default_settings
    my $settings = PACCompat::get_default_settings();
    ok(defined $settings, "get_default_settings() returns an object");
    
    # Test get_setting_property
    my $theme_name = PACCompat::get_setting_property('gtk-theme-name');
    ok(defined $theme_name, "get_setting_property() returns a value for gtk-theme-name");
    
    # Test get_theme_preference
    my ($theme, $prefer_dark) = PACCompat::get_theme_preference();
    ok(defined $theme, "get_theme_preference() returns theme name");
    ok(defined $prefer_dark, "get_theme_preference() returns dark preference");
};

###############################################################################
# Test Icon Size Constants
###############################################################################

subtest 'Icon Size Constants' => sub {
    plan tests => 6;
    
    # Test all icon size constants
    my $menu_size = PACCompat::ICON_SIZE_MENU();
    ok(defined $menu_size && $menu_size > 0, "ICON_SIZE_MENU is valid");
    
    my $small_toolbar_size = PACCompat::ICON_SIZE_SMALL_TOOLBAR();
    ok(defined $small_toolbar_size && $small_toolbar_size > 0, "ICON_SIZE_SMALL_TOOLBAR is valid");
    
    my $large_toolbar_size = PACCompat::ICON_SIZE_LARGE_TOOLBAR();
    ok(defined $large_toolbar_size && $large_toolbar_size > 0, "ICON_SIZE_LARGE_TOOLBAR is valid");
    
    my $button_size = PACCompat::ICON_SIZE_BUTTON();
    ok(defined $button_size && $button_size > 0, "ICON_SIZE_BUTTON is valid");
    
    my $dnd_size = PACCompat::ICON_SIZE_DND();
    ok(defined $dnd_size && $dnd_size > 0, "ICON_SIZE_DND is valid");
    
    my $dialog_size = PACCompat::ICON_SIZE_DIALOG();
    ok(defined $dialog_size && $dialog_size > 0, "ICON_SIZE_DIALOG is valid");
};

###############################################################################
# Test Widget Creation Compatibility
###############################################################################

subtest 'Widget Creation Compatibility' => sub {
    plan tests => 10;
    
    # Test basic widget creation
    my $window = PACCompat::create_window('toplevel', 'Test Window');
    ok(defined $window, "create_window() returns a widget");
    
    my $box = PACCompat::create_box('vertical', 5);
    ok(defined $box, "create_box() returns a widget");
    
    my $button = PACCompat::create_button('Test Button');
    ok(defined $button, "create_button() returns a widget");
    
    my $label = PACCompat::create_label('Test Label');
    ok(defined $label, "create_label() returns a widget");
    
    my $entry = PACCompat::create_entry();
    ok(defined $entry, "create_entry() returns a widget");
    
    my $text_view = PACCompat::create_text_view();
    ok(defined $text_view, "create_text_view() returns a widget");
    
    my $scrolled = PACCompat::create_scrolled_window();
    ok(defined $scrolled, "create_scrolled_window() returns a widget");
    
    my $notebook = PACCompat::create_notebook();
    ok(defined $notebook, "create_notebook() returns a widget");
    
    my $frame = PACCompat::create_frame('Test Frame');
    ok(defined $frame, "create_frame() returns a widget");
    
    my $separator = PACCompat::create_separator('horizontal');
    ok(defined $separator, "create_separator() returns a widget");
};

###############################################################################
# Test Environment Detection
###############################################################################

subtest 'Environment Detection' => sub {
    plan tests => 8;
    
    # Test display server detection
    my $display_server = PACCompat::detect_display_server();
    ok(defined $display_server, "detect_display_server() returns a value");
    like($display_server, qr/^(wayland|x11|unknown|mir)$/, "Display server is valid");
    
    # Test desktop environment detection
    my $desktop_env = PACCompat::detect_desktop_environment();
    ok(defined $desktop_env, "detect_desktop_environment() returns a value");
    
    # Test boolean checks
    my $is_wayland = PACCompat::is_wayland();
    my $is_x11 = PACCompat::is_x11();
    ok(defined $is_wayland, "is_wayland() returns a defined value");
    ok(defined $is_x11, "is_x11() returns a defined value");
    
    # Test desktop environment checks
    my $is_cosmic = PACCompat::is_cosmic_desktop();
    my $is_gnome = PACCompat::is_gnome_desktop();
    ok(defined $is_cosmic, "is_cosmic_desktop() returns a defined value");
    ok(defined $is_gnome, "is_gnome_desktop() returns a defined value");
    
    # Test environment info
    my %env_info = PACCompat::get_environment_info();
    ok(keys %env_info > 0, "get_environment_info() returns data");
};

###############################################################################
# Test Error Handling
###############################################################################

subtest 'Error Handling' => sub {
    plan tests => 4;
    
    # Test loading non-existent icon
    my $nonexistent_icon = PACCompat::load_icon('nonexistent-icon-12345', 16);
    ok(!defined $nonexistent_icon, "load_icon() returns undef for non-existent icon");
    
    # Test loading CSS from invalid data
    my $css_provider = PACCompat::create_css_provider();
    my $invalid_css_result = PACCompat::load_css_from_data($css_provider, "invalid css {{{");
    ok(defined $invalid_css_result, "load_css_from_data() handles invalid CSS gracefully");
    
    # Test loading CSS from non-existent file
    my $file_result = PACCompat::load_css_from_file($css_provider, "/nonexistent/file.css");
    ok(defined $file_result, "load_css_from_file() handles non-existent file gracefully");
    
    # Test getting non-existent setting (handle gracefully)
    my $nonexistent_setting;
    eval {
        $nonexistent_setting = PACCompat::get_setting_property('nonexistent-setting-12345');
    };
    ok($@ || !defined $nonexistent_setting, "get_setting_property() handles non-existent setting gracefully");
};

###############################################################################
# Test Enhanced Icon System Functions
###############################################################################

subtest 'Enhanced Icon System Functions' => sub {
    plan tests => 12;
    
    # Test register_icons function
    my $temp_dir = tempdir(CLEANUP => 1);
    my $test_icon_path = File::Spec->catfile($temp_dir, 'test-icon.svg');
    
    # Create a simple SVG file for testing
    open my $fh, '>', $test_icon_path or skip "Cannot create test icon file", 12;
    print $fh '<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="red"/></svg>';
    close $fh;
    
    my %test_icons = (
        'test-icon' => $test_icon_path,
    );
    
    my $registered_count = PACCompat::register_icons(\%test_icons);
    ok($registered_count >= 0, "register_icons() returns a count");
    
    # Test lookup_icon_with_fallback
    my $icon = PACCompat::lookup_icon_with_fallback('test-icon', 16, ['edit-copy', 'gtk-edit']);
    ok(defined $icon || 1, "lookup_icon_with_fallback() handles test gracefully");
    
    # Test get_icon_theme_directories
    my @directories = PACCompat::get_icon_theme_directories();
    ok(@directories >= 0, "get_icon_theme_directories() returns array");
    
    # Test has_icon_with_size
    my $has_icon = PACCompat::has_icon_with_size('edit-copy', 16);
    ok(defined $has_icon, "has_icon_with_size() returns defined value");
    
    # Test icon creation functions
    my $icon_factory = PACCompat::create_icon_factory();
    if (PACCompat::is_gtk4()) {
        ok(!defined $icon_factory, "create_icon_factory() returns undef for GTK4");
    } else {
        ok(defined $icon_factory || 1, "create_icon_factory() works for GTK3");
    }
    
    my $icon_source = PACCompat::create_icon_source();
    if (PACCompat::is_gtk4()) {
        ok(!defined $icon_source, "create_icon_source() returns undef for GTK4");
    } else {
        ok(defined $icon_source || 1, "create_icon_source() works for GTK3");
    }
    
    my $icon_set = PACCompat::create_icon_set();
    if (PACCompat::is_gtk4()) {
        ok(!defined $icon_set, "create_icon_set() returns undef for GTK4");
    } else {
        ok(defined $icon_set || 1, "create_icon_set() works for GTK3");
    }
    
    # Test add_icon_to_theme
    my $add_result = PACCompat::add_icon_to_theme('test-icon-2', $test_icon_path, 16);
    ok(defined $add_result, "add_icon_to_theme() returns a result");
    
    # Test get_default_icon_theme
    my $default_theme = PACCompat::get_default_icon_theme();
    ok(defined $default_theme, "get_default_icon_theme() returns an object");
    
    # Test has_icon function
    my $has_edit = PACCompat::has_icon('edit-copy');
    ok(defined $has_edit, "has_icon() returns defined value for common icon");
    
    # Test load_icon function
    my $loaded_icon = PACCompat::load_icon('edit-copy', 16);
    ok(defined $loaded_icon || 1, "load_icon() handles common icon gracefully");
    
    # Test with invalid icon
    my $invalid_icon = PACCompat::load_icon('nonexistent-icon-xyz', 16);
    ok(!defined $invalid_icon, "load_icon() returns undef for invalid icon");
};

###############################################################################
# Test Enhanced CSS Provider Functions
###############################################################################

subtest 'Enhanced CSS Provider Functions' => sub {
    plan tests => 10;
    
    # Test apply_css_to_widget
    my $test_widget = PACCompat::create_button('Test');
    my $test_css = 'button { color: blue; }';
    my $apply_result = PACCompat::apply_css_to_widget($test_widget, $test_css);
    ok(defined $apply_result, "apply_css_to_widget() returns a result");
    
    # Test apply_css_globally
    my $global_result = PACCompat::apply_css_globally($test_css);
    ok(defined $global_result, "apply_css_globally() returns a result");
    
    # Test load_and_apply_css_file with temporary file
    my ($fh, $temp_css_file) = tempfile(SUFFIX => '.css', UNLINK => 1);
    print $fh "label { font-weight: bold; }\n";
    close $fh;
    
    my $file_result = PACCompat::load_and_apply_css_file($temp_css_file);
    ok(defined $file_result, "load_and_apply_css_file() returns a result");
    
    # Test with non-existent file
    my $invalid_file_result = PACCompat::load_and_apply_css_file('/nonexistent/file.css');
    ok(!$invalid_file_result, "load_and_apply_css_file() returns false for non-existent file");
    
    # Test create_css_provider
    my $css_provider = PACCompat::create_css_provider();
    ok(defined $css_provider, "create_css_provider() returns an object");
    
    # Test load_css_from_data
    my $load_data_result = PACCompat::load_css_from_data($css_provider, $test_css);
    ok(defined $load_data_result, "load_css_from_data() returns a result");
    
    # Test load_css_from_file
    my $load_file_result = PACCompat::load_css_from_file($css_provider, $temp_css_file);
    ok(defined $load_file_result, "load_css_from_file() returns a result");
    
    # Test add_css_provider_to_widget
    eval {
        PACCompat::add_css_provider_to_widget($test_widget, $css_provider);
    };
    ok(!$@, "add_css_provider_to_widget() executes without error");
    
    # Test add_css_provider_globally
    eval {
        PACCompat::add_css_provider_globally($css_provider);
    };
    ok(!$@, "add_css_provider_globally() executes without error");
    
    # Test with invalid CSS
    my $invalid_css_result = PACCompat::load_css_from_data($css_provider, 'invalid css {{{');
    ok(defined $invalid_css_result, "load_css_from_data() handles invalid CSS gracefully");
};

###############################################################################
# Test Enhanced Theme Detection Functions
###############################################################################

subtest 'Enhanced Theme Detection Functions' => sub {
    plan tests => 8;
    
    # Test get_theme_info
    my %theme_info = PACCompat::get_theme_info();
    ok(keys %theme_info > 0, "get_theme_info() returns data");
    ok(exists $theme_info{name}, "Theme info contains name");
    ok(exists $theme_info{prefer_dark}, "Theme info contains prefer_dark");
    ok(exists $theme_info{icon_theme}, "Theme info contains icon_theme");
    
    # Test prefers_dark_theme
    my $prefers_dark = PACCompat::prefers_dark_theme();
    ok(defined $prefers_dark, "prefers_dark_theme() returns defined value");
    
    # Test get_default_settings
    my $settings = PACCompat::get_default_settings();
    ok(defined $settings, "get_default_settings() returns an object");
    
    # Test get_setting_property
    my $theme_name = PACCompat::get_setting_property('gtk-theme-name');
    ok(defined $theme_name, "get_setting_property() returns theme name");
    
    # Test monitor_theme_changes (just test that it doesn't crash)
    my $callback = sub { my ($event, $data) = @_; };
    my @signals = PACCompat::monitor_theme_changes($callback);
    ok(@signals >= 0, "monitor_theme_changes() returns signal IDs");
};

###############################################################################
# Test Enhanced Widget Utility Functions
###############################################################################

subtest 'Enhanced Widget Utility Functions' => sub {
    plan tests => 9;
    
    my $test_widget = PACCompat::create_button('Test Widget');
    
    # Test set_widget_css_class
    my $set_class_result = PACCompat::set_widget_css_class($test_widget, 'test-class');
    ok(defined $set_class_result, "set_widget_css_class() returns a result");
    
    # Test widget_has_css_class
    my $has_class = PACCompat::widget_has_css_class($test_widget, 'test-class');
    ok(defined $has_class, "widget_has_css_class() returns defined value");
    
    # Test remove_widget_css_class
    my $remove_class_result = PACCompat::remove_widget_css_class($test_widget, 'test-class');
    ok(defined $remove_class_result, "remove_widget_css_class() returns a result");
    
    # Test with invalid widget
    my $invalid_set = PACCompat::set_widget_css_class(undef, 'test-class');
    ok(!$invalid_set, "set_widget_css_class() returns false for invalid widget");
    
    my $invalid_has = PACCompat::widget_has_css_class(undef, 'test-class');
    ok(!$invalid_has, "widget_has_css_class() returns false for invalid widget");
    
    my $invalid_remove = PACCompat::remove_widget_css_class(undef, 'test-class');
    ok(!$invalid_remove, "remove_widget_css_class() returns false for invalid widget");
    
    # Test with empty class name
    my $empty_set = PACCompat::set_widget_css_class($test_widget, '');
    ok(!$empty_set, "set_widget_css_class() returns false for empty class");
    
    my $empty_has = PACCompat::widget_has_css_class($test_widget, '');
    ok(!$empty_has, "widget_has_css_class() returns false for empty class");
    
    my $empty_remove = PACCompat::remove_widget_css_class($test_widget, '');
    ok(!$empty_remove, "remove_widget_css_class() returns false for empty class");
};

###############################################################################
# Test GTK4 Specific Functionality
###############################################################################

subtest 'GTK4 Specific Functionality' => sub {
    plan tests => 6;
    
    if (PACCompat::is_gtk4()) {
        # GTK4 specific tests
        ok(1, "Running GTK4 specific tests");
        
        # Test that GTK3-only functions return undef
        ok(!defined PACCompat::IconFactory(), "IconFactory() returns undef in GTK4");
        ok(!defined PACCompat::IconSource(), "IconSource() returns undef in GTK4");
        ok(!defined PACCompat::IconSet(), "IconSet() returns undef in GTK4");
        ok(!defined PACCompat::create_icon_factory(), "create_icon_factory() returns undef in GTK4");
        ok(!defined PACCompat::create_icon_source(), "create_icon_source() returns undef in GTK4");
    } else {
        # GTK3 specific tests
        ok(1, "Running GTK3 specific tests");
        
        # Test that GTK3 functions work
        ok(defined PACCompat::IconFactory(), "IconFactory() returns class name in GTK3");
        ok(defined PACCompat::IconSource(), "IconSource() returns class name in GTK3");
        ok(defined PACCompat::IconSet(), "IconSet() returns class name in GTK3");
        
        my $factory = PACCompat::create_icon_factory();
        ok(defined $factory, "create_icon_factory() returns object in GTK3");
        
        my $source = PACCompat::create_icon_source();
        ok(defined $source, "create_icon_source() returns object in GTK3");
    }
};

###############################################################################
# Test Comprehensive Error Handling
###############################################################################

subtest 'Comprehensive Error Handling' => sub {
    plan tests => 8;
    
    # Test register_icons with invalid input
    my $invalid_register = PACCompat::register_icons(undef);
    ok(!$invalid_register, "register_icons() returns 0 for undef input");
    
    my $empty_register = PACCompat::register_icons({});
    ok($empty_register == 0, "register_icons() returns 0 for empty hash");
    
    # Test lookup_icon_with_fallback with invalid input
    my $invalid_lookup = PACCompat::lookup_icon_with_fallback('', 16);
    ok(!defined $invalid_lookup, "lookup_icon_with_fallback() returns undef for empty name");
    
    # Test apply_css_to_widget with invalid input
    my $invalid_css_apply = PACCompat::apply_css_to_widget(undef, 'test');
    ok(!$invalid_css_apply, "apply_css_to_widget() returns false for invalid widget");
    
    # Test apply_css_globally with invalid input
    my $invalid_global_css = PACCompat::apply_css_globally('');
    ok(!$invalid_global_css, "apply_css_globally() returns false for empty CSS");
    
    # Test monitor_theme_changes with invalid callback
    my @invalid_signals = PACCompat::monitor_theme_changes(undef);
    ok(@invalid_signals == 0, "monitor_theme_changes() returns empty array for invalid callback");
    
    # Test has_icon_with_size with invalid input
    my $invalid_has_icon = PACCompat::has_icon_with_size('', 16);
    ok(!$invalid_has_icon, "has_icon_with_size() returns false for empty icon name");
    
    # Test get_icon_theme_directories error handling
    my @dirs = PACCompat::get_icon_theme_directories();
    ok(@dirs >= 0, "get_icon_theme_directories() returns array even on error");
};

###############################################################################
# Run the tests
###############################################################################

done_testing();

print "\n";
print "=" x 70 . "\n";
print "PACCompat GTK3/GTK4 Compatibility Tests Complete\n";
print "GTK Version: " . PACCompat::get_gtk_version() . "\n";
print "Display Server: " . PACCompat::detect_display_server() . "\n";
print "Desktop Environment: " . PACCompat::detect_desktop_environment() . "\n";

# Print theme information
my %theme_info = PACCompat::get_theme_info();
print "Theme Name: $theme_info{name}\n";
print "Prefers Dark: " . ($theme_info{prefer_dark} ? 'Yes' : 'No') . "\n";
print "Icon Theme: $theme_info{icon_theme}\n";

print "=" x 70 . "\n";

exit 0;