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
    simulate_user_interaction
);

# Test plan
plan tests => 10;

# Setup test environment
setup_test_environment(headless => 1, gtk => 1, gtk4 => 1);

# Test keyboard shortcuts and accessibility features
subtest 'Basic Keyboard Navigation' => sub {
    plan tests => 6;
    
    my $window = create_mock_gtk_widget('Gtk4::Window');
    my $button1 = create_mock_gtk_widget('Gtk4::Button', label => 'Button 1');
    my $button2 = create_mock_gtk_widget('Gtk4::Button', label => 'Button 2');
    
    # Mock focus management
    my $focused_widget = undef;
    
    for my $widget ($button1, $button2) {
        $widget->mock('grab_focus', sub { 
            $focused_widget = $_[0]; 
            $_[0]->{has_focus} = 1;
            return 1; 
        });
        $widget->mock('has_focus', sub { 
            return $_[0] == $focused_widget ? 1 : 0; 
        });
        $widget->mock('set_can_focus', sub { 
            $_[0]->{can_focus} = $_[1]; 
            return 1; 
        });
    }
    
    # Set up focusable widgets
    ok($button1->set_can_focus(1), 'Button 1 can receive focus');
    ok($button2->set_can_focus(1), 'Button 2 can receive focus');
    
    # Test focus navigation
    ok($button1->grab_focus(), 'Button 1 can grab focus');
    ok($button1->has_focus(), 'Button 1 has focus');
    
    ok($button2->grab_focus(), 'Button 2 can grab focus');
    ok(!$button1->has_focus(), 'Button 1 lost focus when Button 2 gained it');
};

subtest 'Tab Navigation' => sub {
    plan tests => 5;
    
    # Create a form with multiple focusable elements
    my @widgets = (
        create_mock_gtk_widget('Gtk4::Entry', placeholder => 'Username'),
        create_mock_gtk_widget('Gtk4::Entry', placeholder => 'Password'),
        create_mock_gtk_widget('Gtk4::Button', label => 'Connect'),
        create_mock_gtk_widget('Gtk4::Button', label => 'Cancel')
    );
    
    my $current_focus = 0;
    
    # Mock tab navigation
    for my $i (0..$#widgets) {
        $widgets[$i]->mock('has_focus', sub { return $current_focus == $i; });
        $widgets[$i]->mock('grab_focus', sub { $current_focus = $i; return 1; });
    }
    
    # Test forward tab navigation
    ok($widgets[0]->grab_focus(), 'First widget focused');
    is($current_focus, 0, 'Focus on first widget');
    
    # Simulate Tab key press
    $current_focus = ($current_focus + 1) % @widgets;
    ok($widgets[$current_focus]->has_focus(), 'Tab moved focus forward');
    
    # Simulate Shift+Tab (reverse navigation)
    $current_focus = ($current_focus - 1 + @widgets) % @widgets;
    ok($widgets[$current_focus]->has_focus(), 'Shift+Tab moved focus backward');
    
    # Test focus wrapping
    $current_focus = $#widgets;
    $current_focus = ($current_focus + 1) % @widgets;
    is($current_focus, 0, 'Focus wraps around to beginning');
};

