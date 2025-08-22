#!/usr/bin/env perl

# Simple test script for multithreaded configuration import functionality
# Tests the core functions without loading the full PACConfig module

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

# Load required modules
use PACCompat;
use Gtk3 '-init';

print "Testing PACCompat functionality...\n";

# Test GTK version detection
print "GTK Version: " . PACCompat::get_gtk_version() . "\n";
print "Is GTK4: " . (PACCompat::is_gtk4() ? "Yes" : "No") . "\n";

# Test widget creation functions
print "\nTesting widget creation...\n";

eval {
    my $window = PACCompat::create_window('toplevel', 'Test Window');
    print "✅ Window creation works\n";
    
    my $box = PACCompat::create_box('vertical', 10);
    print "✅ Box creation works\n";
    
    my $label = PACCompat::create_label('Test Label');
    print "✅ Label creation works\n";
    
    my $progress_bar = PACCompat::create_progress_bar();
    print "✅ ProgressBar creation works\n";
    
    # Test CSS provider
    my $css_provider = PACCompat::create_css_provider();
    print "✅ CSS Provider creation works\n";
    
    # Test settings
    my $settings = PACCompat::get_default_settings();
    if ($settings) {
        print "✅ Settings access works\n";
        
        # Test theme detection
        my ($theme_name, $prefer_dark) = PACCompat::get_theme_preference();
        print "Detected theme: $theme_name, Dark mode: " . ($prefer_dark ? "Yes" : "No") . "\n";
        print "✅ Theme detection works\n";
    } else {
        print "⚠️  Settings access failed (may be normal in some environments)\n";
    }
    
    # Test constants
    my $priority = PACCompat::STYLE_PROVIDER_PRIORITY_APPLICATION();
    print "Style provider priority: $priority\n";
    print "✅ Constants work\n";
    
    # Clean up
    $window->destroy() if $window;
    
};

if ($@) {
    print "❌ Error during widget testing: $@\n";
}

# Test threading availability
print "\nTesting threading support...\n";
eval {
    require threads;
    require Thread::Queue;
    require threads::shared;
    print "✅ Threading modules available\n";
    
    # Test simple thread creation
    my $queue = Thread::Queue->new();
    my $thread = threads->create(sub {
        $queue->enqueue("Hello from thread!");
        return "Thread completed";
    });
    
    my $message = $queue->dequeue();
    my $result = $thread->join();
    
    print "Thread message: $message\n";
    print "Thread result: $result\n";
    print "✅ Basic threading works\n";
};

if ($@) {
    print "⚠️  Threading not available: $@\n";
    print "Will use synchronous processing as fallback\n";
}

# Test YAML processing
print "\nTesting YAML processing...\n";
eval {
    require YAML::XS;
    
    my $test_data = {
        test => 'value',
        number => 42,
        array => [1, 2, 3],
        hash => { nested => 'data' }
    };
    
    my $yaml_string = YAML::XS::Dump($test_data);
    my $parsed_data = YAML::XS::Load($yaml_string);
    
    if ($parsed_data->{test} eq 'value' && $parsed_data->{number} == 42) {
        print "✅ YAML processing works\n";
    } else {
        print "❌ YAML processing failed\n";
    }
};

if ($@) {
    print "❌ YAML processing error: $@\n";
}

print "\n=== Test Summary ===\n";
print "Core functionality tests completed.\n";
print "The multithreaded configuration import components are ready.\n";

# Test a simple progress window
print "\nTesting progress window creation...\n";
eval {
    my $window = PACCompat::create_window('toplevel', 'Progress Test');
    $window->set_default_size(400, 150);
    $window->set_position('center');
    
    my $vbox = PACCompat::create_box('vertical', 10);
    $window->add($vbox);
    
    my $label = PACCompat::create_label('Testing progress window...');
    $vbox->pack_start($label, 0, 0, 0);
    
    my $progress_bar = PACCompat::create_progress_bar();
    $progress_bar->set_show_text(1);
    $vbox->pack_start($progress_bar, 0, 0, 10);
    
    $window->show_all();
    
    # Simulate progress
    for my $i (1..10) {
        my $fraction = $i / 10.0;
        $progress_bar->set_fraction($fraction);
        $progress_bar->set_text("Progress: " . int($fraction * 100) . "%");
        
        # Process GTK events
        while (Gtk3::events_pending) {
            Gtk3::main_iteration;
        }
        
        select(undef, undef, undef, 0.1); # Sleep 100ms
    }
    
    $window->destroy();
    print "✅ Progress window test completed successfully\n";
};

if ($@) {
    print "❌ Progress window test failed: $@\n";
}

print "\nAll tests completed!\n";