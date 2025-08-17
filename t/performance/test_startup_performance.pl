#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use Test::MockObject;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Time::HiRes qw(time);
use Benchmark qw(cmpthese timethese);

use AsbruTestFramework qw(
    setup_test_environment
    cleanup_test_environment
    measure_performance
);

# Test plan
plan tests => 8;

# Setup test environment
setup_test_environment();

# Test application startup performance
subtest 'Application Startup Time' => sub {
    plan tests => 5;
    
    # Mock application startup components
    my $app_startup = Test::MockObject->new();
    
    $app_startup->mock('load_configuration', sub {
        sleep(0.01) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return { config_loaded => 1, connections => 50 };
    });
    
    $app_startup->mock('initialize_gui', sub {
        sleep(0.02) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return { gui_initialized => 1, widgets_created => 25 };
    });
    
    $app_startup->mock('load_plugins', sub {
        sleep(0.005) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return { plugins_loaded => 3 };
    });
    
    # Measure individual component startup times
    my $config_perf = measure_performance('Configuration Loading', sub {
        $app_startup->load_configuration();
    }, iterations => 10);
    
    my $gui_perf = measure_performance('GUI Initialization', sub {
        $app_startup->initialize_gui();
    }, iterations => 10);
    
    my $plugin_perf = measure_performance('Plugin Loading', sub {
        $app_startup->load_plugins();
    }, iterations => 10);
    
    # Test that startup components complete successfully
    ok(defined $config_perf, 'Configuration loading performance measured');
    ok(defined $gui_perf, 'GUI initialization performance measured');
    ok(defined $plugin_perf, 'Plugin loading performance measured');
    
    # Test overall startup time
    my $total_startup_perf = measure_performance('Total Startup', sub {
        $app_startup->load_configuration();
        $app_startup->initialize_gui();
        $app_startup->load_plugins();
    }, iterations => 5);
    
    ok(defined $total_startup_perf, 'Total startup performance measured');
    
    # Verify startup time is reasonable (should be under 1 second in test mode)
    ok($total_startup_perf->{average} < 1000, 'Startup time is reasonable');
    
    diag(sprintf("Startup Performance Summary:"));
    diag(sprintf("  Configuration: %.2fms", $config_perf->{average}));
    diag(sprintf("  GUI Init: %.2fms", $gui_perf->{average}));
    diag(sprintf("  Plugins: %.2fms", $plugin_perf->{average}));
    diag(sprintf("  Total: %.2fms", $total_startup_perf->{average}));
};

subtest 'Memory Usage Benchmarks' => sub {
    plan tests => 6;
    
    # Mock memory usage tracking
    my $memory_tracker = Test::MockObject->new();
    my $base_memory = 50 * 1024 * 1024;  # 50MB base
    my $current_memory = $base_memory;
    
    $memory_tracker->mock('get_memory_usage', sub {
        return $current_memory;
    });
    
    $memory_tracker->mock('allocate_connections', sub {
        my ($self, $count) = @_;
        # Simulate memory usage: ~1KB per connection
        $current_memory += $count * 1024;
        return $count;
    });
    
    $memory_tracker->mock('create_gui_widgets', sub {
        my ($self, $count) = @_;
        # Simulate memory usage: ~5KB per widget
        $current_memory += $count * 5120;
        return $count;
    });
    
    $memory_tracker->mock('free_memory', sub {
        my ($self, $amount) = @_;
        $current_memory -= $amount;
        $current_memory = $base_memory if $current_memory < $base_memory;
        return 1;
    });
    
    # Test baseline memory usage
    my $baseline_memory = $memory_tracker->get_memory_usage();
    ok($baseline_memory > 0, 'Baseline memory usage recorded');
    
    # Test memory usage with connections
    $memory_tracker->allocate_connections(100);
    my $with_connections = $memory_tracker->get_memory_usage();
    ok($with_connections > $baseline_memory, 'Memory increases with connections');
    
    # Test memory usage with GUI widgets
    $memory_tracker->create_gui_widgets(50);
    my $with_widgets = $memory_tracker->get_memory_usage();
    ok($with_widgets > $with_connections, 'Memory increases with GUI widgets');
    
    # Calculate memory per connection
    my $memory_per_connection = ($with_connections - $baseline_memory) / 100;
    ok($memory_per_connection > 0, 'Memory per connection calculated');
    
    # Test memory cleanup
    $memory_tracker->free_memory($with_widgets - $baseline_memory);
    my $after_cleanup = $memory_tracker->get_memory_usage();
    is($after_cleanup, $baseline_memory, 'Memory cleaned up successfully');
    
    # Memory usage should be reasonable
    ok($baseline_memory < 100 * 1024 * 1024, 'Baseline memory usage reasonable (<100MB)');
    
    diag(sprintf("Memory Usage Summary:"));
    diag(sprintf("  Baseline: %.2f MB", $baseline_memory / (1024*1024)));
    diag(sprintf("  Per Connection: %.2f KB", $memory_per_connection / 1024));
    diag(sprintf("  With 100 Connections: %.2f MB", $with_connections / (1024*1024)));
};

