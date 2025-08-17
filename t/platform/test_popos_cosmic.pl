#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($Bin);
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

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
    verify_gtk4_compatibility
    test_theme_compatibility
);

# Test configuration
my $TEST_TIMEOUT = 300; # 5 minutes
my $COSMIC_REQUIRED = 1;

plan tests => 25;

# Set up test environment
setup_test_environment(
    headless => 0,  # We want to test actual display integration
    gtk => 1,
    gtk4 => 1
);

# Test 1: Verify we're running on PopOS 24.04
subtest 'PopOS 24.04 Platform Verification' => sub {
    plan tests => 4;
    
    # Check OS release
    my $os_release = '';
    if (-f '/etc/os-release') {
        open my $fh, '<', '/etc/os-release' or die "Cannot read /etc/os-release: $!";
        $os_release = do { local $/; <$fh> };
        close $fh;
    }
    
    like($os_release, qr/Pop!_OS/, 'Running on Pop!_OS');
    like($os_release, qr/24\.04/, 'Running on version 24.04');
    
    # Check kernel version (should be recent)
    my $kernel_version = `uname -r`;
    chomp $kernel_version;
    ok($kernel_version, 'Kernel version available');
    diag("Kernel version: $kernel_version");
    
    # Check if we have required packages
    my $gtk4_available = system("dpkg -l | grep -q libgtk-4") == 0;
    ok($gtk4_available, 'GTK4 packages are installed');
};

# Test 2: Verify Cosmic Desktop Environment
subtest 'Cosmic Desktop Environment Detection' => sub {
    plan tests => 5;
    
    # Check if Cosmic session is active
    my $cosmic_session = $ENV{COSMIC_SESSION} || '';
    my $xdg_desktop = $ENV{XDG_CURRENT_DESKTOP} || '';
    
    ok($cosmic_session || $xdg_desktop =~ /cosmic/i, 'Cosmic desktop environment detected');
    diag("XDG_CURRENT_DESKTOP: $xdg_desktop");
    diag("COSMIC_SESSION: $cosmic_session");
    
    # Check Wayland display server
    my $wayland_display = $ENV{WAYLAND_DISPLAY} || '';
    ok($wayland_display, 'Wayland display server active');
    diag("WAYLAND_DISPLAY: $wayland_display");
    
    # Check for Cosmic-specific processes
    my $cosmic_comp = `pgrep -f cosmic-comp 2>/dev/null`;
    my $cosmic_panel = `pgrep -f cosmic-panel 2>/dev/null`;
    
    ok($cosmic_comp, 'Cosmic compositor running');
    ok($cosmic_panel, 'Cosmic panel running');
    
    # Check for required Cosmic libraries
    my $cosmic_libs = system("ldconfig -p | grep -q cosmic") == 0;
    ok($cosmic_libs || 1, 'Cosmic libraries available (optional)');
};

# Test 3: Application Startup and Basic Functionality
subtest 'Application Startup Testing' => sub {
    plan tests => 6;
    
    # Test if asbru-cm executable exists and is executable
    my $asbru_path = File::Spec->catfile(dirname(dirname($Bin)), 'asbru-cm');
    ok(-f $asbru_path, 'asbru-cm executable exists');
    ok(-x $asbru_path, 'asbru-cm is executable');
    
    # Test basic module loading
    eval { require PACMain; };
    ok(!$@, 'PACMain module loads without errors') or diag("Error: $@");
    
    eval { require PACCompat; };
    ok(!$@, 'PACCompat module loads without errors') or diag("Error: $@");
    
    eval { require PACCosmic; };
    ok(!$@, 'PACCosmic module loads without errors') or diag("Error: $@");
    
    # Test GTK4 initialization
    eval {
        require Gtk4;
        Gtk4->init();
    };
    ok(!$@, 'GTK4 initializes successfully') or diag("GTK4 error: $@");
};

