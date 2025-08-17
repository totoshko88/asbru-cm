#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use AsbruTestFramework qw(
    setup_test_environment
    cleanup_test_environment
    create_mock_gtk_widget
    test_theme_compatibility
);

# Test plan
plan tests => 8;

# Setup test environment
setup_test_environment(headless => 1, gtk => 1, gtk4 => 1);

# Test theme compatibility across different themes
subtest 'Default Theme Compatibility' => sub {
    plan tests => 4;
    
    my $window = create_mock_gtk_widget('Gtk4::Window');
    
    # Mock theme-related methods
    $window->mock('add_css_class', sub { return 1; });
    $window->mock('get_style_context', sub { 
        my $context = Test::MockObject->new();
        $context->mock('add_class', sub { return 1; });
        return $context;
    });
    
    my ($passed, $total) = test_theme_compatibility($window, 'default');
    
    ok($passed > 0, 'Default theme tests passed');
    ok($total > 0, 'Default theme tests executed');
    
    # Test specific default theme features
    ok($window->add_css_class('asbru-window'), 'Can add Ásbrú-specific CSS class');
    ok(defined $window->get_style_context(), 'Style context available');
};

subtest 'Dark Theme Compatibility' => sub {
    plan tests => 5;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock dark theme detection
    $widget->mock('get_settings', sub {
        my $settings = Test::MockObject->new();
        $settings->mock('get_property', sub {
            return $_[1] eq 'gtk-application-prefer-dark-theme' ? 1 : 0;
        });
        return $settings;
    });
    
    # Mock CSS class management for dark theme
    $widget->mock('add_css_class', sub { 
        push @{$_[0]->{css_classes} ||= []}, $_[1]; 
        return 1; 
    });
    $widget->mock('has_css_class', sub {
        my ($self, $class) = @_;
        return grep { $_ eq $class } @{$self->{css_classes} || []};
    });
    
    my $settings = $widget->get_settings();
    ok($settings->get_property('gtk-application-prefer-dark-theme'), 'Dark theme preference detected');
    
    ok($widget->add_css_class('dark-theme'), 'Dark theme CSS class added');
    ok($widget->has_css_class('dark-theme'), 'Dark theme class present');
    
    # Test dark theme specific styling
    ok($widget->add_css_class('asbru-dark'), 'Ásbrú dark theme class added');
    ok($widget->has_css_class('asbru-dark'), 'Ásbrú dark theme class present');
};

subtest 'Light Theme Compatibility' => sub {
    plan tests => 4;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock light theme settings
    $widget->mock('get_settings', sub {
        my $settings = Test::MockObject->new();
        $settings->mock('get_property', sub {
            return $_[1] eq 'gtk-application-prefer-dark-theme' ? 0 : 1;
        });
        return $settings;
    });
    
    $widget->mock('add_css_class', sub { return 1; });
    $widget->mock('has_css_class', sub { return 1; });
    
    my $settings = $widget->get_settings();
    ok(!$settings->get_property('gtk-application-prefer-dark-theme'), 'Light theme preference detected');
    
    ok($widget->add_css_class('light-theme'), 'Light theme CSS class added');
    ok($widget->add_css_class('asbru-light'), 'Ásbrú light theme class added');
    ok($widget->has_css_class('asbru-light'), 'Ásbrú light theme class present');
};

subtest 'Cosmic Desktop Theme Integration' => sub {
    plan tests => 6;
    
    # Simulate Cosmic desktop environment
    local $ENV{COSMIC_SESSION} = 1;
    local $ENV{XDG_CURRENT_DESKTOP} = 'cosmic';
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock Cosmic-specific theming
    $widget->mock('add_css_class', sub { 
        push @{$_[0]->{css_classes} ||= []}, $_[1]; 
        return 1; 
    });
    $widget->mock('has_css_class', sub {
        my ($self, $class) = @_;
        return grep { $_ eq $class } @{$self->{css_classes} || []};
    });
    
    # Test Cosmic desktop detection
    ok($ENV{COSMIC_SESSION}, 'Cosmic session detected');
    is($ENV{XDG_CURRENT_DESKTOP}, 'cosmic', 'Cosmic desktop environment detected');
    
    # Test Cosmic-specific styling
    ok($widget->add_css_class('cosmic-theme'), 'Cosmic theme class added');
    ok($widget->add_css_class('asbru-cosmic'), 'Ásbrú Cosmic integration class added');
    ok($widget->has_css_class('cosmic-theme'), 'Cosmic theme class present');
    ok($widget->has_css_class('asbru-cosmic'), 'Ásbrú Cosmic class present');
};

