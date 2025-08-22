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
    measure_performance
    create_mock_gtk_widget
    create_mock_protocol_handler
);

# Test plan
plan tests => 8;

# Setup test environment
setup_test_environment();

# Test Local Shell and VTE functionality
subtest 'VTE Terminal Widget Creation' => sub {
    plan tests => 6;
    
    # Mock VTE terminal widget
    my $vte_terminal = create_mock_gtk_widget('Vte::Terminal');
    
    # Add VTE-specific methods
    $vte_terminal->mock('spawn_sync', sub {
        my ($self, $pty_flags, $working_directory, $argv, $envv, $spawn_flags, $child_setup, $child_setup_data, $child_pid, $cancellable) = @_;
        
        # Simulate successful shell spawn
        if ($argv && @$argv > 0) {
            ${$child_pid} = int(rand(30000)) + 1000 if $child_pid;
            return 1;
        }
        return 0;
    });
    
    $vte_terminal->mock('feed', sub {
        my ($self, $data) = @_;
        $self->{_buffer} .= $data if defined $data;
        return length($data || '');
    });
    
    $vte_terminal->mock('get_text', sub {
        my ($self) = @_;
        return $self->{_buffer} || '';
    });
    
    $vte_terminal->mock('set_size', sub {
        my ($self, $columns, $rows) = @_;
        $self->{_columns} = $columns;
        $self->{_rows} = $rows;
        return 1;
    });
    
    $vte_terminal->mock('reset', sub {
        my ($self, $clear_tabstops, $clear_history) = @_;
        $self->{_buffer} = '' if $clear_history;
        return 1;
    });
    
    # Test VTE terminal creation
    ok(defined $vte_terminal, 'VTE terminal widget created');
    ok($vte_terminal->can('spawn_sync'), 'VTE terminal has spawn_sync method');
    ok($vte_terminal->can('feed'), 'VTE terminal has feed method');
    ok($vte_terminal->can('get_text'), 'VTE terminal has get_text method');
    
    # Test terminal sizing
    ok($vte_terminal->set_size(80, 24), 'Terminal size set successfully');
    is($vte_terminal->{_columns}, 80, 'Terminal columns set correctly');
};

subtest 'Local Shell Process Spawning' => sub {
    plan tests => 7;
    
    my $shell_manager = create_mock_protocol_handler('local');
    my $active_processes = {};
    
    $shell_manager->mock('spawn_shell', sub {
        my ($self, %params) = @_;
        
        my $shell = $params{shell} || '/bin/bash';
        my $working_dir = $params{working_directory} || $ENV{HOME};
        
        # Simulate shell process creation
        my $pid = int(rand(30000)) + 1000;
        $active_processes->{$pid} = {
            shell => $shell,
            working_directory => $working_dir,
            started_at => time(),
            status => 'running'
        };
        
        return {
            success => 1,
            pid => $pid,
            shell => $shell
        };
    });
    
    $shell_manager->mock('get_process_status', sub {
        my ($self, $pid) = @_;
        return $active_processes->{$pid} || { status => 'not_found' };
    });
    
    $shell_manager->mock('terminate_process', sub {
        my ($self, $pid) = @_;
        if (exists $active_processes->{$pid}) {
            $active_processes->{$pid}->{status} = 'terminated';
            return 1;
        }
        return 0;
    });
    
    # Test shell spawning with default shell
    my $result = $shell_manager->spawn_shell();
    ok($result->{success}, 'Default shell spawned successfully');
    ok(defined $result->{pid}, 'Shell process PID returned');
    like($result->{shell}, qr{/(bash|sh)$}, 'Default shell is bash or sh');
    
    # Test shell spawning with custom shell
    $result = $shell_manager->spawn_shell(shell => '/bin/zsh');
    ok($result->{success}, 'Custom shell spawned successfully');
    is($result->{shell}, '/bin/zsh', 'Custom shell path correct');
    
    # Test process status checking
    my $status = $shell_manager->get_process_status($result->{pid});
    is($status->{status}, 'running', 'Process status is running');
    
    # Test process termination
    ok($shell_manager->terminate_process($result->{pid}), 'Process terminated successfully');
};

