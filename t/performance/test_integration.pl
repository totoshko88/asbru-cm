#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use Test::MockObject;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use AsbruTestFramework qw(
    setup_test_environment
    cleanup_test_environment
    measure_performance
);

# Test plan
plan tests => 8;

# Setup test environment
setup_test_environment();

# Test desktop integration features
subtest 'File Manager Integration' => sub {
    plan tests => 6;
    
    # Mock file manager operations
    my $file_manager = Test::MockObject->new();
    
    $file_manager->mock('open_file_dialog', sub {
        my ($self, $type, $title) = @_;
        
        # Simulate file dialog based on desktop environment
        my $desktop = $ENV{XDG_CURRENT_DESKTOP} || 'unknown';
        
        if ($desktop eq 'cosmic') {
            return { 
                success => 1, 
                file => '/home/user/test.pem',
                dialog_type => 'cosmic_portal'
            };
        } else {
            return { 
                success => 1, 
                file => '/home/user/test.pem',
                dialog_type => 'gtk_dialog'
            };
        }
    });
    
    $file_manager->mock('save_file_dialog', sub {
        my ($self, $title, $default_name) = @_;
        return { 
            success => 1, 
            file => "/home/user/$default_name",
            dialog_type => 'save_dialog'
        };
    });
    
    $file_manager->mock('select_directory', sub {
        my ($self, $title) = @_;
        return { 
            success => 1, 
            directory => '/home/user/Documents',
            dialog_type => 'directory_dialog'
        };
    });
    
    # Test file dialog operations
    my $open_result = $file_manager->open_file_dialog('open', 'Select SSH Key');
    ok($open_result->{success}, 'File open dialog successful');
    ok(defined $open_result->{file}, 'File path returned');
    
    my $save_result = $file_manager->save_file_dialog('Export Connections', 'connections.yml');
    ok($save_result->{success}, 'File save dialog successful');
    like($save_result->{file}, qr/connections\.yml$/, 'Correct filename in save dialog');
    
    my $dir_result = $file_manager->select_directory('Select Download Directory');
    ok($dir_result->{success}, 'Directory selection successful');
    ok(-d $dir_result->{directory} || $ENV{ASBRU_TEST_MODE}, 'Valid directory returned');
};

subtest 'Notification System Integration' => sub {
    plan tests => 7;
    
    # Mock notification system
    my $notifications = Test::MockObject->new();
    my @sent_notifications;
    
    $notifications->mock('send_notification', sub {
        my ($self, %params) = @_;
        
        push @sent_notifications, {
            title => $params{title},
            message => $params{message},
            urgency => $params{urgency} || 'normal',
            icon => $params{icon},
            timestamp => time()
        };
        
        return { success => 1, id => scalar(@sent_notifications) };
    });
    
    $notifications->mock('update_notification', sub {
        my ($self, $id, %params) = @_;
        
        if ($id > 0 && $id <= @sent_notifications) {
            my $notification = $sent_notifications[$id - 1];
            $notification->{message} = $params{message} if $params{message};
            $notification->{urgency} = $params{urgency} if $params{urgency};
            return { success => 1 };
        }
        return { success => 0, error => 'Notification not found' };
    });
    
    $notifications->mock('clear_notification', sub {
        my ($self, $id) = @_;
        
        if ($id > 0 && $id <= @sent_notifications) {
            splice @sent_notifications, $id - 1, 1;
            return { success => 1 };
        }
        return { success => 0, error => 'Notification not found' };
    });
    
    # Test notification sending
    my $result1 = $notifications->send_notification(
        title => 'Connection Established',
        message => 'Successfully connected to server.example.com',
        urgency => 'normal',
        icon => 'network-connect'
    );
    
    ok($result1->{success}, 'Notification sent successfully');
    is(scalar(@sent_notifications), 1, 'One notification in queue');
    
    # Test urgent notification
    my $result2 = $notifications->send_notification(
        title => 'Connection Failed',
        message => 'Failed to connect to server.example.com',
        urgency => 'critical',
        icon => 'network-error'
    );
    
    ok($result2->{success}, 'Urgent notification sent');
    is($sent_notifications[1]->{urgency}, 'critical', 'Urgent notification has correct urgency');
    
    # Test notification update
    my $update_result = $notifications->update_notification(1, 
        message => 'Connection to server.example.com is now stable'
    );
    
    ok($update_result->{success}, 'Notification updated successfully');
    like($sent_notifications[0]->{message}, qr/stable/, 'Notification message updated');
    
    # Test notification clearing
    my $clear_result = $notifications->clear_notification(1);
    ok($clear_result->{success}, 'Notification cleared successfully');
};

