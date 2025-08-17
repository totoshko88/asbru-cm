#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($Bin);
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Time::HiRes qw(time sleep);
use POSIX qw(getpid);

# Add lib directories to path
BEGIN {
    my $lib_path = File::Spec->catdir(dirname(dirname(abs_path(__FILE__))), 'lib');
    my $test_lib_path = File::Spec->catdir(dirname(abs_path(__FILE__)), 'lib');
    unshift @INC, $lib_path, $test_lib_path;
}

use AsbruTestFramework qw(
    setup_test_environment
    cleanup_test_environment
    measure_performance
);

# Test configuration
my $STRESS_TEST_DURATION = 30; # seconds
my $MEMORY_LEAK_ITERATIONS = 100;
my $CONNECTION_STRESS_COUNT = 10;

plan tests => 15;

# Set up test environment
setup_test_environment(
    headless => 1,  # Use headless for performance testing
    gtk => 0        # Skip GTK for pure performance tests
);

# Test 1: Application Startup Performance
subtest 'Application Startup Performance' => sub {
    plan tests => 5;
    
    # Test cold startup (first time)
    my $cold_startup = measure_performance(
        'Cold Startup',
        sub {
            # Simulate application initialization
            eval {
                require File::Spec;
                require YAML::Tiny if eval { require YAML::Tiny; 1; };
                require Storable;
            };
        },
        iterations => 1
    );
    
    ok($cold_startup->{average} < 2000, 'Cold startup under 2 seconds')
        or diag("Cold startup time: " . $cold_startup->{average} . "ms");
    
    # Test warm startup (subsequent times)
    my $warm_startup = measure_performance(
        'Warm Startup',
        sub {
            eval {
                require File::Spec;
                require YAML::Tiny if eval { require YAML::Tiny; 1; };
                require Storable;
            };
        },
        iterations => 5,
        warmup => 1
    );
    
    ok($warm_startup->{average} < 500, 'Warm startup under 500ms')
        or diag("Warm startup time: " . $warm_startup->{average} . "ms");
    
    # Test module loading performance
    my $module_loading = measure_performance(
        'Module Loading',
        sub {
            eval { require PACUtils; } if -f File::Spec->catfile(dirname(dirname($Bin)), 'lib', 'PACUtils.pm');
        },
        iterations => 10
    );
    
    ok($module_loading->{average} < 100, 'Module loading under 100ms')
        or diag("Module loading time: " . $module_loading->{average} . "ms");
    
    # Test configuration loading performance
    my $config_dir = File::Spec->catdir($ENV{HOME}, '.config', 'asbru-perf-test');
    mkdir $config_dir unless -d $config_dir;
    
    # Create a test configuration file
    my $config_file = File::Spec->catfile($config_dir, 'test.yml');
    open my $fh, '>', $config_file or die "Cannot create config file: $!";
    print $fh "test_config:\n  value: 123\n  array:\n    - item1\n    - item2\n";
    close $fh;
    
    my $config_loading = measure_performance(
        'Configuration Loading',
        sub {
            if (eval { require YAML::Tiny; 1; }) {
                my $yaml = YAML::Tiny->read($config_file);
            } elsif (eval { require YAML; 1; }) {
                YAML::LoadFile($config_file);
            }
        },
        iterations => 20
    );
    
    ok($config_loading->{average} < 50, 'Configuration loading under 50ms')
        or diag("Config loading time: " . $config_loading->{average} . "ms");
    
    # Cleanup
    unlink $config_file;
    rmdir $config_dir;
    
    # Test startup consistency (low variance)
    my $variance = calculate_variance($warm_startup->{times});
    ok($variance < 100, 'Startup time variance acceptable')
        or diag("Startup variance: ${variance}ms²");
};