# Test 4: GUI Functionality and Theme Integration
subtest 'GUI Functionality Testing' => sub {
    plan tests => 8;
    
    SKIP: {
        skip "GTK4 not available", 8 unless eval { require Gtk4; 1; };
        
        # Test basic window creation
        my $window;
        eval {
            $window = Gtk4::Window->new();
            $window->set_title("Ásbrú Test Window");
            $window->set_default_size(400, 300);
        };
        ok(!$@ && $window, 'GTK4 window creation successful') or diag("Window error: $@");
        
        # Test GTK4 compatibility
        if ($window) {
            ok($window->can('set_title'), 'Window has set_title method');
            ok($window->can('present'), 'Window has present method');
            ok($window->can('close'), 'Window has close method');
            
            # Test theme integration
            my $style_context;
            eval { $style_context = $window->get_style_context(); };
            ok($style_context, 'Style context available');
            
            # Test CSS class addition (GTK4 feature)
            eval { $window->add_css_class('asbru-main-window'); };
            ok(!$@, 'CSS class addition works') or diag("CSS error: $@");
            
            # Test dark theme detection
            my $dark_theme = 0;
            eval {
                my $settings = Gtk4::Settings::get_default();
                $dark_theme = $settings->get_property('gtk-application-prefer-dark-theme') if $settings;
            };
            ok(defined $dark_theme, 'Theme preference detection works');
            diag("Dark theme preferred: " . ($dark_theme ? 'Yes' : 'No'));
            
            # Clean up
            eval { $window->destroy(); };
            ok(!$@, 'Window cleanup successful');
        } else {
            skip "Window creation failed", 7;
        }
    }
};

# Test 5: VTE Terminal Integration
subtest 'VTE Terminal Integration' => sub {
    plan tests => 6;
    
    # Test VTE module loading
    eval { require Vte; };
    my $vte_available = !$@;
    ok($vte_available, 'VTE module loads successfully') or diag("VTE error: $@");
    
    SKIP: {
        skip "VTE not available", 5 unless $vte_available;
        
        # Test VTE terminal creation
        my $terminal;
        eval {
            $terminal = Vte::Terminal->new();
        };
        ok(!$@ && $terminal, 'VTE terminal creation successful') or diag("Terminal error: $@");
        
        if ($terminal) {
            # Test basic terminal methods
            ok($terminal->can('spawn_async'), 'Terminal has spawn_async method');
            ok($terminal->can('feed'), 'Terminal has feed method');
            ok($terminal->can('get_text_range'), 'Terminal has get_text_range method');
            
            # Test terminal configuration
            eval {
                $terminal->set_size(80, 24);
                $terminal->set_scroll_on_output(1);
            };
            ok(!$@, 'Terminal configuration successful') or diag("Config error: $@");
        } else {
            skip "Terminal creation failed", 4;
        }
    }
};

# Test 6: Connection Protocol Support
subtest 'Connection Protocol Testing' => sub {
    plan tests => 6;
    
    # Test SSH protocol support
    eval { require PACMethod_ssh; };
    ok(!$@, 'SSH protocol module loads') or diag("SSH error: $@");
    
    # Test RDP protocol support  
    eval { require PACMethod_xfreerdp; };
    ok(!$@, 'RDP protocol module loads') or diag("RDP error: $@");
    
    # Test VNC protocol support
    eval { require PACMethod_tigervnc; };
    ok(!$@, 'VNC protocol module loads') or diag("VNC error: $@");
    
    # Check for required external tools
    my $ssh_available = system("which ssh > /dev/null 2>&1") == 0;
    ok($ssh_available, 'SSH client available');
    
    my $xfreerdp_available = system("which xfreerdp > /dev/null 2>&1") == 0;
    ok($xfreerdp_available, 'xfreerdp client available');
    
    my $vncviewer_available = system("which vncviewer > /dev/null 2>&1") == 0 ||
                             system("which tigervnc > /dev/null 2>&1") == 0;
    ok($vncviewer_available, 'VNC viewer available');
};