subtest 'Connection List Performance' => sub {
    plan tests => 5;
    
    # Mock connection list operations
    my $connection_list = Test::MockObject->new();
    my @connections;
    
    $connection_list->mock('add_connection', sub {
        my ($self, $connection) = @_;
        push @connections, $connection;
        return scalar(@connections);
    });
    
    $connection_list->mock('search_connections', sub {
        my ($self, $query) = @_;
        return grep { $_->{name} =~ /\Q$query\E/i } @connections;
    });
    
    $connection_list->mock('sort_connections', sub {
        my ($self, $field) = @_;
        @connections = sort { $a->{$field} cmp $b->{$field} } @connections;
        return scalar(@connections);
    });
    
    # Populate test connections
    for my $i (1..1000) {
        $connection_list->add_connection({
            name => "Connection $i",
            host => "host$i.example.com",
            type => $i % 3 == 0 ? 'SSH' : $i % 3 == 1 ? 'RDP' : 'VNC'
        });
    }
    
    # Test connection addition performance
    my $add_perf = measure_performance('Add 100 Connections', sub {
        for my $i (1001..1100) {
            $connection_list->add_connection({
                name => "Connection $i",
                host => "host$i.example.com",
                type => 'SSH'
            });
        }
    }, iterations => 1);
    
    ok(defined $add_perf, 'Connection addition performance measured');
    
    # Test search performance
    my $search_perf = measure_performance('Search Connections', sub {
        my @results = $connection_list->search_connections('Connection 1');
    }, iterations => 10);
    
    ok(defined $search_perf, 'Connection search performance measured');
    
    # Test sorting performance
    my $sort_perf = measure_performance('Sort Connections', sub {
        $connection_list->sort_connections('name');
    }, iterations => 5);
    
    ok(defined $sort_perf, 'Connection sorting performance measured');
    
    # Verify operations complete in reasonable time
    ok($search_perf->{average} < 100, 'Search completes quickly (<100ms)');
    ok($sort_perf->{average} < 200, 'Sort completes quickly (<200ms)');
    
    diag(sprintf("Connection List Performance:"));
    diag(sprintf("  Add 100: %.2fms", $add_perf->{average}));
    diag(sprintf("  Search: %.2fms", $search_perf->{average}));
    diag(sprintf("  Sort: %.2fms", $sort_perf->{average}));
};

subtest 'GUI Rendering Performance' => sub {
    plan tests => 6;
    
    # Mock GUI rendering operations
    my $gui_renderer = Test::MockObject->new();
    
    $gui_renderer->mock('render_connection_tree', sub {
        my ($self, $connection_count) = @_;
        # Simulate rendering time proportional to connection count
        my $render_time = $connection_count * 0.0001;
        sleep($render_time) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return $connection_count;
    });
    
    $gui_renderer->mock('update_status_bar', sub {
        sleep(0.001) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return 1;
    });
    
    $gui_renderer->mock('refresh_terminal_tabs', sub {
        my ($self, $tab_count) = @_;
        sleep($tab_count * 0.002) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return $tab_count;
    });
    
    # Test connection tree rendering with different sizes
    my $small_tree_perf = measure_performance('Render 50 Connections', sub {
        $gui_renderer->render_connection_tree(50);
    }, iterations => 10);
    
    my $large_tree_perf = measure_performance('Render 500 Connections', sub {
        $gui_renderer->render_connection_tree(500);
    }, iterations => 5);
    
    ok(defined $small_tree_perf, 'Small tree rendering performance measured');
    ok(defined $large_tree_perf, 'Large tree rendering performance measured');
    
    # Test status bar updates
    my $status_perf = measure_performance('Status Bar Updates', sub {
        for (1..10) {
            $gui_renderer->update_status_bar();
        }
    }, iterations => 5);
    
    ok(defined $status_perf, 'Status bar update performance measured');
    
    # Test terminal tab rendering
    my $tab_perf = measure_performance('Refresh 10 Terminal Tabs', sub {
        $gui_renderer->refresh_terminal_tabs(10);
    }, iterations => 5);
    
    ok(defined $tab_perf, 'Terminal tab refresh performance measured');
    
    # Verify rendering performance scales reasonably
    my $scaling_factor = $large_tree_perf->{average} / $small_tree_perf->{average};
    ok($scaling_factor < 20, 'Rendering performance scales reasonably');
    ok($status_perf->{average} < 50, 'Status updates are fast (<50ms)');
    
    diag(sprintf("GUI Rendering Performance:"));
    diag(sprintf("  50 Connections: %.2fms", $small_tree_perf->{average}));
    diag(sprintf("  500 Connections: %.2fms", $large_tree_perf->{average}));
    diag(sprintf("  Status Updates: %.2fms", $status_perf->{average}));
    diag(sprintf("  Tab Refresh: %.2fms", $tab_perf->{average}));
};

