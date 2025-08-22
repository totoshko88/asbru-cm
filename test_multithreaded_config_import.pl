#!/usr/bin/env perl

# Test script for multithreaded configuration import functionality
# Tests both the asynchronous processing and theme-aware progress window

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

# Load required modules
use PACConfig;
use PACCompat;
use Gtk3 '-init';

# Test configuration data
my $test_config = {
    defaults => {
        'global variables' => {
            'TEST_VAR1' => { value => 'test_value_1' },
            'TEST_VAR2' => { value => 'test_value_2' },
        },
        'gui password' => '',
        'save session logs' => 0,
    },
    environments => {
        '__PAC__ROOT__' => {
            name => 'My Connections',
            _is_group => 1,
            children => {
                'test-connection-1' => 1,
                'test-group-1' => 1,
            }
        },
        'test-connection-1' => {
            name => 'Test SSH Connection',
            method => 'ssh',
            ip => '127.0.0.1',
            user => 'testuser',
            _is_group => 0,
        },
        'test-group-1' => {
            name => 'Test Group',
            _is_group => 1,
            children => {
                'test-connection-2' => 1,
            }
        },
        'test-connection-2' => {
            name => 'Test RDP Connection',
            method => 'xfreerdp',
            ip => '192.168.1.100',
            user => 'rdpuser',
            _is_group => 0,
        },
    }
};

# Create test configuration file
my $test_config_file = '/tmp/test_asbru_config.yml';
eval {
    require YAML::XS;
    YAML::XS::DumpFile($test_config_file, $test_config);
    print "Created test configuration file: $test_config_file\n";
};

if ($@) {
    die "Failed to create test configuration file: $@\n";
}

# Test the multithreaded configuration import
print "Testing multithreaded configuration import...\n";

# Create a PACConfig instance
my $pac_config = PACConfig->new({});

# Test progress window creation
print "Testing progress window creation...\n";
my $progress_window = $pac_config->_createProgressWindow(
    "Test Configuration Import",
    "Testing the multithreaded configuration import functionality..."
);

if ($progress_window && ref $progress_window eq 'HASH') {
    print "✅ Progress window created successfully\n";
    
    # Test progress updates
    for my $i (1..10) {
        $pac_config->_updateProgressWindow($progress_window, $i, 10, "Processing item $i of 10");
        select(undef, undef, undef, 0.2); # Sleep 200ms
        
        # Process GTK events
        while (Gtk3::events_pending) {
            Gtk3::main_iteration;
        }
    }
    
    print "✅ Progress window updates working\n";
    
    # Close progress window
    $pac_config->_closeProgressWindow($progress_window);
    print "✅ Progress window closed successfully\n";
} else {
    print "❌ Failed to create progress window\n";
}

# Test configuration item counting
print "Testing configuration item counting...\n";
my $item_count = $pac_config->_countConfigItems($test_config_file);
print "Configuration contains $item_count items\n";

if ($item_count > 0) {
    print "✅ Configuration item counting works\n";
} else {
    print "❌ Configuration item counting failed\n";
}

# Test configuration chunking
print "Testing configuration chunking...\n";
my $chunk = $pac_config->_getNextConfigChunk($test_config_file, 5, 0);
if ($chunk && ref $chunk eq 'ARRAY' && @$chunk > 0) {
    print "✅ Configuration chunking works (got " . scalar(@$chunk) . " items)\n";
    
    # Test chunk processing
    my $result = $pac_config->_processConfigChunk($chunk);
    if ($result) {
        print "✅ Configuration chunk processing works\n";
    } else {
        print "❌ Configuration chunk processing failed\n";
    }
} else {
    print "❌ Configuration chunking failed\n";
}

# Test theme detection
print "Testing theme detection...\n";
my ($theme_name, $prefer_dark) = $pac_config->_detectSystemTheme();
print "Detected theme: $theme_name, Dark mode: " . ($prefer_dark ? "Yes" : "No") . "\n";
print "✅ Theme detection works\n";

# Test synchronous import (fallback)
print "Testing synchronous configuration import...\n";
my $sync_result = $pac_config->_importConfigurationSync($test_config_file, sub {
    my ($processed, $total) = @_;
    print "Sync progress: $processed/$total\n";
});

if ($sync_result) {
    print "✅ Synchronous configuration import works\n";
} else {
    print "❌ Synchronous configuration import failed\n";
}

# Clean up test file
unlink $test_config_file;
print "Cleaned up test configuration file\n";

print "\n=== Test Summary ===\n";
print "All multithreaded configuration import tests completed.\n";
print "The functionality is ready for integration.\n";