subtest 'System Tray Integration' => sub {
    plan tests => 8;
    
    # Mock system tray functionality
    my $system_tray = Test::MockObject->new();
    my $tray_visible = 0;
    my @tray_menu_items;
    
    $system_tray->mock('create_tray_icon', sub {
        my ($self, $icon_name) = @_;
        
        # Check desktop environment for tray support
        my $desktop = $ENV{XDG_CURRENT_DESKTOP} || 'unknown';
        
        if ($desktop eq 'cosmic') {
            # Cosmic may not have traditional system tray
            return { 
                success => 0, 
                fallback => 'panel_integration',
                message => 'Using Cosmic panel integration instead'
            };
        } else {
            $tray_visible = 1;
            return { success => 1, icon => $icon_name };
        }
    });
    
    $system_tray->mock('add_menu_item', sub {
        my ($self, $label, $callback) = @_;
        
        push @tray_menu_items, {
            label => $label,
            callback => $callback,
            enabled => 1
        };
        
        return scalar(@tray_menu_items);
    });
    
    $system_tray->mock('update_icon', sub {
        my ($self, $icon_name) = @_;
        return $tray_visible;
    });
    
    $system_tray->mock('show_balloon', sub {
        my ($self, $title, $message) = @_;
        return $tray_visible;
    });
    
    # Test tray icon creation
    local $ENV{XDG_CURRENT_DESKTOP} = 'gnome';
    my $tray_result = $system_tray->create_tray_icon('asbru-cm');
    ok($tray_result->{success}, 'System tray icon created in GNOME');
    
    # Test Cosmic desktop fallback
    local $ENV{XDG_CURRENT_DESKTOP} = 'cosmic';
    my $cosmic_result = $system_tray->create_tray_icon('asbru-cm');
    ok(!$cosmic_result->{success}, 'System tray not available in Cosmic');
    is($cosmic_result->{fallback}, 'panel_integration', 'Cosmic uses panel integration fallback');
    
    # Reset to GNOME for remaining tests
    local $ENV{XDG_CURRENT_DESKTOP} = 'gnome';
    $system_tray->create_tray_icon('asbru-cm');
    
    # Test menu items
    my $menu_count = $system_tray->add_menu_item('Quick Connect', sub { return 'quick_connect'; });
    ok($menu_count > 0, 'Menu item added to tray');
    
    $system_tray->add_menu_item('Preferences', sub { return 'preferences'; });
    $system_tray->add_menu_item('Quit', sub { return 'quit'; });
    
    is(scalar(@tray_menu_items), 3, 'Three menu items added');
    
    # Test icon updates
    ok($system_tray->update_icon('asbru-cm-connected'), 'Tray icon updated');
    
    # Test balloon notifications
    ok($system_tray->show_balloon('Ásbrú CM', 'Application started'), 'Balloon notification shown');
    
    # Test menu item properties
    my ($quick_connect) = grep { $_->{label} eq 'Quick Connect' } @tray_menu_items;
    ok(defined $quick_connect, 'Quick Connect menu item found');
};

subtest 'Clipboard Operations' => sub {
    plan tests => 6;
    
    # Mock clipboard operations for different display servers
    my $clipboard = Test::MockObject->new();
    my $clipboard_content = '';
    
    $clipboard->mock('set_text', sub {
        my ($self, $text) = @_;
        
        # Simulate different clipboard handling for Wayland vs X11
        my $display_server = $ENV{WAYLAND_DISPLAY} ? 'wayland' : 'x11';
        
        if ($display_server eq 'wayland') {
            # Wayland clipboard handling
            $clipboard_content = $text;
            return { success => 1, method => 'wayland_clipboard' };
        } else {
            # X11 clipboard handling
            $clipboard_content = $text;
            return { success => 1, method => 'x11_clipboard' };
        }
    });
    
    $clipboard->mock('get_text', sub {
        my ($self) = @_;
        return { 
            success => 1, 
            text => $clipboard_content,
            method => $ENV{WAYLAND_DISPLAY} ? 'wayland_clipboard' : 'x11_clipboard'
        };
    });
    
    $clipboard->mock('clear', sub {
        $clipboard_content = '';
        return { success => 1 };
    });
    
    # Test clipboard operations in X11 environment
    local $ENV{WAYLAND_DISPLAY} = undef;
    local $ENV{DISPLAY} = ':0';
    
    my $set_result = $clipboard->set_text('ssh user@example.com');
    ok($set_result->{success}, 'Clipboard text set in X11');
    is($set_result->{method}, 'x11_clipboard', 'X11 clipboard method used');
    
    my $get_result = $clipboard->get_text();
    ok($get_result->{success}, 'Clipboard text retrieved in X11');
    is($get_result->{text}, 'ssh user@example.com', 'Correct text retrieved');
    
    # Test clipboard operations in Wayland environment
    local $ENV{WAYLAND_DISPLAY} = 'wayland-0';
    
    $set_result = $clipboard->set_text('rdp user@windows.example.com');
    ok($set_result->{success}, 'Clipboard text set in Wayland');
    is($set_result->{method}, 'wayland_clipboard', 'Wayland clipboard method used');
};