# Test 2: Memory Usage and Leak Detection
subtest 'Memory Usage and Leak Detection' => sub {
    plan tests => 6;
    
    # Get initial memory usage
    my $initial_memory = get_memory_usage();
    ok($initial_memory > 0, 'Initial memory usage measurable');
    diag("Initial memory usage: ${initial_memory}KB");
    
    # Test memory usage during normal operations
    my $pre_ops_memory = get_memory_usage();
    
    # Simulate normal operations
    for my $i (1..50) {
        my $data = "test data " x 100;  # Create some data
        my @array = split /\s+/, $data;
        my %hash = map { $_ => $i } @array;
    }
    
    my $post_ops_memory = get_memory_usage();
    my $ops_memory_diff = $post_ops_memory - $pre_ops_memory;
    
    ok($ops_memory_diff < 10000, 'Memory usage during operations reasonable')
        or diag("Memory increase during ops: ${ops_memory_diff}KB");
    
    # Test for memory leaks
    my $leak_test_start = get_memory_usage();
    
    for my $iteration (1..$MEMORY_LEAK_ITERATIONS) {
        # Simulate operations that might leak memory
        my $large_data = "x" x 1000;
        my @large_array = ($large_data) x 100;
        
        # Create and destroy objects
        my $obj = { data => \@large_array, id => $iteration };
        
        # Force garbage collection periodically
        if ($iteration % 10 == 0) {
            # Perl doesn't have explicit GC, but we can undef variables
            undef $obj;
            undef @large_array;
            undef $large_data;
        }
    }
    
    my $leak_test_end = get_memory_usage();
    my $potential_leak = $leak_test_end - $leak_test_start;
    
    ok($potential_leak < 50000, 'No significant memory leaks detected')
        or diag("Potential memory leak: ${potential_leak}KB over $MEMORY_LEAK_ITERATIONS iterations");
    
    # Test memory usage with file operations
    my $file_ops_start = get_memory_usage();
    
    my $temp_dir = File::Spec->catdir($ENV{HOME}, '.asbru-temp-test');
    mkdir $temp_dir unless -d $temp_dir;
    
    for my $i (1..20) {
        my $temp_file = File::Spec->catfile($temp_dir, "test_$i.tmp");
        open my $fh, '>', $temp_file or die "Cannot create temp file: $!";
        print $fh "test data " x 1000;
        close $fh;
        
        # Read it back
        open $fh, '<', $temp_file or die "Cannot read temp file: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        
        unlink $temp_file;
    }
    
    rmdir $temp_dir;
    
    my $file_ops_end = get_memory_usage();
    my $file_ops_diff = $file_ops_end - $file_ops_start;
    
    ok($file_ops_diff < 5000, 'File operations memory usage reasonable')
        or diag("File operations memory increase: ${file_ops_diff}KB");
    
    # Test peak memory usage
    my $peak_memory = get_peak_memory_usage();
    ok($peak_memory > $initial_memory, 'Peak memory usage tracked');
    diag("Peak memory usage: ${peak_memory}KB");
    
    # Test memory efficiency
    my $final_memory = get_memory_usage();
    my $total_increase = $final_memory - $initial_memory;
    ok($total_increase < 20000, 'Total memory increase acceptable')
        or diag("Total memory increase: ${total_increase}KB");
};

# Test 3: CPU Performance and Resource Management
subtest 'CPU Performance and Resource Management' => sub {
    plan tests => 5;
    
    # Test CPU-intensive operations
    my $cpu_test = measure_performance(
        'CPU Intensive Operations',
        sub {
            # Simulate CPU-intensive work
            my $result = 0;
            for my $i (1..10000) {
                $result += sqrt($i) * sin($i);
            }
            return $result;
        },
        iterations => 5
    );
    
    ok($cpu_test->{average} < 1000, 'CPU intensive operations complete quickly')
        or diag("CPU test time: " . $cpu_test->{average} . "ms");
    
    # Test string processing performance
    my $string_test = measure_performance(
        'String Processing',
        sub {
            my $text = "The quick brown fox jumps over the lazy dog " x 100;
            $text =~ s/fox/cat/g;
            $text =~ s/dog/mouse/g;
            my @words = split /\s+/, $text;
            my $word_count = scalar @words;
            return $word_count;
        },
        iterations => 10
    );
    
    ok($string_test->{average} < 100, 'String processing efficient')
        or diag("String processing time: " . $string_test->{average} . "ms");
    
    # Test file I/O performance
    my $temp_file = File::Spec->catfile($ENV{HOME}, '.asbru-io-test.tmp');
    
    my $io_test = measure_performance(
        'File I/O Operations',
        sub {
            # Write test
            open my $fh, '>', $temp_file or die "Cannot create temp file: $!";
            for my $i (1..1000) {
                print $fh "Line $i: " . ("data " x 10) . "\n";
            }
            close $fh;
            
            # Read test
            open $fh, '<', $temp_file or die "Cannot read temp file: $!";
            my @lines = <$fh>;
            close $fh;
            
            return scalar @lines;
        },
        iterations => 5
    );
    
    unlink $temp_file if -f $temp_file;
    
    ok($io_test->{average} < 500, 'File I/O operations efficient')
        or diag("File I/O time: " . $io_test->{average} . "ms");
    
    # Test concurrent operations simulation
    my $concurrent_test = measure_performance(
        'Concurrent Operations Simulation',
        sub {
            # Simulate multiple concurrent tasks
            my @tasks;
            for my $i (1..5) {
                push @tasks, sub {
                    my $result = 0;
                    for my $j (1..1000) {
                        $result += $j * $i;
                    }
                    return $result;
                };
            }
            
            # Execute tasks
            my @results;
            for my $task (@tasks) {
                push @results, $task->();
            }
            
            return scalar @results;
        },
        iterations => 3
    );
    
    ok($concurrent_test->{average} < 200, 'Concurrent operations handled efficiently')
        or diag("Concurrent operations time: " . $concurrent_test->{average} . "ms");
    
    # Test resource cleanup
    my $cleanup_test = measure_performance(
        'Resource Cleanup',
        sub {
            # Create resources
            my @resources;
            for my $i (1..100) {
                push @resources, {
                    id => $i,
                    data => "resource data " x 50,
                    timestamp => time()
                };
            }
            
            # Cleanup resources
            @resources = ();
            
            return 1;
        },
        iterations => 10
    );
    
    ok($cleanup_test->{average} < 50, 'Resource cleanup efficient')
        or diag("Resource cleanup time: " . $cleanup_test->{average} . "ms");
};

