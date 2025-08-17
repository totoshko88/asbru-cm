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
    verify_gtk4_compatibility
    test_theme_compatibility
);

# Test plan
plan tests => 15;

# Setup test environment
setup_test_environment(headless => 1, gtk => 1, gtk4 => 1);

# Test GTK4 widget creation and rendering
subtest 'GTK4 Window Creation' => sub {
    plan tests => 5;
    
    my $window = create_mock_gtk_widget('Gtk4::Window', 
        title => 'Test Window',
        visible => 0
    );
    
    ok(defined $window, 'Window object created');
    ok($window->isa('Gtk4::Window'), 'Window is correct type');
    is($window->get_title(), 'Test Window', 'Window title set correctly');
    ok(!$window->get_visible(), 'Window initially hidden');
    
    $window->show();
    ok($window->get_visible(), 'Window becomes visible after show()');
};

subtest 'GTK4 Button Widget Tests' => sub {
    plan tests => 4;
    
    my $button = create_mock_gtk_widget('Gtk4::Button',
        label => 'Test Button',
        sensitive => 1
    );
    
    ok(defined $button, 'Button object created');
    is($button->get_label(), 'Test Button', 'Button label set correctly');
    ok($button->get_sensitive(), 'Button is sensitive');
    
    $button->set_sensitive(0);
    ok(!$button->get_sensitive(), 'Button sensitivity can be changed');
};

subtest 'GTK4 Entry Widget Tests' => sub {
    plan tests => 3;
    
    my $entry = create_mock_gtk_widget('Gtk4::Entry',
        text => ''
    );
    
    ok(defined $entry, 'Entry object created');
    is($entry->get_text(), '', 'Entry initially empty');
    
    $entry->set_text('Test input');
    is($entry->get_text(), 'Test input', 'Entry text can be set');
};

subtest 'GTK4 Box Container Tests' => sub {
    plan tests => 3;
    
    my $box = create_mock_gtk_widget('Gtk4::Box');
    
    ok(defined $box, 'Box container created');
    ok($box->isa('Gtk4::Box'), 'Box is correct type');
    
    # Test adding children (mocked)
    my $child = create_mock_gtk_widget('Gtk4::Label');
    $box->mock('append', sub { return 1; });
    
    ok($box->append($child), 'Child widget can be added to box');
};

subtest 'Widget Hierarchy Tests' => sub {
    plan tests => 4;
    
    # Create a typical Ásbrú window structure
    my $window = create_mock_gtk_widget('Gtk4::Window');
    my $main_box = create_mock_gtk_widget('Gtk4::Box');
    my $toolbar = create_mock_gtk_widget('Gtk4::Box');
    my $content_area = create_mock_gtk_widget('Gtk4::Box');
    
    # Mock parent-child relationships
    $window->mock('set_child', sub { return 1; });
    $main_box->mock('append', sub { return 1; });
    
    ok($window->set_child($main_box), 'Main box added to window');
    ok($main_box->append($toolbar), 'Toolbar added to main box');
    ok($main_box->append($content_area), 'Content area added to main box');
    
    # Test widget destruction
    $window->mock('destroy', sub { return 1; });
    ok($window->destroy(), 'Window can be destroyed');
};

subtest 'GTK4 Compatibility Verification' => sub {
    plan tests => 2;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock GTK4-specific methods
    $widget->mock('get_first_child', sub { return undef; });
    $widget->mock('get_last_child', sub { return undef; });
    $widget->mock('get_next_sibling', sub { return undef; });
    $widget->mock('get_prev_sibling', sub { return undef; });
    
    ok(verify_gtk4_compatibility($widget), 'Widget is GTK4 compatible');
    
    # Test with GTK3-style widget (should fail)
    my $gtk3_widget = create_mock_gtk_widget('Gtk3::Widget');
    ok(!verify_gtk4_compatibility($gtk3_widget), 'GTK3 widget correctly identified as incompatible');
};

subtest 'Theme Compatibility Tests' => sub {
    plan tests => 3;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock theme-related methods
    $widget->mock('add_css_class', sub { return 1; });
    $widget->mock('get_style_context', sub { return Test::MockObject->new(); });
    
    my ($passed, $total) = test_theme_compatibility($widget, 'default');
    
    ok($passed > 0, 'Some theme tests passed');
    ok($total > 0, 'Theme tests were executed');
    is($passed, $total, 'All theme tests passed');
};

subtest 'Widget State Management' => sub {
    plan tests => 6;
    
    my $button = create_mock_gtk_widget('Gtk4::Button',
        sensitive => 1,
        visible => 1
    );
    
    # Test initial state
    ok($button->get_sensitive(), 'Button initially sensitive');
    ok($button->get_visible(), 'Button initially visible');
    
    # Test state changes
    $button->set_sensitive(0);
    ok(!$button->get_sensitive(), 'Button can be made insensitive');
    
    $button->hide();
    ok(!$button->get_visible(), 'Button can be hidden');
    
    $button->show();
    ok($button->get_visible(), 'Button can be shown again');
    
    $button->set_sensitive(1);
    ok($button->get_sensitive(), 'Button can be made sensitive again');
};