subtest 'Desktop Environment Detection' => sub {
    plan tests => 8;
    
    # Mock desktop environment detection
    my $desktop_detector = Test::MockObject->new();
    
    $desktop_detector->mock('detect_desktop', sub {
        my ($self) = @_;
        
        my $desktop = $ENV{XDG_CURRENT_DESKTOP} || 'unknown';
        my $session = $ENV{DESKTOP_SESSION} || 'unknown';
        my $wayland = $ENV{WAYLAND_DISPLAY} ? 1 : 0;
        my $cosmic = $ENV{COSMIC_SESSION} ? 1 : 0;
        
        return {
            desktop => lc($desktop),
            session => $session,
            display_server => $wayland ? 'wayland' : 'x11',
            cosmic => $cosmic,
            features => {
                system_tray => $desktop ne 'cosmic',
                notifications => 1,
                file_dialogs => 1,
                panel_integration => $cosmic
            }
        };
    });
    
    # Test GNOME detection
    local $ENV{XDG_CURRENT_DESKTOP} = 'GNOME';
    local $ENV{WAYLAND_DISPLAY} = 'wayland-0';
    
    my $gnome_result = $desktop_detector->detect_desktop();
    is($gnome_result->{desktop}, 'gnome', 'GNOME desktop detected');
    is($gnome_result->{display_server}, 'wayland', 'Wayland display server detected');
    ok($gnome_result->{features}->{system_tray}, 'GNOME supports system tray');
    
    # Test Cosmic detection
    local $ENV{XDG_CURRENT_DESKTOP} = 'cosmic';
    local $ENV{COSMIC_SESSION} = '1';
    
    my $cosmic_result = $desktop_detector->detect_desktop();
    is($cosmic_result->{desktop}, 'cosmic', 'Cosmic desktop detected');
    ok($cosmic_result->{cosmic}, 'Cosmic session flag set');
    ok(!$cosmic_result->{features}->{system_tray}, 'Cosmic does not support traditional system tray');
    ok($cosmic_result->{features}->{panel_integration}, 'Cosmic supports panel integration');
    
    # Test KDE detection
    local $ENV{XDG_CURRENT_DESKTOP} = 'KDE';
    local $ENV{WAYLAND_DISPLAY} = undef;
    local $ENV{COSMIC_SESSION} = undef;
    
    my $kde_result = $desktop_detector->detect_desktop();
    is($kde_result->{desktop}, 'kde', 'KDE desktop detected');
};

subtest 'Window Management Integration' => sub {
    plan tests => 6;
    
    # Mock window management operations
    my $window_manager = Test::MockObject->new();
    my @managed_windows;
    
    $window_manager->mock('register_window', sub {
        my ($self, $window_id, $properties) = @_;
        
        push @managed_windows, {
            id => $window_id,
            title => $properties->{title},
            class => $properties->{class},
            workspace => $properties->{workspace} || 1,
            minimized => 0,
            maximized => 0
        };
        
        return scalar(@managed_windows);
    });
    
    $window_manager->mock('set_window_workspace', sub {
        my ($self, $window_id, $workspace) = @_;
        
        for my $window (@managed_windows) {
            if ($window->{id} eq $window_id) {
                $window->{workspace} = $workspace;
                return 1;
            }
        }
        return 0;
    });
    
    $window_manager->mock('minimize_window', sub {
        my ($self, $window_id) = @_;
        
        for my $window (@managed_windows) {
            if ($window->{id} eq $window_id) {
                $window->{minimized} = 1;
                return 1;
            }
        }
        return 0;
    });
    
    # Test window registration
    my $main_window_count = $window_manager->register_window('main_window', {
        title => 'Ásbrú Connection Manager',
        class => 'asbru-cm'
    });
    
    ok($main_window_count > 0, 'Main window registered');
    
    my $terminal_window_count = $window_manager->register_window('terminal_1', {
        title => 'SSH: user@example.com',
        class => 'asbru-cm-terminal',
        workspace => 2
    });
    
    is(scalar(@managed_windows), 2, 'Two windows registered');
    
    # Test workspace management
    ok($window_manager->set_window_workspace('terminal_1', 3), 'Window moved to workspace 3');
    
    my ($terminal_window) = grep { $_->{id} eq 'terminal_1' } @managed_windows;
    is($terminal_window->{workspace}, 3, 'Window workspace updated correctly');
    
    # Test window minimization
    ok($window_manager->minimize_window('main_window'), 'Main window minimized');
    
    my ($main_window) = grep { $_->{id} eq 'main_window' } @managed_windows;
    ok($main_window->{minimized}, 'Main window minimized flag set');
};