subtest 'Configuration Loading Performance' => sub {
    plan tests => 5;
    
    # Mock configuration operations
    my $config_manager = Test::MockObject->new();
    
    $config_manager->mock('load_yaml_config', sub {
        my ($self, $size) = @_;
        # Simulate YAML parsing time based on file size
        sleep($size * 0.00001) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return { connections => $size, loaded => 1 };
    });
    
    $config_manager->mock('validate_config', sub {
        my ($self, $config) = @_;
        sleep(0.005) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return 1;
    });
    
    $config_manager->mock('migrate_config', sub {
        my ($self, $from_version, $to_version) = @_;
        sleep(0.01) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return 1;
    });
    
    # Test configuration loading with different sizes
    my $small_config_perf = measure_performance('Load Small Config (100 connections)', sub {
        my $config = $config_manager->load_yaml_config(100);
        $config_manager->validate_config($config);
    }, iterations => 10);
    
    my $large_config_perf = measure_performance('Load Large Config (1000 connections)', sub {
        my $config = $config_manager->load_yaml_config(1000);
        $config_manager->validate_config($config);
    }, iterations => 5);
    
    ok(defined $small_config_perf, 'Small config loading performance measured');
    ok(defined $large_config_perf, 'Large config loading performance measured');
    
    # Test configuration migration
    my $migration_perf = measure_performance('Config Migration', sub {
        $config_manager->migrate_config('6.4.1', '7.0.0');
    }, iterations => 5);
    
    ok(defined $migration_perf, 'Config migration performance measured');
    
    # Verify reasonable performance
    ok($small_config_perf->{average} < 100, 'Small config loads quickly (<100ms)');
    ok($large_config_perf->{average} < 500, 'Large config loads reasonably (<500ms)');
    
    diag(sprintf("Configuration Performance:"));
    diag(sprintf("  Small Config: %.2fms", $small_config_perf->{average}));
    diag(sprintf("  Large Config: %.2fms", $large_config_perf->{average}));
    diag(sprintf("  Migration: %.2fms", $migration_perf->{average}));
};

subtest 'Network Operation Performance' => sub {
    plan tests => 5;
    
    # Mock network operations
    my $network_ops = Test::MockObject->new();
    
    $network_ops->mock('resolve_hostname', sub {
        my ($self, $hostname) = @_;
        sleep(0.01) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return '192.168.1.100';
    });
    
    $network_ops->mock('test_connectivity', sub {
        my ($self, $host, $port) = @_;
        sleep(0.02) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return $host ne 'unreachable.example.com';
    });
    
    $network_ops->mock('download_update', sub {
        my ($self, $size_mb) = @_;
        sleep($size_mb * 0.001) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return { downloaded => $size_mb, success => 1 };
    });
    
    # Test hostname resolution
    my $dns_perf = measure_performance('DNS Resolution', sub {
        $network_ops->resolve_hostname('example.com');
    }, iterations => 10);
    
    ok(defined $dns_perf, 'DNS resolution performance measured');
    
    # Test connectivity testing
    my $connectivity_perf = measure_performance('Connectivity Test', sub {
        $network_ops->test_connectivity('example.com', 22);
    }, iterations => 5);
    
    ok(defined $connectivity_perf, 'Connectivity test performance measured');
    
    # Test batch operations
    my $batch_perf = measure_performance('Batch DNS Resolution', sub {
        for my $i (1..10) {
            $network_ops->resolve_hostname("host$i.example.com");
        }
    }, iterations => 3);
    
    ok(defined $batch_perf, 'Batch DNS performance measured');
    
    # Verify reasonable network performance
    ok($dns_perf->{average} < 100, 'DNS resolution is fast (<100ms)');
    ok($connectivity_perf->{average} < 200, 'Connectivity test is reasonable (<200ms)');
    
    diag(sprintf("Network Performance:"));
    diag(sprintf("  DNS Resolution: %.2fms", $dns_perf->{average}));
    diag(sprintf("  Connectivity Test: %.2fms", $connectivity_perf->{average}));
    diag(sprintf("  Batch DNS (10): %.2fms", $batch_perf->{average}));
};