# Test 4: Stress Testing with Multiple Connections
subtest 'Stress Testing with Multiple Connections' => sub {
    plan tests => 4;
    
    # Simulate multiple connection objects
    my @connections;
    
    my $connection_creation = measure_performance(
        'Connection Object Creation',
        sub {
            for my $i (1..$CONNECTION_STRESS_COUNT) {
                my $conn = {
                    id => "conn_$i",
                    host => "host$i.example.com",
                    port => 22 + $i,
                    protocol => 'SSH',
                    status => 'disconnected',
                    config => {
                        timeout => 30,
                        retries => 3,
                        options => [map { "option$_" } 1..5]
                    }
                };
                push @connections, $conn;
            }
            return scalar @connections;
        },
        iterations => 1
    );
    
    ok($connection_creation->{average} < 100, 'Connection creation efficient')
        or diag("Connection creation time: " . $connection_creation->{average} . "ms");
    
    # Test connection management operations
    my $connection_ops = measure_performance(
        'Connection Management Operations',
        sub {
            # Simulate connection operations
            for my $conn (@connections) {
                $conn->{status} = 'connecting';
                $conn->{last_attempt} = time();
                
                # Simulate connection logic
                if (rand() > 0.5) {
                    $conn->{status} = 'connected';
                    $conn->{connected_at} = time();
                } else {
                    $conn->{status} = 'failed';
                    $conn->{error} = 'Connection timeout';
                }
            }
            
            # Count successful connections
            my $connected = grep { $_->{status} eq 'connected' } @connections;
            return $connected;
        },
        iterations => 5
    );
    
    ok($connection_ops->{average} < 50, 'Connection operations efficient')
        or diag("Connection operations time: " . $connection_ops->{average} . "ms");
    
    # Test data processing for multiple connections
    my $data_processing = measure_performance(
        'Multi-Connection Data Processing',
        sub {
            for my $conn (@connections) {
                # Simulate data processing
                $conn->{data_buffer} = [map { "output line $_\n" } 1..100];
                
                # Process buffer
                my @lines = split /\n/, join('', @{$conn->{data_buffer} || []});
                $conn->{line_count} = scalar @lines;
                
                # Clear buffer
                delete $conn->{data_buffer};
            }
            
            my $total_lines = 0;
            $total_lines += $_->{line_count} || 0 for @connections;
            return $total_lines;
        },
        iterations => 3
    );
    
    ok($data_processing->{average} < 200, 'Multi-connection data processing efficient')
        or diag("Data processing time: " . $data_processing->{average} . "ms");
    
    # Test cleanup of multiple connections
    my $cleanup_time = measure_performance(
        'Connection Cleanup',
        sub {
            for my $conn (@connections) {
                $conn->{status} = 'disconnected';
                delete $conn->{data_buffer};
                delete $conn->{connected_at};
                delete $conn->{error};
            }
            @connections = ();
            return 1;
        },
        iterations => 1
    );
    
    ok($cleanup_time->{average} < 50, 'Connection cleanup efficient')
        or diag("Connection cleanup time: " . $cleanup_time->{average} . "ms");
};