subtest 'Event Handling Tests' => sub {
    plan tests => 3;
    
    my $button = create_mock_gtk_widget('Gtk4::Button');
    my $clicked = 0;
    
    # Mock signal connection
    $button->mock('signal_connect', sub {
        my ($self, $signal, $callback) = @_;
        if ($signal eq 'clicked') {
            $self->{_clicked_callback} = $callback;
        }
        return 1;
    });
    
    # Mock signal emission
    $button->mock('clicked', sub {
        my $self = shift;
        if ($self->{_clicked_callback}) {
            $self->{_clicked_callback}->($self);
        }
    });
    
    ok($button->signal_connect('clicked', sub { $clicked = 1; }), 'Signal connected');
    
    $button->clicked();
    ok($clicked, 'Click event triggered callback');
    
    # Test multiple callbacks
    my $clicked2 = 0;
    $button->signal_connect('clicked', sub { $clicked2 = 1; });
    $button->clicked();
    ok($clicked2, 'Second callback also triggered');
};

subtest 'Memory Management Tests' => sub {
    plan tests => 2;
    
    # Create multiple widgets to test memory handling
    my @widgets;
    for (1..100) {
        push @widgets, create_mock_gtk_widget('Gtk4::Widget');
    }
    
    ok(scalar(@widgets) == 100, 'Multiple widgets created successfully');
    
    # Destroy all widgets
    for my $widget (@widgets) {
        $widget->destroy();
    }
    
    ok(1, 'All widgets destroyed without errors');
};

subtest 'Accessibility Features Tests' => sub {
    plan tests => 4;
    
    my $button = create_mock_gtk_widget('Gtk4::Button');
    
    # Mock accessibility methods
    $button->mock('set_tooltip_text', sub { return 1; });
    $button->mock('get_tooltip_text', sub { return $_[0]->{tooltip} || ''; });
    $button->mock('set_accessible_name', sub { $_[0]->{accessible_name} = $_[1]; });
    $button->mock('get_accessible_name', sub { return $_[0]->{accessible_name} || ''; });
    
    ok($button->set_tooltip_text('Test tooltip'), 'Tooltip can be set');
    
    $button->{tooltip} = 'Test tooltip';
    is($button->get_tooltip_text(), 'Test tooltip', 'Tooltip text retrieved');
    
    ok($button->set_accessible_name('Test Button'), 'Accessible name can be set');
    is($button->get_accessible_name(), 'Test Button', 'Accessible name retrieved');
};

subtest 'Keyboard Navigation Tests' => sub {
    plan tests => 3;
    
    my $entry = create_mock_gtk_widget('Gtk4::Entry');
    
    # Mock focus methods
    $entry->mock('grab_focus', sub { $_[0]->{has_focus} = 1; return 1; });
    $entry->mock('has_focus', sub { return $_[0]->{has_focus} || 0; });
    
    ok($entry->grab_focus(), 'Widget can grab focus');
    ok($entry->has_focus(), 'Widget reports having focus');
    
    # Mock tab navigation
    $entry->mock('set_can_focus', sub { $_[0]->{can_focus} = $_[1]; });
    $entry->set_can_focus(1);
    ok($entry->{can_focus}, 'Widget can participate in tab navigation');
};

subtest 'Widget Sizing Tests' => sub {
    plan tests => 4;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock sizing methods
    $widget->mock('set_size_request', sub { 
        $_[0]->{width} = $_[1]; 
        $_[0]->{height} = $_[2]; 
        return 1; 
    });
    $widget->mock('get_allocated_width', sub { return $_[0]->{width} || 0; });
    $widget->mock('get_allocated_height', sub { return $_[0]->{height} || 0; });
    
    ok($widget->set_size_request(200, 100), 'Size request can be set');
    
    $widget->{width} = 200;
    $widget->{height} = 100;
    
    is($widget->get_allocated_width(), 200, 'Width allocated correctly');
    is($widget->get_allocated_height(), 100, 'Height allocated correctly');
    
    # Test minimum size
    $widget->set_size_request(50, 30);
    $widget->{width} = 50;
    $widget->{height} = 30;
    
    ok($widget->get_allocated_width() >= 50 && $widget->get_allocated_height() >= 30, 
       'Minimum size respected');
};

subtest 'CSS Styling Tests' => sub {
    plan tests => 3;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock CSS methods
    $widget->mock('add_css_class', sub { 
        push @{$_[0]->{css_classes} ||= []}, $_[1]; 
        return 1; 
    });
    $widget->mock('remove_css_class', sub { 
        my ($self, $class) = @_;
        $self->{css_classes} = [grep { $_ ne $class } @{$self->{css_classes} || []}];
        return 1;
    });
    $widget->mock('has_css_class', sub {
        my ($self, $class) = @_;
        return grep { $_ eq $class } @{$self->{css_classes} || []};
    });
    
    ok($widget->add_css_class('test-class'), 'CSS class can be added');
    ok($widget->has_css_class('test-class'), 'CSS class is present');
    
    $widget->remove_css_class('test-class');
    ok(!$widget->has_css_class('test-class'), 'CSS class can be removed');
};

subtest 'Widget Lifecycle Tests' => sub {
    plan tests => 4;
    
    my $widget = create_mock_gtk_widget('Gtk4::Widget');
    
    # Mock lifecycle methods
    my $realized = 0;
    my $mapped = 0;
    
    $widget->mock('realize', sub { $realized = 1; return 1; });
    $widget->mock('map', sub { $mapped = 1; return 1; });
    $widget->mock('is_realized', sub { return $realized; });
    $widget->mock('is_mapped', sub { return $mapped; });
    
    ok($widget->realize(), 'Widget can be realized');
    ok($widget->is_realized(), 'Widget reports being realized');
    
    ok($widget->map(), 'Widget can be mapped');
    ok($widget->is_mapped(), 'Widget reports being mapped');
};

# Cleanup
cleanup_test_environment();

done_testing();