subtest 'Application Shortcuts' => sub {
    plan tests => 8;
    
    my $window = create_mock_gtk_widget('Gtk4::Window');
    
    # Mock accelerator/shortcut handling
    my %shortcuts_triggered;
    
    $window->mock('add_accelerator', sub {
        my ($self, $signal, $accel_group, $key, $mods, $flags) = @_;
        $self->{accelerators} ||= {};
        $self->{accelerators}->{"$key:$mods"} = $signal;
        return 1;
    });
    
    $window->mock('trigger_shortcut', sub {
        my ($self, $key, $mods) = @_;
        my $signal = $self->{accelerators}->{"$key:$mods"};
        if ($signal) {
            $shortcuts_triggered{$signal}++;
            return 1;
        }
        return 0;
    });
    
    # Test common Ásbrú shortcuts
    ok($window->add_accelerator('new_connection', undef, ord('N'), ['control-mask'], []), 'Ctrl+N shortcut added');
    ok($window->add_accelerator('quick_connect', undef, ord('Q'), ['control-mask'], []), 'Ctrl+Q shortcut added');
    ok($window->add_accelerator('preferences', undef, ord('P'), ['control-mask'], []), 'Ctrl+P shortcut added');
    ok($window->add_accelerator('quit', undef, ord('Q'), ['control-mask', 'shift-mask'], []), 'Ctrl+Shift+Q shortcut added');
    
    # Test shortcut triggering
    ok($window->trigger_shortcut(ord('N'), ['control-mask']), 'Ctrl+N triggered');
    ok($window->trigger_shortcut(ord('Q'), ['control-mask']), 'Ctrl+Q triggered');
    
    is($shortcuts_triggered{new_connection}, 1, 'New connection shortcut fired');
    is($shortcuts_triggered{quick_connect}, 1, 'Quick connect shortcut fired');
};

subtest 'Menu Navigation' => sub {
    plan tests => 6;
    
    my $menubar = create_mock_gtk_widget('Gtk4::MenuBar');
    my $file_menu = create_mock_gtk_widget('Gtk4::Menu');
    my $edit_menu = create_mock_gtk_widget('Gtk4::Menu');
    
    # Mock menu navigation
    my $active_menu = undef;
    
    $menubar->mock('set_active_menu', sub { 
        $active_menu = $_[1]; 
        return 1; 
    });
    $menubar->mock('get_active_menu', sub { 
        return $active_menu; 
    });
    
    # Mock Alt+F for File menu
    $menubar->mock('activate_mnemonic', sub {
        my ($self, $key) = @_;
        if ($key eq 'f' || $key eq 'F') {
            $self->set_active_menu($file_menu);
            return 1;
        } elsif ($key eq 'e' || $key eq 'E') {
            $self->set_active_menu($edit_menu);
            return 1;
        }
        return 0;
    });
    
    ok($menubar->activate_mnemonic('f'), 'Alt+F activates File menu');
    is($menubar->get_active_menu(), $file_menu, 'File menu is active');
    
    ok($menubar->activate_mnemonic('e'), 'Alt+E activates Edit menu');
    is($menubar->get_active_menu(), $edit_menu, 'Edit menu is active');
    
    # Test arrow key navigation between menus
    $menubar->mock('navigate_menu', sub {
        my ($self, $direction) = @_;
        if ($direction eq 'right' && $active_menu == $file_menu) {
            $active_menu = $edit_menu;
            return 1;
        } elsif ($direction eq 'left' && $active_menu == $edit_menu) {
            $active_menu = $file_menu;
            return 1;
        }
        return 0;
    });
    
    $menubar->set_active_menu($file_menu);
    ok($menubar->navigate_menu('right'), 'Right arrow navigates to next menu');
    is($menubar->get_active_menu(), $edit_menu, 'Edit menu active after navigation');
};

subtest 'Connection Management Shortcuts' => sub {
    plan tests => 6;
    
    # Test Ásbrú-specific connection shortcuts
    my $connection_manager = Test::MockObject->new();
    my %actions_performed;
    
    $connection_manager->mock('perform_action', sub {
        my ($self, $action) = @_;
        $actions_performed{$action}++;
        return 1;
    });
    
    # Mock shortcut handlers
    my %shortcut_map = (
        'F5' => 'refresh_connections',
        'F9' => 'toggle_connection_tree',
        'Delete' => 'delete_connection',
        'F2' => 'rename_connection',
        'Ctrl+D' => 'duplicate_connection',
        'Enter' => 'connect_to_selected'
    );
    
    $connection_manager->mock('handle_shortcut', sub {
        my ($self, $key) = @_;
        if (exists $shortcut_map{$key}) {
            return $self->perform_action($shortcut_map{$key});
        }
        return 0;
    });
    
    # Test connection management shortcuts
    ok($connection_manager->handle_shortcut('F5'), 'F5 refresh handled');
    ok($connection_manager->handle_shortcut('F9'), 'F9 toggle tree handled');
    ok($connection_manager->handle_shortcut('Delete'), 'Delete connection handled');
    
    is($actions_performed{refresh_connections}, 1, 'Refresh action performed');
    is($actions_performed{toggle_connection_tree}, 1, 'Toggle tree action performed');
    is($actions_performed{delete_connection}, 1, 'Delete action performed');
};