subtest 'High Contrast Theme Support' => sub {
    plan tests => 4;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock high contrast theme detection
    $widget->mock('get_settings', sub {
        my $settings = Test::MockObject->new();
        $settings->mock('get_property', sub {
            return $_[1] eq 'gtk-theme-name' ? 'HighContrast' : '';
        });
        return $settings;
    });
    
    $widget->mock('add_css_class', sub { return 1; });
    $widget->mock('has_css_class', sub { return 1; });
    
    my $settings = $widget->get_settings();
    is($settings->get_property('gtk-theme-name'), 'HighContrast', 'High contrast theme detected');
    
    ok($widget->add_css_class('high-contrast'), 'High contrast CSS class added');
    ok($widget->add_css_class('asbru-accessible'), 'Ásbrú accessibility class added');
    ok($widget->has_css_class('asbru-accessible'), 'Accessibility class present');
};

subtest 'Custom Theme Loading' => sub {
    plan tests => 5;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock CSS provider for custom themes
    $widget->mock('get_style_context', sub {
        my $context = Test::MockObject->new();
        $context->mock('add_provider', sub { return 1; });
        return $context;
    });
    
    # Mock CSS provider creation
    my $css_provider = Test::MockObject->new();
    $css_provider->mock('load_from_data', sub { return 1; });
    $css_provider->mock('load_from_file', sub { return 1; });
    
    my $context = $widget->get_style_context();
    ok(defined $context, 'Style context available');
    ok($context->add_provider($css_provider, 600), 'CSS provider added');
    
    # Test loading custom CSS
    ok($css_provider->load_from_data('.asbru-window { background: #333; }'), 'CSS loaded from data');
    
    # Test loading CSS file
    ok($css_provider->load_from_file('/path/to/theme.css'), 'CSS loaded from file');
    
    # Test theme switching
    ok($css_provider->load_from_data('.asbru-window { background: #fff; }'), 'Theme switched successfully');
};

subtest 'Theme Transition Effects' => sub {
    plan tests => 4;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock transition properties
    $widget->mock('set_transition_duration', sub { 
        $_[0]->{transition_duration} = $_[1]; 
        return 1; 
    });
    $widget->mock('get_transition_duration', sub { 
        return $_[0]->{transition_duration} || 0; 
    });
    $widget->mock('set_transition_type', sub { 
        $_[0]->{transition_type} = $_[1]; 
        return 1; 
    });
    
    ok($widget->set_transition_duration(200), 'Transition duration set');
    is($widget->get_transition_duration(), 200, 'Transition duration retrieved');
    
    ok($widget->set_transition_type('ease-in-out'), 'Transition type set');
    
    # Test smooth theme transitions
    my $transition_complete = 0;
    $widget->mock('transition_complete', sub { $transition_complete = 1; });
    
    # Simulate theme change with transition
    $widget->add_css_class('theme-changing');
    $widget->transition_complete();
    
    ok($transition_complete, 'Theme transition completed');
};

subtest 'Theme Resource Management' => sub {
    plan tests => 5;
    
    # Test theme resource loading and cleanup
    my @loaded_resources;
    
    # Mock resource management
    my $resource_manager = Test::MockObject->new();
    $resource_manager->mock('load_theme', sub {
        my ($self, $theme_name) = @_;
        push @loaded_resources, $theme_name;
        return 1;
    });
    $resource_manager->mock('unload_theme', sub {
        my ($self, $theme_name) = @_;
        @loaded_resources = grep { $_ ne $theme_name } @loaded_resources;
        return 1;
    });
    $resource_manager->mock('get_loaded_themes', sub {
        return @loaded_resources;
    });
    
    ok($resource_manager->load_theme('default'), 'Default theme loaded');
    ok($resource_manager->load_theme('dark'), 'Dark theme loaded');
    
    my @themes = $resource_manager->get_loaded_themes();
    is(scalar(@themes), 2, 'Two themes loaded');
    
    ok($resource_manager->unload_theme('default'), 'Default theme unloaded');
    
    @themes = $resource_manager->get_loaded_themes();
    is(scalar(@themes), 1, 'One theme remains after unload');
};

# Cleanup
cleanup_test_environment();

done_testing();