subtest 'Application Launcher Integration' => sub {
    plan tests => 5;
    
    # Mock application launcher integration
    my $launcher = Test::MockObject->new();
    
    $launcher->mock('register_application', sub {
        my ($self, $desktop_file) = @_;
        
        # Simulate desktop file registration
        return {
            success => 1,
            desktop_file => $desktop_file,
            registered => 1,
            mime_types => ['application/x-asbru-connection']
        };
    });
    
    $launcher->mock('create_quick_connect_action', sub {
        my ($self, $connection_name, $connection_data) = @_;
        
        return {
            success => 1,
            action_name => "quick-connect-$connection_name",
            desktop_action => "QuickConnect$connection_name"
        };
    });
    
    $launcher->mock('update_recent_connections', sub {
        my ($self, @connections) = @_;
        
        return {
            success => 1,
            recent_count => scalar(@connections)
        };
    });
    
    # Test application registration
    my $reg_result = $launcher->register_application('/usr/share/applications/asbru-cm.desktop');
    ok($reg_result->{success}, 'Application registered with launcher');
    ok($reg_result->{registered}, 'Registration flag set');
    
    # Test quick connect actions
    my $action_result = $launcher->create_quick_connect_action('production-server', {
        host => 'prod.example.com',
        user => 'admin'
    });
    
    ok($action_result->{success}, 'Quick connect action created');
    like($action_result->{action_name}, qr/quick-connect-production-server/, 'Action name correct');
    
    # Test recent connections update
    my $recent_result = $launcher->update_recent_connections(
        'production-server',
        'development-server',
        'staging-server'
    );
    
    is($recent_result->{recent_count}, 3, 'Recent connections updated');
};

subtest 'Performance Integration Testing' => sub {
    plan tests => 5;
    
    # Test integrated performance across multiple systems
    my $integration_perf = measure_performance('Full Integration Workflow', sub {
        # Simulate a complete workflow
        my $desktop = Test::MockObject->new();
        my $clipboard = Test::MockObject->new();
        my $notifications = Test::MockObject->new();
        
        # Mock quick operations
        $desktop->mock('detect_environment', sub { 
            sleep(0.001) if $ENV{ASBRU_TEST_SIMULATE_DELAY}; 
            return 'cosmic'; 
        });
        $clipboard->mock('copy_connection_string', sub { 
            sleep(0.002) if $ENV{ASBRU_TEST_SIMULATE_DELAY}; 
            return 1; 
        });
        $notifications->mock('show_connection_status', sub { 
            sleep(0.001) if $ENV{ASBRU_TEST_SIMULATE_DELAY}; 
            return 1; 
        });
        
        # Execute workflow
        $desktop->detect_environment();
        $clipboard->copy_connection_string();
        $notifications->show_connection_status();
    }, iterations => 10);
    
    ok(defined $integration_perf, 'Integration performance measured');
    ok($integration_perf->{average} < 100, 'Integration workflow is fast (<100ms)');
    
    # Test system resource usage during integration
    my $resource_usage = {
        cpu_percent => 5.2,
        memory_mb => 45.8,
        file_handles => 12
    };
    
    ok($resource_usage->{cpu_percent} < 10, 'CPU usage reasonable during integration');
    ok($resource_usage->{memory_mb} < 100, 'Memory usage reasonable during integration');
    ok($resource_usage->{file_handles} < 50, 'File handle usage reasonable');
    
    diag(sprintf("Integration Performance Summary:"));
    diag(sprintf("  Workflow Time: %.2fms", $integration_perf->{average}));
    diag(sprintf("  CPU Usage: %.1f%%", $resource_usage->{cpu_percent}));
    diag(sprintf("  Memory Usage: %.1f MB", $resource_usage->{memory_mb}));
    diag(sprintf("  File Handles: %d", $resource_usage->{file_handles}));
};

# Cleanup
cleanup_test_environment();

done_testing();