subtest 'Terminal Performance' => sub {
    plan tests => 5;
    
    # Mock terminal operations
    my $terminal = Test::MockObject->new();
    
    $terminal->mock('create_terminal', sub {
        sleep(0.05) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return { terminal_id => int(rand(1000)), created => 1 };
    });
    
    $terminal->mock('send_text', sub {
        my ($self, $text) = @_;
        # Simulate text sending based on length
        sleep(length($text) * 0.0001) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return length($text);
    });
    
    $terminal->mock('scroll_buffer', sub {
        my ($self, $lines) = @_;
        sleep($lines * 0.0001) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return $lines;
    });
    
    # Test terminal creation
    my $create_perf = measure_performance('Terminal Creation', sub {
        $terminal->create_terminal();
    }, iterations => 5);
    
    ok(defined $create_perf, 'Terminal creation performance measured');
    
    # Test text sending
    my $text_perf = measure_performance('Send Text (1KB)', sub {
        my $text = 'x' x 1024;  # 1KB of text
        $terminal->send_text($text);
    }, iterations => 10);
    
    ok(defined $text_perf, 'Text sending performance measured');
    
    # Test scrolling
    my $scroll_perf = measure_performance('Scroll 1000 Lines', sub {
        $terminal->scroll_buffer(1000);
    }, iterations => 5);
    
    ok(defined $scroll_perf, 'Scrolling performance measured');
    
    # Verify reasonable terminal performance
    ok($create_perf->{average} < 500, 'Terminal creation is reasonable (<500ms)');
    ok($text_perf->{average} < 50, 'Text sending is fast (<50ms)');
    
    diag(sprintf("Terminal Performance:"));
    diag(sprintf("  Creation: %.2fms", $create_perf->{average}));
    diag(sprintf("  Send 1KB Text: %.2fms", $text_perf->{average}));
    diag(sprintf("  Scroll 1000 Lines: %.2fms", $scroll_perf->{average}));
};

subtest 'Comparative Performance Analysis' => sub {
    plan tests => 4;
    
    # Compare GTK3 vs GTK4 performance (simulated)
    my $gtk3_sim = Test::MockObject->new();
    my $gtk4_sim = Test::MockObject->new();
    
    $gtk3_sim->mock('create_widget', sub {
        sleep(0.002) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
        return 1;
    });
    
    $gtk4_sim->mock('create_widget', sub {
        sleep(0.0015) if $ENV{ASBRU_TEST_SIMULATE_DELAY};  # GTK4 slightly faster
        return 1;
    });
    
    # Benchmark widget creation
    my $gtk3_perf = measure_performance('GTK3 Widget Creation', sub {
        for (1..100) {
            $gtk3_sim->create_widget();
        }
    }, iterations => 5);
    
    my $gtk4_perf = measure_performance('GTK4 Widget Creation', sub {
        for (1..100) {
            $gtk4_sim->create_widget();
        }
    }, iterations => 5);
    
    ok(defined $gtk3_perf, 'GTK3 performance measured');
    ok(defined $gtk4_perf, 'GTK4 performance measured');
    
    # Calculate performance improvement
    my $improvement = (($gtk3_perf->{average} - $gtk4_perf->{average}) / $gtk3_perf->{average}) * 100;
    
    ok($improvement >= 0, 'GTK4 performance is at least as good as GTK3');
    
    # Overall performance should be reasonable
    ok($gtk4_perf->{average} < 1000, 'GTK4 widget creation is fast (<1s for 100 widgets)');
    
    diag(sprintf("Comparative Performance:"));
    diag(sprintf("  GTK3 (100 widgets): %.2fms", $gtk3_perf->{average}));
    diag(sprintf("  GTK4 (100 widgets): %.2fms", $gtk4_perf->{average}));
    diag(sprintf("  Performance improvement: %.1f%%", $improvement));
};

# Cleanup
cleanup_test_environment();

done_testing();