#!/usr/bin/env perl

# Test script for the dependency checker function
use strict;
use warnings;

# Mock self object for testing
my $self = {};

sub _checkDependencies {
    my $self = shift;
    
    print STDERR "INFO: Checking system dependencies...\n";
    
    # Define tools with their installation hints
    my %tools = (
        'xfreerdp' => {
            'description' => 'FreeRDP client for RDP connections',
            'install_hint' => 'freerdp2-wayland or freerdp-x11',
            'critical' => 0
        },
        'rdesktop' => {
            'description' => 'Alternative RDP client',
            'install_hint' => 'rdesktop',
            'critical' => 0
        },
        'vncviewer' => {
            'description' => 'VNC viewer client',
            'install_hint' => 'tigervnc-viewer or xtightvncviewer',
            'critical' => 0
        },
        'ssh' => {
            'description' => 'SSH client for secure connections',
            'install_hint' => 'openssh-client',
            'critical' => 1
        },
        'mosh' => {
            'description' => 'Mobile shell for unstable connections',
            'install_hint' => 'mosh',
            'critical' => 0
        },
        'telnet' => {
            'description' => 'Telnet client for legacy connections',
            'install_hint' => 'telnet',
            'critical' => 0
        },
        'ftp' => {
            'description' => 'FTP client for file transfers',
            'install_hint' => 'ftp',
            'critical' => 0
        },
        'cu' => {
            'description' => 'Serial connection utility',
            'install_hint' => 'cu or uucp',
            'critical' => 0
        }
    );
    
    my $missing_critical = 0;
    my $missing_optional = 0;
    
    foreach my $tool (sort keys %tools) {
        my $available = system("which $tool >/dev/null 2>&1") == 0;
        
        if ($available) {
            print STDERR "✅ $tool: Available ($tools{$tool}{'description'})\n";
        } else {
            if ($tools{$tool}{'critical'}) {
                print STDERR "❌ $tool: Missing (CRITICAL) - $tools{$tool}{'description'}\n";
                print STDERR "   Install with: $tools{$tool}{'install_hint'}\n";
                $missing_critical++;
            } else {
                print STDERR "⚠️  $tool: Missing (optional) - $tools{$tool}{'description'}\n";
                print STDERR "   Install with: $tools{$tool}{'install_hint'}\n";
                $missing_optional++;
            }
        }
    }
    
    # Summary
    if ($missing_critical > 0) {
        print STDERR "WARNING: $missing_critical critical tool(s) missing. Some features may not work.\n";
    }
    if ($missing_optional > 0) {
        print STDERR "INFO: $missing_optional optional tool(s) missing. Install them for full functionality.\n";
    }
    if ($missing_critical == 0 && $missing_optional == 0) {
        print STDERR "INFO: All dependency checks passed successfully.\n";
    }
    
    return 1;
}

# Test the function
print "Testing dependency checker...\n";
_checkDependencies($self);
print "Test completed.\n";