subtest 'Terminal Input/Output Handling' => sub {
    plan tests => 8;
    
    my $terminal_io = create_mock_protocol_handler('local');
    my $output_buffer = '';
    my $input_history = [];
    
    $terminal_io->mock('send_input', sub {
        my ($self, $input) = @_;
        push @$input_history, $input;
        
        # Simulate command execution and output
        if ($input =~ /^echo\s+(.+)/) {
            $output_buffer .= "$1\n";
        } elsif ($input =~ /^pwd/) {
            $output_buffer .= "/home/testuser\n";
        } elsif ($input =~ /^ls/) {
            $output_buffer .= "file1.txt\nfile2.txt\ndirectory1\n";
        } elsif ($input =~ /^whoami/) {
            $output_buffer .= "testuser\n";
        }
        
        return length($input);
    });
    
    $terminal_io->mock('get_output', sub {
        my ($self) = @_;
        return $output_buffer;
    });
    
    $terminal_io->mock('clear_output', sub {
        my ($self) = @_;
        $output_buffer = '';
        return 1;
    });
    
    $terminal_io->mock('get_input_history', sub {
        my ($self) = @_;
        return [@$input_history];
    });
    
    # Test basic command input/output
    my $bytes_sent = $terminal_io->send_input('echo "Hello World"');
    ok($bytes_sent > 0, 'Input sent to terminal');
    like($terminal_io->get_output(), qr/Hello World/, 'Echo command output received');
    
    # Test directory commands
    $terminal_io->send_input('pwd');
    like($terminal_io->get_output(), qr{/home/testuser}, 'pwd command output received');
    
    $terminal_io->send_input('ls');
    like($terminal_io->get_output(), qr/file1\.txt/, 'ls command output received');
    
    # Test user identification
    $terminal_io->send_input('whoami');
    like($terminal_io->get_output(), qr/testuser/, 'whoami command output received');
    
    # Test input history
    my $history = $terminal_io->get_input_history();
    is(scalar(@$history), 4, 'Input history contains all commands');
    is($history->[0], 'echo "Hello World"', 'First command in history correct');
    
    # Test output clearing
    ok($terminal_io->clear_output(), 'Output buffer cleared');
};

subtest 'Terminal Resizing and Scrollback' => sub {
    plan tests => 6;
    
    my $terminal_display = create_mock_protocol_handler('local');
    my $terminal_config = {
        columns => 80,
        rows => 24,
        scrollback_lines => 1000,
        current_scrollback => 0
    };
    
    $terminal_display->mock('resize', sub {
        my ($self, $columns, $rows) = @_;
        if ($columns > 0 && $rows > 0) {
            $terminal_config->{columns} = $columns;
            $terminal_config->{rows} = $rows;
            return 1;
        }
        return 0;
    });
    
    $terminal_display->mock('get_size', sub {
        my ($self) = @_;
        return ($terminal_config->{columns}, $terminal_config->{rows});
    });
    
    $terminal_display->mock('set_scrollback_lines', sub {
        my ($self, $lines) = @_;
        if ($lines >= 0) {
            $terminal_config->{scrollback_lines} = $lines;
            return 1;
        }
        return 0;
    });
    
    $terminal_display->mock('scroll_to_bottom', sub {
        my ($self) = @_;
        $terminal_config->{current_scrollback} = 0;
        return 1;
    });
    
    # Test terminal resizing
    ok($terminal_display->resize(120, 30), 'Terminal resized successfully');
    my ($cols, $rows) = $terminal_display->get_size();
    is($cols, 120, 'Terminal columns updated');
    is($rows, 30, 'Terminal rows updated');
    
    # Test invalid resize
    ok(!$terminal_display->resize(0, 24), 'Invalid resize rejected');
    
    # Test scrollback configuration
    ok($terminal_display->set_scrollback_lines(2000), 'Scrollback lines set');
    is($terminal_config->{scrollback_lines}, 2000, 'Scrollback lines updated');
};

subtest 'Terminal Color and Font Configuration' => sub {
    plan tests => 7;
    
    my $terminal_style = create_mock_protocol_handler('local');
    my $style_config = {
        font_family => 'monospace',
        font_size => 12,
        foreground_color => '#ffffff',
        background_color => '#000000',
        cursor_color => '#ffffff'
    };
    
    $terminal_style->mock('set_font', sub {
        my ($self, $font_family, $font_size) = @_;
        if ($font_family && $font_size > 0) {
            $style_config->{font_family} = $font_family;
            $style_config->{font_size} = $font_size;
            return 1;
        }
        return 0;
    });
    
    $terminal_style->mock('set_colors', sub {
        my ($self, $foreground, $background) = @_;
        if ($foreground =~ /^#[0-9a-fA-F]{6}$/ && $background =~ /^#[0-9a-fA-F]{6}$/) {
            $style_config->{foreground_color} = $foreground;
            $style_config->{background_color} = $background;
            return 1;
        }
        return 0;
    });
    
    $terminal_style->mock('set_cursor_color', sub {
        my ($self, $color) = @_;
        if ($color =~ /^#[0-9a-fA-F]{6}$/) {
            $style_config->{cursor_color} = $color;
            return 1;
        }
        return 0;
    });
    
    $terminal_style->mock('get_style_config', sub {
        my ($self) = @_;
        return { %$style_config };
    });
    
    # Test font configuration
    ok($terminal_style->set_font('DejaVu Sans Mono', 14), 'Font set successfully');
    is($style_config->{font_family}, 'DejaVu Sans Mono', 'Font family updated');
    is($style_config->{font_size}, 14, 'Font size updated');
    
    # Test color configuration
    ok($terminal_style->set_colors('#00ff00', '#001100'), 'Colors set successfully');
    is($style_config->{foreground_color}, '#00ff00', 'Foreground color updated');
    
    # Test cursor color
    ok($terminal_style->set_cursor_color('#ff0000'), 'Cursor color set');
    
    # Test invalid color format
    ok(!$terminal_style->set_colors('invalid', '#000000'), 'Invalid color format rejected');
};