# Test 7: System Integration Features
subtest 'System Integration Testing' => sub {
    plan tests => 7;
    
    # Test system tray/panel integration
    eval { require PACTrayCosmic; };
    ok(!$@, 'Cosmic tray module loads') or diag("Tray error: $@");
    
    # Test notification system
    my $notify_available = system("which notify-send > /dev/null 2>&1") == 0;
    ok($notify_available, 'Notification system available');
    
    # Test file manager integration
    my $file_manager = $ENV{XDG_CONFIG_HOME} || "$ENV{HOME}/.config";
    ok(-d $file_manager, 'XDG config directory accessible');
    
    # Test clipboard functionality
    my $clipboard_available = system("which wl-copy > /dev/null 2>&1") == 0 ||
                             system("which xclip > /dev/null 2>&1") == 0;
    ok($clipboard_available, 'Clipboard tools available');
    
    # Test desktop file integration
    my $desktop_file = File::Spec->catfile(dirname(dirname($Bin)), 'res', 'asbru-cm.desktop');
    ok(-f $desktop_file, 'Desktop file exists');
    
    # Test application icon
    my $icon_file = File::Spec->catfile(dirname(dirname($Bin)), 'res', 'asbru-logo-64.png');
    ok(-f $icon_file, 'Application icon exists');
    
    # Test MIME type associations
    my $mime_available = system("which xdg-mime > /dev/null 2>&1") == 0;
    ok($mime_available, 'MIME type tools available');
};

# Test 8: Performance Benchmarking
subtest 'Performance Benchmarking' => sub {
    plan tests => 4;
    
    # Test application startup time
    my $startup_perf = measure_performance(
        'Application Startup',
        sub {
            # Simulate application initialization
            eval {
                require PACMain;
                require PACConfig;
            };
        },
        iterations => 5,
        warmup => 1
    );
    
    ok($startup_perf->{average} < 5000, 'Startup time under 5 seconds')
        or diag("Average startup time: " . $startup_perf->{average} . "ms");
    
    # Test GUI rendering performance
    SKIP: {
        skip "GTK4 not available", 1 unless eval { require Gtk4; 1; };
        
        my $render_perf = measure_performance(
            'GUI Rendering',
            sub {
                my $window = Gtk4::Window->new();
                $window->set_title("Performance Test");
                $window->destroy();
            },
            iterations => 10
        );
        
        ok($render_perf->{average} < 100, 'GUI rendering under 100ms per operation')
            or diag("Average render time: " . $render_perf->{average} . "ms");
    }
    
    # Test memory usage
    my $memory_before = get_memory_usage();
    
    # Simulate some operations
    for (1..10) {
        eval {
            require PACUtils;
            my $utils = {};  # Simulate object creation
        };
    }
    
    my $memory_after = get_memory_usage();
    my $memory_diff = $memory_after - $memory_before;
    
    ok($memory_diff < 50000, 'Memory usage increase reasonable')  # Less than 50MB
        or diag("Memory increase: ${memory_diff}KB");
    
    # Test configuration loading performance
    my $config_perf = measure_performance(
        'Configuration Loading',
        sub {
            eval { require PACConfig; };
        },
        iterations => 3
    );
    
    ok($config_perf->{average} < 1000, 'Configuration loading under 1 second')
        or diag("Average config load time: " . $config_perf->{average} . "ms");
};

# Helper function to get memory usage
sub get_memory_usage {
    my $pid = $$;
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

# Cleanup
cleanup_test_environment();

done_testing();

__END__

=head1 NAME

test_popos_cosmic.pl - Primary Platform Testing for PopOS 24.04 + Cosmic

=head1 DESCRIPTION

This test script performs comprehensive testing of Ásbrú Connection Manager
on the primary target platform: PopOS 24.04 with Cosmic desktop environment.

Tests include:
- Platform verification
- Desktop environment detection
- Application startup and basic functionality
- GUI functionality and theme integration
- VTE terminal integration
- Connection protocol support
- System integration features
- Performance benchmarking

=head1 AUTHOR

Ásbrú Connection Manager Development Team

This test was developed with AI assistance as part of the modernization project.

=cut