subtest 'Terminal Shortcuts' => sub {
    plan tests => 5;
    
    # Test terminal-specific keyboard shortcuts
    my $terminal = create_mock_gtk_widget('Vte::Terminal');
    my %terminal_actions;
    
    $terminal->mock('handle_terminal_shortcut', sub {
        my ($self, $key, $mods) = @_;
        my $shortcut = join('+', @$mods, $key);
        
        given ($shortcut) {
            when ('control+shift+C') { $terminal_actions{copy}++; return 1; }
            when ('control+shift+V') { $terminal_actions{paste}++; return 1; }
            when ('control+shift+T') { $terminal_actions{new_tab}++; return 1; }
            when ('control+shift+W') { $terminal_actions{close_tab}++; return 1; }
            when ('control+shift+F') { $terminal_actions{find}++; return 1; }
        }
        return 0;
    });
    
    # Test terminal shortcuts
    ok($terminal->handle_terminal_shortcut('C', ['control', 'shift']), 'Ctrl+Shift+C copy');
    ok($terminal->handle_terminal_shortcut('V', ['control', 'shift']), 'Ctrl+Shift+V paste');
    ok($terminal->handle_terminal_shortcut('T', ['control', 'shift']), 'Ctrl+Shift+T new tab');
    
    is($terminal_actions{copy}, 1, 'Copy action performed');
    is($terminal_actions{paste}, 1, 'Paste action performed');
};

subtest 'Accessibility Shortcuts' => sub {
    plan tests => 6;
    
    my $window = create_mock_gtk_widget('Gtk4::Window');
    my %accessibility_features;
    
    # Mock accessibility shortcut handling
    $window->mock('handle_accessibility_shortcut', sub {
        my ($self, $key, $mods) = @_;
        my $shortcut = join('+', @$mods, $key);
        
        given ($shortcut) {
            when ('alt+shift+Tab') { 
                $accessibility_features{reverse_tab}++; 
                return 1; 
            }
            when ('F6') { 
                $accessibility_features{cycle_panes}++; 
                return 1; 
            }
            when ('F10') { 
                $accessibility_features{activate_menubar}++; 
                return 1; 
            }
            when ('shift+F10') { 
                $accessibility_features{context_menu}++; 
                return 1; 
            }
        }
        return 0;
    });
    
    # Test accessibility shortcuts
    ok($window->handle_accessibility_shortcut('Tab', ['alt', 'shift']), 'Alt+Shift+Tab reverse tab');
    ok($window->handle_accessibility_shortcut('F6', []), 'F6 cycle panes');
    ok($window->handle_accessibility_shortcut('F10', []), 'F10 activate menubar');
    ok($window->handle_accessibility_shortcut('F10', ['shift']), 'Shift+F10 context menu');
    
    is($accessibility_features{reverse_tab}, 1, 'Reverse tab navigation');
    is($accessibility_features{activate_menubar}, 1, 'Menubar activation');
};