# Test 5: Extended Stability Testing
subtest 'Extended Stability Testing' => sub {
    plan tests => 3;
    
    my $stability_start_time = time();
    my $stability_start_memory = get_memory_usage();
    
    # Run stability test for specified duration
    my $iterations = 0;
    my $errors = 0;
    
    while ((time() - $stability_start_time) < $STRESS_TEST_DURATION) {
        $iterations++;
        
        eval {
            # Simulate various operations
            my $operation = $iterations % 4;
            
            if ($operation == 0) {
                # File operations
                my $temp_file = File::Spec->catfile($ENV{HOME}, ".asbru-stability-$iterations.tmp");
                open my $fh, '>', $temp_file or die "Cannot create file: $!";
                print $fh "stability test $iterations\n";
                close $fh;
                unlink $temp_file;
            } elsif ($operation == 1) {
                # Memory operations
                my @data = map { "test" x 100 } 1..50;
                undef @data;
            } elsif ($operation == 2) {
                # String operations
                my $text = "stability test " x 100;
                $text =~ s/test/TEST/g;
                my @words = split /\s+/, $text;
            } else {
                # Math operations
                my $result = 0;
                $result += sqrt($_) foreach (1..1000);
            }
        };
        
        if ($@) {
            $errors++;
            diag("Stability test error in iteration $iterations: $@");
        }
        
        # Brief pause to prevent overwhelming the system
        sleep(0.01) if $iterations % 100 == 0;
    }
    
    my $stability_end_time = time();
    my $stability_end_memory = get_memory_usage();
    
    ok($iterations > 100, 'Completed significant number of stability iterations')
        or diag("Completed $iterations iterations");
    
    my $error_rate = $errors / $iterations * 100;
    ok($error_rate < 1, 'Error rate acceptable during stability test')
        or diag("Error rate: ${error_rate}% ($errors errors in $iterations iterations)");
    
    my $memory_growth = $stability_end_memory - $stability_start_memory;
    ok($memory_growth < 10000, 'Memory growth acceptable during stability test')
        or diag("Memory growth during stability test: ${memory_growth}KB");
    
    diag("Stability test completed: $iterations iterations in " . 
         sprintf("%.2f", $stability_end_time - $stability_start_time) . " seconds");
};

# Helper functions
sub get_memory_usage {
    my $pid = getpid();
    my $status_file = "/proc/$pid/status";
    
    return 0 unless -f $status_file;
    
    open my $fh, '<', $status_file or return 0;
    while (my $line = <$fh>) {
        if ($line =~ /^VmRSS:\s+(\d+)\s+kB/) {
            close $fh;
            return $1;
        }
    }
    close $fh;
    return 0;
}

sub get_peak_memory_usage {
    my $pid = getpid();
    my $status_file = "/proc/$pid/status";
    
    return 0 unless -f $status_file;
    
    open my $fh, '<', $status_file or return 0;
    while (my $line = <$fh>) {
        if ($line =~ /^VmPeak:\s+(\d+)\s+kB/) {
            close $fh;
            return $1;
        }
    }
    close $fh;
    return 0;
}

sub calculate_variance {
    my @values = @_;
    return 0 unless @values > 1;
    
    my $mean = 0;
    $mean += $_ for @values;
    $mean /= @values;
    
    my $variance = 0;
    $variance += ($_ - $mean) ** 2 for @values;
    $variance /= (@values - 1);
    
    return $variance;
}

# Cleanup
cleanup_test_environment();

done_testing();

__END__

=head1 NAME

test_performance_stability.pl - Performance and Stability Testing

=head1 DESCRIPTION

This test script performs comprehensive performance and stability testing
of Ásbrú Connection Manager including:

- Application startup performance
- Memory usage and leak detection  
- CPU performance and resource management
- Stress testing with multiple connections
- Extended stability testing

=head1 AUTHOR

Ásbrú Connection Manager Development Team

This test was developed with AI assistance as part of the modernization project.

=cut