#!/usr/bin/perl

package AsbruTestFramework;

use strict;
use warnings;
use v5.20;

use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use Time::HiRes qw(time);

# Optional modules - load if available
my $MOCK_OBJECT_AVAILABLE = 0;
eval {
    require Test::MockObject;
    Test::MockObject->import();
    $MOCK_OBJECT_AVAILABLE = 1;
};

# Simple mock object implementation if Test::MockObject not available
unless ($MOCK_OBJECT_AVAILABLE) {
    package SimpleMockObject;
    
    sub new {
        my $class = shift;
        return bless {
            _methods => {},
            _isa => [],
            _properties => {}
        }, $class;
    }
    
    sub mock {
        my ($self, $method, $code) = @_;
        $self->{_methods}{$method} = $code;
    }
    
    sub set_isa {
        my ($self, @classes) = @_;
        $self->{_isa} = \@classes;
    }
    
    sub can {
        my ($self, $method) = @_;
        return $self->{_methods}{$method} || $self->SUPER::can($method);
    }
    
    sub AUTOLOAD {
        my $self = shift;
        our $AUTOLOAD;
        my $method = $AUTOLOAD;
        $method =~ s/.*:://;
        
        return if $method eq 'DESTROY';
        
        if (exists $self->{_methods}{$method}) {
            return $self->{_methods}{$method}->($self, @_);
        }
        
        # Default behavior
        return 1;
    }
}

# Add lib directory to path for testing
BEGIN {
    my $lib_path = File::Spec->catdir(dirname(dirname(abs_path(__FILE__))), 'lib');
    unshift @INC, $lib_path;
}

use Exporter 'import';
our @EXPORT_OK = qw(
    setup_test_environment
    cleanup_test_environment
    create_mock_gtk_widget
    measure_performance
    setup_headless_display
    verify_gtk4_compatibility
    test_theme_compatibility
    simulate_user_interaction
    create_mock_protocol_handler
    simulate_network_delay
    check_tool_availability
    load_test_configuration
);

our $TEST_ENV_SETUP = 0;
our $HEADLESS_DISPLAY = 0;

=head1 NAME

AsbruTestFramework - Comprehensive testing framework for Ásbrú Connection Manager

=head1 DESCRIPTION

This module provides utilities for testing GUI functionality, performance benchmarking,
and protocol validation for the modernized Ásbrú Connection Manager.

=head1 METHODS

=cut

sub setup_test_environment {
    my %options = @_;
    
    return if $TEST_ENV_SETUP;
    
    # Set up environment variables for testing
    $ENV{ASBRU_TEST_MODE} = 1;
    $ENV{ASBRU_CONFIG_DIR} = File::Spec->catdir($ENV{HOME}, '.config', 'asbru-test');
    
    # Create test configuration directory
    unless (-d $ENV{ASBRU_CONFIG_DIR}) {
        mkdir $ENV{ASBRU_CONFIG_DIR} or die "Cannot create test config dir: $!";
    }
    
    # Set up headless display if requested
    if ($options{headless}) {
        setup_headless_display();
    }
    
    # Initialize GTK if available
    if ($options{gtk}) {
        eval {
            if ($options{gtk4}) {
                require Gtk4;
                Gtk4->init();
            } else {
                require Gtk3;
                Gtk3->init();
            }
        };
        if ($@) {
            warn "GTK not available for testing: $@";
            return 0;
        }
    }
    
    $TEST_ENV_SETUP = 1;
    return 1;
}

sub cleanup_test_environment {
    return unless $TEST_ENV_SETUP;
    
    # Clean up test configuration directory
    if ($ENV{ASBRU_CONFIG_DIR} && -d $ENV{ASBRU_CONFIG_DIR}) {
        system("rm", "-rf", $ENV{ASBRU_CONFIG_DIR});
    }
    
    # Clean up headless display
    if ($HEADLESS_DISPLAY && $ENV{DISPLAY} =~ /:99/) {
        system("pkill", "-f", "Xvfb :99");
    }
    
    $TEST_ENV_SETUP = 0;
    $HEADLESS_DISPLAY = 0;
}

sub setup_headless_display {
    return if $HEADLESS_DISPLAY;
    
    # Check if Xvfb is available
    my $xvfb_available = system("which xvfb-run > /dev/null 2>&1") == 0;
    
    if ($xvfb_available) {
        # Start Xvfb on display :99
        system("Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &");
        $ENV{DISPLAY} = ":99";
        sleep 2; # Give Xvfb time to start
        $HEADLESS_DISPLAY = 1;
    } else {
        diag("Xvfb not available, using existing display");
    }
    
    return $HEADLESS_DISPLAY;
}