subtest 'Terminal Environment Variables' => sub {
    plan tests => 6;
    
    my $terminal_env = create_mock_protocol_handler('local');
    my $environment = {
        'TERM' => 'xterm-256color',
        'SHELL' => '/bin/bash',
        'HOME' => '/home/testuser',
        'PATH' => '/usr/local/bin:/usr/bin:/bin'
    };
    
    $terminal_env->mock('set_environment_variable', sub {
        my ($self, $name, $value) = @_;
        if ($name && defined $value) {
            $environment->{$name} = $value;
            return 1;
        }
        return 0;
    });
    
    $terminal_env->mock('get_environment_variable', sub {
        my ($self, $name) = @_;
        return $environment->{$name};
    });
    
    $terminal_env->mock('get_all_environment', sub {
        my ($self) = @_;
        return { %$environment };
    });
    
    $terminal_env->mock('setup_default_environment', sub {
        my ($self) = @_;
        $environment = {
            'TERM' => 'xterm-256color',
            'SHELL' => '/bin/bash',
            'HOME' => $ENV{HOME} || '/home/user',
            'PATH' => '/usr/local/bin:/usr/bin:/bin',
            'LANG' => 'en_US.UTF-8',
            'LC_ALL' => 'en_US.UTF-8'
        };
        return scalar(keys %$environment);
    });
    
    # Test environment variable setting
    ok($terminal_env->set_environment_variable('CUSTOM_VAR', 'test_value'), 'Environment variable set');
    is($terminal_env->get_environment_variable('CUSTOM_VAR'), 'test_value', 'Environment variable retrieved');
    
    # Test default environment setup
    my $env_count = $terminal_env->setup_default_environment();
    ok($env_count > 0, 'Default environment variables set');
    is($terminal_env->get_environment_variable('TERM'), 'xterm-256color', 'TERM variable set correctly');
    
    # Test environment retrieval
    my $all_env = $terminal_env->get_all_environment();
    ok(exists $all_env->{SHELL}, 'SHELL variable exists in environment');
    ok(exists $all_env->{PATH}, 'PATH variable exists in environment');
};

subtest 'Terminal Session Management' => sub {
    plan tests => 7;
    
    my $session_manager = create_mock_protocol_handler('local');
    my $active_sessions = {};
    my $session_counter = 0;
    
    $session_manager->mock('create_session', sub {
        my ($self, %params) = @_;
        
        $session_counter++;
        my $session_id = "session_$session_counter";
        
        $active_sessions->{$session_id} = {
            id => $session_id,
            shell => $params{shell} || '/bin/bash',
            working_directory => $params{working_directory} || $ENV{HOME},
            created_at => time(),
            last_activity => time(),
            status => 'active'
        };
        
        return {
            success => 1,
            session_id => $session_id
        };
    });
    
    $session_manager->mock('get_session', sub {
        my ($self, $session_id) = @_;
        return $active_sessions->{$session_id};
    });
    
    $session_manager->mock('close_session', sub {
        my ($self, $session_id) = @_;
        if (exists $active_sessions->{$session_id}) {
            $active_sessions->{$session_id}->{status} = 'closed';
            return 1;
        }
        return 0;
    });
    
    $session_manager->mock('list_active_sessions', sub {
        my ($self) = @_;
        return grep { $_->{status} eq 'active' } values %$active_sessions;
    });
    
    # Test session creation
    my $result = $session_manager->create_session();
    ok($result->{success}, 'Session created successfully');
    ok(defined $result->{session_id}, 'Session ID returned');
    
    # Test session retrieval
    my $session = $session_manager->get_session($result->{session_id});
    ok(defined $session, 'Session retrieved successfully');
    is($session->{status}, 'active', 'Session status is active');
    
    # Test multiple sessions
    my $result2 = $session_manager->create_session(shell => '/bin/zsh');
    my @active = $session_manager->list_active_sessions();
    is(scalar(@active), 2, 'Two active sessions exist');
    
    # Test session closing
    ok($session_manager->close_session($result->{session_id}), 'Session closed successfully');
    @active = $session_manager->list_active_sessions();
    is(scalar(@active), 1, 'One active session remains after closing');
};

subtest 'Local Shell Performance Testing' => sub {
    plan tests => 3;
    
    # Test local shell startup performance
    my $perf_result = measure_performance('Local Shell Startup', sub {
        # Simulate shell startup process
        my $shell = create_mock_protocol_handler('local');
        $shell->mock('spawn', sub { 
            sleep(0.005) if $ENV{ASBRU_TEST_SIMULATE_DELAY}; 
            return { success => 1, pid => 12345 }; 
        });
        $shell->spawn();
    }, iterations => 5);
    
    ok(defined $perf_result, 'Local shell startup performance measured');
    ok($perf_result->{average} >= 0, 'Average startup time recorded');
    is($perf_result->{iterations}, 5, 'Correct number of iterations performed');
};

# Cleanup
cleanup_test_environment();

done_testing();