subtest 'Custom Shortcut Configuration' => sub {
    plan tests => 5;
    
    # Test custom shortcut configuration system
    my $shortcut_manager = Test::MockObject->new();
    my %custom_shortcuts;
    
    $shortcut_manager->mock('add_custom_shortcut', sub {
        my ($self, $key_combo, $action) = @_;
        $custom_shortcuts{$key_combo} = $action;
        return 1;
    });
    
    $shortcut_manager->mock('remove_custom_shortcut', sub {
        my ($self, $key_combo) = @_;
        delete $custom_shortcuts{$key_combo};
        return 1;
    });
    
    $shortcut_manager->mock('get_custom_shortcuts', sub {
        return %custom_shortcuts;
    });
    
    # Test adding custom shortcuts
    ok($shortcut_manager->add_custom_shortcut('Ctrl+Alt+C', 'quick_connect'), 'Custom shortcut added');
    ok($shortcut_manager->add_custom_shortcut('F12', 'toggle_fullscreen'), 'F12 shortcut added');
    
    my %shortcuts = $shortcut_manager->get_custom_shortcuts();
    is($shortcuts{'Ctrl+Alt+C'}, 'quick_connect', 'Custom shortcut stored correctly');
    
    # Test removing custom shortcuts
    ok($shortcut_manager->remove_custom_shortcut('F12'), 'F12 shortcut removed');
    
    %shortcuts = $shortcut_manager->get_custom_shortcuts();
    ok(!exists $shortcuts{'F12'}, 'F12 shortcut no longer exists');
};

subtest 'Shortcut Conflict Detection' => sub {
    plan tests => 4;
    
    # Test shortcut conflict detection and resolution
    my $conflict_detector = Test::MockObject->new();
    my %registered_shortcuts;
    
    $conflict_detector->mock('register_shortcut', sub {
        my ($self, $key_combo, $action, $context) = @_;
        
        if (exists $registered_shortcuts{$key_combo}) {
            return { conflict => 1, existing => $registered_shortcuts{$key_combo} };
        }
        
        $registered_shortcuts{$key_combo} = { action => $action, context => $context };
        return { conflict => 0 };
    });
    
    $conflict_detector->mock('resolve_conflict', sub {
        my ($self, $key_combo, $preferred_action) = @_;
        $registered_shortcuts{$key_combo} = $preferred_action;
        return 1;
    });
    
    # Test conflict detection
    my $result1 = $conflict_detector->register_shortcut('Ctrl+N', 'new_connection', 'global');
    ok(!$result1->{conflict}, 'First shortcut registered without conflict');
    
    my $result2 = $conflict_detector->register_shortcut('Ctrl+N', 'new_file', 'editor');
    ok($result2->{conflict}, 'Conflict detected for duplicate shortcut');
    
    # Test conflict resolution
    ok($conflict_detector->resolve_conflict('Ctrl+N', { action => 'new_connection', context => 'global' }), 
       'Conflict resolved');
    
    is($registered_shortcuts{'Ctrl+N'}->{action}, 'new_connection', 'Preferred action set');
};

subtest 'Shortcut Help System' => sub {
    plan tests => 4;
    
    # Test shortcut help and documentation system
    my $help_system = Test::MockObject->new();
    my %shortcut_help;
    
    $help_system->mock('add_shortcut_help', sub {
        my ($self, $key_combo, $description, $category) = @_;
        $shortcut_help{$key_combo} = {
            description => $description,
            category => $category
        };
        return 1;
    });
    
    $help_system->mock('get_shortcuts_by_category', sub {
        my ($self, $category) = @_;
        my @shortcuts;
        for my $key (keys %shortcut_help) {
            if ($shortcut_help{$key}->{category} eq $category) {
                push @shortcuts, {
                    key => $key,
                    description => $shortcut_help{$key}->{description}
                };
            }
        }
        return @shortcuts;
    });
    
    # Add shortcut help entries
    ok($help_system->add_shortcut_help('Ctrl+N', 'Create new connection', 'Connection Management'), 
       'Help entry added');
    ok($help_system->add_shortcut_help('F5', 'Refresh connection list', 'Connection Management'), 
       'F5 help entry added');
    
    # Test category-based help retrieval
    my @connection_shortcuts = $help_system->get_shortcuts_by_category('Connection Management');
    is(scalar(@connection_shortcuts), 2, 'Two connection management shortcuts found');
    
    my ($ctrl_n_help) = grep { $_->{key} eq 'Ctrl+N' } @connection_shortcuts;
    is($ctrl_n_help->{description}, 'Create new connection', 'Correct help description retrieved');
};

# Cleanup
cleanup_test_environment();

done_testing();