sub create_mock_gtk_widget {
    my ($widget_type, %properties) = @_;
    
    my $mock = $MOCK_OBJECT_AVAILABLE ? Test::MockObject->new() : SimpleMockObject->new();
    $mock->set_isa($widget_type);
    
    # Common GTK widget methods
    $mock->mock('show', sub { return 1; });
    $mock->mock('hide', sub { return 1; });
    $mock->mock('destroy', sub { return 1; });
    $mock->mock('get_visible', sub { return $properties{visible} // 1; });
    $mock->mock('set_sensitive', sub { $properties{sensitive} = $_[1]; });
    $mock->mock('get_sensitive', sub { return $properties{sensitive} // 1; });
    
    # Widget-specific methods based on type
    if ($widget_type =~ /Window/) {
        $mock->mock('set_title', sub { $properties{title} = $_[1]; });
        $mock->mock('get_title', sub { return $properties{title} // "Test Window"; });
        $mock->mock('present', sub { return 1; });
    } elsif ($widget_type =~ /Button/) {
        $mock->mock('set_label', sub { $properties{label} = $_[1]; });
        $mock->mock('get_label', sub { return $properties{label} // "Test Button"; });
        $mock->mock('clicked', sub { return 1; });
    } elsif ($widget_type =~ /Entry/) {
        $mock->mock('set_text', sub { $properties{text} = $_[1]; });
        $mock->mock('get_text', sub { return $properties{text} // ""; });
    }
    
    return $mock;
}

sub measure_performance {
    my ($test_name, $code_ref, %options) = @_;
    
    my $iterations = $options{iterations} || 1;
    my $warmup = $options{warmup} || 0;
    
    # Warmup runs
    for (1..$warmup) {
        $code_ref->();
    }
    
    my @times;
    for (1..$iterations) {
        my $start_time = time();
        $code_ref->();
        my $end_time = time();
        push @times, ($end_time - $start_time) * 1000; # Convert to milliseconds
    }
    
    my $avg_time = (sum(@times) / @times);
    my $min_time = min(@times);
    my $max_time = max(@times);
    
    diag(sprintf("Performance: %s - Avg: %.2fms, Min: %.2fms, Max: %.2fms", 
                 $test_name, $avg_time, $min_time, $max_time));
    
    return {
        average => $avg_time,
        minimum => $min_time,
        maximum => $max_time,
        iterations => $iterations,
        times => \@times
    };
}

sub verify_gtk4_compatibility {
    my ($widget) = @_;
    
    # Check if widget responds to GTK4-specific methods
    my @gtk4_methods = qw(get_first_child get_last_child get_next_sibling get_prev_sibling);
    
    my $gtk4_compatible = 1;
    for my $method (@gtk4_methods) {
        unless ($widget->can($method)) {
            $gtk4_compatible = 0;
            last;
        }
    }
    
    return $gtk4_compatible;
}

sub test_theme_compatibility {
    my ($widget, $theme_name) = @_;
    
    # Test basic theme properties
    my $tests_passed = 0;
    my $total_tests = 0;
    
    # Test if widget accepts CSS classes
    eval {
        if ($widget->can('add_css_class')) {
            $widget->add_css_class('test-class');
            $tests_passed++;
        }
        $total_tests++;
    };
    
    # Test if widget responds to style context
    eval {
        if ($widget->can('get_style_context')) {
            my $context = $widget->get_style_context();
            $tests_passed++ if defined $context;
        }
        $total_tests++;
    };
    
    return ($tests_passed, $total_tests);
}

sub simulate_user_interaction {
    my ($widget, $interaction_type, %params) = @_;
    
    my $result = 0;
    
    if ($interaction_type eq 'click') {
        if ($widget->can('clicked')) {
            $widget->clicked();
            $result = 1;
        }
    } elsif ($interaction_type eq 'key_press') {
        # Simulate key press event
        if ($widget->can('key_press_event')) {
            # Create mock key event
            my $event = create_mock_key_event($params{key});
            $result = $widget->key_press_event($event);
        }
    } elsif ($interaction_type eq 'text_input') {
        if ($widget->can('set_text')) {
            $widget->set_text($params{text});
            $result = 1;
        }
    }
    
    return $result;
}

sub create_mock_key_event {
    my ($key) = @_;
    
    my $event = $MOCK_OBJECT_AVAILABLE ? Test::MockObject->new() : SimpleMockObject->new();
    $event->mock('keyval', sub { return ord($key); });
    $event->mock('state', sub { return 0; });
    
    return $event;
}

sub create_mock_protocol_handler {
    my ($protocol_type, %options) = @_;
    
    my $handler = $MOCK_OBJECT_AVAILABLE ? Test::MockObject->new() : SimpleMockObject->new();
    
    # Common protocol handler methods
    $handler->mock('connect', sub {
        my ($self, %params) = @_;
        
        # Simulate network delay if requested
        simulate_network_delay() if $options{simulate_delay};
        
        # Simulate connection success/failure based on host
        if ($params{host} && $params{host} ne 'unreachable.example.com') {
            return { success => 1, pid => int(rand(30000)) + 1000 };
        }
        return { success => 0, error => 'Connection failed' };
    });
    
    $handler->mock('disconnect', sub { return 1; });
    $handler->mock('is_connected', sub { return 1; });
    $handler->mock('get_status', sub { return 'connected'; });
    
    # Protocol-specific methods
    if ($protocol_type eq 'ssh') {
        $handler->mock('execute_command', sub {
            my ($self, $command) = @_;
            return {
                command => $command,
                exit_code => 0,
                stdout => "Command output for: $command\n",
                stderr => ''
            };
        });
        
        $handler->mock('upload_file', sub { return { success => 1, bytes_transferred => 1024 }; });
        $handler->mock('download_file', sub { return { success => 1, bytes_transferred => 1024 }; });
        
    } elsif ($protocol_type eq 'rdp') {
        $handler->mock('set_resolution', sub { return 1; });
        $handler->mock('enable_clipboard', sub { return 1; });
        $handler->mock('redirect_drive', sub { return 1; });
        
    } elsif ($protocol_type eq 'vnc') {
        $handler->mock('set_quality', sub { return 1; });
        $handler->mock('set_compression', sub { return 1; });
        $handler->mock('send_key', sub { return 1; });
        $handler->mock('send_mouse_event', sub { return 1; });
        
    } elsif ($protocol_type eq 'local') {
        $handler->mock('spawn_shell', sub {
            return { success => 1, pid => int(rand(30000)) + 1000 };
        });
        $handler->mock('send_input', sub { return length($_[1] || ''); });
        $handler->mock('get_output', sub { return "Shell output\n"; });
    }
    
    return $handler;
}

sub simulate_network_delay {
    my ($delay_ms) = @_;
    $delay_ms ||= 50; # Default 50ms delay
    
    # Only simulate delay if explicitly requested
    if ($ENV{ASBRU_TEST_SIMULATE_DELAY}) {
        Time::HiRes::usleep($delay_ms * 1000);
    }
}

sub check_tool_availability {
    my (@tools) = @_;
    my %availability;
    
    for my $tool (@tools) {
        # In test mode, simulate tool availability
        if ($ENV{ASBRU_TEST_MODE}) {
            # Simulate some tools as missing for testing
            $availability{$tool} = !($tool eq 'missing_tool' || $tool eq 'unavailable_client');
        } else {
            # Actually check for tool availability
            $availability{$tool} = (system("which $tool > /dev/null 2>&1") == 0);
        }
    }
    
    return %availability;
}

sub load_test_configuration {
    my ($config_file) = @_;
    $config_file ||= File::Spec->catfile(dirname(dirname(abs_path(__FILE__))), 'fixtures', 'test_connections.yml');
    
    # Simple YAML-like parser for test configurations
    my %config;
    my $current_section;
    my $current_connection;
    
    if (open my $fh, '<', $config_file) {
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
            
            if ($line =~ /^(\w+):/) {
                $current_section = $1;
                $config{$current_section} = {};
            } elsif ($line =~ /^\s+(\w+(?:-\w+)*):/) {
                $current_connection = $1;
                $config{$current_section}{$current_connection} = {};
            } elsif ($line =~ /^\s+(\w+):\s*(.+)/) {
                my ($key, $value) = ($1, $2);
                $value =~ s/^["']|["']$//g; # Remove quotes
                if ($current_connection) {
                    $config{$current_section}{$current_connection}{$key} = $value;
                } else {
                    $config{$current_section}{$key} = $value;
                }
            }
        }
        close $fh;
    } else {
        diag("Warning: Could not load test configuration from $config_file");
    }
    
    return %config;
}

# Utility functions
sub sum { my $sum = 0; $sum += $_ for @_; return $sum; }
sub min { my $min = $_[0]; $min = $_ < $min ? $_ : $min for @_; return $min; }
sub max { my $max = $_[0]; $max = $_ > $max ? $_ : $max for @_; return $max; }

# Cleanup on exit
END {
    cleanup_test_environment();
}

1;

__END__

=head1 AUTHOR

Ásbrú Connection Manager Development Team

=head1 COPYRIGHT

This test framework was developed with AI assistance as part of the Ásbrú Connection Manager modernization project.

=cut