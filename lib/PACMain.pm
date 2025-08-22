package PACMain;

###############################################################################
# This file is part of Ásbrú Connection Manager
#
# Copyright (C) 2017-2022 Ásbrú Connection Manager team (https://asbru-cm.net)
# Copyright (C) 2010-2016 David Torrejón Vaquerizas
# Copyright (C) 2025 Anton Isaiev totoshko88@gmail.com
#
# Ásbrú Connection Manager is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ásbrú Connection Manager is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License version 3
# along with Ásbrú Connection Manager.
# If not, see <http://www.gnu.org/licenses/gpl-3.0.html>.
###############################################################################

# AI-ASSISTED MODERNIZATION NOTE: This file has been modified with AI assistance
# as part of the Ásbrú Connection Manager v7.0.0 modernization project.
# Key AI-assisted changes include:
# - GTK4 compatibility integration via PACCompat module
# - Modern cryptography integration via PACCryptoCompat
# - Wayland display server support
# - Updated VTE terminal emulation
# - Enhanced desktop environment detection and integration
# All changes have been thoroughly tested and validated by human developers.

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

use FindBin qw ($RealBin $Bin $Script);
my $REALBIN = $RealBin;
use lib "$RealBin/lib", "$RealBin/lib/ex";

# Standard
use strict;
use warnings;
use YAML qw (LoadFile DumpFile);
use Storable qw (thaw dclone nstore retrieve);
use Encode;
use File::Copy;
use Net::Ping;
use OSSP::uuid;
use POSIX ":sys_wait_h";
use POSIX qw (strftime);
use Scalar::Util qw(blessed);
use PACCryptoCompat;
use SortedTreeStore;
use PACVte;  # Modern VTE compatibility layer
my $HAVE_VTE = $PACVte::HAVE_VTE;
use PACIcons;  # Modern symbolic icon mapping

use Config;

# GTK - AI-assisted modernization: Updated for GTK3/GTK4 compatibility
use PACCompat;

# PAC modules
use PACUtils;
use PACTray;
use PACTerminal;
use PACEdit;
use PACConfig;
use PACCluster;
use PACScreenshots;
use PACStatistics;
use PACTree;
use PACPipe;
use PACScripts;
use PACWidgetSafety;

# END: Import Modules
###################################################################

###################################################################
# Define GLOBAL CLASS variables

my $APPNAME = $PACUtils::APPNAME;
my $APPVERSION = $PACUtils::APPVERSION;
my $AUTOSTART_FILE = "$RealBin/res/asbru_start.desktop";
my $RES_DIR = "$RealBin/res";

# Register icons on Gtk
#&_registerPACIcons;

my $VENDOR_CFG_FILE = "$RealBin/vendor/asbru-conf-default-overrides.yml";
my $INIT_CFG_FILE = "$RealBin/res/asbru.yml";
my $CFG_DIR = $ENV{"ASBRU_CFG"};
my $CFG_FILE = "$CFG_DIR/asbru.yml";
my $THEME_DIR = "$RES_DIR/themes/default"; # internal assets
our $R_CFG_FILE = '';
my $CFG_FILE_FREEZE = "$CFG_DIR/asbru.freeze";
my $CFG_FILE_NFREEZE = "$CFG_DIR/asbru.nfreeze";
my $CFG_FILE_DUMPER = "$CFG_DIR/asbru.dumper";

my $PAC_START_PROGRESS = 0;
my $PAC_START_TOTAL = 6;
my $APP_START_TIME = time();

my $APPICON = "$RES_DIR/asbru-logo-64.png";
my $AUTOCLUSTERICON;
my $CLUSTERICON;
my $GROUPICON_ROOT;
my $GROUPICON;
my $GROUPICONOPEN;
my $GROUPICONCLOSED;
my $DEFCONNICON; # Default individual connection icon (fallback when a connection lacks its own icon)

my $CHECK_VERSION = 0;
my $NEW_VERSION = 0;
my $NEW_CHANGES = '';
our $_NO_SPLASH = 0;
# Modern cryptographic system - AI-assisted modernization 2024
my $CIPHER = PACCryptoCompat->new(-key => 'PAC Manager (David Torrejon Vaquerizas, david.tv@gmail.com)', -migration => 1) or die "ERROR: Failed to initialize crypto system";
# Legacy salt constant for compatibility
my $SALT = '12345678';

our $UNITY = 0; # Are we in a Unity environment?
our $COSMIC = 0; # Are we in a Cosmic desktop environment? (AI-assisted modernization)
our $STRAY = 1; # Are we using a system tray icon?
our $DESKTOP_LOGGED = 0; # Guard to avoid duplicate desktop detection log lines
our $START_CALLS = 0;     # Count invocations of start()
our $STARTED = 0;         # Latch to prevent double initialization

our %RUNNING;
our %FUNCS;
our %SOCKS5PORTS;
my @SELECTED_UUIDS;
my $LAST_COPIED_NODES;
# END: Define GLOBAL CLASS variables
###################################################################

###################################################################
# START: Define PUBLIC CLASS methods

sub new {
    my $class = shift;
    my @argv = @_;

    my $self = {};

    print STDERR "INFO: Config directory is '$CFG_DIR'\n";

    $SIG{'TERM'} = $SIG{'STOP'} = $SIG{'QUIT'} = $SIG{'INT'} = sub {
        print STDERR "INFO: Signal '$_[0]' received. Exiting Ásbrú...\n";
        _quitProgram($self, 'force');
        exit 0;
    };

    $self->{_CFG} = {};
    @{ $self->{_OPTS} } = @argv;
    $self->{_PREVTAB} = 0;

    $self->{_GUI} = undef;
    $self->{_PACTABS} = undef;
    $self->{_TABSINWINDOW} = 0;
    $self->{_COPY}{'data'} = {};
    $self->{_COPY}{'cut'} = 0;
    $self->{_UPDATING} = 0;
    $self->{_CMDLINETRAY} = 0;
    $self->{_SHOWFINDTREE} = 0;
    $self->{_READONLY} = 0;
    $self->{_HAS_FOCUS} = '';
    $self->{_VERBOSE} = 0;
    $self->{_Vte} = undef;

    @{ $self->{_UNDO} } = ();
    $$self{_GUILOCKED} = 0;

    # Create application & register it
    # This will let us know if another Ásbrú instance is running
    $self->{_APP} = Gtk3::Application->new('org.asbru-cm.main', 'handles-open');
    if (!$self->{_APP}->register()) {
        print("ERROR: Failed to register Gtk3 application.\n");
        exit 0;
    }

    $_NO_SPLASH = grep({ /^(--no-splash)|(--list-uuids)|(--dump-uuid)/go } @{ $$self{_OPTS} });
    $_NO_SPLASH ||= $$self{_APP}->get_is_remote;

    # Show splash-screen while loading
    PACUtils::_splash(1, "Starting $PACUtils::APPNAME (v$PACUtils::APPVERSION)", ++$PAC_START_PROGRESS, $PAC_START_TOTAL);
    $self->{_START_TS} = time;
    $self->{_PROFILE} = [];
    push @{$self->{_PROFILE}}, sprintf('[%0.3f] start:new()', 0.0);

    $self->{_PING} = Net::Ping->new('tcp');
    $self->{_PING}->tcp_service_check(1);

    if (grep({ /^--verbose$/ } @{ $$self{_OPTS} })) {
        $$self{_VERBOSE} = 1;
    }

    # Show some info about dependencies
    if ($$self{_VERBOSE}) {
        print STDERR "INFO: Crypt::CBC version is ${Crypt::CBC::VERSION}\n";
        _checkDependencies($self);
    }

    # Read the config/connections file...
    PACUtils::_splash(1, "Reading config...", ++$PAC_START_PROGRESS, $PAC_START_TOTAL);
    my $t0 = time; _readConfiguration($self); my $dt = time - $t0; push @{$self->{_PROFILE}}, sprintf('[%0.3f] config loaded', $dt);

    # Set conflictive layout options as early as possible
    my $t1=time; _setSafeLayoutOptions($self,$$self{_CFG}{'defaults'}{'layout'}); push @{$self->{_PROFILE}}, sprintf('[%0.3f] safe layout options', time-$t1);

    # Test Vte Capabilities
    my $t2=time; _setVteCapabilities($self); push @{$self->{_PROFILE}}, sprintf('[%0.3f] vte capabilities', time-$t2);

    # If VTE missing, enforce safe transparency defaults to avoid UI glitches
    if (!$$self{_Vte}) {
        my $d = $$self{_CFG}{defaults} ||= {};
        if (($d->{'terminal support transparency'} // 0) || ($d->{'terminal transparency'} // 0)) {
            $d->{'terminal support transparency'} = 0;
            $d->{'terminal transparency'} = 0;
        }
    }

    if ($$self{_CFG}{'defaults'}{'theme'}) {
        my $cfg_theme = $$self{_CFG}{'defaults'}{'theme'} // 'default';
        if ($cfg_theme =~ /^(asbru-dark|asbru-color|default)$/) {
            $THEME_DIR = "$RES_DIR/themes/$cfg_theme";
            eval { require PACIcons; PACIcons::set_theme_dir($THEME_DIR, force => ($ENV{ASBRU_FORCE_ICON_RESCAN}?1:0)); };
        } elsif ($cfg_theme eq 'system') {
            # System theme: we don't force an override; if user supplied one we defer apply, else we let GTK pick current desktop icon theme
            if (my $sys_theme = $$self{_CFG}{'defaults'}{'system icon theme override'}) {
                $$self{_DEFER_SYSTEM_ICON_THEME} = $sys_theme; # apply later (realized)
            }
            # For internal-only icons still need default assets
            $THEME_DIR = "$RES_DIR/themes/default";
            eval { require PACIcons; PACIcons::set_theme_dir($THEME_DIR, force => ($ENV{ASBRU_FORCE_ICON_RESCAN}?1:0)); };
        } else {
            # Unknown -> fallback
            $THEME_DIR = "$RES_DIR/themes/default";
            eval { require PACIcons; PACIcons::set_theme_dir($THEME_DIR, force => ($ENV{ASBRU_FORCE_ICON_RESCAN}?1:0)); };
        }
    }
    $$self{_THEME} = $THEME_DIR;
    # Capture GUI builder reference early when available (preferences & refresh use it)
    $$self{_GUI_BUILDER} ||= $$self{_GUI}{builder} if eval { $$self{_GUI}{builder} };
    print STDERR "INFO: Theme directory is '$$self{_THEME}'\n";
    if ($$self{_VERBOSE}) { print STDERR "DIAG: Startup profile so far -> " . join(' | ', @{$self->{_PROFILE}}) . "\n"; }

    # _registerPACIcons($THEME_DIR); # Removed - will be restored in PACUtils.pm
    $AUTOCLUSTERICON = _pixBufFromFile("$THEME_DIR/asbru_cluster_auto.png");
    $CLUSTERICON = _pixBufFromFile("$THEME_DIR/asbru_cluster_connection.svg");
    # Scale root group icon to 16x16 to match other group icons
    my $root_pixbuf = _pixBufFromFile("$THEME_DIR/asbru_group.svg");
    $GROUPICON_ROOT = $root_pixbuf ? $root_pixbuf->scale_simple(16, 16, 'hyper') : _pixBufFromFile("$THEME_DIR/asbru_group_open_16x16.svg");
    $GROUPICON = _pixBufFromFile("$THEME_DIR/asbru_group_open_16x16.svg");
    $GROUPICONOPEN = _pixBufFromFile("$THEME_DIR/asbru_group_open_16x16.svg");
    $GROUPICONCLOSED = _pixBufFromFile("$THEME_DIR/asbru_group_closed_16x16.svg");
    # Try preferred themed connection icon; fallback to cluster connection icon if missing
    if (-f "$THEME_DIR/asbru_quick_connect.svg") {
        my $def_pixbuf = _pixBufFromFile("$THEME_DIR/asbru_quick_connect.svg");
        $DEFCONNICON = $def_pixbuf ? $def_pixbuf->scale_simple(16, 16, 'hyper') : $CLUSTERICON;
    } else {
        my $cluster_pixbuf = $CLUSTERICON;
        $DEFCONNICON = $cluster_pixbuf ? $cluster_pixbuf->scale_simple(16, 16, 'hyper') : $cluster_pixbuf;
    }

    map({
    if (/^--dump-uuid=(.+)$/) {
        require Data::Dumper;
        print Data::Dumper::Dumper($$self{_CFG}{environments}{$1});
        exit 0;
    } } @{ $$self{_OPTS} });

    # Option --list-uuids, list uuids and exit

    if (grep({ /^--list-uuids$/ } @{ $$self{_OPTS} })) {
        print '-'x36 . '|' . '-'x36 . '|' . '-'x5 . '|' . '-'x15 . '|' . '-'x21 . "\n";
        printf "%36s|%36s|%5s|%15s|%s\n", 'UUID', 'PARENT_UUID', 'TYPE', 'METHOD', 'NAME';
        print '-'x36 . '|' . '-'x36 . '|' . '-'x5 . '|' . '-'x15 . '|' . '-'x21 . "\n";
        foreach my $uuid (keys %{ $$self{_CFG}{environments} }) {
            if ((!defined $$self{_CFG}{environments}{$uuid}{name})||($uuid eq '__PAC_SHELL__')) {
                next;
            }
            print "$uuid|";
            printf "%36s|", $$self{_CFG}{environments}{$uuid}{parent};
            printf "%5s|", ($$self{_CFG}{environments}{$uuid}{_is_group} ? 'GROUP' : '');
            printf "%15s|", (defined $$self{_CFG}{environments}{$uuid}{method} ? "$$self{_CFG}{environments}{$uuid}{method}" : '');
            printf "%s\n", $$self{_CFG}{environments}{$uuid}{name};
        }
        print '-'x36 . '|' . '-'x36 . '|' . '-'x5 . '|' . '-'x15 . '|' . '-'x21 . "\n";
        exit 0;
    }

    # Start iconified is option set or command line option --iconified
    if (($$self{_CFG}{defaults}{'start iconified'}) || (grep({ /^--iconified$/ } @{ $$self{_OPTS} }))) {
        $$self{_CMDLINETRAY} = 1;
    }

    # Check if startup password is required and validate

    if ($$self{_CFG}{'defaults'}{'use gui password'}) {
        my $pass;
        grep({ if (/^--password=(.+)$/) { $pass = $1; } } @{ $$self{_OPTS} });
        if (!defined $pass) {
            PACUtils::_splash(1, "Waiting for password...", $PAC_START_PROGRESS, $PAC_START_TOTAL);
            $pass = _wEnterValue(undef, 'GUI Password Protection', 'Please, enter GUI Password...', undef, 0, 'asbru-protected');
        }
        if (!defined $pass) {
            exit 0;
        }
        if (!$CIPHER->salt()) {
            $CIPHER->salt(pack('Q',$SALT));
        }
        if ($pass ne $CIPHER->decrypt_hex($$self{_CFG}{'defaults'}{'gui password'})) {
            _wMessage(undef, 'ERROR: Wrong password!!');
            exit 0;
        }
    }

    # Check if only one instance is allowed

    if ($$self{_APP}->get_is_remote()) {
        print "INFO: Ásbrú is already running.\n";

        my $getout = 0;
        my $uuid;
        if (grep { /--start-shell/; } @{ $$self{_OPTS} }) {
            _sendAppMessage($$self{_APP}, 'start-shell');
            $getout = 1;
        } elsif (grep { /--quick-conn/; } @{ $$self{_OPTS} }) {
            _sendAppMessage($$self{_APP}, 'quick-conn');
            $getout = 1;
        } elsif (grep { /--start-uuid=(.+)/ and $uuid = $1; } @{ $$self{_OPTS} }) {
            _sendAppMessage($$self{_APP}, 'start-uuid', $uuid);
            $getout = 1;
        } elsif (grep { /--edit-uuid=(.+)/ and $uuid = $1; } @{ $$self{_OPTS} }) {
            _sendAppMessage($$self{_APP}, 'edit-uuid', $uuid);
            $getout = 1;
        } else {
            $getout = 0;
        }

        if (! $getout) {
            if ($$self{_CFG}{'defaults'}{'allow more instances'}) {
                print "INFO: Starting '$0' in READ ONLY mode!\n";
                $$self{_READONLY} = 1;
            } elsif (! $$self{_CFG}{'defaults'}{'allow more instances'}) {
                print "INFO: No more instances allowed!\n";
            eval {
                if ($self->{_TRAY} && $self->{_TRAY}->can('get_integration_mode')) {
                    my $mode = $self->{_TRAY}->get_integration_mode();
                    print "INFO: Tray integration mode active: $mode\n";
                }
            };
                return 0;
            }
        } else {
            Gtk3::Gdk::notify_startup_complete();
            return 0;
        }
    }

    if (grep(/^--readonly$/, @{ $$self{_OPTS} })) {
        print "INFO: Starting '$0' in READ ONLY mode!\n";
        $$self{_READONLY} = 1;
    }

    # Gtk style
    my $css_provider = Gtk3::CssProvider->new();
    $css_provider->load_from_path("$THEME_DIR/asbru.css");
    # Guard deprecated Gdk::Screen usage (Wayland/GTK4 forward compatibility)
    eval {
    my $screen = Gtk3::Gdk::Screen::get_default(); # may be undef
        if ($screen) {
            Gtk3::StyleContext::add_provider_for_screen($screen, $css_provider, 600);
            $$self{_THEME_CSS_PROVIDER} = $css_provider; # Store for later replacement
        } else {
            # Fallback: apply provider to a dummy widget so rules cascade
            my $dummy = Gtk3::Window->new();
            $dummy->get_style_context->add_provider($css_provider, 600);
        }
        1;
    } or do { };
    # Load optional modern icon tweaks
    if (-f "$THEME_DIR/modern-icons.css") {
        my $css_icons = Gtk3::CssProvider->new();
        eval { $css_icons->load_from_path("$THEME_DIR/modern-icons.css"); };
        unless ($@) {
            eval {
                my $screen = Gtk3::Gdk::Screen::get_default();
                if ($screen) {
                    Gtk3::StyleContext::add_provider_for_screen($screen, $css_icons, 610);
                } else {
                    my $dummy = Gtk3::Window->new();
                    $dummy->get_style_context->add_provider($css_icons, 610);
                }
                1;
            } or do { };
        }
    }

    # Environment override still wins for quick testing
    if ($ENV{ASBRU_ICON_THEME}) {
        if ((!defined $$self{_CURRENT_SYSTEM_ICON_THEME}) || $$self{_CURRENT_SYSTEM_ICON_THEME} ne $ENV{ASBRU_ICON_THEME}) {
            eval { Gtk3::IconTheme::get_default()->set_custom_theme($ENV{ASBRU_ICON_THEME}); print STDERR "INFO: Icon theme override: $ENV{ASBRU_ICON_THEME} (ASBRU_ICON_THEME)\n"; 1 } or do { print STDERR "WARN: Failed to apply icon theme '$ENV{ASBRU_ICON_THEME}': $@\n" if $@; };
            $$self{_CURRENT_SYSTEM_ICON_THEME} = $ENV{ASBRU_ICON_THEME} if !$@;
        }
    }
    if ($ENV{ASBRU_LARGE_ICONS}) {
        if ($$self{_GUI}{main}) {
            eval { $$self{_GUI}{main}->get_style_context()->add_class('asbru-large-icons'); 1 };
        } else {
            warn "WARN: main window not yet initialized for large icon class (will retry later)" if $ENV{ASBRU_DEBUG};
        }
        print STDERR "INFO: Large icon mode enabled (ASBRU_LARGE_ICONS)\n";
    }
    elsif (my $scale = $ENV{GDK_SCALE}) {
        if ($scale >= 2) {
            if ($$self{_GUI}{main}) {
                eval { $$self{_GUI}{main}->get_style_context()->add_class('asbru-large-icons'); 1 };
            } else {
                warn "WARN: main window not yet initialized for auto large icon class (will retry later)" if $ENV{ASBRU_DEBUG};
            }
            print STDERR "INFO: Auto large icons (GDK_SCALE=$scale)\n";
        }
    }

    # Setup known connection methods
    %{ $$self{_METHODS} } = _getMethods($self,$$self{_THEME});

    # Dynamically load the Tray icon class related to the current environment/settings
    if ($ENV{'ASBRU_DESKTOP'} eq 'unity') {
        print("INFO: Trying to loading Unity specific tray icon package...\n");
        $@ = '';
        $UNITY = 1;
        eval {
            require 'PACTrayUnity.pm';
        };
        if ($@) {
            $UNITY = 0;
        }
    }
    
    # AI-assisted modernization: Add Cosmic desktop detection (with opt-out)
    # NOTE: Actual module loading & object instantiation now deferred to _initGUI via _initCosmicEnvironment
    if ($ENV{ASBRU_DISABLE_COSMIC}) {
        print "INFO: Cosmic integration disabled (ASBRU_DISABLE_COSMIC set)\n";
    } else {
        eval {
            require 'PACCosmic.pm';
            if (PACCosmic::is_cosmic_desktop()) {
                $COSMIC = 1; # defer any logging until start() to keep single detection line
            }
        };
        if ($@) { print "WARNING: Cosmic detection failed: $@\n"; $COSMIC = 0; }
    }

    bless($self, $class);

    if ($$self{_VERBOSE} && $self->{_START_TS}) {
        my $elapsed = time - $self->{_START_TS};
        push @{$self->{_PROFILE}}, sprintf('[%0.3f] total initialization', $elapsed);
        print STDERR "DIAG: Startup profile summary -> " . join(' | ', @{$self->{_PROFILE}}) . "\n";
    }

    return $self;
}

# DESTRUCTOR
sub DESTROY {
    my $self = shift;
    undef $self;
    return 1;
}

# Start GUI and launch connection
sub start {
    my $self = shift;

    $START_CALLS++;
    return 1 if $STARTED; # Prevent double initialization and duplicate logs

    # Re-evaluate desktop environment early and set $COSMIC flag (robust cosmic detection)
    my $detected_de = eval { PACCompat::detect_desktop_environment(1) } || 'unknown';
    $COSMIC = ($detected_de eq 'cosmic') ? 1 : 0;
    # Decide tray availability / messaging only once (avoid duplicate lines across multiple loads)
    if (!$DESKTOP_LOGGED) {
        if ($ENV{'ASBRU_DESKTOP'} =~ /gnome-shell/ && $ENV{'ASBRU_DESKTOP'} !~ /withtray/ && !$UNITY && !$COSMIC) {
            $STRAY = 0;
            print "INFO: Desktop environment detected: $detected_de\n";
            print "INFO: No tray available\n";
        } else {
            print "INFO: Desktop environment detected: $detected_de\n";
            if ($COSMIC) {
                print "INFO: Using Cosmic tray integration (initializing)\n";
            } else {
                print "INFO: Using " . ($UNITY ? 'Unity' : 'Gnome') . " tray icon\n";
            }
        }
    $DESKTOP_LOGGED = 1;
    $ENV{ASBRU_DESKTOP_DETECTED} = 1;
    }

    # Build the GUI (only first invocation reaches here due to $STARTED latch)
    PACUtils::_splash(1, "Building GUI...", ++$PAC_START_PROGRESS, $PAC_START_TOTAL);
    if (!$self->_initGUI()) {
        _splash(0);
        return 0;
    }

    # Build the Tree with the connections list
    PACUtils::_splash(1, "Loading Connections...", ++$PAC_START_PROGRESS, $PAC_START_TOTAL);
    $self->_loadTreeConfiguration('__PAC__ROOT__');

    # Enable tray menu
    $FUNCS{_TRAY}->set_tray_menu();

    PACUtils::_splash(1, "Finalizing...", ++$PAC_START_PROGRESS, $PAC_START_TOTAL);

    $STARTED = 1; # Mark successful initialization

    # Automated test hook: auto-exit after N ms if ASBRU_AUTOTEST is set (avoid manual interaction during integration tests)
    if ($ENV{ASBRU_AUTOTEST} && $ENV{ASBRU_AUTOTEST} =~ /^(\d{2,6})$/) {
        my $delay = $1 + 0;
        Glib::Timeout->add($delay, sub { eval { $self->_quitProgram(); }; return 0; });
        print STDERR "INFO: Auto-test mode: will exit after ${delay}ms (ASBRU_AUTOTEST)\n" if $ENV{ASBRU_DEBUG};
    }

    # Setup callbacks
    $self->_setupCallbacks();

    # If version is lower than current, update and save the new one
    if ($APPVERSION gt $$self{_CFG}{defaults}{version}) {
        $$self{_CFG}{defaults}{version} = $APPVERSION;
        $self->_saveConfiguration();
    }

    # Load information about last expanded groups
    $self->_loadTreeExpanded();

    Gtk3::Gdk::notify_startup_complete();
    Glib::Idle->add(
        sub {
            _splash(0);
            return 0;
        }
    );

    # Show main interface
    if (!$$self{_CMDLINETRAY}) {
        $$self{_GUI}{main}->show_all();
        
        # Start automatic theme monitoring for tree widgets (Task 4.2)
        PACCompat::startTreeThemeMonitoring();
        
        if ($$self{_GUI}{hpane}) {
            my $alloc = $$self{_GUI}{hpane}->get_allocation; my $tw=$alloc->{width}||0; if ($tw>200){ my $pos=int($tw*30/100); $pos = 120 if $pos < 120; eval { $$self{_GUI}{hpane}->set_position($pos); }; }
        }
        # If system icon theme application was deferred, apply now (after realization) to reduce Gtk criticals
        if (defined $$self{_DEFER_SYSTEM_ICON_THEME}) {
            my $sys_theme = delete $$self{_DEFER_SYSTEM_ICON_THEME};
            Glib::Idle->add(sub {
                my $now = time;
                my $skip = 0;
                if (defined $$self{_CURRENT_SYSTEM_ICON_THEME} && $$self{_CURRENT_SYSTEM_ICON_THEME} eq $sys_theme) {
                    if (defined $$self{_LAST_SYSTEM_ICON_THEME_APPLY} && ($now - $$self{_LAST_SYSTEM_ICON_THEME_APPLY}) < 1) { $skip = 1; }
                }
                if (!$skip) {
                    eval { Gtk3::IconTheme::get_default()->set_custom_theme($sys_theme); 1 } or do { print STDERR "WARN: Deferred set_custom_theme($sys_theme) failed: $@\n"; };
                    if (!$@) {
                        $$self{_CURRENT_SYSTEM_ICON_THEME} = $sys_theme;
                        $$self{_LAST_SYSTEM_ICON_THEME_APPLY} = $now;
                        print STDERR "INFO: Applied deferred system icon theme '$sys_theme'\n" if $ENV{ASBRU_DEBUG};
                        eval { $self->_refresh_all_icons(); };
                    }
                }
                return 0;
            });
        }
    }

    # Apply Layout as early as possible
    $self->_ApplyLayout($$self{_CFG}{'defaults'}{'layout'});

    # Autostart selected connections
    my @idx;
    grep({ $$self{_CFG}{'environments'}{$_}{'startup launch'} and push(@idx, [ $_ ]); } keys %{ $$self{_CFG}{'environments'} });
    grep({ if (/^--start-uuid=(.+)$/) { my ($uuid, $clu) = split(':', $1); push(@idx, [ $uuid, undef, $clu // undef ]); } } @{ $$self{_OPTS} });
    $self->_launchTerminals(\@idx) if scalar(@idx);

    # Autostart Shell if so is configured
    if ($$self{_CFG}{'defaults'}{'autostart shell upon PAC start'}) {
        $$self{_GUI}{shellBtn}->clicked();
    }

    $$self{_GUI}{statistics}->update('__PAC__ROOT__', $$self{_CFG});

    # Is tray available (Gnome or Unity)?
    if (!$$self{_CFG}{defaults}{'start iconified'} && !$$self{_CMDLINETRAY}) {
        $$self{_GUI}{main}->present();
    } else {
        $self->_hideConnectionsList();
    }

    # Auto open "Edit" dialog
    foreach my $arg (@{ $$self{_OPTS} }) {
        if ($arg =~ /^--edit-uuid=(.+)$/go) {
            my $uuid = $1;
            my $path = $$self{_GUI}{treeConnections}->_getPath($uuid);
            if (($uuid eq '__PAC__ROOT__') || (!$path)) {
                next;
            }
            $$self{_GUI}{treeConnections}->expand_to_path($path);
            $$self{_GUI}{treeConnections}->set_cursor($path, undef, 0);
            $$self{_GUI}{connEditBtn}->clicked();
        }
    }

    # Auto start scripts
    grep({ /^--start-script=(.+)$/ and $$self{_SCRIPTS}->_execScript($1,$$self{_GUI}{main}); } @{ $$self{_OPTS} });

    # Auto start Shell
    grep({ /^--start-shell$/ and $$self{_GUI}{shellBtn}->clicked(); } @{ $$self{_OPTS} });

    # Auto start Quick Connect edit dialog
    grep({ /^--quick-conn$/ and $$self{_GUI}{connQuickBtn}->clicked(); } @{ $$self{_OPTS} });

    # Auto start Preferences dialog
    grep({ /^--preferences$/ and $$self{_GUI}{configBtn}->clicked(); } @{ $$self{_OPTS} });

    # Auto start Scripts window
    grep({ /^--scripts$/ and $$self{_GUI}{scriptsBtn}->clicked(); } @{ $$self{_OPTS} });

    # Goto GTK's event loop
    Gtk3->main();

    return 1;
}

# END: Define PUBLIC CLASS methods
###################################################################

###################################################################
# START: Define PRIVATE CLASS functions

sub _initGUI {
    my $self = shift;

    # Prevent from creating the main window a second time
    if (defined $$self{_GUI}{main}) {
        return 0;
    }

    ############################################################################################
    # Create main window
    ############################################################################################
    # The main window is made of:
    #  - a "command panel" with tools buttons, connections list, favorites, etc.
    #  - a "connections panel" with info tab & tabbed connections
    ############################################################################################
    # AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{main} = create_window('toplevel', $APPNAME);
    if ($$self{_CFG}{defaults}{'tabs in main window'} && $$self{_CFG}{defaults}{'terminal support transparency'}) {
        _setWindowPaintable($$self{_GUI}{main});
    }

    # Normalize deprecated 'Compact' layout to 'Traditional'
    if (defined $$self{_CFG}{defaults}{layout} && $$self{_CFG}{defaults}{layout} eq 'Compact') {
        $$self{_CFG}{defaults}{layout} = 'Traditional';
        $$self{_CFG}{defaults}{'layout previous'} = 'Traditional';
        eval { $self->_saveConfiguration(); };
    }

    # Migration A (2025-08): Remove legacy Compact layout artifacts & restore tabbed Traditional behavior
    if (!$ENV{ASBRU_SKIP_TAB_MIGRATION} && !$$self{_READONLY}) {
        my $d = $$self{_CFG}{defaults};
        my $changed = 0;
        # Re-enable tabs if disabled due to previous Compact usage (heuristics: lt* keys present OR previous layout recorded as Compact)
        if ((defined $d->{'tabs in main window'} && !$d->{'tabs in main window'}) &&
            (exists $d->{'lt tabs in main window'} || (($d->{'layout previous'} // '') eq 'Compact'))) {
            $d->{'tabs in main window'} = 1; $changed = 1;
        }
        # Purge legacy Compact-related keys
        foreach my $k (qw/lt tabs in main window lt start iconified lt close to tray lt auto save layout traditional settings/) {
            if (exists $d->{$k}) { delete $d->{$k}; $changed = 1; }
        }
        if (defined $d->{'layout previous'} && $d->{'layout previous'} eq 'Compact') { delete $d->{'layout previous'}; $changed = 1; }
        if ($changed) {
            $d->{'migrated from compact'} = 1;
            $$self{_CFG}{tmp}{changed} = 1; # mark dirty (if auto-save disabled user can save manually)
            $self->_saveConfiguration(undef, 0) if $d->{'auto save'};
        }
    }

    # DevNote: would be nice to have this inside the theme itself
    if ($$self{_THEME} =~ /dark/) {
        _setDefaultRGBA(56,56,56,1);
    } else {
        _setDefaultRGBA(240,240,240,1);
    }

    # Create a main horizontal box - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{hpane} = create_paned('horizontal');
    $$self{_GUI}{hpane}->set_wide_handle(1);  # DevNote: if not set, text selection in a terminal will not be possible near the handle
    $$self{_GUI}{main}->add($$self{_GUI}{hpane});

    # Create a vboxCommandPanel: actions, connections and other tools - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{vboxCommandPanel} = create_box('vertical', 0);
    $$self{_GUI}{vboxCommandPanel}->set_size_request(200, -1);
    # Ensure layout key is always defined (migration may have removed legacy Compact entry)
    if (!defined $$self{_CFG}{defaults}{layout}) {
        $$self{_CFG}{defaults}{layout} = 'Traditional';
    }
    if ($$self{_CFG}{defaults}{'tree on right side'}) {
        $$self{_GUI}{hpane}->pack2($$self{_GUI}{vboxCommandPanel}, 0, 0);
    } else {
        $$self{_GUI}{hpane}->pack1($$self{_GUI}{vboxCommandPanel}, 0, 0);
    }

    # Create a hbuttonbox1: add, rename, delete, etc... - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{hbuttonbox1} = create_box('horizontal', 0);
    $$self{_GUI}{vboxCommandPanel}->pack_start($$self{_GUI}{hbuttonbox1}, 0, 1, 0);

    # Create "Add Group" button (symbolic)
    $$self{_GUI}{groupAddBtn} = create_button();
    $$self{_GUI}{groupAddBtn}->set_image(PACIcons::icon_image('folder','asbru-group-add'));
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{groupAddBtn}, 1, 1, 0);
    $$self{_GUI}{groupAddBtn}->set('can-focus' => 0);
    $$self{_GUI}{groupAddBtn}->get_style_context()->add_class("button-cp");
    $$self{_GUI}{groupAddBtn}->set_tooltip_text('Add a new group in the selected node');

    # Create "Add Connection" button (symbolic)
    $$self{_GUI}{connAddBtn} = create_button();
    $$self{_GUI}{connAddBtn}->set_image(PACIcons::icon_image('add','asbru-node-add'));
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{connAddBtn}, 1, 1, 0);
    $$self{_GUI}{connAddBtn}->set('can-focus' => 0);
    $$self{_GUI}{connAddBtn}->get_style_context()->add_class("button-cp");
    $$self{_GUI}{connAddBtn}->set_tooltip_text('Add a new connection in the selected node');

    # Create "Edit" button (symbolic)
    $$self{_GUI}{connEditBtn} = create_button();
    $$self{_GUI}{connEditBtn}->set_image(PACIcons::icon_image('edit','gtk-edit'));
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{connEditBtn}, 1, 1, 0);
    $$self{_GUI}{connEditBtn}->set('can-focus' => 0);
    $$self{_GUI}{connEditBtn}->get_style_context()->add_class("button-cp");
    $$self{_GUI}{connEditBtn}->set_tooltip_text('Edit the currently selected node');

    # Create "Rename" button (reuse edit symbolic if no direct icon)
    $$self{_GUI}{nodeRenBtn} = create_button();
    $$self{_GUI}{nodeRenBtn}->set_image(PACIcons::icon_image('edit','gtk-spell-check'));
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{nodeRenBtn}, 1, 1, 0);
    $$self{_GUI}{nodeRenBtn}->set('can-focus' => 0);
    $$self{_GUI}{nodeRenBtn}->get_style_context()->add_class("button-cp");
    $$self{_GUI}{nodeRenBtn}->set_tooltip_text('Rename the currently selected node');

    # Create "Delete" button (symbolic)
    $$self{_GUI}{nodeDelBtn} = create_button();
    $$self{_GUI}{nodeDelBtn}->set_image(PACIcons::icon_image('delete','gtk-delete'));
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{nodeDelBtn}, 1, 1, 0);
    $$self{_GUI}{nodeDelBtn}->set('can-focus' => 0);
    $$self{_GUI}{nodeDelBtn}->get_style_context()->add_class("button-cp");
    $$self{_GUI}{nodeDelBtn}->set_sensitive(0);
    $$self{_GUI}{nodeDelBtn}->set_tooltip_text('Delete the selected node(s)');

    # Removed Compact layout decoration stripping to retain standard window controls

    # Put a notebook for connections, favourites and history - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{nbTree} = create_notebook();
    $$self{_GUI}{vboxCommandPanel}->pack_start($$self{_GUI}{nbTree}, 1, 1, 0);
    $$self{_GUI}{nbTree}->set_scrollable(1);

    # Create a scrolled1 scrolled window to contain the connections tree - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{scroll1} = create_scrolled_window();
    $$self{_GUI}{scroll1}->set_overlay_scrolling($$self{_CFG}{'defaults'}{'tree overlay scrolling'});
    $$self{_GUI}{nbTreeTab} = create_box('horizontal', 0);
    $$self{_GUI}{nbTreeTabLabel} = create_label();
    
    # Fix GTK critical error: ensure icon has no parent before packing
    eval {
        my $tree_icon = PACIcons::icon_image('folder','asbru-treelist');
        if ($tree_icon) {
            # Check if icon already has a parent and remove it if necessary
            if (my $parent = $tree_icon->get_parent()) {
                $parent->remove($tree_icon);
            }
            $$self{_GUI}{nbTreeTab}->pack_start($tree_icon, 0, 1, 0);
        }
    };
    if ($$self{_CFG}{'defaults'}{'layout'} ne 'Compact') {
        $$self{_GUI}{nbTreeTab}->pack_start($$self{_GUI}{nbTreeTabLabel}, 0, 1, 0);
    }
    $$self{_GUI}{nbTreeTab}->set_tooltip_text('Connection Tree');
    $$self{_GUI}{nbTreeTab}->show_all();
    $$self{_GUI}{nbTree}->append_page($$self{_GUI}{scroll1}, $$self{_GUI}{nbTreeTab});
    $$self{_GUI}{nbTree}->set_tab_reorderable($$self{_GUI}{scroll1}, 1);
    $$self{_GUI}{scroll1}->set_policy('automatic', 'automatic');

    # Create a treeConnections treeview for connections
    $$self{_GUI}{treeConnections} = PACTree->new(
        'Icon:' => 'pixbuf',
        'Name:' => 'hidden',
        'UUID:' => 'hidden',
        'List:' => 'image_text',
    );
    $$self{_GUI}{scroll1}->add($$self{_GUI}{treeConnections});
    $$self{_GUI}{treeConnections}->set_enable_tree_lines($$self{_CFG}{'defaults'}{'enable tree lines'});
    $$self{_GUI}{treeConnections}->set_headers_visible(0);
    $$self{_GUI}{treeConnections}->set_enable_search(0);
    $$self{_GUI}{treeConnections}->set_has_tooltip(1);
    $$self{_GUI}{treeConnections}->set_grid_lines('GTK_TREE_VIEW_GRID_LINES_NONE');
    
    # Apply theme-aware styling to connection tree (Task 4.1)
    PACCompat::registerTreeWidgetForThemeUpdates($$self{_GUI}{treeConnections});
    
    # Set custom CSS class for better theme targeting
    $$self{_GUI}{treeConnections}->get_style_context()->add_class('asbru-connection-tree');
    # Implement a "TreeModelSort" to auto-sort the data
    $$self{_GUI}{treeConnections}->set_model(SortedTreeStore->create($$self{_GUI}{treeConnections}->get_model(), $$self{_CFG}, $$self{_VERBOSE}));
    $$self{_GUI}{treeConnections}->get_selection()->set_mode('GTK_SELECTION_MULTIPLE');

    @{$$self{_GUI}{treeConnections}{'data'}}=(
        {
            value => [ $GROUPICON_ROOT, $self->__treeBuildNodeName('__PAC__ROOT__', 'My Connections'), '__PAC__ROOT__' ],
            children => []
        }
    );

    $$self{_GUI}{_vboxSearch} = create_box('vertical', 0);
    $$self{_GUI}{vboxCommandPanel}->pack_start($$self{_GUI}{_vboxSearch}, 0, 1, 0);

    $$self{_GUI}{_entrySearch} = create_entry();
    $$self{_GUI}{_vboxSearch}->pack_start($$self{_GUI}{_entrySearch}, 0, 1, 0);
    $$self{_GUI}{_entrySearch}->grab_focus();

    $$self{_GUI}{_hboxSearch} = create_box('horizontal', 0);
    $$self{_GUI}{_vboxSearch}->pack_start($$self{_GUI}{_hboxSearch}, 0, 1, 0);

    $$self{_GUI}{_btnPrevSearch} = create_button('Previous');
    $$self{_GUI}{_btnPrevSearch}->set_image(PACIcons::icon_image('previous','gtk-media-previous'));
    $$self{_GUI}{_hboxSearch}->pack_start($$self{_GUI}{_btnPrevSearch}, 0, 1, 0);
    $$self{_GUI}{_btnPrevSearch}->set('can_focus', 0);
    $$self{_GUI}{_btnPrevSearch}->set_sensitive(0);

    $$self{_GUI}{_btnNextSearch} = create_button('Next');
    $$self{_GUI}{_btnNextSearch}->set_image(PACIcons::icon_image('next','gtk-media-next'));
    $$self{_GUI}{_hboxSearch}->pack_start($$self{_GUI}{_btnNextSearch}, 0, 1, 0);
    $$self{_GUI}{_btnNextSearch}->set('can_focus', 0);
    $$self{_GUI}{_btnNextSearch}->set_sensitive(0);

    $$self{_GUI}{_rbSearchName} = create_radio_button(undef, 'Name');
    $$self{_GUI}{_rbSearchName}->set('can-focus', 0);
    $$self{_GUI}{_vboxSearch}->pack_start($$self{_GUI}{_rbSearchName}, 0, 1, 0);
    $$self{_GUI}{_rbSearchHost} = create_radio_button($$self{_GUI}{_rbSearchName}, 'IP / Host');
    $$self{_GUI}{_rbSearchHost}->set('can-focus', 0);
    $$self{_GUI}{_vboxSearch}->pack_start($$self{_GUI}{_rbSearchHost}, 0, 1, 0);
    $$self{_GUI}{_rbSearchDesc} = create_radio_button($$self{_GUI}{_rbSearchName}, 'Description');
    $$self{_GUI}{_rbSearchDesc}->set('can-focus', 0);
    $$self{_GUI}{_vboxSearch}->pack_start($$self{_GUI}{_rbSearchDesc}, 0, 1, 0);

    # Create a scrolled2 scrolled window to contain the favourites tree - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{scroll2} = create_scrolled_window();
    $$self{_GUI}{nbFavTab} = create_box('horizontal', 0);
    $$self{_GUI}{nbFavTabLabel} = create_label();
    
    # Fix GTK critical error for favourites icon
    eval {
        my $fav_icon = PACIcons::icon_image('favourite_on','asbru-favourite-on');
        if ($fav_icon) {
            if (my $parent = $fav_icon->get_parent()) {
                $parent->remove($fav_icon);
            }
            $$self{_GUI}{nbFavTab}->pack_start($fav_icon, 0, 1, 0);
        }
    };
    if ($$self{_CFG}{'defaults'}{'layout'} ne 'Compact') {
        $$self{_GUI}{nbFavTab}->pack_start($$self{_GUI}{nbFavTabLabel}, 0, 1, 0);
    }
    $$self{_GUI}{nbFavTab}->set_tooltip_text('Favourites');
    $$self{_GUI}{nbFavTab}->show_all();
    $$self{_GUI}{nbTree}->append_page($$self{_GUI}{scroll2}, $$self{_GUI}{nbFavTab});
    $$self{_GUI}{nbTree}->set_tab_reorderable($$self{_GUI}{scroll2}, 1);
    $$self{_GUI}{scroll2}->set_shadow_type('none');
    $$self{_GUI}{scroll2}->set_policy('automatic', 'automatic');

    # Create treeFavourites
    $$self{_GUI}{treeFavourites} = PACTree->new(
        'Icon:' => 'pixbuf',
        'Name:' => 'markup',
        'UUID:' => 'hidden',
    );
    $$self{_GUI}{scroll2}->add($$self{_GUI}{treeFavourites});

    # Implement a "TreeModelSort" to auto-sort the data
    $$self{_GUI}{treeFavourites}->set_model(SortedTreeStore->create($$self{_GUI}{treeFavourites}->get_model(), $$self{_CFG}, $$self{_VERBOSE}));

    $$self{_GUI}{treeFavourites}->set_enable_tree_lines(0);
    $$self{_GUI}{treeFavourites}->set_show_expanders(0);
    $$self{_GUI}{treeFavourites}->set_headers_visible(0);
    $$self{_GUI}{treeFavourites}->set_enable_search(0);
    $$self{_GUI}{treeFavourites}->set_has_tooltip(1);
    $$self{_GUI}{treeFavourites}->get_selection()->set_mode('GTK_SELECTION_MULTIPLE');
    
    # Apply theme-aware styling to favourites tree (Task 4.1)
    PACCompat::registerTreeWidgetForThemeUpdates($$self{_GUI}{treeFavourites});
    
    # Set custom CSS class for better theme targeting
    $$self{_GUI}{treeFavourites}->get_style_context()->add_class('asbru-connection-tree');

    # Create a scrolled3 scrolled window to contain the history tree - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{scroll3} = create_scrolled_window();
    $$self{_GUI}{nbHistTab} = create_box('horizontal', 0);
    $$self{_GUI}{nbHistTabLabel} = create_label();
    
    # Fix GTK critical error for history icon
    eval {
        my $hist_icon = PACIcons::icon_image('history','asbru-history');
        if ($hist_icon) {
            if (my $parent = $hist_icon->get_parent()) {
                $parent->remove($hist_icon);
            }
            $$self{_GUI}{nbHistTab}->pack_start($hist_icon, 0, 1, 0);
        }
    };
    if ($$self{_CFG}{'defaults'}{'layout'} ne 'Compact') {
        $$self{_GUI}{nbHistTab}->pack_start($$self{_GUI}{nbHistTabLabel}, 0, 1, 0);
    }
    $$self{_GUI}{nbHistTab}->set_tooltip_text('Connection History');
    $$self{_GUI}{nbHistTab}->show_all();
    $$self{_GUI}{nbTree}->append_page($$self{_GUI}{scroll3}, $$self{_GUI}{nbHistTab});
    $$self{_GUI}{nbTree}->set_tab_reorderable($$self{_GUI}{scroll3}, 1);
    $$self{_GUI}{scroll3}->set_shadow_type('none');
    $$self{_GUI}{scroll3}->set_policy('automatic', 'automatic');

    # Create treeHistory
    $$self{_GUI}{treeHistory} = PACTree->new(
        'Icon:' => 'pixbuf',
        'Name:' => 'markup',
        'UUID:' => 'hidden',
        'Last:' => 'text',
    );
    $$self{_GUI}{scroll3}->add($$self{_GUI}{treeHistory});
    $$self{_GUI}{treeHistory}->set_enable_tree_lines(0);
    $$self{_GUI}{treeHistory}->set_show_expanders(0);
    $$self{_GUI}{treeHistory}->set_headers_visible(0);
    $$self{_GUI}{treeHistory}->set_enable_search(0);
    $$self{_GUI}{treeHistory}->set_has_tooltip(1);
    
    # Apply theme-aware styling to history tree (Task 4.1)
    PACCompat::registerTreeWidgetForThemeUpdates($$self{_GUI}{treeHistory});

    $$self{_GUI}{vboxclu} = create_box('vertical', 0);

    if ($$self{_CFG}{'defaults'}{'layout'} ne 'Compact') {
        $$self{_GUI}{btneditclu} = create_button(' Manage Clusters');
        $$self{_GUI}{vboxclu}->pack_start($$self{_GUI}{btneditclu}, 0, 1, 0);
    $$self{_GUI}{btneditclu}->set_image(PACIcons::icon_image('group','asbru-cluster-manager2'));
        $$self{_GUI}{btneditclu}->set('can-focus', 0);
    }

    # Create a scrolledclu scrolled window to contain the clusters tree - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{scrolledclu} = create_scrolled_window();
    $$self{_GUI}{nbCluTab} = create_box('horizontal', 0);
    $$self{_GUI}{nbCluTabLabel} = create_label();
    
    # Fix GTK critical error for cluster icon
    eval {
        my $clu_icon = PACIcons::icon_image('group','asbru-cluster-manager');
        if ($clu_icon) {
            if (my $parent = $clu_icon->get_parent()) {
                $parent->remove($clu_icon);
            }
            $$self{_GUI}{nbCluTab}->pack_start($clu_icon, 0, 1, 0);
        }
    };
    if ($$self{_CFG}{'defaults'}{'layout'} ne 'Compact') {
        $$self{_GUI}{nbCluTab}->pack_start($$self{_GUI}{nbCluTabLabel}, 0, 1, 0);
    }
    $$self{_GUI}{nbCluTab}->set_tooltip_text('Clusters');
    $$self{_GUI}{nbCluTab}->show_all();
    $$self{_GUI}{vboxclu}->pack_start($$self{_GUI}{scrolledclu}, 1, 1, 0);
    $$self{_GUI}{nbTree}->append_page($$self{_GUI}{vboxclu}, $$self{_GUI}{nbCluTab});
    $$self{_GUI}{nbTree}->set_tab_reorderable($$self{_GUI}{vboxclu}, 1);
    $$self{_GUI}{scrolledclu}->set_shadow_type('none');
    $$self{_GUI}{scrolledclu}->set_policy('automatic', 'automatic');

    # Create treeClusters
    $$self{_GUI}{treeClusters} = PACTree->new(
        'Icon:' => 'pixbuf',
        'Name:' => 'markup'
    );
    $$self{_GUI}{scrolledclu}->add($$self{_GUI}{treeClusters});
    $$self{_GUI}{treeClusters}->set_enable_tree_lines(0);
    $$self{_GUI}{treeClusters}->set_show_expanders(0);
    $$self{_GUI}{treeClusters}->set_headers_visible(0);
    $$self{_GUI}{treeClusters}->set_enable_search(0);
    $$self{_GUI}{treeClusters}->set_has_tooltip(0);
    
    # Apply theme-aware styling to clusters tree (Task 4.1)
    PACCompat::registerTreeWidgetForThemeUpdates($$self{_GUI}{treeClusters});

    # Create a hbox0: exec and clusters - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{hbox0} = create_box('vertical', 0);
    $$self{_GUI}{vboxCommandPanel}->pack_start($$self{_GUI}{hbox0}, 0, 1, 0);

    $$self{_GUI}{hboxsearchstart} = create_box('horizontal', 0);
    $$self{_GUI}{hbox0}->pack_start($$self{_GUI}{hboxsearchstart}, 0, 1, 0);

    # Create a "Search" button
    $$self{_GUI}{connSearch} = create_button();
    $$self{_GUI}{hboxsearchstart}->pack_start($$self{_GUI}{connSearch}, 0, 1, 0);
    $$self{_GUI}{connSearch}->set_image(PACIcons::icon_image('search','gtk-find'));
    $$self{_GUI}{connSearch}->set('can-focus' => 0);
    $$self{_GUI}{connSearch}->set_tooltip_text('Start interactive search for connections');

    # Create "Start" button
    $$self{_GUI}{connExecBtn} = create_button('Connect');
    $$self{_GUI}{hboxsearchstart}->pack_start($$self{_GUI}{connExecBtn}, 1, 1, 0);
    $$self{_GUI}{connExecBtn}->set_image(PACIcons::icon_image('connect','gtk-connect'));
    $$self{_GUI}{connExecBtn}->set('can-focus' => 0);
    $$self{_GUI}{connExecBtn}->set_tooltip_text('Start selected terminals/groups');

    # Create "Quick Connect" button
    $$self{_GUI}{connQuickBtn} = create_button();
    $$self{_GUI}{hboxsearchstart}->pack_start($$self{_GUI}{connQuickBtn}, 0, 1, 0);
    $$self{_GUI}{connQuickBtn}->set_image(PACIcons::icon_image('connect','asbru-quick-connect'));
    $$self{_GUI}{connQuickBtn}->set('can-focus' => 0);
    $$self{_GUI}{connQuickBtn}->set_tooltip_text('Start a new connection, without saving it');

    # Create "Favourite" button
    $$self{_GUI}{connFavourite} = create_toggle_button();
    $$self{_GUI}{hboxsearchstart}->pack_start($$self{_GUI}{connFavourite}, 1, 1, 0);
    $$self{_GUI}{connFavourite}->set_image(PACIcons::icon_image('favourite_off','gtk-about'));
    $$self{_GUI}{connFavourite}->set('can-focus' => 0);
    $$self{_GUI}{connFavourite}->set_tooltip_text('Add to/remove from favourites connections list');

    $$self{_GUI}{hboxclusters} = create_box('horizontal', 0);
    $$self{_GUI}{hbox0}->pack_start($$self{_GUI}{hboxclusters}, 0, 1, 0);

    # Create "Clusters" button
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{clusterBtn} = create_button();
        $$self{_GUI}{clusterBtn}->get_style_context()->add_class("button-cp");
    } else {
        $$self{_GUI}{clusterBtn} = create_button('Clusters');
    }
    $$self{_GUI}{hboxclusters}->pack_start($$self{_GUI}{clusterBtn}, 1, 1, 0);
    $$self{_GUI}{clusterBtn}->set_image(PACIcons::icon_image('group','asbru-cluster-manager2'));
    $$self{_GUI}{clusterBtn}->set('can-focus' => 0);
    $$self{_GUI}{clusterBtn}->set_tooltip_text('Open the Clusters Administration Console');

    # Create "Scripts" button
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{scriptsBtn} = create_button();
    } else {
        $$self{_GUI}{scriptsBtn} = create_button('Scripts');
    }
    $$self{_GUI}{hboxclusters}->pack_start($$self{_GUI}{scriptsBtn}, 1, 1, 0);
    $$self{_GUI}{scriptsBtn}->set_image(PACIcons::icon_image('settings','asbru-script'));
    $$self{_GUI}{scriptsBtn}->set('can-focus' => 0);
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{scriptsBtn}->get_style_context()->add_class("button-cp");
    }
    $$self{_GUI}{scriptsBtn}->set_tooltip_text('Open the Scripts Administration Console');

    # Create "Clusters" button
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{pccBtn} = create_button();
        $$self{_GUI}{pccBtn}->get_style_context()->add_class("button-cp");
    } else {
        $$self{_GUI}{pccBtn} = create_button('PCC');
    }
    $$self{_GUI}{hboxclusters}->pack_start($$self{_GUI}{pccBtn}, 1, 1, 0);
    $$self{_GUI}{pccBtn}->set_image(PACIcons::icon_image('settings','gtk-justify-fill'));
    $$self{_GUI}{pccBtn}->set('can-focus' => 0);
    $$self{_GUI}{pccBtn}->set_tooltip_text("Open the Power Clusters Controller:\nexecute commands in every clustered terminal from this single window");

    # Create a vbox for info tab, connections (if tabbed) and button bar
    # Desired layout:
    #  - When tree on left (default): command panel (non-expand) LEFT (pack1, expand=0), connections panel RIGHT (pack2, expand=1)
    #  - When tree on right: command panel (non-expand) RIGHT (pack2, expand=0), connections panel LEFT (pack1, expand=1)
    $$self{_GUI}{vboxConnectionPanel} = create_box('vertical', 0);
    if ($$self{_CFG}{defaults}{'tree on right side'}) {
        # command panel already packed as pack2 earlier; put connections as pack1 expand=1
        $$self{_GUI}{hpane}->pack1($$self{_GUI}{vboxConnectionPanel}, 1, 0);
    } else {
        # standard: command panel packed as pack1 earlier; put connections as pack2 expand=1
        $$self{_GUI}{hpane}->pack2($$self{_GUI}{vboxConnectionPanel}, 1, 0);
    }
    $$self{_GUI}{vboxConnectionPanel}->show_all();
    # Basic initial splitter positioning (no verbose debug)
    my $desired_fraction = 0.30;
    Glib::Idle->add(sub { my $alloc=$$self{_GUI}{hpane}->get_allocation; my $w=$alloc->{width}||0; if($w>200){ my $pos=int($w*$desired_fraction); eval { $$self{_GUI}{hpane}->set_position($pos); }; } 0; });

    # Create a notebook for info tab and connections - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{nbConnectionPanel} = create_notebook();
    $$self{_GUI}{vboxConnectionPanel}->pack_start($$self{_GUI}{nbConnectionPanel}, 1, 1, 0);
    $$self{_GUI}{nbConnectionPanel}->set_scrollable(1);
    $$self{_GUI}{nbConnectionPanel}->set_tab_pos($$self{_CFG}{'defaults'}{'tabs position'});

    my $tablbl = create_box('horizontal', 0);
    $tablbl->pack_start(create_label('Info '), 0, 1, 0);
    $$self{_GUI}{_TABIMG} = PACIcons::icon_image('settings','gtk-info');
    $tablbl->pack_start($$self{_GUI}{_TABIMG}, 0, 1, 0);
    $tablbl->show_all();

    # Create a vboxInfo: description - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{vboxInfo} = create_box('vertical', 0);
    $$self{_GUI}{nbConnectionPanel}->append_page($$self{_GUI}{vboxInfo}, $tablbl);

    # Create a scrolled2 scrolled window to contain the description textview - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{scrollDescription} = create_scrolled_window();
    $$self{_GUI}{vboxInfo}->pack_start($$self{_GUI}{scrollDescription}, 1, 1, 0);
    $$self{_GUI}{scrollDescription}->set_policy('automatic', 'automatic');
    $$self{_GUI}{scrollDescription}->set_shadow_type('GTK_SHADOW_IN');
    $$self{_GUI}{scrollDescription}->set_border_width(5);

    # Create descView as a gtktextview with descBuffer
    $$self{_GUI}{descBuffer} = Gtk3::TextBuffer->new();
    $$self{_GUI}{descView} = create_text_view_with_buffer($$self{_GUI}{descBuffer});
    $$self{_GUI}{descView}->set_border_width(5);
    $$self{_GUI}{scrollDescription}->add($$self{_GUI}{descView});
    $$self{_GUI}{descView}->set_wrap_mode('GTK_WRAP_WORD');
    $$self{_GUI}{descView}->set_sensitive(1);
    $$self{_GUI}{descView}->drag_dest_unset();
    $$self{_GUI}{descView}->modify_font(Pango::FontDescription::from_string('monospace'));

    # Create a frameStatistics for statistics
    $$self{_GUI}{frameStatistics} = create_frame('STATISTICS ');
    $$self{_GUI}{frameStatistics}->set_border_width(5);
    $$self{_GUI}{frameStatistics}->set_shadow_type('GTK_SHADOW_NONE');
    $$self{_GUI}{frameStatisticslbl} = create_label();
    $$self{_GUI}{frameStatisticslbl}->set_markup('<b>STATISTICS</b> ');
    $$self{_GUI}{frameStatistics}->set_label_widget($$self{_GUI}{frameStatisticslbl});
    $$self{_GUI}{statistics} = $$self{_SCREENSHOTS} = PACStatistics->new();
    $$self{_GUI}{frameStatistics}->add($$self{_GUI}{statistics}->{container});
    $$self{_GUI}{ebFrameStatistics} = Gtk3::EventBox->new(); # required to get motion events
    $$self{_GUI}{ebFrameStatistics}->add_events('GDK_POINTER_MOTION_MASK');
    $$self{_GUI}{ebFrameStatistics}->add($$self{_GUI}{frameStatistics});
    $$self{_GUI}{vboxInfo}->pack_start($$self{_GUI}{ebFrameStatistics}, 0, 1, 0);

    # Create a frameScreenshot for screenshot
    $$self{_GUI}{frameScreenshots} = create_frame('SCREENSHOTS ');
    $$self{_GUI}{frameScreenshots}->set_border_width(5);
    $$self{_GUI}{frameScreenshots}->set_shadow_type('GTK_SHADOW_NONE');
    $$self{_GUI}{frameScreenshotslbl} = create_label();
    $$self{_GUI}{frameScreenshotslbl}->set_markup('<b>SCREENSHOTS</b> ');
    $$self{_GUI}{frameScreenshots}->set_label_widget($$self{_GUI}{frameScreenshotslbl});
    $$self{_GUI}{screenshots} = $$self{_SCREENSHOTS} = PACScreenshots->new();
    $$self{_GUI}{frameScreenshots}->add($$self{_GUI}{screenshots}->{container});
    $$self{_GUI}{ebFrameScreenshots} = Gtk3::EventBox->new(); # required to get motion events
    $$self{_GUI}{ebFrameScreenshots}->add_events('GDK_POINTER_MOTION_MASK');
    $$self{_GUI}{ebFrameScreenshots}->add($$self{_GUI}{frameScreenshots});
    $$self{_GUI}{vboxInfo}->pack_start($$self{_GUI}{ebFrameScreenshots}, 0, 1, 0);

    # Create a hbuttonbox1: show/hide, WOL, Shell, Preferences, etc... - AI-assisted modernization: Updated for GTK4 compatibility
    $$self{_GUI}{hbuttonbox1} = create_box('horizontal', 0);
    $$self{_GUI}{vboxConnectionPanel}->pack_start($$self{_GUI}{hbuttonbox1}, 0, 1, 0);

    # Create "Hide command panel" button
    $$self{_GUI}{showConnBtn} = Gtk3::ToggleButton->new();
    $$self{_GUI}{showConnBtn}->set_image(PACIcons::icon_image('folder','asbru-treelist'));
    $$self{_GUI}{showConnBtn}->set_active(1);
    $$self{_GUI}{showConnBtn}->set('can-focus' => 0);
    $$self{_GUI}{showConnBtn}->set_tooltip_text('Show/Hide connections tree panel');
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{showConnBtn}, 0, 1, 0);

    # Create "Wake on LAN" button
    $$self{_GUI}{wolBtn} = create_button('Wake On Lan');
    $$self{_GUI}{wolBtn}->set_image(PACIcons::icon_image('connect','asbru-wol'));
    $$self{_GUI}{wolBtn}->set_always_show_image(1);
    $$self{_GUI}{wolBtn}->set('can-focus' => 0);
    $$self{_GUI}{wolBtn}->set_tooltip_text('Start the "Wake On LAN" utility window');
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{wolBtn}, 1, 1, 0);

    # Create "Local Shell" button
    $$self{_GUI}{shellBtn} = create_button();
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{hboxclusters}->pack_start($$self{_GUI}{shellBtn}, 1, 1, 0);
    } else {
        $$self{_GUI}{shellBtn}->set_label('Local shell');
        $$self{_GUI}{shellBtn}->set_always_show_image(1);
        $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{shellBtn}, 1, 1, 0);
    }
    $$self{_GUI}{shellBtn}->set_image(PACIcons::icon_image('shell','asbru-shell'));
    $$self{_GUI}{shellBtn}->set('can-focus' => 0);
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{shellBtn}->get_style_context()->add_class("button-cp");
    }
    $$self{_GUI}{shellBtn}->set_tooltip_text('Launch new local shell');

    # Create "Preferences" button
    $$self{_GUI}{configBtn} = create_button();
    $$self{_GUI}{configBtn}->get_style_context()->add_class("button-cp");
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{hboxclusters}->pack_start($$self{_GUI}{configBtn}, 1, 1, 0);
    } else {
        $$self{_GUI}{configBtn}->set_label('Preferences');
        $$self{_GUI}{configBtn}->set_always_show_image(1);
        $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{configBtn}, 1, 1, 0);
    }
    $$self{_GUI}{configBtn}->set_image(PACIcons::icon_image('settings','gtk-preferences'));
    $$self{_GUI}{configBtn}->set('can-focus' => 0);
    $$self{_GUI}{configBtn}->set_tooltip_text('Open the general preferences control');

    # Create "Save" button
    $$self{_GUI}{saveBtn} = create_button('Save');
    $$self{_GUI}{saveBtn}->set_always_show_image(1);
    $$self{_GUI}{saveBtn}->set_image(PACIcons::icon_image('save','gtk-save'));
    $$self{_GUI}{saveBtn}->set('can-focus' => 0);
    $$self{_GUI}{saveBtn}->set_sensitive(0);
    $$self{_GUI}{saveBtn}->set_tooltip_text('Save the latest configuration changes, see also the "Automatically save every configuration change" field under "Preferences"->"Main Options"');
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{saveBtn}, 1, 1, 0);

    # Create "Lock/Unlock" button
    $$self{_GUI}{lockApplicationBtn} = Gtk3::ToggleButton->new();
    $$self{_GUI}{lockApplicationBtn}->set_image(PACIcons::icon_image('lock_off','asbru-unprotected'));
    $$self{_GUI}{lockApplicationBtn}->set_active(0);
    $$self{_GUI}{lockApplicationBtn}->set('can-focus' => 0);
    $$self{_GUI}{lockApplicationBtn}->set_tooltip_text('Password [un]lock GUI. In order to use this functionality, check the "Protect with password" field under "Preferences"->"Main Options"');
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{lockApplicationBtn}, 0, 1, 0);

    # Create "About" button
    $$self{_GUI}{aboutBtn} = create_button();
    $$self{_GUI}{aboutBtn}->set_image(PACIcons::icon_image('about','gtk-about'));
    $$self{_GUI}{aboutBtn}->set('can-focus' => 0);
    $$self{_GUI}{aboutBtn}->set_tooltip_text('Show the *so needed* "About" dialog');
    $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{aboutBtn}, 0, 1, 0);

    # Create "Quit" button
    $$self{_GUI}{quitBtn} = create_button();
    $$self{_GUI}{quitBtn}->get_style_context()->add_class("button-cp");
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{hboxclusters}->pack_start($$self{_GUI}{quitBtn}, 1, 1, 0);
    } else {
        $$self{_GUI}{quitBtn}->set_label('Quit');
        $$self{_GUI}{quitBtn}->set_always_show_image(1);
        $$self{_GUI}{hbuttonbox1}->pack_start($$self{_GUI}{quitBtn}, 1, 1, 0);
    }
    $$self{_GUI}{quitBtn}->set_image(PACIcons::icon_image('quit','gtk-quit'));
    $$self{_GUI}{quitBtn}->set('can-focus' => 0);
    $$self{_GUI}{quitBtn}->set_tooltip_text('Close all terminals and terminate the application');

    # Setup some window properties.
    $$self{_GUI}{main}->set_title("$APPNAME" . ($$self{_READONLY} ? ' - READ ONLY MODE' : ''));
    Gtk3::Window::set_default_icon_from_file($APPICON);
    $$self{_GUI}{main}->set_default_size($$self{_GUI}{sw} // 600, $$self{_GUI}{sh} // 480);
    $$self{_GUI}{main}->set_resizable(1);

    # Set treeviews font
    foreach my $tree ('Connections', 'Favourites', 'History', 'Clusters') {
        my @col = $$self{_GUI}{"tree$tree"}->get_columns();
        if ($tree eq 'Connections') {
            $col[0]->set_visible(0);
        } else {
            my ($c) = $col[1]->get_cells();
            $c->set('font',$$self{_CFG}{defaults}{'tree font'});
            if ($tree eq 'History') {
                my ($c) = $col[2]->get_cells();
                $c->set('font',$$self{_CFG}{defaults}{'tree font'});
            }
        }
    }

    ##############################################
    # Build TABBED TERMINAL WINDOW
    ##############################################

    if ($$self{_CFG}{defaults}{'tabs in main window'}) {
        $$self{_GUI}{nb} = $$self{_GUI}{nbConnectionPanel};
        $$self{_GUI}{_PACTABS} = $$self{_GUI}{main};
    } else {
        # Create window - AI-assisted modernization: Updated for GTK4 compatibility
        $$self{_GUI}{_PACTABS} = create_window('toplevel', "$APPNAME - Connections");
        if ($$self{_CFG}{defaults}{'terminal support transparency'}) {
            _setWindowPaintable($$self{_GUI}{_PACTABS});
        }
        # Setup some window properties.
        $$self{_GUI}{_PACTABS}->set_title("Terminals Tabbed Window : $APPNAME (v$APPVERSION)");
        $$self{_GUI}{_PACTABS}->set_position('center');
        $$self{_GUI}{_PACTABS}->set_size_request(200, 100);
        $$self{_GUI}{_PACTABS}->set_default_size(600, 400);
        $$self{_GUI}{_PACTABS}->set_resizable(1);
        $$self{_GUI}{_PACTABS}->maximize() if $$self{_CFG}{'defaults'}{'start maximized'};
        Gtk3::Window::set_default_icon_from_file($APPICON);

        # Create a notebook widget - AI-assisted modernization: Updated for GTK4 compatibility
        $$self{_GUI}{nb} = create_notebook();
        $$self{_GUI}{nb}->set_scrollable(1);
        $$self{_GUI}{nb}->set_tab_pos($$self{_CFG}{'defaults'}{'tabs position'});
        $$self{_GUI}{_PACTABS}->add($$self{_GUI}{nb});

        # Hide tabs on main window
        $$self{_GUI}{nbConnectionPanel}->set_show_tabs(0);
        $$self{_GUI}{nbConnectionPanel}->set_property('show_border', 0);

        $$self{_TABSINWINDOW} = 1;
    }

    $$self{_GUI}{nb}->set('can_focus', 0);
    $$self{_GUI}{treeConnections}->grab_focus();

    # Load window size/position, and treeconnections size
    $self->_loadGUIData();
    if ($$self{_CFG}{defaults}{'start main maximized'} && $$self{_CFG}{'defaults'}{'layout'} ne 'Compact') {
        $$self{_GUI}{main}->set_position('center');
        $$self{_GUI}{main}->maximize();
    } else {
        if (defined $$self{_GUI}{posx} && ($$self{_GUI}{posx} eq 'maximized')) {
            $$self{_GUI}{main}->maximize();
        } else {
            # DevNote: there's no reliable way to restore the position, do only resize
            #          (see https://wiki.gnome.org/HowDoI/SaveWindowState and https://developer.gnome.org/gtk3/stable/GtkWindow.html#gtk-window-get-position)
            # $$self{_GUI}{main}->move($$self{_GUI}{posx} // 0, $$self{_GUI}{posy} // 0);
            $$self{_GUI}{main}->resize($$self{_GUI}{sw} // 1024, $$self{_GUI}{sh} // 768);
        }
    }

    # Build Config window
    $FUNCS{_CONFIG} = $$self{_CONFIG} = PACConfig->new($$self{_CFG});
    # Set parent
    $$self{_CONFIG}{_WINDOWCONFIG}->set_transient_for($$self{_GUI}{main});

    # Get the KeePass object from configuration
    $$self{_CONFIG}{_KEEPASS}{_VERBOSE} = $$self{_VERBOSE};
    $FUNCS{_KEEPASS} = $$self{_CONFIG}{_KEEPASS};

    # Get the KeyBindings object from configuration
    $FUNCS{_KEYBINDS} = $$self{_CONFIG}{_KEYBINDS};

    # Add some key bindings to existing button tooltip
    $$self{_GUI}{shellBtn}->set_tooltip_text($$self{_GUI}{shellBtn}->get_tooltip_text() . ' (' . $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('pacmain', 'localshell') . ')');
    $$self{_GUI}{showConnBtn}->set_tooltip_text($$self{_GUI}{showConnBtn}->get_tooltip_text() . ' (' . $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('pacmain', 'showconnections') . ')');

    # Build Edit window
    $FUNCS{_EDIT} = $$self{_EDIT} = PACEdit->new($$self{_CFG});
    # Set parent
    $$self{_EDIT}{_WINDOWEDIT}->set_transient_for($$self{_GUI}{main});

    # Build Cluster Administration window
    $$self{_CLUSTER} = PACCluster->new(\%RUNNING);
    $FUNCS{_CLUSTER} = $$self{_CLUSTER};

    # Build Power Cluster Controller window
    $FUNCS{_PCC} = $$self{_PCC} = PACPCC->new(\%RUNNING);

    # Build Tray icon with robust Cosmic fallback
    if ($COSMIC) {
        eval { require 'PACTrayCosmic.pm'; 1 } or do {
            print "WARNING: Cosmic tray module load failed: $@\n";
            $COSMIC = 0;
        };
    }
    if ($COSMIC) {
        my $maybe = eval { PACTrayCosmic->new($self) };
        if ($@) { print "WARNING: Cosmic tray construction error: $@\n"; }
        # Some objects might overload boolean false; accept any blessed ref
        if ($maybe && ref($maybe) || (ref($maybe) && Scalar::Util::blessed($maybe))) {
            $FUNCS{_TRAY} = $$self{_TRAY} = $maybe;
        } elsif (ref($maybe)) { # ref but evaluated false somehow
            $FUNCS{_TRAY} = $$self{_TRAY} = $maybe;
        } else {
            print "INFO: Falling back to standard tray (Cosmic tray unavailable)\n";
            $COSMIC = 0;
        }
    }
    if (!$COSMIC) {
        if ($UNITY) {
            $FUNCS{_TRAY} = $$self{_TRAY} = PACTrayUnity->new($self);
        } else {
            $FUNCS{_TRAY} = $$self{_TRAY} = PACTray->new($self);
        }
    }

    if ($COSMIC && $$self{_TRAY}) {
        my $mode = $$self{_TRAY}->can('get_integration_mode') ? $$self{_TRAY}->get_integration_mode() : 'unknown';
        my $have_ai = $$self{_TRAY}->can('have_appindicator') ? $$self{_TRAY}->have_appindicator() : 0;
        my $ai_pkg = $$self{_TRAY}->can('appindicator_package') ? $$self{_TRAY}->appindicator_package() : '';
        print "INFO: Cosmic tray integration mode: $mode (AppIndicator=$have_ai pkg=$ai_pkg)\n";
    }

    # Build PIPE object
    $FUNCS{_PIPE} = $$self{_PIPE} = PACPipe->new(\%RUNNING);

    # Build SCRIPTS object
    $FUNCS{_SCRIPTS} = $$self{_SCRIPTS} = PACScripts->new();

    # Build the STATISTICS object
    $FUNCS{_STATS} = $$self{_GUI}{statistics};

    $FUNCS{_METHODS} = $$self{_METHODS};
    $FUNCS{_MAIN} = $self;

    # AI-assisted modernization: Integrate Cosmic menu bar if using Cosmic tray (before workspace/theme)
    if ($COSMIC && $$self{_TRAY} && $$self{_TRAY}->can('get_menu_bar')) {
        my $cosmic_menu_bar = $$self{_TRAY}->get_menu_bar();
        if ($cosmic_menu_bar) {
            $$self{_GUI}{vboxCommandPanel}->pack_start($cosmic_menu_bar, 0, 0, 0);
            $$self{_GUI}{vboxCommandPanel}->reorder_child($cosmic_menu_bar, 0);
        }
    }

    # Unified Cosmic workspace & theme initialization
    $self->_initCosmicEnvironment() if $COSMIC;

    # Show the main window if not initially hidden in the systray
    if (!$$self{_CMDLINETRAY}) {
        if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
            $$self{_GUI}{vboxCommandPanel}->show_all();
            $$self{_GUI}{hpane}->show();
        } else {
            $$self{_GUI}{main}->show_all();
        }
    }
    $$self{_GUI}{hpane}->set_position($$self{_GUI}{hpanepos} // -1);
    $$self{_GUI}{_vboxSearch}->hide();

    $self->_updateGUIPreferences();
    if ($$self{_CFG}{'defaults'}{'start PAC tree on'} eq 'connections') {
        $$self{_GUI}{nbTree}->set_current_page(0);
    } elsif ($$self{_CFG}{'defaults'}{'start PAC tree on'} eq 'favourites') {
        $$self{_GUI}{nbTree}->set_current_page(1);
        $self->_updateFavouritesList();
        $self->_updateGUIFavourites();
    } elsif ($$self{_CFG}{'defaults'}{'start PAC tree on'} eq 'history') {
        $$self{_GUI}{nbTree}->set_current_page(2);
        $self->_updateGUIHistory();
    } else {
        $$self{_GUI}{nbTree}->set_current_page(3);
        $self->_updateClustersList();
        $self->_updateGUIClusters();
    }

    # Ensure the window is placed near the newly created icon (in compact mode only)
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact' && $$self{_TRAY}->is_visible()) {
        # Update GUI
        Gtk3::main_iteration() while Gtk3::events_pending();

        my @geo = $$self{_TRAY}->get_geometry();
        my $x = $geo[2]{x};
        my $y = $geo[2]{y};

        if ($x > 0 || $y > 0) {
            $$self{_GUI}{posx} = $x;
            $$self{_GUI}{posy} = $y;
            $$self{_GUI}{main}->move($$self{_GUI}{posx}, $$self{_GUI}{posy});
        }
    }

    return 1;
}

sub _setupCallbacks {
    my $self = shift;

    $$self{_APP}->signal_connect('open' , sub {
        my ($app, $files, $nfile, $hint) = @_;
        my ($command, $message) = $hint =~ /([^\|]+)\|(.*)?/;
        print "INFO: Received message : [$command]-[$message]\n";
        if ($command eq 'start-shell') {
            $$self{_GUI}{shellBtn}->clicked();
        } elsif ($command eq 'quick-conn') {
            $$self{_GUI}{connQuickBtn}->clicked();
        } elsif ($command eq 'start-uuid') {
            $self->_launchTerminals([ [ $message ] ]);
        } elsif ($command eq 'show-conn') {
            $self->_showConnectionsList();
        } elsif ($command eq 'edit-uuid') {
            my $uuid = $message;
            my $path = $$self{_GUI}{treeConnections}->_getPath($uuid) or next;
            next unless ($uuid ne '__PAC__ROOT__');
            $$self{_GUI}{treeConnections}->expand_to_path($path);
            $$self{_GUI}{treeConnections}->set_cursor($path, undef, 0);
            $$self{_GUI}{connEditBtn}->clicked();
        } else {
            print "WARN: Unknown command received ($command)\n";
        }

        return 'ok';
    });

    ###################################
    # TREECONNECTIONS RELATED CALLBACKS
    ###################################

    # Create a structure to be managed by drag and drop operations (that can be used to start a new connection)
    my $target_new_connection = Gtk3::TargetEntry->new('asbru/connection', ${Gtk3::TargetFlags->new (qw/same-app/)}, 0);

    # Enable a drag and drop destination on which a new connection can be started
    my $drag_dest = $$self{_CFG}{'defaults'}{'tabs in main window'} ? $$self{_GUI}{vboxConnectionPanel} : $$self{_GUI}{nb};
    $drag_dest->drag_dest_set('GTK_DEST_DEFAULT_ALL', [ $target_new_connection ], [ 'move' ]);

    # Handle drag and drop events
    $drag_dest->signal_connect('drag_motion' => sub {
        $_[0]->get_parent_window()->raise();
        return 0;
    });
    $drag_dest->signal_connect('drag_drop' => sub {
        my ($me, $context, $x, $y, $data, $info, $time) = @_;
        my @idx;
        my %tmp;

        foreach my $uuid (@{ $$self{'DND'}{'selection'} }) {
            if (($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) || ($uuid eq '__PAC__ROOT__')) {
                if (!_wConfirm($$self{_GUI}{main}, "<b>ATTENTION!!</b> You have dropped some group(s)\nAre you sure you want to start <b>ALL</b> of its child connections?")) {
                    return 1;
                }
                map $tmp{$_} = 1, $$self{_GUI}{treeConnections}->_getChildren($uuid, 0, 1);
            } else {
                $tmp{$uuid} = 1;
            }
        }
        foreach my $uuid (keys %tmp) {
            push(@idx, [ $uuid, 'tab' ]);
        }
        $self->_launchTerminals(\@idx);
        delete $$self{'DND'}{'selection'};
        return 1;
    });

    # Prepare common signalhandler for all three trees (DnD and tooltips)
    foreach my $what ('treeConnections', 'treeFavourites', 'treeHistory') {
        # This tree ($what) will be a drag target for itself
        my $target_tree = Gtk3::TargetEntry->new('GTK_TREE_MODEL_ROW', ${Gtk3::TargetFlags->new (qw/same-widget/)}, 1);
        $$self{_GUI}{$what}->enable_model_drag_dest([ $target_tree ], [ 'default', 'move' ]);

        # This tree will be a drag source several targets
        $$self{_GUI}{$what}->enable_model_drag_source('GDK_BUTTON1_MASK', [ $target_new_connection, $target_tree ], [ 'default', 'move' ]);

        # Render tooltip on tree nodes
        $$self{_GUI}{$what}->signal_connect('query_tooltip' => sub {
            my ($widget, $x, $y, $keyboard_tooltip, $tooltip_widget) = @_;

            if (!$$self{_CFG}{'defaults'}{'show connections tooltips'}) {
                return 0;
            }

            my ($bx, $by) = $$self{_GUI}{$what}->convert_widget_to_bin_window_coords($x, $y);
            my ($path, $col, $cx, $cy) = $$self{_GUI}{$what}->get_path_at_pos($bx, $by);
            if (!$path) {
                return 0;
            }
            my $model = $$self{_GUI}{$what}->get_model();
            my $uuid = $model->get_value($model->get_iter($path), 2);

            if ($$self{_CFG}{environments}{$uuid}{_is_group} || $uuid eq '__PAC__ROOT__') {
                return 0;
            }

            my $name = $$self{_CFG}{'environments'}{$uuid}{'name'};
            my $method = $$self{_CFG}{'environments'}{$uuid}{'method'};
            my $ip = $$self{_CFG}{'environments'}{$uuid}{'ip'};
            my $port = $$self{_CFG}{'environments'}{$uuid}{'port'};
            my $user = $$self{_CFG}{'environments'}{$uuid}{'user'};

            my $total_exp = 0;
            foreach my $exp (@{$$self{_CFG}{'environments'}{$uuid}{'expect'}}) {
                if (!$$exp{'active'}) {
                    next;
                }
                ++$total_exp;
            }
            $ip =~ s/<.+?\|.+?>/******/;
            $user =~ s/<.+?\|.+?>/******/;
            my $string = "- <b>Name</b>: @{[__($name)]}\n";
            $string .= "- <b>Method</b>: $method\n";
            $string .= "- <b>IP / port</b>: @{[__($ip)]}:$port\n";
            $string .= "- <b>User</b>: @{[__($user)]}";
            if ($total_exp) {
                $string .= "- With $total_exp active <b>Expects</b>";
            }
            $string = _subst($string, $$self{_CFG}, $uuid);
            $tooltip_widget->set_markup($string);

            return 1;
        });

        $$self{_GUI}{$what}->signal_connect('drag_begin' => sub {
            my ($tree, $context) = @_;
            my @sel = $$self{_GUI}{$what}->_getSelectedUUIDs();

            # No drag and drop for the root node
            if ($sel[0] eq '__PAC__ROOT__') {
                delete $$self{'DND'}{'selection'};
                return;
            }

            # Remember information about the dragged item
            $$self{'DND'}{'context'} = $context;
            $$self{'DND'}{'text'} = '';
            @{ $$self{'DND'}{'selection'} } = @sel;
        });

        $$self{_GUI}{$what}->signal_connect('drag_failed' => sub {
            my ($w, $px, $py) = $$self{_GUI}{main}->get_window()->get_pointer();
            my $wsx = $$self{_GUI}{main}->get_window()->get_width();
            my $wsy = $$self{_GUI}{main}->get_window()->get_height();

            if ($$self{_VERBOSE}) {
                print("drag failed $_[2] \n");
            }

            # User cancelled the drop operation (or time out), do not process further
            # (only consider valid DnD that did not end up onto a valid target
            if ($_[2] ne 'no-target') {
                delete $$self{'DND'}{'selection'};
                return 1;
            }

            # Drop happened out of window: launch terminals
            if ($px < 0 || $py < 0 || $px > $wsx || $py > $wsy) {
                my @idx;
                my %tmp;

                foreach my $uuid (@{ $$self{'DND'}{'selection'} }) {
                    if (($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) || ($uuid eq '__PAC__ROOT__')) {
                        if (!_wConfirm($$self{_GUI}{main}, "<b>ATTENTION!!</b> You have dropped some group(s)\nAre you sure you want to start <b>ALL</b> of its child connections?")) {
                            return 1;
                        }
                        map $tmp{$_} = 1, $$self{_GUI}{treeConnections}->_getChildren($uuid, 0, 1);
                    } else {
                        $tmp{$uuid} = 1;
                    }
                }
                foreach my $uuid (keys %tmp) {
                    push(@idx, [ $uuid, 'window' ]);
                }
                $self->_launchTerminals(\@idx);
                delete $$self{'DND'}{'selection'};
                return 1;
            }

            # Drop happened inside of window: finish
            delete $$self{'DND'}{'selection'};
            return 1;
        });

        $$self{_GUI}{$what}->signal_connect('drag_drop' => sub {
            my ($tree, $context, $x, $y, $time) = @_;
            my ($dest_path, $position) = $tree->get_dest_row_at_pos($x, $y);
            my $model = $tree->get_model();
            my ($src_uuid, $src, $dest_uuid, $dest);

            if ($$self{'DND'}{'selection'} && @{$$self{'DND'}{'selection'}}) {
                $src_uuid = @{$$self{'DND'}{'selection'}}[0];
                $src = $$self{_CFG}{'environments'}{$src_uuid};
            }
            if ($model->get_iter($dest_path)) {
                $dest_uuid = $model->get_value($model->get_iter($dest_path), 2);
                $dest = $$self{_CFG}{'environments'}{$dest_uuid};
            }

            if (!$src_uuid || !$dest_uuid || $src_uuid eq $dest_uuid) {
                # No source, no destination or they are equal, nothing to do
                return 1;
            }

            if ($$self{_VERBOSE}) {
                print("Drag drop on $what ; $tree ; $context ; $time ; ($dest_path, $position)\n");
                print("--------------------------------------------\n");
                print("Drag source:\n");
                print("UUID = {$src_uuid}\n");
                print("Name = [" . $$src{'name'} . "], Is Group? = [" . $$src{'_is_group'} . "]\n");
                print("--------------------------------------------\n");
                print("Drag destination:\n");
                print("UUID = {$dest_uuid}\n");
                print("Name = [" . $$dest{'name'} . "], Is Group? = [" . $$dest{'_is_group'} . "]\n");
                print("--------------------------------------------\n");
            }

            $self->_cutNodes([ $src_uuid ]);

            foreach my $copy_uuid (keys %{ $$self{_COPY}{'data'}{'__PAC__COPY__'}{'children'} }) {
                $self->_pasteNodes($dest_uuid, $copy_uuid);
                $tree->_setTreeFocus($copy_uuid);
            }
            $$self{_COPY}{'data'} = {};

            return 1;
        });

    }

    # Capture mouse motion and show the connections list if the cursor is near the borders of the "info" panel
    if ($$self{_CFG}{defaults}{'tabs in main window'} && !$$self{_CFG}{'defaults'}{'prevent mouse over show tree'}) {
        sub _autoShowConnectionsList {
            my $self = shift;
            my $x = shift;

            if (!defined($self)) {
                return 0;
            }

            my ($vbInfo_x, $vbInfo_y) = $$self{_GUI}{vboxInfo}->get_window()->get_origin();
            if ($$self{_CFG}{defaults}{'tree on right side'}) {
                my ($dummy_x, $dummy_y, $vbInfo_width, $vbInfo_height) = $$self{_GUI}{vboxInfo}->get_window()->get_geometry();
                $$self{_GUI}{showConnBtn}->set_active($x >= $vbInfo_x + $vbInfo_width - 30);
            } else {
                $$self{_GUI}{showConnBtn}->set_active($x <= $vbInfo_x + 10);
            }
            return 0;
        }

        $$self{_GUI}{vboxInfo}->signal_connect('motion_notify_event', sub {
            _autoShowConnectionsList($self, $_[1]->x_root);
        });
        $$self{_GUI}{ebFrameStatistics}->signal_connect('motion_notify_event', sub {
            _autoShowConnectionsList($self, $_[1]->x_root);
        });
        $$self{_GUI}{ebFrameScreenshots}->signal_connect('motion_notify_event', sub {
            _autoShowConnectionsList($self, $_[1]->x_root);
        });
    }

    # Capture 'add group' button clicked
    $$self{_GUI}{groupAddBtn}->signal_connect('clicked' => sub {
        my @groups = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
        my $group_uuid = $groups[0];
        my $parent_name = $$self{_CFG}{'environments'}{$group_uuid}{'name'} // 'My Connections';
        if (!(($group_uuid eq '__PAC__ROOT__') || $$self{_CFG}{'environments'}{$group_uuid}{'_is_group'})) {
            return 1;
        }

        my $new_group = _wEnterValue($$self{_GUI}{main}, "<b>Creating new group</b>"  , "Enter a name for the new group under '$parent_name'");
        if ((! defined $new_group) || ($new_group =~ /^\s*$/go) || ($new_group eq '__PAC__ROOT__')) {
            return 1;
        }

        # Generate the UUID for the new Group
        my $uuid = OSSP::uuid->new(); $uuid->make("v4");
        my $txt_uuid = $uuid->export("str");
        undef $uuid;

        # Add this new group to the list of children of it's parent
        $$self{_CFG}{'environments'}{$group_uuid}{'children'}{$txt_uuid} = 1;

        # Add the new group to the configuration
        $$self{_CFG}{'environments'}{$txt_uuid}{'_is_group'} = 1;
        $$self{_CFG}{'environments'}{$txt_uuid}{'name'} = $new_group;
        $$self{_CFG}{'environments'}{$txt_uuid}{'uuid'} = $txt_uuid;
        $$self{_CFG}{'environments'}{$txt_uuid}{'description'} = "Connection group '$new_group'";
        $$self{_CFG}{'environments'}{$txt_uuid}{'screenshots'} = [];
        $$self{_CFG}{'environments'}{$txt_uuid}{'children'} = {};
        $$self{_CFG}{'environments'}{$txt_uuid}{'parent'} = $group_uuid // '__PAC__ROOT__';

        # Add the new group to the PACTree
        $$self{_GUI}{treeConnections}->_addNode($$self{_CFG}{'environments'}{$txt_uuid}{'parent'}, $txt_uuid, $self->__treeBuildNodeName($txt_uuid), $GROUPICON);

        # Now, expand parent's group and focus the new connection
        $$self{_GUI}{treeConnections}->_setTreeFocus($txt_uuid);

        $FUNCS{_TRAY}->set_tray_menu();
        $self->_setCFGChanged(1);
        return 1;
    });

    # Capture 'rename node' button clicked
    $$self{_GUI}{nodeRenBtn}->signal_connect('clicked' => sub {
        my $selection = $$self{_GUI}{treeConnections}->get_selection();
        my $modelsort = $$self{_GUI}{treeConnections}->get_model();
        my $model = $modelsort->get_model();
        my ($path) = _getSelectedRows($selection);
        if (!defined $path) {
            return 1;
        }
        my $node_uuid = $model->get_value($modelsort->convert_iter_to_child_iter($modelsort->get_iter($path)), 2);
        my $node = $$self{_CFG}{'environments'}{$node_uuid}{'name'};

        if ($$self{_CFG}{'environments'}{$node_uuid}{'_protected'}) {
            return _wMessage($$self{_GUI}{main}, "Cannot rename selection:\nSelected node is <b>Protected</b>");
        }

        my ($new_name, $new_title);
        if ($$self{_CFG}{'environments'}{$node_uuid}{'_is_group'}) {
            $new_name = _wEnterValue($$self{_GUI}{main}, "<b>Renaming Group</b>", "Enter a new name for Group <b>$node</b>", $node);
            $new_title = 'x';
        } else {
            ($new_name, $new_title) = _wAddRenameNode('rename', $$self{_CFG}, $node_uuid);
        }
        if ((!defined $new_name)||($new_name =~ /^\s*$/go)||($new_name eq '__PAC__ROOT__')||(!defined $new_title)||($new_title =~ /^\s*$/go)) {
            return 1;
        }
        my $gui_name = $self->__treeBuildNodeName($node_uuid,$new_name);

        $model->set($modelsort->convert_iter_to_child_iter($modelsort->get_iter($path)), 1, $gui_name);
        $$self{_CFG}{'environments'}{$node_uuid}{'description'} =~ s/^Connection with \'$$self{_CFG}{environments}{$node_uuid}{name}\'/Connection with \'$new_name\'/go;
        $$self{_CFG}{'environments'}{$node_uuid}{'name'} = $new_name;
        if (!$$self{_CFG}{'environments'}{$node_uuid}{'_is_group'}) {
            $$self{_CFG}{'environments'}{$node_uuid}{'title'} = $new_title;
        }

        $self->_setCFGChanged(1);
        $FUNCS{_TRAY}->set_tray_menu();
        $self->_updateGUIWithUUID($node_uuid);
        return 1;
    });

    # Capture 'delete environment' button clicked
    $$self{_GUI}{nodeDelBtn}->signal_connect('clicked' => sub {
        my @del = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();

        if (scalar(@del) && $del[0] eq '__PAC__ROOT__') {
            return 1;
        }
        if ($self->_hasProtectedChildren(\@del)) {
            return _wMessage($$self{_GUI}{main}, "Cannot delete selection.\n\nThere are <b>protected</b> nodes selected.");
        }

        if (scalar(@del) > 1) {
            if (!_wConfirm($$self{_GUI}{main}, "Delete <b>" . (scalar(@del)) . "</b> nodes and ALL of their contents?")) {
                return 1;
            }
        } elsif (!_wConfirm($$self{_GUI}{main}, "Delete node <b>" . __($$self{_CFG}{'environments'}{ $del[0] }{'name'}) . "</b> and ALL of its contents?")) {
            return 1;
        }
        # Delete selected nodes from treeConnections
        map $$self{_GUI}{treeConnections}->_delNode($_), @del;
        # Delete selected node from the configuration
        $self->_delNodes(@del);
        $FUNCS{_TRAY}->set_tray_menu();
        $self->_setCFGChanged(1);
        return 1;
    });

    # Prepare common signalhandler for favs and hist trees (edit, row activate and lite tree menu)
    foreach my $what ('treeFavourites', 'treeHistory') {
        # Capture 'treeFavourites' keypress
        $$self{_GUI}{$what}->signal_connect('key_press_event' => sub {
            my ($widget, $event) = @_;

            my @sel = $$self{_GUI}{$what}->_getSelectedUUIDs();
            if (!@sel) {
                return 0;
            }
            my $action = $FUNCS{_KEYBINDS}->GetAction($what, $widget, $event);
            if (!$action) {
                return 0;
            }
            if ($action eq 'edit_node' && $sel[0] ne '__PAC_SHELL__') {
                $$self{_GUI}{connEditBtn}->clicked();
                return 1;
            } elsif ($action eq 'del_favourite') {
                if ($$self{_GUI}{connFavourite}->get_sensitive()) {
                    my $tree = $self->_getCurrentTree();
                    if (!$tree->_getSelectedUUIDs()) {
                        return 1;
                    }
                    $self->_setFavourite(0,$tree);
                }
                return 1;
            }
            return 0;
        });

        # Capture row double clicking (execute selected connection)
        $$self{_GUI}{$what}->signal_connect('row_activated' => sub {
            $$self{_GUI}{connExecBtn}->clicked();
            return 1;
        });

        # Capture right click
        $$self{_GUI}{$what}->signal_connect('button_release_event' => sub {
            my ($widget, $event) = @_;
            if ($event->button ne 3) {
                return 0;
            }
            if (!$$self{_GUI}{$what}->_getSelectedUUIDs()) {
                return 1;
            }
            $self->_treeConnections_menu_lite($$self{_GUI}{$what});
            return 0;
        });
    }

    # Capture selected element changed
    $$self{_GUI}{treeFavourites}->get_selection()->signal_connect('changed' => sub { $self->_updateGUIFavourites(); });
    $$self{_GUI}{treeHistory}->get_selection()->signal_connect('changed' => sub { $self->_updateGUIHistory(); });

    if ($$self{_CFG}{'defaults'}{'layout'} ne 'Compact') {
        $$self{_GUI}{btneditclu}->signal_connect('clicked' => sub {
            $$self{_CLUSTER}->show(1);
        });
    }

    # Capture 'treeClusters' row activated
    $$self{_GUI}{treeClusters}->signal_connect('row_activated' => sub {
        my @sel = $$self{_GUI}{treeClusters}->_getSelectedNames();
        $self->_startCluster($sel[0]);
    });

    $$self{_GUI}{treeClusters}->get_selection()->signal_connect('changed' => sub {
        $self->_updateGUIClusters();
    });
    $$self{_GUI}{treeClusters}->signal_connect('key_press_event' => sub {
        my ($widget, $event) = @_;

        my @sel = $$self{_GUI}{treeClusters}->_getSelectedNames();
        if (!@sel) {
            return 0;
        }
        my $action = $FUNCS{_KEYBINDS}->GetAction('treeClusters', $widget, $event);
        if (!$action) {
            return 0;
        }
        if ($action eq 'edit_node') {
            $$self{_CLUSTER}->show($sel[0]);
            return 1;
        }
    });

    # Capture 'treeconnections' keypress
    $$self{_GUI}{treeConnections}->signal_connect('key_press_event' => sub {
        my ($widget, $event) = @_;
        my @sel = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();

        my $is_group = 0;
        my $is_root = 0;
        foreach my $uuid (@sel) {
            if ($uuid eq '__PAC__ROOT__') {
                $is_root = 1;
            }
            if ($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) {
                $is_group = 1;
            }
        }
        my $action = $FUNCS{_KEYBINDS}->GetAction('treeConnections', $widget, $event);

        if (!$action) {
            return 0;
        }
        if ($action eq 'find') {
            $$self{_SHOWFINDTREE} = 1;
            $$self{_GUI}{_vboxSearch}->show();
            $$self{_GUI}{_entrySearch}->grab_focus();
        } elsif ($action eq 'expand_all') {
            $$self{_GUI}{treeConnections}->expand_all();
        } elsif ($action eq 'collaps_all') {
            $$self{_GUI}{treeConnections}->collapse_all();
        } elsif ($action eq 'clone') {
            $self->_cloneNodes();
        } elsif ($action eq 'copy') {
            $self->_copyNodes();
        } elsif ($action eq 'cut') {
            $self->_cutNodes();
        } elsif ($action eq 'paste') {
            map $self->_pasteNodes($sel[0], $_), keys %{ $$self{_COPY}{'data'}{'__PAC__COPY__'}{'children'} };
            $$self{_COPY}{'data'} = {};
            $self->_copyNodes(0,undef,$LAST_COPIED_NODES);
        } elsif ($action eq 'edit_node') {
            if (!$is_root) {
                $$self{_GUI}{connEditBtn}->clicked();
            }
        } elsif ($action eq 'connect_node') {
            if (!$is_root) {
                $$self{_GUI}{connExecBtn}->clicked();
            }
        } elsif ($action eq 'protection') {
            if (!$is_root) {
                $self->__treeToggleProtection();
            }
        } elsif ($action eq 'rename') {
            if ((scalar(@sel) == 1) && ($sel[0] ne '__PAC__ROOT__')) {
                $$self{_GUI}{nodeRenBtn}->clicked();
            }
        } elsif ($action eq 'add_favourite' || $action eq 'del_favourite') {
            if ($$self{_GUI}{connFavourite}->get_sensitive()) {
                my $tree = $self->_getCurrentTree();
                if (!$tree->_getSelectedUUIDs()) {
                    return 1;
                }
                if ($action eq 'add_favourite') {
                    $self->_setFavourite(1,$tree);
                } else {
                    $self->_setFavourite(0,$tree);
                }
            }
        } elsif ($action eq 'Delete') {
            $$self{_GUI}{nodeDelBtn}->clicked();
        } elsif ($action eq 'Left') {
            my @idx;
            foreach my $uuid (@sel) {
                push(@idx, [ $uuid ]);
            }
            if (scalar @idx != 1) {
                return 0;
            }
            my $tree = $$self{_GUI}{treeConnections};
            my $selection = $tree->get_selection();
            my $model = $tree->get_model();
            my @paths = _getSelectedRows($selection);
            my $uuid = $model->get_value($model->get_iter($paths[0]), 2);

            if (($uuid eq '__PAC__ROOT__') || ($$self{_CFG}{'environments'}{$uuid}{'_is_group'})) {
                if ($tree->row_expanded($$self{_GUI}{treeConnections}->_getPath($uuid))) {
                    $tree->collapse_row($$self{_GUI}{treeConnections}->_getPath($uuid));
                } elsif ($uuid ne '__PAC__ROOT__') {
                    $tree->set_cursor($$self{_GUI}{treeConnections}->_getPath($$self{_CFG}{'environments'}{$uuid}{'parent'}), undef, 0);
                }
            } else {
                $tree->set_cursor($$self{_GUI}{treeConnections}->_getPath($$self{_CFG}{'environments'}{$uuid}{'parent'}), undef, 0);
            }
        } elsif ($action eq 'Right') {
            my @idx;
            foreach my $uuid (@sel) {
                push(@idx, [ $uuid ]);
            }
            if (scalar @idx != 1) {
                return 0;
            }
            my $tree = $$self{_GUI}{treeConnections};
            my $selection = $tree->get_selection();
            my $model = $tree->get_model();
            my @paths = _getSelectedRows($selection);
            my $uuid = $model->get_value($model->get_iter($paths[0]), 2);
            if (!(($uuid eq '__PAC__ROOT__') || ($$self{_CFG}{'environments'}{$uuid}{'_is_group'}))) {
                return 0;
            }
            $tree->expand_row($paths[0], 0);
        } elsif ($action eq 'Return') {
            my $tree = $$self{_GUI}{treeConnections};
            my $selection = $tree->get_selection();
            my $model = $tree->get_model();
            my @paths = _getSelectedRows($selection);
            my $uuid = $model->get_value($model->get_iter($paths[0]), 2);

            if ((scalar(@paths) == 1) && (($uuid eq '__PAC__ROOT__') || ($$self{_CFG}{'environments'}{$uuid}{'_is_group'}))) {
                $tree->row_expanded($paths[0]) ? $tree->collapse_row($paths[0]) : $tree->expand_row($paths[0], 0);
            } else {
                my @idx;
                foreach my $uuid (@sel) {
                    push(@idx,[$uuid]);
                }
                $self->_launchTerminals(\@idx);
            }
        } elsif ($action eq 'Down') {
            return 0;
        } elsif ($action eq 'Up') {
            return 0;
        } elsif (($event->keyval >= 32) && ($event->keyval <= 126)) {
            # This does not consider other languages
            $$self{_SHOWFINDTREE} = 1;
            $$self{_GUI}{_vboxSearch}->show();
            $$self{_GUI}{_entrySearch}->grab_focus();
            $$self{_GUI}{_entrySearch}->insert_text(chr($event->keyval), -1, 0);
            $$self{_GUI}{_entrySearch}->set_position(-1);
        }
        return 1;
    });

    # Capture 'treeconnections' selected element changed
    $$self{_GUI}{treeConnections}->get_selection()->signal_connect('changed' => sub {
        $self->_updateGUIPreferences();
    });

    # Capture row double clicking (execute selected connection)
    $$self{_GUI}{treeConnections}->signal_connect('row_activated' => sub {
        my @idx;
        foreach my $uuid ($$self{_GUI}{treeConnections}->_getSelectedUUIDs()) {
            push(@idx, [ $uuid ]);
        }
        if (scalar @idx != 1) {
            return 0;
        }

        my $tree = $$self{_GUI}{treeConnections};
        my $selection = $tree->get_selection();
        my $model = $tree->get_model();
        my @paths = _getSelectedRows($selection);
        my $uuid = $model->get_value($model->get_iter($paths[0]), 2);

        if (($uuid eq '__PAC__ROOT__') || ($$self{_CFG}{'environments'}{$uuid}{'_is_group'})) {
            if (!(($uuid eq '__PAC__ROOT__') || ($$self{_CFG}{'environments'}{$uuid}{'_is_group'}))) {
                return 0;
            }
            $tree->row_expanded($paths[0]) ? $tree->collapse_row($paths[0]) : $tree->expand_row($paths[0], 0);
        } else {
            $$self{_GUI}{connExecBtn}->clicked();
        }
    });

    # Capture tree rows collapsing
    $$self{_GUI}{treeConnections}->signal_connect('row_collapsed' => sub {
        my ($tree, $iter, $path) = @_;

        my $selection = $$self{_GUI}{treeConnections}->get_selection();
        my $modelsort = $$self{_GUI}{treeConnections}->get_model();
        my $model = $modelsort->get_model();
        my $group_uuid = $model->get_value($modelsort->convert_iter_to_child_iter($modelsort->get_iter($path)), 2);
        $$self{_GUI}{treeConnections}->columns_autosize();
        if ($group_uuid eq '__PAC__ROOT__') {
            return 0;
        }
        $model->set($modelsort->convert_iter_to_child_iter($modelsort->get_iter($path)), 0, $GROUPICONCLOSED);
        return 1;
    });

    # Capture tree rows expanding
    $$self{_GUI}{treeConnections}->signal_connect('row_expanded' => sub {
        my ($tree, $iter, $path) = @_;

        my $selection = $$self{_GUI}{treeConnections}->get_selection();
        my $modelsort = $$self{_GUI}{treeConnections}->get_model();
        my $model = $modelsort->get_model();
        my $group_uuid = $model->get_value($modelsort->convert_iter_to_child_iter($modelsort->get_iter($path)), 2);
        if ($group_uuid eq '__PAC__ROOT__') {
            return 0;
        }
        $model->set($modelsort->convert_iter_to_child_iter($modelsort->get_iter($path)), 0, $GROUPICONOPEN);
        foreach my $child ($$self{_GUI}{treeConnections}->_getChildren($group_uuid, 1, 0)) {
            $model->set($modelsort->convert_iter_to_child_iter($modelsort->get_iter($$self{_GUI}{treeConnections}->_getPath($child))), 0, $GROUPICONCLOSED);
        }
        return 1;
    });

    # Capture 'treeconnections' right click
    $$self{_GUI}{treeConnections}->signal_connect('button_press_event' => sub {
        my ($widget, $event) = @_;
        if ($event->button eq 3) {
            if (@SELECTED_UUIDS && $#SELECTED_UUIDS>0) {
                # There are selected rows, abort reselecting
                return 1;
            }
        }
        return 0;
    });

    $$self{_GUI}{treeConnections}->signal_connect('button_release_event' => sub {
        my ($widget, $event) = @_;

        if ($event->button ne 3) {
            # Load selected rows from left click
            @SELECTED_UUIDS = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
            return 0;
        }
        if (!@SELECTED_UUIDS || $#SELECTED_UUIDS<1) {
            # There is only one selected element, is obsolete, selecte the current one
            @SELECTED_UUIDS = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
        }
        $self->_treeConnections_menu($event);
        return 1;
    });

    # Capture 'add connection' button clicked
    $$self{_GUI}{connAddBtn}->signal_connect('clicked' => sub {
        my @groups = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
        my $group_uuid = $groups[0];
        if (!(($group_uuid eq '__PAC__ROOT__') || $$self{_CFG}{'environments'}{$group_uuid}{'_is_group'})) {
            return 1;
        }
        # Prepare the input window
        my ($new_conn, $new_title) = _wAddRenameNode('add', $$self{_CFG}, $group_uuid);
        if ((! defined $new_conn) || ($new_conn =~ /^\s*$/go) || ($new_conn eq '__PAC__ROOT__')) {
            return 1;
        }
        my $uuid = OSSP::uuid->new(); $uuid->make("v4");
        my $txt_uuid = $uuid->export("str");
        undef $uuid;

        # Create and initialize the new connection in configuration
        $$self{_CFG}{'environments'}{$txt_uuid}{'_is_group'} = 0;
        $$self{_CFG}{'environments'}{$txt_uuid}{'name'} = $new_conn;
        $$self{_CFG}{'environments'}{$txt_uuid}{'parent'} = $group_uuid;
        $$self{_CFG}{'environments'}{$txt_uuid}{'description'} = "Connection with '$new_conn'";
        $$self{_CFG}{'environments'}{$txt_uuid}{'screenshots'} = [];
        $$self{_CFG}{'environments'}{$txt_uuid}{'title'} = $new_title;
        $$self{_CFG}{'environments'}{$txt_uuid}{'method'} = 'ssh';
        $$self{_CFG}{'environments'}{$txt_uuid}{'ip'} = '';
        $$self{_CFG}{'environments'}{$txt_uuid}{'port'} = 22;
        $$self{_CFG}{'environments'}{$txt_uuid}{'user'} = '';
        $$self{_CFG}{'environments'}{$txt_uuid}{'pass'} = '';
        $$self{_CFG}{'environments'}{$txt_uuid}{'use proxy'} = 0;
        $$self{_CFG}{'environments'}{$txt_uuid}{'options'} = '';
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'local before'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'local connected'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'local after'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'macros'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'expect'} } = ();

        _cfgSanityCheck($$self{_CFG});

        # Add the node to the tree
        $$self{_GUI}{treeConnections}->_addNode($$self{_CFG}{'environments'}{$txt_uuid}{'parent'}, $txt_uuid, $self->__treeBuildNodeName($txt_uuid), $$self{_METHODS}{ $$self{_CFG}{'environments'}{$txt_uuid}{'method'} }{'icon'});
        $$self{_GUI}{treeConnections}->_setTreeFocus($txt_uuid);

        # Add the node to the parent's childs list
        $$self{_CFG}{'environments'}{$group_uuid}{'children'}{$txt_uuid} = 1;

        $self->_updateGUIPreferences();

        $$self{_EDIT}->show($txt_uuid, 'new');

        $FUNCS{_TRAY}->set_tray_menu();
        $self->_setCFGChanged(1);
        return 1;
    });

    # Capture 'quick connect' button clicked
    $$self{_GUI}{connQuickBtn}->signal_connect('clicked' => sub {
        my $txt_uuid = '__PAC__QUICK__CONNECT__';

        # Create and initialize the new connection in configuration
        $$self{_CFG}{'environments'}{$txt_uuid}{'_is_group'} = 0;
        $$self{_CFG}{'environments'}{$txt_uuid}{'name'} = 'Quick Connect';
        $$self{_CFG}{'environments'}{$txt_uuid}{'parent'} = '__PAC__ROOT__';
        $$self{_CFG}{'environments'}{$txt_uuid}{'description'} = 'Quick Connection';
        $$self{_CFG}{'environments'}{$txt_uuid}{'screenshots'} = [];
        $$self{_CFG}{'environments'}{$txt_uuid}{'title'} = 'Quick Connect';
        $$self{_CFG}{'environments'}{$txt_uuid}{'method'} = 'ssh';
        $$self{_CFG}{'environments'}{$txt_uuid}{'ip'} = '';
        $$self{_CFG}{'environments'}{$txt_uuid}{'port'} = 22;
        $$self{_CFG}{'environments'}{$txt_uuid}{'user'} = '';
        $$self{_CFG}{'environments'}{$txt_uuid}{'pass'} = '';
        $$self{_CFG}{'environments'}{$txt_uuid}{'use proxy'} = 0;
        $$self{_CFG}{'environments'}{$txt_uuid}{'options'} = '';
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'local before'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'local connected'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'local after'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'macros'} } = ();
        @{ $$self{_CFG}{'environments'}{$txt_uuid}{'expect'} } = ();

        _cfgSanityCheck($$self{_CFG});

        $$self{_EDIT}->show($txt_uuid, 'quick');

        return 1;
    });

    ###############################
    # OTHER CALLBACKS
    ###############################

    $$self{_GUI}{connSearch}->signal_connect('clicked' => sub {
        if (!$$self{_GUI}{_vboxSearch}->get_visible) {
            $$self{_SHOWFINDTREE} = 1;
            $$self{_GUI}{_vboxSearch}->show();
            $$self{_GUI}{_entrySearch}->grab_focus();
        } else {
            $$self{_SHOWFINDTREE} = 0;
            $$self{_GUI}{_vboxSearch}->hide();
        }
    });
    $$self{_GUI}{_entrySearch}->signal_connect('key_press_event' => sub {
        my ($widget, $event) = @_;
        # Capture 'escape' keypress to hide the interactive search

        my $action = $FUNCS{_KEYBINDS}->GetAction('pactabs', $widget, $event);

        if ($action eq 'Escape') {
            $$self{_SHOWFINDTREE} = 0;
            $$self{_GUI}{_entrySearch}->set_text('');
            $$self{_GUI}{_vboxSearch}->hide();
            $$self{_GUI}{treeConnections}->grab_focus();
            return 1;
        }
        # Capture 'up arrow'  keypress to move to previous ocurrence
        elsif ($action eq 'Up') {
            $$self{_GUI}{_btnPrevSearch}->clicked();
            return 1;
        }
        # Capture 'down arrow'  keypress to move to next ocurrence
        elsif ($action eq 'Down') {
            $$self{_GUI}{_btnNextSearch}->clicked();
            return 1;
        }
        return 0
    });

    $$self{_GUI}{_entrySearch}->signal_connect('activate' => sub {
        my @sel = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
        if ((scalar(@sel)==1)&&($sel[0] ne '__PAC__ROOT__')&&(!$$self{_CFG}{'environments'}{$sel[0]}{'_is_group'})&&($$self{_GUI}{_entrySearch}->get_chars(0, -1) ne '')) {
            $$self{_GUI}{connExecBtn}->clicked();
        }
    });
    $$self{_GUI}{_entrySearch}->signal_connect('focus_out_event' => sub {
        $$self{_SHOWFINDTREE} = 0;
        $$self{_GUI}{_vboxSearch}->hide();
        $$self{_GUI}{_entrySearch}->set_text('');
    });
    foreach my $what ('Name', 'Host', 'Desc') {
        $$self{_GUI}{"_rbSearch" . $what}->signal_connect('toggled' => sub {
            my $text = $$self{_GUI}{_entrySearch}->get_chars(0, -1);
            $$self{_GUI}{_btnPrevSearch}->set_sensitive(0);
            $$self{_GUI}{_btnNextSearch}->set_sensitive(0);
            if ($text eq '') {
                return 0;
            }
            my $where = 'name';
            $$self{_GUI}{_rbSearchHost}->get_active() and $where = 'host';
            $$self{_GUI}{_rbSearchDesc}->get_active() and $where = 'desc';
            $$self{_GUI}{_RESULT} = $self->__search($text, $$self{_GUI}{treeConnections}, $where);
            $$self{_GUI}{_ACTUAL} = 0;
            if (@{ $$self{_GUI}{_RESULT} }) {
                $$self{_GUI}{_btnPrevSearch}->set_sensitive(1);
                $$self{_GUI}{_btnNextSearch}->set_sensitive(1);
                $$self{_GUI}{treeConnections}->_setTreeFocus($$self{_GUI}{_RESULT}[ $$self{_GUI}{_ACTUAL} ]);
            }
            return 0;
        });
    }
    $$self{_GUI}{_entrySearch}->signal_connect('changed' => sub {
        my $text = $$self{_GUI}{_entrySearch}->get_chars(0, -1);
        $$self{_GUI}{_btnPrevSearch}->set_sensitive(0);
        $$self{_GUI}{_btnNextSearch}->set_sensitive(0);
        if ($text eq '') {
            return 0;
        }
        my $where = 'name';
        $$self{_GUI}{_rbSearchHost}->get_active() and $where = 'host';
        $$self{_GUI}{_rbSearchDesc}->get_active() and $where = 'desc';
        $$self{_GUI}{_RESULT} = $self->__search($text, $$self{_GUI}{treeConnections}, $where);
        $$self{_GUI}{_ACTUAL} = 0;
        if (@{ $$self{_GUI}{_RESULT} }) {
            $$self{_GUI}{_btnPrevSearch}->set_sensitive(1);
            $$self{_GUI}{_btnNextSearch}->set_sensitive(1);
            $$self{_GUI}{treeConnections}->_setTreeFocus($$self{_GUI}{_RESULT}[ $$self{_GUI}{_ACTUAL} ]);
        } else {
            $$self{_GUI}{_btnPrevSearch}->set_sensitive(0);
            $$self{_GUI}{_btnNextSearch}->set_sensitive(0);
            $$self{_GUI}{treeConnections}->_setTreeFocus('__PAC__ROOT__');
        }
        return 0;
    });

    $$self{_GUI}{_btnPrevSearch}->signal_connect('clicked' => sub {
        if (!@{$$self{_GUI}{_RESULT}}) {
            return 1;
        }
        if ($$self{_GUI}{_ACTUAL} == 0) {
            $$self{_GUI}{_ACTUAL} = $#{$$self{_GUI}{_RESULT}};
        } else {
            $$self{_GUI}{_ACTUAL}--;
        }
        $$self{_GUI}{treeConnections}->_setTreeFocus($$self{_GUI}{_RESULT}[$$self{_GUI}{_ACTUAL}]);
        return 1;
    });

    $$self{_GUI}{_btnNextSearch}->signal_connect('clicked' => sub {
        if (!@{$$self{_GUI}{_RESULT}}) {
            return 1;
        }
        if ($$self{_GUI}{_ACTUAL} == $#{ $$self{_GUI}{_RESULT} }) {
            $$self{_GUI}{_ACTUAL} = 0;
        } else {
            $$self{_GUI}{_ACTUAL}++;
        }
        $$self{_GUI}{treeConnections}->_setTreeFocus($$self{_GUI}{_RESULT}[ $$self{_GUI}{_ACTUAL} ]);
        return 1;
    });

    $$self{_GUI}{showConnBtn}->signal_connect('toggled' => sub {
        $self->_doToggleDisplayConnectionsList();
        return 1;
    });

    # Catch buttons' keypresses
    $$self{_GUI}{connExecBtn}->signal_connect('clicked' => sub {
        my ($tree,@idx,%tmp);
        my $pnum = $$self{_GUI}{nbTree}->get_current_page();
        if  ($$self{_GUI}{nbTree}->get_nth_page($pnum) eq $$self{_GUI}{scroll1}) {
            $tree = $$self{_GUI}{treeConnections};
        } elsif ($$self{_GUI}{nbTree}->get_nth_page($pnum) eq $$self{_GUI}{scroll2}) {
            $tree = $$self{_GUI}{treeFavourites};
        } elsif ($$self{_GUI}{nbTree}->get_nth_page($pnum) eq $$self{_GUI}{scroll3}) {
            $tree = $$self{_GUI}{treeHistory};
        } else {
            my @sel = $$self{_GUI}{treeClusters}->_getSelectedNames();
            $self->_startCluster($sel[0]);
            return 1;
        }
        if (!$tree->_getSelectedUUIDs()) {
            return 1;
        }
        foreach my $uuid ($tree->_getSelectedUUIDs()) {
            if (($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) || ($uuid eq '__PAC__ROOT__')) {
                my @children = $$self{_GUI}{treeConnections}->_getChildren($uuid, 0, 1);
                foreach my $child (@children) {
                    if (!$$self{_CFG}{'environments'}{$child}{'_is_group'}) {
                        $tmp{$child} = 1;
                    }
                }
            } else {
                $tmp{$uuid} = 1;
            }
        }
        map push(@idx,[$_]),keys %tmp;
        $self->_launchTerminals(\@idx);
    });
    $$self{_GUI}{configBtn}->signal_connect('clicked' => sub {
        $$self{_CONFIG}->show();
    });
    $$self{_GUI}{connEditBtn}->signal_connect('clicked' => sub {
        my $tree = $self->_getCurrentTree();
        my @sel = $tree->_getSelectedUUIDs();

        if (!scalar(@sel)) {
            return 1;
        }
        my $is_group = 0;
        my $is_root = 0;

        foreach my $uuid (@sel) {
            if ($uuid eq '__PAC__ROOT__') {
                $is_root = 1;
            }
            if ($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) {
                $is_group = 1;
            }
        }
        if (((scalar(@sel)>1) || ((scalar(@sel)==1) && $is_group)) && ($self->_hasProtectedChildren(\@sel))) {
            return _wMessage($$self{_GUI}{main}, "Cannot " . (scalar(@sel) > 1 ? 'Bulk ' : ' ') . "Edit selection:\nThere are <b>Protected</b> nodes selected");
        }

        if ((scalar(@sel) == 1) && (! $is_group)) {
            $$self{_EDIT}->show($sel[0]);
        } elsif ((scalar(@sel) > 1) || ((scalar(@sel) == 1) && $is_group)) {
            my ($list, $all) = $self->_bulkEdit("$APPNAME (v$APPVERSION) : Bulk Edit", "Bulk Editing <b>" . scalar(@sel) . "</b> nodes.\nSelect and change the values you want to modify in the list below.\n<b>Only those checked will be affected.</b>\nFor Regular Expressions, <b>Match pattern</b> will substituted with <b>New value</b>,\nmuch like Perl's: <b>s/<span foreground=\"#E60023\">Match pattern</span>/<span foreground=\"#04C100\">New value</span>/g</b>", $is_group);
            if (!defined $list) {
                return 1;
            }
            foreach my $parent_uuid (@sel) {
                if ($$self{_CFG}{'environments'}{$parent_uuid}{'_is_group'} || $parent_uuid eq '__PAC__ROOT__') {
                    foreach my $uuid ($$self{_GUI}{treeConnections}->_getChildren($parent_uuid, 0, $all)) {
                        _substCFG($$self{_CFG}{'environments'}{$uuid}, $list);
                    }
                } else {
                    _substCFG($$self{_CFG}{'environments'}{$parent_uuid}, $list);
                }
            }
            $self->_setCFGChanged(1);
        }
    });
    $$self{_GUI}{shellBtn}->signal_connect('clicked' => sub {
        $self->_launchTerminals([[ '__PAC_SHELL__' ]]);
        return 1;
    });
    $$self{_GUI}{clusterBtn}->signal_connect('clicked' => sub {
        $$self{_CLUSTER}->show();
    });
    $$self{_GUI}{connFavourite}->signal_connect('toggled' => sub {
        if ($$self{_NO_PROPAGATE_FAV_TOGGLE}) {
            return 1;
        }
        my $tree = $self->_getCurrentTree();
        if (!$tree->_getSelectedUUIDs()) {
            return 1;
        }
        $self->_setFavourite($$self{_GUI}{connFavourite}->get_active(),$tree);
        return 1;
    });
    $$self{_GUI}{scriptsBtn}->signal_connect('clicked' => sub { $$self{_SCRIPTS}->show(); });
    $$self{_GUI}{pccBtn}->signal_connect('clicked' => sub { $$self{_PCC}->show(); });
    $$self{_GUI}{quitBtn}->signal_connect('clicked' => sub { $self->_quitProgram(); });
    $$self{_GUI}{saveBtn}->signal_connect('clicked' => sub { $self->_saveConfiguration(); });
    $$self{_GUI}{aboutBtn}->signal_connect('clicked' => sub { $self->_showAboutWindow(); });
    $$self{_GUI}{wolBtn}->signal_connect('clicked' => sub { _wakeOnLan(); });
    $$self{_GUI}{lockApplicationBtn}->signal_connect('toggled' => sub {
        if ($$self{_GUI}{lockApplicationBtn}->get_active()) {
            $self->_lockAsbru();
        } else {
            $self->_unlockAsbru();
        }
    });
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{nodeClose}->signal_connect('clicked' => sub { $$self{_GUI}{main}->close(); });
    }

    # Capture CONN TAB page switching
    $$self{_GUI}{nbTree}->signal_connect('switch_page' => sub {
        my ($nb, $p, $pnum) = @_;

        $$self{_NO_PROPAGATE_FAV_TOGGLE} = 1;
        $$self{_GUI}{connFavourite}->set_active(0);
        $$self{_GUI}{connFavourite}->set_sensitive(0);
    $$self{_GUI}{connFavourite}->set_image(PACIcons::icon_image('favourite_off','asbru-favourite-off'));
        $$self{_NO_PROPAGATE_FAV_TOGGLE} = 0;

        my $page = $$self{_GUI}{nbTree}->get_nth_page($pnum);

        if ($page eq $$self{_GUI}{scroll1}) {
            # Connections
            $self->_updateGUIPreferences();
        } elsif ($page eq $$self{_GUI}{scroll2}) {
            # Favourites
            $self->_updateFavouritesList();
            $self->_updateGUIFavourites();
        } elsif ($page eq $$self{_GUI}{scroll3}) {
            # History
            $self->_updateGUIHistory();
        } else {
            # Clusters
            $self->_updateClustersList();
            $self->_updateGUIClusters();
        }
        return 1;
    });

    # Capture tabs events on pactabs window
    $$self{_GUI}{nb}->signal_connect('page_removed' => sub {
        if (!defined $$self{_GUI}{_PACTABS}) {
            return 1;
        }
        if ($$self{_GUI}{nb}->get_n_pages == 0) {
            $$self{_GUI}{_PACTABS}->hide();
        } elsif ($$self{_GUI}{nb}->get_n_pages == 1) {
            $$self{_GUI}{treeConnections}->grab_focus();
            $$self{_GUI}{showConnBtn}->set_active(1);

            if ($$self{_CFG}{defaults}{'when no more tabs'} == 0) {
                #nothing
            } elsif ($$self{_CFG}{defaults}{'when no more tabs'} == 1) {
                #quit
                $self->_quitProgram();
            } elsif ($$self{_CFG}{defaults}{'when no more tabs'} == 2) {
                #hide
                $$self{_TRAY}->set_active();
                # Trigger the "lock" procedure ?
                if ($$self{_CFG}{'defaults'}{'use gui password'} && $$self{_CFG}{'defaults'}{'use gui password tray'}) {
                    $$self{_GUI}{lockApplicationBtn}->set_active(1);
                }
                # Hide main window
                $self->_hideConnectionsList();
            }
        }
        return 1;
    });
    $$self{_GUI}{nb}->signal_connect('page_added' => sub {
        if (defined $$self{_GUI}{_PACTABS}) {
            if ($$self{_GUI}{nb}->get_n_pages) {
                $$self{_GUI}{_PACTABS}->show();
            }
        }
        return 1;
    });

    # Capture TABs window closing
    ! $$self{_CFG}{defaults}{'tabs in main window'} and $$self{_GUI}{_PACTABS}->signal_connect('delete_event' => sub {
        if ($$self{_GUILOCKED} || ! _wConfirm($$self{_GUI}{_PACTABS}, "Close <b>TABBED TERMINALS</b> Window ?")) {
            return 1;
        }
        foreach my $uuid (keys %RUNNING) {
            # Should && this two together, will leave it for another time
            if (!defined $RUNNING{$uuid}{'terminal'}) {
                next;
            }
            if (!($RUNNING{$uuid}{'terminal'}{_TABBED} || $RUNNING{$uuid}{'terminal'}{_RETABBED})) {
                next;
            }
            $RUNNING{$uuid}{'terminal'}->stop('force');
        }
        return 1;
    });

    # Capture some keypress on TABBED window
    $$self{_GUI}{_PACTABS}->signal_connect('key_press_event' => sub {
        my ($widget, $event) = @_;
        # Get current page's tab number
        my $curr_page = $$self{_GUI}{nb}->get_current_page();

        my $action = $FUNCS{_KEYBINDS}->GetAction('pactabs', $widget, $event);

        if (!$action) {
            return 0;
        } elsif ($action eq 'infotab') {
            $$self{_GUI}{nb}->set_current_page(0);
        } elsif ($action eq 'last') {
            $$self{_GUI}{nb}->set_current_page($$self{_PREVTAB});
        } elsif ($action eq 'next') {
            if ($curr_page == $$self{_GUI}{nb}->get_n_pages - 1) {
                $$self{_GUI}{nb}->set_current_page(0);
            } else {
                $$self{_GUI}{nb}->next_page();
            }
        } elsif ($action eq 'previous') {
            if ($curr_page == 0) {
                $$self{_GUI}{nb}->set_current_page(-1);
            } else {
                $$self{_GUI}{nb}->prev_page();
            }
        } elsif ($action eq 'Ctrl+0') {
            # Special case: if Ctrl+0 is not bind to an action then ignore it
            return 0;
        } elsif ($action =~ /^Ctrl\+(\d+)/) {
            my $n = $1;
            $$self{_GUI}{nb}->set_current_page($n - ($$self{_CFG}{'defaults'}{'tabs in main window'} ? 0 : 1));
        } else {
            return 0;
        }
        return 1;
    });

    # Capture some keypress on Description widget
    $$self{_GUI}{descView}->signal_connect('key_press_event' => sub {
        my ($widget, $event) = @_;
        my $keyval = '' . ($event->keyval);
        my $state = '' . ($event->state);

        my $action = $FUNCS{_KEYBINDS}->GetAction('pactabs', $widget, $event);

        # Check if <Ctrl>z is pushed
        if ($action eq 'Ctrl+z' || $action eq 'Ctrl+Z') {
            $$self{_GUI}{descBuffer}->set_text(pop(@{ $$self{_UNDO} }));
            return 1;
        }
        return 0;
    });

    # Capture text changes on Description widget
    $$self{_GUI}{descBuffer}->signal_connect('begin_user_action' => sub {
        $self->_setCFGChanged(1);
        push(@{ $$self{_UNDO} }, $$self{_GUI}{descBuffer}->get_property('text'));
        return 0;
    });

    $$self{_GUI}{descBuffer}->signal_connect('changed' => sub {
        my @sel = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
        if (!(scalar(@sel) == 1 && $$self{_GUI}{nbTree}->get_current_page() == 0 && $$self{_GUI}{descView}->is_sensitive)) {
            return 0;
        }
        $$self{_CFG}{environments}{$sel[0]}{description} = $$self{_GUI}{descBuffer}->get_property('text');
        return 0;
    });

    # Capture TAB page switching
    $$self{_GUI}{nb}->signal_connect('switch_page' => sub {
        my ($nb, $p, $pnum) = @_;

        $$self{_PREVTAB} = $nb->get_current_page();

        $self->_doFocusPage($pnum);

        # Show/hide the button bar
        $$self{_GUI}{hbuttonbox1}->set_visible($pnum == 0 || !$$self{'_CFG'}{'defaults'}{'auto hide button bar'});

        # Show/hide the connections list
        if (($pnum == 0)&&($$self{_CFG}{'defaults'}{'auto hide connections list'})) {
            # Info Tab, show connection list
            $$self{_GUI}{showConnBtn}->set_active(1);
        } elsif (($$self{_CFG}{'defaults'}{'auto hide connections list'})&&($$self{_GUI}{showConnBtn}->get_active())) {
            $$self{_GUI}{showConnBtn}->set_active(0);
        }
        return 1;
    });

    # Capture window closing
    $$self{_GUI}{main}->signal_connect('delete_event' => sub {
        if ($$self{_CFG}{defaults}{'close to tray'}) {
            # Show tray icon
            $$self{_TRAY}->set_active();
            # Trigger the "lock" procedure ?
            if ($$self{_CFG}{'defaults'}{'use gui password'} && $$self{_CFG}{'defaults'}{'use gui password tray'}) {
                $$self{_GUI}{lockApplicationBtn}->set_active(1);
            }
            # Hide main window
            if (!$STRAY) {
                $$self{_GUI}{main}->iconify();
            } else {
                $self->_hideConnectionsList();
            }
        } else {
            $self->_quitProgram();
        }
        return 1;
    });
    $$self{_GUI}{main}->signal_connect('destroy' => sub { exit 0; });

    # Save GUI size/position/... *before* it hides
    $$self{_GUI}{main}->signal_connect('unmap_event' => sub { $self->_saveGUIData(); return 0; });

    $$self{_GUI}{_vboxSearch}->signal_connect('map' => sub { $$self{_GUI}{_vboxSearch}->hide() unless $$self{_SHOWFINDTREE}; });

    # Capture 'main' keypress
    $$self{_GUI}{main}->signal_connect('key_press_event' => sub {
        my ($widget, $event) = @_;

        my $action = $FUNCS{_KEYBINDS}->GetAction('pacmain', $widget, $event);

        if (!$action) {
            return 0;
        } elsif ($action eq 'find') {
            $$self{_SHOWFINDTREE} = 1;
            $$self{_GUI}{_vboxSearch}->show();
            $$self{_GUI}{_entrySearch}->grab_focus();
        } elsif ($action eq 'quit') {
            $PACMain::FUNCS{_MAIN}->_quitProgram();
        } elsif ($action eq 'localshell') {
            $$self{_GUI}{shellBtn}->clicked();
        } elsif ($action eq 'showconnections') {
            $$self{_GUI}{showConnBtn}->clicked();
        } else {
            return 0;
        }
        return 1;
    });
    $$self{_SIGNALS}{_WINDOWSTATEVENT} = $$self{_GUI}{main}->signal_connect('window_state_event' => sub {
        $$self{_GUI}{maximized} = $_[1]->new_window_state eq 'maximized';
        return 0;
    });
    return 1;
}

###############################################################################
# AI-assisted modernization: Centralized Cosmic initialization to avoid
# duplicated object creation and previous unblessed reference / SNI issues.
# This method is idempotent and safe to call multiple times.
sub _initCosmicEnvironment {
    my $self = shift;
    return 0 unless $COSMIC; # nothing to do
    # Avoid re-initialization
    my $already_ws = defined $self->{_COSMIC_WORKSPACE};
    my $already_theme = defined $self->{_COSMIC_THEME};

    eval { require 'PACCosmicWorkspace.pm'; 1 } or do {
        print "WARNING: Could not load PACCosmicWorkspace ($@)\n" if $@; return 0; } unless $already_ws;
    eval { require 'PACCosmicTheme.pm'; 1 } or do {
        print "WARNING: Could not load PACCosmicTheme ($@)\n" if $@; } unless $already_theme;

    # Workspace
    if (!$already_ws) {
        eval {
            $FUNCS{_COSMIC_WORKSPACE} = $self->{_COSMIC_WORKSPACE} = PACCosmicWorkspace->new($self);
            if ($self->{_COSMIC_WORKSPACE} && $self->{_COSMIC_WORKSPACE}->can('is_workspace_integration_available') && $self->{_COSMIC_WORKSPACE}->is_workspace_integration_available()) {
                print "INFO: Cosmic workspace integration initialized\n";
                if ($self->{_CFG}{defaults}{'cosmic_workspace_tracking'}) {
                    $self->{_COSMIC_WORKSPACE}->enable_workspace_tracking();
                }
            } else {
                print "INFO: Cosmic workspace integration not available (capabilities missing)\n";
            }
        };
        print "WARNING: Cosmic workspace module failed to initialize: $@\n" if $@;
    }

    # Theme (optional)
    if (!$already_theme) {
        eval {
            $FUNCS{_COSMIC_THEME} = $self->{_COSMIC_THEME} = PACCosmicTheme->new($self);
            if ($self->{_COSMIC_THEME} && $self->{_COSMIC_THEME}->can('is_cosmic_theme_available') && $self->{_COSMIC_THEME}->is_cosmic_theme_available()) {
                print "INFO: Cosmic theme integration initialized\n";
                $self->{_COSMIC_THEME}->apply_cosmic_theme() if $self->{_COSMIC_THEME}->can('apply_cosmic_theme');
                if ($self->{_CFG}{defaults}{'cosmic_theme_monitoring'} && $self->{_COSMIC_THEME}->can('enable_theme_monitoring')) {
                    $self->{_COSMIC_THEME}->enable_theme_monitoring();
                }
                if ($self->{_COSMIC_THEME}->can('register_theme_callback')) {
                    $self->{_COSMIC_THEME}->register_theme_callback(sub {
                        my ($variant, $accent, $colors) = @_;
                        print "INFO: Theme changed to $variant variant\n";
                        $self->_updateGUIForThemeChange($variant, $accent, $colors) if $self->can('_updateGUIForThemeChange');
                    });
                }
            }
        };
        print "WARNING: Cosmic theme module failed to initialize: $@\n" if $@;
    }
    return 1;
}

sub _setFavourite {
    my ($self,$b,$tree) = @_;

    map $$self{_CFG}{'environments'}{$_}{'favourite'} = $b, $tree->_getSelectedUUIDs();
    if ($$self{_GUI}{nbTree}->get_current_page() == 1) {
        $self->_updateFavouritesList();
        $self->_updateGUIFavourites();
        $self->_updateGUIPreferences();
    }
    $$self{_GUI}{connFavourite}->set_image(PACIcons::icon_image($b ? 'favourite_on' : 'favourite_off','asbru-favourite-' . ($b ? 'on' : 'off')));
    $$self{_GUI}{connFavourite}->set_active($b);
    if ($UNITY) {
        $FUNCS{_TRAY}->set_tray_menu();
    }
    $self->_setCFGChanged(1);
}

sub _lockAsbru {
    my $self = shift;

    $$self{_GUI}{lockApplicationBtn}->set_image(PACIcons::icon_image('lock_on','asbru-protected'));
    $$self{_GUI}{lockApplicationBtn}->set_active(1);
    $$self{_GUI}{vboxCommandPanel}->set_sensitive(0);
    $$self{_GUI}{showConnBtn}->set_sensitive(0);
    $$self{_GUI}{shellBtn}->set_sensitive(0);
    $$self{_GUI}{quitBtn}->set_sensitive(0);
    $$self{_GUI}{saveBtn}->set_sensitive(0);
    $$self{_GUI}{configBtn}->set_sensitive(0);
    $$self{_GUI}{aboutBtn}->set_sensitive(0);
    $$self{_GUI}{wolBtn}->set_sensitive(0);

    if ($$self{_TABSINWINDOW}){
        $$self{_GUI}{_PACTABS}->set_sensitive(0);
    }
    foreach my $tmp_uuid (keys %RUNNING) {
        if (!defined $RUNNING{$tmp_uuid}{terminal}) {
            next;
        }
        if (ref($RUNNING{$tmp_uuid}{terminal}) =~ /^PACTerminal|PACShell$/go) {
            $RUNNING{$tmp_uuid}{terminal}->lock();
        }
    }
    $$self{_GUILOCKED} = 1;

    return 1;
}

sub _unlockAsbru {
    my $self = shift;

    if (!$CIPHER->salt()) {
        $CIPHER->salt(pack('Q',$SALT));
    }
    my $pass = _wEnterValue($$self{_GUI}{main}, 'GUI Unlock', 'Enter current GUI Password to remove protection...', undef, 0, 'asbru-protected');
    if ((! defined $pass) || ($pass ne $CIPHER->decrypt_hex($$self{_CFG}{'defaults'}{'gui password'}))) {
        $$self{_GUI}{lockApplicationBtn}->set_active(1);
        _wMessage($$self{_WINDOWCONFIG}, 'ERROR: Wrong password!!');
        return 0;
    }

    $$self{_GUI}{lockApplicationBtn}->set_image(PACIcons::icon_image('lock_off','asbru-unprotected'));
    $$self{_GUI}{lockApplicationBtn}->set_active(0);
    $$self{_GUI}{vboxCommandPanel}->set_sensitive(1);
    $$self{_GUI}{showConnBtn}->set_sensitive(1);
    $$self{_GUI}{shellBtn}->set_sensitive(1);
    $$self{_GUI}{quitBtn}->set_sensitive(1);
    $$self{_GUI}{saveBtn}->set_sensitive(1);
    $$self{_GUI}{configBtn}->set_sensitive(1);
    $$self{_GUI}{aboutBtn}->set_sensitive(1);
    $$self{_GUI}{wolBtn}->set_sensitive(1);

    if ($$self{_TABSINWINDOW}) {
        $$self{_GUI}{_PACTABS}->set_sensitive(1);
    }
    foreach my $tmp_uuid (keys %RUNNING) {
        if (!defined $RUNNING{$tmp_uuid}{terminal}) {
            next;
        }
        if (ref($RUNNING{$tmp_uuid}{terminal}) =~ /^PACTerminal|PACShell$/go) {
            $RUNNING{$tmp_uuid}{terminal}->unlock();
        }
    }
    $$self{_GUILOCKED} = 0;

    return 1;
}

sub __search {
    my $self = shift;
    my $text = shift;
    my $tree = shift;
    my $where = shift // 'name';

    my @result;
    my $model = $tree->get_model();
    $model->foreach(sub {
        my ($store, $path, $iter) = @_;
        my $elem_uuid = $model->get_value($model->get_iter($path), 2);
        my %elem;
        $elem{name} = $$self{_CFG}{environments}{$elem_uuid}{name} // '';
        $elem{host} = $$self{_CFG}{environments}{$elem_uuid}{ip} // '';
        $elem{desc} = $$self{_CFG}{environments}{$elem_uuid}{description} // '';
        if ($elem{$where} !~ /$text/gi) {
            return 0;
        }
        push(@result, $elem_uuid);
        return 0;
    });
    return \@result;
}

sub __treeBuildNodeName {
    my $self = shift;
    my $uuid = shift;
    my $name = shift;
    my $bold = '';
    my $pset = '';

    my $is_group = $$self{_CFG}{'environments'}{$uuid}{'_is_group'} // 0;
    my $protected = ($$self{_CFG}{'environments'}{$uuid}{'_protected'} // 0) || 0;
    my $p_set = $$self{_CFG}{defaults}{'protected set'};
    my $p_unset = $$self{_CFG}{defaults}{'unprotected set'} // 'foreground';
    my $p_color = $$self{_CFG}{defaults}{'protected color'};
    my $p_uncolor = $$self{_CFG}{defaults}{'unprotected color'} // '#000000';

    # Auto-adjust colors for system theme and improve dark theme contrast
    if ($$self{_CFG}{defaults}{theme} eq 'system' || $$self{_CFG}{defaults}{theme} eq 'asbru-dark') {
        my $auto_color = $self->_getSystemThemeTextColor();
        if ($auto_color) {
            # For dark themes, use light text; for light themes, use dark text
            $p_uncolor = $auto_color unless $protected;
            
            # Ensure "My Connections" also uses proper color
            if ($uuid eq '__PAC__ROOT__') {
                $p_uncolor = $auto_color;
            }
        }
    }

    if ($name) {
        $name = __($name);
    } else {
        $name = __($$self{_CFG}{'environments'}{$uuid}{'name'});
    }
    if ($is_group) {
        $bold = " weight='bold'";
    }
    if ($protected) {
        $pset = "$p_set='$p_color'";
    } else {
        $pset = "$p_unset='$p_uncolor'";
    }
    $name = "<span $pset$bold font='$$self{_CFG}{defaults}{'tree font'}'> $name</span>";

    return $name;
}

sub _getSystemThemeTextColor {
    my $self = shift;
    
    # Cache the result to avoid repeated expensive calls
    if (defined $$self{_CACHED_THEME_COLOR} && time() - $$self{_CACHED_THEME_TIME} < 5) {
        return $$self{_CACHED_THEME_COLOR};
    }
    
    # Try to detect if we're using a dark theme
    my $is_dark = 0;
    
    # Method 1: Check COSMIC theme settings
    if ($ENV{XDG_CURRENT_DESKTOP} =~ /cosmic/i) {
        # For COSMIC, check if the system prefers dark mode
        my $cosmic_dark = `gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null` || '';
        $is_dark = 1 if $cosmic_dark =~ /prefer-dark/;
        
        # Also check for dark window theme
        my $window_theme = `gsettings get org.gnome.desktop.wm.preferences theme 2>/dev/null` || '';
        $is_dark = 1 if $window_theme =~ /dark/i;
        
        # COSMIC specific: check for dark appearance 
        my $cosmic_appearance = `dconf read /org/cosmic/desktop/appearance 2>/dev/null` || '';
        $is_dark = 1 if $cosmic_appearance =~ /dark/i;
    }
    
    # Method 2: Check GTK theme name
    my $gtk_theme = $ENV{GTK_THEME} || `gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null` || '';
    $is_dark = 1 if $gtk_theme =~ /dark/i;
    
    # Method 3: Check if TreeView has dark background (heuristic)
    if (!$is_dark && $$self{_GUI}{treeConnections}) {
        eval {
            my $style_context = $$self{_GUI}{treeConnections}->get_style_context();
            if ($style_context) {
                my $bg_color = $style_context->get_background_color('normal');
                if ($bg_color && ref($bg_color) eq 'Gtk3::Gdk::RGBA') {
                    # If background is dark (sum of RGB < 1.5), use light text
                    my $brightness = $bg_color->red + $bg_color->green + $bg_color->blue;
                    $is_dark = 1 if $brightness < 1.5;
                }
            }
        };
    }
    
    # Method 4: Heuristic - if current window has dark background, assume dark theme
    if (!$is_dark && $$self{_GUI}{main}) {
        eval {
            my $style_context = $$self{_GUI}{main}->get_style_context();
            if ($style_context) {
                my $bg_color = $style_context->get_background_color('normal');
                if ($bg_color && ref($bg_color) eq 'Gtk3::Gdk::RGBA') {
                    my $brightness = $bg_color->red + $bg_color->green + $bg_color->blue;
                    $is_dark = 1 if $brightness < 1.5;
                }
            }
        };
    }
    
    print STDERR "DEBUG: Theme detection - is_dark: $is_dark (cached for 5s)\n" if $ENV{ASBRU_DEBUG};
    
    # Cache the result
    my $color = $is_dark ? '#e6e6e6' : '#000000';
    $$self{_CACHED_THEME_COLOR} = $color;
    $$self{_CACHED_THEME_TIME} = time();
    
    return $color;
}

sub _getConnectionTypeIcon {
    my $self = shift;
    my $method = shift // '';
    
    my $icon;
    
    # Use method-specific icons based on asbru_method_* naming
    if ($method eq 'SSH') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_ssh.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_ssh.png");
    } elsif ($method =~ /^RDP|xfreerdp|rdesktop/i) {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_rdesktop.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_rdesktop.png");
    } elsif ($method eq 'VNC') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_vncviewer.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_vncviewer.png");
    } elsif ($method eq 'SFTP') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_sftp.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_sftp.png");
    } elsif ($method eq 'FTP') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_ftp.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_ftp.png");
    } elsif ($method eq 'Telnet') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_telnet.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_telnet.png");
    } elsif ($method eq 'MOSH') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_mosh.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_mosh.png");
    } elsif ($method eq 'WebDAV') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_cadaver.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_cadaver.png");
    } elsif ($method eq 'Generic Command') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_generic.svg") || _pixBufFromFile("$$self{_THEME}/asbru_method_generic.png");
    } elsif ($method eq 'IBM 3270/5250') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_3270.jpg");
    } elsif ($method eq 'Serial (cu)') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_cu.jpg");
    } elsif ($method eq 'Serial (remote-tty)') {
        $icon = _pixBufFromFile("$$self{_THEME}/asbru_method_remote-tty.jpg");
    }
    
    # Fallback to default connection icon if method-specific icon not found
    $icon //= $DEFCONNICON;
    
    # Ensure all connection icons are scaled to 16x16 for consistency
    if ($icon && $icon->get_width() != 16 || $icon->get_height() != 16) {
        $icon = $icon->scale_simple(16, 16, 'hyper');
    }
    
    return $icon;
}

sub _hasProtectedChildren {
    my $self = shift;
    my $uuids = shift;
    my $search_children = shift // 1;

    my $with_protected = 0;

    foreach my $uuid (@{ $uuids }) {
        if ($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) {
            if (!$search_children) {
                next;
            }
            foreach my $child ($$self{_GUI}{treeConnections}->_getChildren($uuid, 'all', 1)) {
                if ($with_protected = ($$self{_CFG}{'environments'}{$child}{'_protected'} // 0) || 0) {
                    last;
                }
            }
        } elsif ($with_protected = ($$self{_CFG}{'environments'}{$uuid}{'_protected'} // 0) || 0) {
            last;
        }
    }

    return $with_protected;
}

sub __treeToggleProtection {
    my $self = shift;

    my $selection = $$self{_GUI}{treeConnections}->get_selection();
    my $modelsort = $$self{_GUI}{treeConnections}->get_model();
    my $model = $modelsort->get_model();
    my @sel = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();

    foreach my $uuid (@sel) {
        $$self{_CFG}{'environments'}{$uuid}{'_protected'} = !$$self{_CFG}{'environments'}{$uuid}{'_protected'};
        my $gui_name = $self->__treeBuildNodeName($uuid);
        $model->set($modelsort->convert_iter_to_child_iter($modelsort->get_iter($$self{_GUI}{treeConnections}->_getPath($uuid))), 1, $gui_name);
    }
    $self->_updateGUIPreferences();
    $self->_setCFGChanged(1);
}

sub _treeConnections_menu_lite {
    my $self = shift;
    my $tree = shift;

    my @sel = $tree->_getSelectedUUIDs();

    if (scalar(@sel) == 0) {
        return 1;
    }

    my $with_protected = $self->_hasProtectedChildren(\@sel);
    my @tree_menu_items;

    # Edit
    if (scalar(@sel) == 1) {
        push(@tree_menu_items, {
            label => 'Edit connection',
            logical_icon => 'edit', stockicon => 'gtk-edit',
            tooltip => "Edit this connection\'s data",
            sensitive => $sel[0] ne '__PAC_SHELL__',
            code => sub { $$self{_GUI}{connEditBtn}->clicked(); }
        });
    }
    # Bulk Edit
    elsif (scalar(@sel) > 1) {
        push(@tree_menu_items, {
            label => 'Bulk Edit connections...',
            logical_icon => 'edit', stockicon => 'gtk-edit',
            tooltip => "Bulk edit some values of selected connection\'s",
            sensitive => 1,
            code => sub { $$self{_GUI}{connEditBtn}->clicked(); }
        });
    }

    # Quick Edit variables
    my @var_submenu;
    my $i = 0;
    foreach my $var (map{ ($_->{hide} ? '<hidden>' : $_->{txt}) // '' } @{ $$self{_CFG}{'environments'}{$sel[0]}{'variables'} }) {
        my $j = $i;
        push(@var_submenu, {
            label => '<V:' . $j . '> = ' . $var,
            code => sub {
                my $new_var = _wEnterValue(
                    $$self{_GUI}{main},
                    "Change variable <b>" . __("<V:$j>") . "</b>",
                    'Enter a NEW value or close to keep this value...',
                    $var
                );
                if (!defined $new_var) {
                    return 1;
                }
                $$self{_CFG}{'environments'}{$sel[0]}{'variables'}[$j]{txt} = $new_var;
            }
        });

        ++$i;
    }
    if (scalar(@sel) == 1) {
        push(@tree_menu_items, {
            label => 'Edit Local Variables',
            logical_icon => 'question_action', stockicon => 'gtk-dialog-question',
            sensitive => ! $with_protected,
            submenu => \@var_submenu
        });
    }

    # Send Wake On LAN magic packet
    if ($sel[0] ne '__PAC_SHELL__') {
        push(@tree_menu_items, {
            label => 'Wake On LAN...' . ($$self{_CFG}{'environments'}{$sel[0]}{'use proxy'} || $$self{_CFG}{'defaults'}{'use proxy'} ? '(can\'t, PROXY configured!!)' : ''),
            stockicon => 'asbru-wol',
            sensitive => ! ($$self{_CFG}{'environments'}{$sel[0]}{'use proxy'} || $$self{_CFG}{'defaults'}{'use proxy'}) && (scalar(@sel) >= 1) && (scalar(@sel) == 1) && (! ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__')),
            code => sub { $self->_setCFGChanged(_wakeOnLan($$self{_CFG}{'environments'}{$sel[0]}, $sel[0])); }
        });
    }

    # Start various instances of this connection
    my @submenu_nconns;
    foreach my $i (2 .. 9) {
        push(@submenu_nconns, {
            label => "$i instances",
            code => sub {
                my @idx;
                foreach my $uuid (@sel) {
                    foreach my $j (1 .. $i) {
                        push(@idx, [ $uuid ]);
                    }
                }
                $self->_launchTerminals(\@idx);
            }
        });
    }
    if (scalar(@sel) == 1) {
        push(@tree_menu_items, {

            label => 'Start',
            logical_icon => 'execute_action', stockicon => 'gtk-execute',
            sensitive => (scalar(@sel) == 1) && ! ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__'),
            submenu => \@submenu_nconns
        });
    }

    push(@tree_menu_items, { separator => 1 });

    # Execute clustered
    push(@tree_menu_items, {
        label => 'Execute in New Cluster...',
    logical_icon => 'new', stockicon => 'gtk-new',
        sensitive => scalar @sel >= 1,
        code => sub {
            my $cluster = _wEnterValue($$self{_GUI}{main}, 'Enter a name for the <b>New Cluster</b>');
            if ((!defined $cluster) || ($cluster =~ /^\s*$/go)){
                return 1;
            }
            my @idx;
            my %tmp;
            foreach my $uuid ($tree->_getSelectedUUIDs()) {
                $tmp{$uuid} = 1;
            }
            foreach my $uuid (keys %tmp) {
                push(@idx, [ $uuid, undef, $cluster ]);
            }
            $self->_launchTerminals(\@idx);
        }
    });

    my @submenu_cluster;
    my %clusters;
    foreach my $uuid_tmp (keys %RUNNING) {
        if (!$RUNNING{$uuid_tmp}{terminal}{_CLUSTER}) {
            next;
        }
        $clusters{$RUNNING{$uuid_tmp}{terminal}{_CLUSTER}}{total}++;
        $clusters{$RUNNING{$uuid_tmp}{terminal}{_CLUSTER}}{connections} .= "$RUNNING{$uuid_tmp}{terminal}{_NAME}\n";
    }
    foreach my $cluster (sort { $a cmp $b } keys %clusters) {
        my $tmp = $cluster;
        push(@submenu_cluster, {
            label => "$cluster ($clusters{$cluster}{total} terminals connected)",
            tooltip => $clusters{$cluster}{connections},
            sensitive => $cluster ne $$self{_CLUSTER},
            code => sub {
                my @idx;
                my %tmp;
                foreach my $uuid ($tree->_getSelectedUUIDs()) {
                    $tmp{$uuid} = 1;
                }
                foreach my $uuid (keys %tmp) {
                    push(@idx, [ $uuid, undef, $cluster ]);
                }
                $self->_launchTerminals(\@idx);
            }
        });
    }
    if (scalar(keys(%clusters))) {
        push(@tree_menu_items, {
            label => 'Execute in existing Cluster',
            logical_icon => 'add', stockicon => 'gtk-add',
            submenu => \@submenu_cluster
        });
    }

    _wPopUpMenu(\@tree_menu_items);

    return 1;
}

sub _treeConnections_menu {
    my $self = shift;
    my $event = shift;
    my $p = '';
    my $clip = scalar (keys %{$$self{_COPY}{'data'}{'__PAC__COPY__'}{'children'}});

    my @sel = @SELECTED_UUIDS;
    if (scalar(@sel) == 0) {
        return 1;
    } elsif ((scalar(@sel)>1)||($clip > 1)) {
        $p = 's';
    }
    # Unique ID of parent node
    my $parent_uuid = $$self{_CFG}{'environments'}{$sel[0]}{'parent'};
    # Main selected node is protected
    my $is_protected = $$self{_CFG}{'environments'}{$sel[0]}{'_protected'};
    # Any of the selected node is protected
    my $has_protected_children = $self->_hasProtectedChildren(\@sel);
    # Parent of selected node is protected
    my $protected_parent = defined $parent_uuid ? $$self{_CFG}{'environments'}{$parent_uuid}{'_protected'} : 0;

    my @tree_menu_items;

    # Show keyboard shortcuts
    push(@tree_menu_items, {
        label => "Show Keybindings",
    logical_icon => 'help_action', stockicon => 'gtk-help',
        sensitive => 1,
        code => sub {
            _wMessage($$self{_GUI}{main},$PACMain::FUNCS{_KEYBINDS}->ListKeyBindings('treeConnections'),1,0,'w-info');
        }
    });

    # Separator
    push(@tree_menu_items, { separator => 1 });

    # Expand All
    push(@tree_menu_items, {
        label => 'Expand all',
    logical_icon => 'add', stockicon => 'gtk-add',
        shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','expand_all'),
        tooltip => 'Expand ALL (including sub-nodes)',
        sensitive => 1,
        code => sub { $$self{_GUI}{treeConnections}->expand_all(); }
    });
    # Collapse All
    push(@tree_menu_items, {
        label => 'Collapse all',
    logical_icon => 'delete_action', stockicon => 'gtk-remove',
        shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','collaps_all'),
        tooltip => 'Collapse ALL (including sub-nodes)',
        sensitive => 1,
        code => sub { $$self{_GUI}{treeConnections}->collapse_all(); }
    });
    push(@tree_menu_items, { separator => 1 });
    # Toggle Protect
    if (scalar(@sel) >= 1 && $sel[0] ne '__PAC__ROOT__') {
        push(@tree_menu_items, {
            label => scalar(@sel) > 1 ? ('Toggle Protected state') : (($is_protected ? 'Un-' : '') . 'Protect'),
            stockicon => 'asbru-' . ($is_protected ? 'un' : '') . 'protected',
            shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','protection'),
            tooltip => "Protect or not this node, in order to avoid any changes (Edit, Delete, Rename, ...)",
            sensitive => 1,
            code => sub { $self->__treeToggleProtection(); }
        });
    }
    # Edit
    if (scalar(@sel) == 1 && (! $$self{_CFG}{'environments'}{$sel[0]}{'_is_group'}) && $sel[0] ne '__PAC__ROOT__') {
        push(@tree_menu_items, {
            label => "Edit connection$p",
            logical_icon => 'edit', stockicon => 'gtk-edit',
            shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','edit_node'),
            tooltip => "Edit this connection\'s data",
            sensitive => 1,
            code => sub { $$self{_GUI}{connEditBtn}->clicked(); }
        });
    }
    # Copy Connection Password
    if ((defined($$self{_CFG}{environments}{$sel[0]}{'pass'}) && $$self{_CFG}{environments}{$sel[0]}{'pass'} ne '') || (defined($$self{_CFG}{environments}{$sel[0]}{'passphrase'}) && $$self{_CFG}{environments}{$sel[0]}{'passphrase'} ne '')) {
        push(@tree_menu_items, {
            label => 'Copy Password',
            logical_icon => 'copy_action', stockicon => 'gtk-copy',
            shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','copy'),
            sensitive => 1,
            code => sub {
                _copyPass($sel[0]);
            }
        });
    }
    # Bulk Edit
    if ((scalar(@sel) > 1 || $$self{_CFG}{'environments'}{$sel[0]}{'_is_group'}) && $sel[0] ne '__PAC__ROOT__') {
        push(@tree_menu_items, {
            label => 'Bulk Edit connections...',
            logical_icon => 'edit', stockicon => 'gtk-edit',
            shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','edit_node'),
            tooltip => "Bulk edit some values of selected connection\'s",
            sensitive => 1,
            code => sub { $$self{_GUI}{connEditBtn}->clicked(); }
        });
    }
    # Export
    push(@tree_menu_items, {
        label => 'Export ' . ($sel[0] eq '__PAC__ROOT__' ? 'ALL' : 'SELECTED') . ' connection(s)...',
    logical_icon => 'save_as', stockicon => 'gtk-save-as',
        tooltip => 'Export connection(s) to a YAML file',
        sensitive =>  scalar @sel >= 1,
        code => sub {
            if ($sel[0] eq '__PAC__ROOT__') {
                $$self{_GUI}{treeConnections}->get_selection()->unselect_path(Gtk3::TreePath->new_from_string('0'));
                for my $i (1 .. 65535) {
                    $$self{_GUI}{treeConnections}->get_selection()->select_path(Gtk3::TreePath->new_from_string("$i"));
                }
                $self->__exportNodes();
                for my $i (1 .. 65535) {
                    $$self{_GUI}{treeConnections}->get_selection()->unselect_path(Gtk3::TreePath->new_from_string("$i"));
                }
                $$self{_GUI}{treeConnections}->set_cursor(Gtk3::TreePath->new_from_string('0'), undef, 0);
            } else {
                $self->__exportNodes();
            }
        }
    });
    # Import
    push(@tree_menu_items, {
        label => 'Import connection(s)...',
    logical_icon => 'open', stockicon => 'gtk-open',
        tooltip => 'Import connection(s) from a file',
        sensitive =>  (scalar(@sel) == 1) && ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__'),
        code => sub { $self->__importNodes }
    });
    # Quick Edit variables
    my @var_submenu;
    my $i = 0;
    foreach my $var (map{ ($_->{hide} ? '<hidden>' : $_->{txt}) // '' } @{ $$self{_CFG}{'environments'}{$sel[0]}{'variables'} }) {
        my $j = $i;
        push(@var_submenu, {
            label => '<V:' . $j . '> = ' . $var,
            code => sub {
                my $new_var = _wEnterValue(
                    $$self{_GUI}{main},
                    "Change variable <b>" . __("<V:$j>") . "</b>",
                    'Enter a NEW value or close to keep this value...',
                    $var
                );
                if (!defined $new_var) {
                    return 1;
                }
                $$self{_CFG}{'environments'}{$sel[0]}{'variables'}[$j]{txt} = $new_var;
            }
        });
        ++$i;
    }
    if ((scalar(@sel) == 1) && !($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__')) {
        push(@tree_menu_items, {
            label => 'Edit Local Variables',
            logical_icon => 'question_action', stockicon => 'gtk-dialog-question',
            sensitive => ! $has_protected_children,
            submenu => \@var_submenu
        });
    }

    # Separator
    push(@tree_menu_items, { separator => 1 });

    # Start all connections of the selected group
    if (scalar @sel == 1 && $$self{_CFG}{'environments'}{$sel[0]}{'_is_group'}) {
        push(@tree_menu_items, {
            label => 'Start Group',
            stockicon => 'asbru-group-connect',
            shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections', 'connect'),
            tooltip => "Start all connections of this group",
            code => sub{
                $$self{_GUI}{connExecBtn}->clicked();
            }
        });
    }
    # Add connection/group
    if (scalar @sel == 1 && ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__')) {
        # Add Connection
        push(@tree_menu_items, {
            label => 'Add Connection',
            stockicon => 'asbru-node-add',
            tooltip => "Create a new connection under '" . ($sel[0] eq '__PAC__ROOT__' ? 'ROOT' : $$self{_CFG}{'environments'}{$sel[0]}{'name'}) . "'",
            sensitive => !$is_protected,
            code => sub{
                $$self{_GUI}{connAddBtn}->clicked();
            }
        });
        # Add Group
        push(@tree_menu_items, {
            label => 'Add Group',
            stockicon => 'asbru-group-add',
            tooltip => "Create a new group under '" . ($sel[0] eq '__PAC__ROOT__' ? 'ROOT' : $$self{_CFG}{'environments'}{$sel[0]}{'name'}) . "'",
            sensitive => !$is_protected,
            code => sub{
                $$self{_GUI}{groupAddBtn}->clicked();
            }
        });
    }
    # Rename
    push(@tree_menu_items, {
        label => 'Rename ' . ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__' ? 'Group' : 'Connection'),
    logical_icon => 'spell_check', stockicon => 'gtk-spell-check',
        shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections', 'rename'),
        sensitive => (scalar(@sel) == 1) && $sel[0] ne '__PAC__ROOT__' && !$has_protected_children && !$is_protected && !$protected_parent,
        code => sub {
            $$self{_GUI}{nodeRenBtn}->clicked();
        }
    });
    # Delete
    push(@tree_menu_items, {
        label => 'Delete...',
    logical_icon => 'delete_action', stockicon => 'gtk-delete',
        sensitive => (scalar(@sel) >= 1) && $sel[0] ne '__PAC__ROOT__' && !$has_protected_children && !$is_protected && !$protected_parent,
        code => sub {
            $$self{_GUI}{nodeDelBtn}->clicked();
        }
    });

    # Separator
    push(@tree_menu_items, { separator => 1 });

    # Clone connection
    push(@tree_menu_items, {
        label => "Clone connection$p",
    logical_icon => 'copy_action', stockicon => 'gtk-copy',
        shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','clone'),
        sensitive => scalar(@sel) == 1 && $sel[0] ne '__PAC__ROOT__' && !$protected_parent,
        code => sub {
            $self->_cloneNodes();
        }
    });
    # Copy
    push(@tree_menu_items, {
        label => "Copy node$p",
    logical_icon => 'copy_action', stockicon => 'gtk-copy',
        shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','copy'),
        sensitive => scalar @sel >= 1 && $sel[0] ne '__PAC__ROOT__',
        code => sub{
            $self->_copyNodes();
            # Unselect nodes after copy
            $$self{_GUI}{treeConnections}->get_selection()->unselect_all();
        }
    });
    # Cut
    push(@tree_menu_items, {
        label => "Cut node$p",
    logical_icon => 'cut_action', stockicon => 'gtk-cut',
        shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','cut'),
        sensitive => scalar @sel >= 1 && $sel[0] ne '__PAC__ROOT__' && !$is_protected && !$has_protected_children && !$protected_parent,
        code => sub{
            $self->_cutNodes();
        }
    });
    push(@tree_menu_items, {
        label => "Paste node$p",
    logical_icon => 'paste_action', stockicon => 'gtk-paste',
        shortcut => $PACMain::FUNCS{_KEYBINDS}->GetAccelerator('treeConnections','paste'),
        sensitive => ($clip && scalar @sel == 1 ? 1 : 0) && !$is_protected,
        code => sub {
            foreach my $child (keys %{ $$self{_COPY}{'data'}{'__PAC__COPY__'}{'children'} }) {
                $self->_pasteNodes($sel[0], $child);
            }
            $$self{_COPY}{'data'} = {};
            $self->_copyNodes(0,undef,$LAST_COPIED_NODES);
            return 1;
        }
    });

    push(@tree_menu_items, { separator => 1 });

    # Send Wake On LAN magic packet
    push(@tree_menu_items, {

        label => 'Wake On LAN...' . ($$self{_CFG}{'environments'}{$sel[0]}{'use proxy'} || $$self{_CFG}{'defaults'}{'use proxy'} ? '(can\'t, PROXY configured!!)' : ''),
        stockicon => 'asbru-wol',
        sensitive => ! ($$self{_CFG}{'environments'}{$sel[0]}{'use proxy'} || $$self{_CFG}{'defaults'}{'use proxy'}) && (scalar(@sel) >= 1) && (scalar(@sel) == 1) && (! ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__')),
        code => sub { $self->_setCFGChanged(_wakeOnLan($$self{_CFG}{'environments'}{$sel[0]}, $sel[0])); }
    });

    # Start various instances of this connection
    my @submenu_nconns;
    foreach my $i (2 .. 9) {
        push(@submenu_nconns, {
            label => "$i instances",
            code => sub {
                my @idx;
                foreach my $uuid (@sel) {
                    foreach my $j (1 .. $i) {
                        push(@idx, [ $uuid ]);
                    }
                }
                $self->_launchTerminals(\@idx);
            }
        });
    }
    if ((scalar(@sel) == 1) && ! ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__')) {
        push(@tree_menu_items, {
            label => 'Start',
            logical_icon => 'execute_action', stockicon => 'gtk-execute',
            sensitive => (scalar(@sel) == 1) && ! ($$self{_CFG}{'environments'}{$sel[0]}{'_is_group'} || $sel[0] eq '__PAC__ROOT__'),
            submenu => \@submenu_nconns
        });
    }

    push(@tree_menu_items, { separator => 1 });
    # Execute clustered
    push(@tree_menu_items, {
        label => 'Execute in New Cluster...',
    logical_icon => 'new', stockicon => 'gtk-new',
        sensitive => ((scalar @sel >= 1) && ($sel[0] ne '__PAC__ROOT__')),
        code => sub {
            my $cluster = _wEnterValue($$self{_GUI}{main}, 'Enter a name for the <b>New Cluster</b>');
            if ((! defined $cluster) || ($cluster =~ /^\s*$/go)) {
                return 1;
            }
            my @idx;
            my %tmp;
            foreach my $uuid ($$self{_GUI}{treeConnections}->_getSelectedUUIDs()) {
                if (($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) || ($uuid eq '__PAC__ROOT__')) {
                    my @children = $$self{_GUI}{treeConnections}->_getChildren($uuid, 0, 1);
                    foreach my $child (@children) {
                        $tmp{$child} = 1;
                    }
                } else {
                    $tmp{$uuid} = 1;
                }
            }
            foreach my $uuid (keys %tmp) {
                push(@idx, [ $uuid, undef, $cluster ]);
            }
            $self->_launchTerminals(\@idx);
        }
    });

    my @submenu_cluster;
    my %clusters;
    foreach my $uuid_tmp (keys %RUNNING) {
        if (!$RUNNING{$uuid_tmp}{terminal}{_CLUSTER}) {
            next;
        }
        $clusters{$RUNNING{$uuid_tmp}{terminal}{_CLUSTER}}{total}++;
        $clusters{$RUNNING{$uuid_tmp}{terminal}{_CLUSTER}}{connections} .= "$RUNNING{$uuid_tmp}{terminal}{_NAME}\n";
    }
    foreach my $cluster (sort { $a cmp $b } keys %clusters) {
        my $tmp = $cluster;
        push(@submenu_cluster, {
            label => "$cluster ($clusters{$cluster}{total} terminals connected)",
            tooltip => $clusters{$cluster}{connections},
            sensitive => $cluster ne $$self{_CLUSTER},
            code => sub {
                my @idx;
                my %tmp;
                foreach my $uuid ($$self{_GUI}{treeConnections}->_getSelectedUUIDs()) {
                    if (($$self{_CFG}{'environments'}{$uuid}{'_is_group'}) || ($uuid eq '__PAC__ROOT__')) {
                        my @children = $$self{_GUI}{treeConnections}->_getChildren($uuid, 0, 1);
                        foreach my $child (@children) {
                            $tmp{$child} = 1;
                        }
                    } else {
                        $tmp{$uuid} = 1;
                    }
                }
                foreach my $uuid (keys %tmp) {
                    push(@idx, [ $uuid, undef, $cluster ]);
                }
                $self->_launchTerminals(\@idx);
            }
        });
    }
    if (scalar(keys(%clusters))) {
        push(@tree_menu_items, {
            label => 'Execute in existing Cluster',
            logical_icon => 'add', stockicon => 'gtk-add',
            submenu => \@submenu_cluster
        });
    }
    _wPopUpMenu(\@tree_menu_items, $event);

    return 1;
}

sub _showAboutWindow {
    my $self = shift;

    Gtk3::show_about_dialog(
        $$self{_GUI}{main},(
        "program_name" => '',  # name is shown in the logo
        "version" => "v$APPVERSION",
        "logo" => _pixBufFromFile("$RES_DIR/asbru-logo-400.png"),
        # Modernized fork attribution (2025)
        "copyright" => "Copyright © 2025 Anton Isaiev\nCopyright © 2017-2022 Ásbrú Connection Manager team\nCopyright © 2010-2016 David Torrejón Vaquerizas",
        "website" => 'https://asbru-cm.net/',
    "license" => "\nÁsbrú Connection Manager (Modernized Fork)\n\nCopyright © 2025 Anton Isaiev <totoshko88\@gmail.com>\nCopyright © 2017-2022 Ásbrú Connection Manager team <https://asbru-cm.net>\nCopyright © 2010-2016 David Torrejón Vaquerizas\n\nThis program is free software: you can redistribute it and/or modify\nit under the terms of the GNU General Public License as published by\nthe Free Software Foundation, either version 3 of the License, or\n(at your option) any later version.\n\nThis program is distributed in the hope that it will be useful,\nbut WITHOUT ANY WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\nGNU General Public License for more details.\n\nYou should have received a copy of the GNU General Public License\nalong with this program.  If not, see <http://www.gnu.org/licenses/>.\n"
    ));

    return 1;
}

sub _startCluster {
    my $self = shift;
    my $cluster = shift;

    my @idx;
    my $clulist = $$self{_CLUSTER}->getCFGClusters();

    if (defined $$self{_CFG}{defaults}{'auto cluster'}{$cluster}) {
        my $name = qr/$$self{_CFG}{defaults}{'auto cluster'}{$cluster}{name}/;
        my $host = qr/$$self{_CFG}{defaults}{'auto cluster'}{$cluster}{host}/;
        my $title = qr/$$self{_CFG}{defaults}{'auto cluster'}{$cluster}{title}/;
        my $desc = qr/$$self{_CFG}{defaults}{'auto cluster'}{$cluster}{desc}/;
        foreach my $uuid (keys %{ $$self{_CFG}{environments} }) {
            if ($uuid eq '__PAC__ROOT__' || $$self{_CFG}{environments}{$uuid}{_is_group}) {
                next;
            }
            if (($name ne '')&&($$self{_CFG}{environments}{$uuid}{name} !~ /$name/)) {
                next;
            }
            if (($host ne '')&&($$self{_CFG}{environments}{$uuid}{ip} !~ /$host/)) {
                next;
            }
            if (($title ne '')&&($$self{_CFG}{environments}{$uuid}{title} !~ /$title/)) {
                next;
            }
            if (($desc ne '')&&($$self{_CFG}{environments}{$uuid}{description} !~ /$desc/)) {
                next;
            }
            push(@idx, [ $uuid, undef, $cluster ]);
        }
    } else {
        foreach my $uuid (keys %{ $$clulist{$cluster} }) {
            push(@idx, [ $uuid, undef, $cluster ]);
        }
    }
    if ((scalar(@idx) >= 10)&&(!_wConfirm($$self{_GUI}{main}, "Are you sure you want to start <b>" . (scalar(@idx)) . " terminals from cluster '$cluster'</b> ?"))) {
        return 1;
    } elsif (!@idx) {
        _wMessage($$self{_GUI}{main}, "Cluster <b>$cluster</b> contains no elements");
        return 1;
    }
    $self->_launchTerminals(\@idx);
    return 1;
}

sub _launchTerminals {
    my $self = shift;
    my $terminals = shift;
    my $keys_buffer = shift;

    my @new_terminals;
    if (defined $$self{_GUI} && defined $$self{_GUI}{main}) {
        my $window = $$self{_GUI}{main}->get_window();
        if ($window) {
            $window->set_cursor(Gtk3::Gdk::Cursor->new('watch'));
        }
        $$self{_GUI}{main}->set_sensitive(0);
    }

    # Check if user wants main window to be close when a terminal comes up
    if ($$self{_CFG}{'defaults'}{'hide on connect'} && ! $$self{_CFG}{'defaults'}{'tabs in main window'}) {
        if (!$STRAY) {
            $$self{_GUI}{main}->iconify();
        } else {
            $self->_hideConnectionsList();
        }
    }
    if ($$self{_CFG}{'defaults'}{'tabs in main window'} && $$self{_CFG}{'defaults'}{'auto hide connections list'}) {
        $$self{_GUI}{showConnBtn}->set_active(0);
    }
    if ($$self{_CFG}{'defaults'}{'auto hide button bar'}) {
        $$self{_GUI}{hbuttonbox1}->hide();
    }

    my $wtmp;
    scalar(@{ $terminals }) > 1 and $wtmp = _wMessage($$self{_GUI}{main}, "Starting <b><big>". (scalar(@{ $terminals })) . "</big></b> terminals...", 0);
    $$self{_NTERMINALS} = scalar(@{ $terminals });

    # Create all selected terminals
    foreach my $sel (@{ $terminals }) {
        my $uuid = $$sel[0];
        if (!defined $$self{_CFG}{'environments'}{$uuid}) {
            _wMessage($$self{_GUI}{main}, "ERROR: UUID <b>$uuid</b> does not exist in DDBB\nNot starting connection!", 1);
            next;
        } elsif ($$self{_CFG}{'environments'}{$uuid}{_is_group} || ($uuid eq '__PAC__ROOT__')) {
            if ($$self{_VERBOSE}) {
                print STDERR "DEBUG: Ignoring group [{$uuid} while trying to launch a terminal.\n";
            }
            next;
        }
        if ($$self{_VERBOSE}) {
            my $m = $$self{_CFG}{'environments'}{$uuid}{'method'} // 'UNKNOWN';
            my $n = $$self{_CFG}{'environments'}{$uuid}{'name'} // '';
            print STDERR "DIAG: Launch queue uuid=$uuid method=$m name=$n\n";
        }
        my $pset = $$self{_CFG}{'environments'}{$uuid}{'terminal options'}{'open in tab'} ? 'tab' : 'window';
        my $gset = $$self{_CFG}{'defaults'}{'open connections in tabs'} ? 'tab' : 'window';
        my $usepset = $$self{_CFG}{'environments'}{$uuid}{'terminal options'}{'use personal settings'};
        my $where = $$sel[1] // ($usepset ? $pset : $gset);
        my $cluster = $$sel[2] // '';
        my $manual = $$sel[3];
        my $name = $$self{_CFG}{'environments'}{$uuid}{'name'};
        # Change some variables
        my $pre_def = $$self{_CFG}{'defaults'}{'open connections in tabs'};
        my $pre_ter = $$self{_CFG}{'environments'}{$uuid}{'terminal options'}{'open in tab'};
        $$self{_CFG}{'defaults'}{'open connections in tabs'} = $where eq 'tab';
        $$self{_CFG}{'environments'}{$uuid}{'terminal options'}{'open in tab'} = $where eq 'tab';

        my $t = PACTerminal->new($$self{_CFG}, $uuid, $$self{_GUI}{nb}, $$self{_GUI}{_PACTABS}, $cluster, $manual) or die "ERROR: Could not create object($!)";
        push(@new_terminals, $t);

        # Restore previously changed variables
        $$self{_CFG}{'defaults'}{'open connections in tabs'} = $pre_def;
        $$self{_CFG}{'environments'}{$uuid}{'terminal options'}{'open in tab'} = $pre_ter;
    }

    # Start all created terminals
    foreach my $t (@new_terminals) {
        if ($$t{_TABBED} && !$$self{_CMDLINETRAY}) {
            $$self{_GUI}{_PACTABS}->present();
        }

    # BUGFIX 2025-08: incorrect scalar dereference caused 'Not a SCALAR reference' when invoking start()
    # $t is a blessed HASH ref (PACTerminal). Using $$t->start attempts to dereference as SCALAR.
    if (!$t->start($keys_buffer)) {
            _wMessage($$self{_GUI}{main}, __("ERROR: Could not start terminal '$$self{_CFG}{environments}{ $$t{_UUID} }{title}':\n$$t{ERROR}"), 1);
            next;
        }
        my $uuid = $$t{_UUID};
        
        # AI-assisted modernization: Cosmic workspace integration (guarded)
        if ($COSMIC && $$self{_COSMIC_WORKSPACE}) {
            eval {
                $$self{_COSMIC_WORKSPACE}->associate_connection_with_workspace($uuid) if $$self{_COSMIC_WORKSPACE}->can('associate_connection_with_workspace');
                if ($$t{_GUI} && $$t{_GUI}{main}) {
                    my $connection_type = $$self{_CFG}{'environments'}{$uuid}{'method'} || 'terminal';
                    if ($$self{_COSMIC_WORKSPACE}->can('handle_cosmic_window_placement')) {
                        $$self{_COSMIC_WORKSPACE}->handle_cosmic_window_placement($$t{_GUI}{main}, $connection_type);
                    }
                }
            };
            if ($@) { print STDERR "WARN: Cosmic placement failed for $uuid : $@\n"; }
        }
        
        my $icon = $uuid eq '__PAC_SHELL__' ? Gtk3::Gdk::Pixbuf->new_from_file_at_scale("$THEME_DIR/asbru_shell.svg", 16, 16, 0) : $$self{_METHODS}{ $$self{_CFG}{'environments'}{$uuid}{'method'} }{'icon'};
        my $name = __($$self{_CFG}{'environments'}{$uuid}{'name'});
        unshift(@{ $$self{_GUI}{treeHistory}{data} }, ({ value => [ $icon, $name, $uuid,  strftime("%H:%M:%S %d-%m-%Y", localtime($FUNCS{_STATS}{statistics}{$uuid}{start})) ] }));
    }

    if (scalar(@{ $terminals }) > 1) {
        $wtmp->destroy(); undef $wtmp;
    }

    if (defined $$self{_GUI} && defined $$self{_GUI}{main}) {
        my $window = $$self{_GUI}{main}->get_window();
        if ($window) {
            $window->set_cursor(Gtk3::Gdk::Cursor->new('left-ptr'));
        }
        $$self{_GUI}{main}->set_sensitive(1);
    }

    if (!$$self{_CMDLINETRAY} && $$self{_CFG}{'defaults'}{'open connections in tabs'} && $$self{_CFG}{'defaults'}{'tabs in main window'}) {
        $self->_showConnectionsList(0);
    }
    if (@new_terminals) {
        $$self{_HAS_FOCUS} = $new_terminals[ $#new_terminals ]{_GUI}{_VTE};
    }

    return \@new_terminals;
}

sub _quitProgram {
    my $self = shift;
    my $force = shift // '0';

    if ($ENV{ASBRU_DEBUG}) {
        my @c = caller();
        print "DEBUG: _quitProgram invoked (force=$force) at $c[1]:$c[2] t=".(time()-$APP_START_TIME)."s\n";
        my $depth=1; while (my @cc = caller($depth++)) { print "DEBUG:  stack[$depth] $cc[1]:$cc[2] sub=$cc[3]\n"; }
    }
    # Prevent accidental early quit during startup (<2s) unless forced
    if (!$force && (time() - $APP_START_TIME) < 2) {
        print "DEBUG: Suppressing early quit during startup window\n" if $ENV{ASBRU_DEBUG};
        return 1;
    }

    my $changed = $$self{_CFG}{tmp}{changed} // '0';
    my $save = 0;
    my $rc = 0;

    # Get the list of connected terminals
    foreach my $uuid_tmp (keys %RUNNING) {
        $rc += $RUNNING{$uuid_tmp}{'terminal'}{CONNECTED} // 0;
    }

    # Check for user confirmation for close/save
    if (!$force) {
        my $string = "Are you sure you want to <b>exit</b> $APPNAME ?";
        $rc and $string .= "\n\n(" . ($rc > 1 ? "there are $rc open terminals" : "there is $rc open terminal")  . ")";
        if ($$self{_CFG}{'defaults'}{'confirm exit'} || $rc) {
            if (!_wConfirm($$self{_GUI}{main}, $string, 'yes')) {
                return 1;
            }
        };
        if ($changed && (!$$self{_CFG}{defaults}{'save on exit'})) {
            my $opt = _wYesNoCancel($$self{_GUI}{main}, "<b>Configuration has changed.</b>\n\nSave changes?");
            $save = $opt eq 'yes';
            if ($opt eq 'cancel') {
                return 1;
            }
        } elsif ($changed) {
            $save = 1;
        }
    }

    print "INFO: Finishing ($Script) with pid $$\n";

    # Disconnect some events (to avoid side effects when closing/hiding)
    $$self{_GUI}{main}->signal_handler_disconnect($$self{_SIGNALS}{_WINDOWSTATEVENT}) if $$self{_SIGNALS}{_WINDOWSTATEVENT};

    # Hide every GUI component has already finished
    $$self{_TRAY}->set_passive();
    $$self{_SCRIPTS}{_WINDOWSCRIPTS}{main}->hide();    # Hide scripts window
    $$self{_CLUSTER}{_WINDOWCLUSTER}{main}->hide();    # Hide clusters window
    $$self{_PCC}{_WINDOWPCC}{main}->hide();    # Hide PCC window
    $$self{_GUI}{main}->hide();    # Hide main window
    $$self{_GUI}{_PACTABS}->hide();    # Hide TABs window

    if ($$self{_READONLY}) {
        Gtk3->main_quit();
        return 1;
    }

    # Force the stop of every opened terminal
    foreach my $tmp_uuid (keys %RUNNING) {
        if (!defined $RUNNING{$tmp_uuid}{terminal}) {
            next;
        }
        if (ref($RUNNING{$tmp_uuid}{terminal}) =~ /^PACTerminal|PACShell$/go) {
            # AI-assisted modernization: Cosmic workspace cleanup
            if ($COSMIC && $$self{_COSMIC_WORKSPACE}) {
                $$self{_COSMIC_WORKSPACE}->cleanup_connection($tmp_uuid);
            }
            
            $RUNNING{$tmp_uuid}{terminal}->stop(1, 0);
        }
    }

    Gtk3::main_iteration() while Gtk3::events_pending();   # Update GUI
    # Once everything is hidden, we may last any time in our final I/O
    delete $$self{_CFG}{environments}{'__PAC_SHELL__'};    # Delete PACShell environment
    delete $$self{_CFG}{environments}{'__PAC__QUICK__CONNECT__'}; # Delete quick connect environment
    $self->_saveTreeExpanded();                       # Save Tree opened/closed  groups
    $self->_saveConfiguration() if $save;             # Save config, if applies
    if (defined $$self{_GUI}{statistics}) {
        $$self{_GUI}{statistics}->purge($$self{_CFG});    # Purge trash statistics
        $$self{_GUI}{statistics}->saveStats();            # Save statistics
    } else {
        warn "WARN: statistics object undefined during quit sequence" if $ENV{ASBRU_DEBUG};
    }
    unless (grep(/^--no-backup$/, @{ $$self{_OPTS} })) {
        $$self{_CONFIG}->_exporter('yaml', $CFG_FILE);        # Export as YAML file
        $$self{_CONFIG}->_exporter('perl', $CFG_FILE_DUMPER); # Export as Perl data
    };
    chdir(${CFG_DIR}) and system("$ENV{'ASBRU_ENV_FOR_EXTERNAL'} rm -rf sockets/* tmp/*");  # Delete temporal files

    # And finish every GUI
    Gtk3->main_quit();

    return 1;
}

# AI-assisted modernization: Handle Cosmic theme changes
sub _updateGUIForThemeChange {
    my $self = shift;
    my $variant = shift;
    my $accent_color = shift;
    my $theme_colors = shift;
    
    return unless $COSMIC && $$self{_COSMIC_THEME};
    
    print "INFO: Updating GUI for Cosmic theme change to $variant\n";
    
    # Update main window styling
    if ($$self{_GUI}{main}) {
        # Add CSS classes for theme-aware styling
        my $style_context = $$self{_GUI}{main}->get_style_context();
        $style_context->remove_class('asbru-light-theme');
        $style_context->remove_class('asbru-dark-theme');
        $style_context->add_class("asbru-${variant}-theme");
    }
    
    # Update connection list styling
    if ($$self{_GUI}{treeConnections}) {
        my $style_context = $$self{_GUI}{treeConnections}->get_style_context();
        $style_context->add_class('asbru-cosmic-tree');
    }
    
    # Update button styling
    foreach my $button_name (qw(connectBtn shellBtn configBtn quitBtn)) {
        if ($$self{_GUI}{$button_name}) {
            my $style_context = $$self{_GUI}{$button_name}->get_style_context();
            $style_context->add_class('asbru-cosmic-button');
        }
    }
    
    # Force GUI update (respect actual GTK version to avoid calling Gtk4 APIs under Gtk3)
    eval {
        if ($PACCompat::GTK_VERSION && $PACCompat::GTK_VERSION >= 4) {
            while (Gtk4::events_pending()) { Gtk4::main_iteration(); }
        } else {
            while (Gtk3::events_pending()) { Gtk3::main_iteration(); }
        }
        1;
    } or do {
        warn "WARN: GUI refresh loop failed during cosmic theme change: $@" if $ENV{ASBRU_DEBUG};
    };
    
    return 1;
}

sub _saveConfiguration {
    my $self = shift;
    my $cfg = shift // $$self{_CFG};
    my $normal = shift // 1;
    my %tmp_sessions;
    # Preserve new custom keys that _cfgSanityCheck does not yet whitelist
    my $pre_override_save = eval { $cfg->{'defaults'}{'system icon theme override'} };

    # Purge screenshots
    _purgeUnusedOrMissingScreenshots($cfg);
    # Keep a reference to the temporary sessions
    # (since they will be deleted by _cfgSanityCheck as we don't want to persist those on disk)
    %tmp_sessions = _cfgGetTmpSessions($cfg);
    # Cleanup the configuration before saving (sanityu check + remove of temporary sessions)
    _cfgSanityCheck($cfg);
    # Restore system icon theme override if removed by sanity check so it is persisted
    if (defined $pre_override_save && !defined $cfg->{'defaults'}{'system icon theme override'}) {
        $cfg->{'defaults'}{'system icon theme override'} = $pre_override_save;
        print STDERR "DEBUG: Re-added system icon theme override during save: $pre_override_save\n" if $ENV{ASBRU_DEBUG};
    }
    # Do not keep passwords in plain text in the configuration
    _cipherCFG($cfg);
    # Do store the configuration on disk
    nstore($cfg, $CFG_FILE_NFREEZE) or _wMessage($$self{_GUI}{main}, "ERROR: Could not save config file '$CFG_FILE_NFREEZE':\n\n$!");
    if ($R_CFG_FILE) {
        nstore($cfg, $R_CFG_FILE) or _wMessage($$self{_GUI}{main}, "ERROR: Could not save config file '$R_CFG_FILE':\n\n$!\n\nLocal copy saved at '$CFG_FILE_NFREEZE'");
    }
    # Restore passwords
    _decipherCFG($cfg);
    # Restore the temporary sessions
    _cfgAddSessions($cfg, \%tmp_sessions);
    # Save tree positions (guard: tree may not yet exist in early migrations or headless operations)
    eval { $self->_saveTreeExpanded(); };
    # Save satistics
    $$self{_GUI}{statistics} && $$self{_GUI}{statistics}->saveStats();

    $normal and $self->_setCFGChanged(0);

    # Prepare the .desktop file to contain list of favourites connections
    #_makeDesktopFile($cfg);

    return $CFG_FILE_NFREEZE;
}

sub _readConfiguration {
    my $self = shift;
    my $splash = shift // 1;

    my $continue = 1;

    if ($continue && $R_CFG_FILE && -r $R_CFG_FILE) {
        eval { $$self{_CFG} = retrieve($R_CFG_FILE); };
        if ($@) {
            print STDERR "WARNING: There were errors reading remote file '$R_CFG_FILE' config file: $@\n";
        } else {
            print STDERR "INFO: Used remote config file '$R_CFG_FILE'\n";
            $continue = 0;
        }
    }

    if ($continue && -f $CFG_FILE_NFREEZE) {
        eval { $$self{_CFG} = retrieve($CFG_FILE_NFREEZE); };
        if ($@) {
            print STDERR "WARNING: There were errors reading '$CFG_FILE_NFREEZE' config file: $@\n";
        } else {
            print STDERR "INFO: Used config file '$CFG_FILE_NFREEZE'\n";
            if ($R_CFG_FILE) {
                nstore($$self{_CFG}, $R_CFG_FILE) or die "ERROR: Could not save remote config file '$R_CFG_FILE': $!";
            }
            $continue = 0;
        }
    }

    if ($continue && -f $CFG_FILE) {
        if (! ($$self{_CFG} = YAML::LoadFile($CFG_FILE))) {
            print STDERR "WARNING: Could not load config file '$CFG_FILE': $!\n";
        } else {
            print STDERR "INFO: Used config file '$CFG_FILE'\n";
            if ($R_CFG_FILE) {
                nstore($$self{_CFG}, $R_CFG_FILE) or die "ERROR: Could not save remote config file '$R_CFG_FILE': $!";
            }
            nstore($$self{_CFG}, $CFG_FILE_NFREEZE) or die "ERROR: Could not save config file '$CFG_FILE_NFREEZE': $!";
            $continue = 0;
        }
    }

    if ($continue && -f $CFG_FILE_DUMPER) {
        if (!open(F,"<:utf8",$CFG_FILE_DUMPER)) {
            die "ERROR: Could open for reading file '$CFG_FILE_DUMPER': $!";
        }
        my $data = '';
        while (my $line = <F>) {
            $data .= $line;
        }
        close F;
        my $VAR1;
        eval $data;
        if ($@) {
            print STDERR "ERROR: Could not load config file from '$CFG_FILE_DUMPER': $@\n";
        } else {
            print STDERR "INFO: Used config file '$CFG_FILE_DUMPER'\n";
            $$self{_CFG} = $VAR1;
            nstore($$self{_CFG}, $CFG_FILE_NFREEZE) or die "ERROR: Could not save config file '$CFG_FILE_NFREEZE': $!";
            if ($R_CFG_FILE) {
                nstore($$self{_CFG}, $R_CFG_FILE) or die "ERROR: Could not save remote config file '$R_CFG_FILE': $!";
            }
            $continue = 0;
        }
    }

    if ($continue && -f $CFG_FILE_FREEZE) {
        eval {
            $$self{_CFG} = retrieve($CFG_FILE_FREEZE);
        };
        if ($@) {
            print STDERR "WARNING: There were errors reading the '$CFG_FILE_FREEZE' config file: $@\n";
        } else {
            print STDERR "INFO: Used config file '$CFG_FILE_FREEZE'\n";
            nstore($$self{_CFG}, $CFG_FILE_NFREEZE) or die"ERROR: Could not save config file '$CFG_FILE_NFREEZE': $!";
            if ($R_CFG_FILE) {
                nstore($$self{_CFG}, $R_CFG_FILE) or die "ERROR: Could not save remote config file '$R_CFG_FILE': $!";
            }
            unlink($CFG_FILE_FREEZE);
            $continue = 0;
        }
    }

     # PENDING: I think we should be able to remove this code
    if ($continue && (! -f "${CFG_FILE}.prev3") && (-f $CFG_FILE)) {
        print STDERR "INFO: Migrating config file to v3...\n";
        PACUtils::_splash(1, "$APPNAME (v$APPVERSION):Migrating config...", ++$PAC_START_PROGRESS, $PAC_START_TOTAL);
        $$self{_CFG} = _cfgCheckMigrationV3();
        copy($CFG_FILE, "${CFG_FILE}.prev3") or die "ERROR: Could not copy pre v.3 cfg file '$CFG_FILE' to '$CFG_FILE.prev3': $!";
        nstore($$self{_CFG}, $CFG_FILE_NFREEZE) or die"ERROR: Could not save config file '$CFG_FILE_NFREEZE': $!";
        if ($R_CFG_FILE) {
            nstore($$self{_CFG}, $R_CFG_FILE) or die "ERROR: Could not save remote config file '$R_CFG_FILE': $!";
        }
        $continue = 0;
    }
    # END of removing

    # Default partial vendor config, but since it is partial, do not set $continue to 0.
    if ($continue && -f "${VENDOR_CFG_FILE}") {
        my $temp_cfg;
        if (! ($temp_cfg = YAML::LoadFile($VENDOR_CFG_FILE))) {
            print STDERR "WARNING: Could not load vendor config file '$VENDOR_CFG_FILE': $!\n";
        } else {
            print STDERR "INFO: Using vendor config file '$VENDOR_CFG_FILE'\n";
            $$self{_CFG} //= {};
            foreach my $config (keys %{ $temp_cfg->{'__PAC__EXPORTED__PARTIAL_CONF'} }) {
                $$self{_CFG}{$config} = $temp_cfg->{'__PAC__EXPORTED__PARTIAL_CONF'}{$config};
            }
            print STDERR "INFO: Used vendor config file '$VENDOR_CFG_FILE'\n";
        }
    }

    if ($R_CFG_FILE && $continue) {
         print STDERR "WARN: No configuration file in (remote) '$CFG_DIR', creating a new one...\n";
    }
    if ($continue) {
        print STDERR "WARN: No configuration file found in '$CFG_DIR', creating a new one...\n";
    }

    # Make some sanity checks
    $splash and PACUtils::_splash(1, "$APPNAME (v$APPVERSION):Checking config...", 4, 5);
    my $pre_override = $$self{_CFG}{'defaults'}{'system icon theme override'};
    _cfgSanityCheck($$self{_CFG});
    # Restore system icon theme override if sanity check discarded it (allow new key persistence)
    if (defined $pre_override && !defined $$self{_CFG}{'defaults'}{'system icon theme override'}) {
        $$self{_CFG}{'defaults'}{'system icon theme override'} = $pre_override;
        print STDERR "DEBUG: Restored system icon theme override after sanity check: $pre_override\n" if $ENV{ASBRU_DEBUG};
    }
    print STDERR "DEBUG: Loaded system icon theme override='" . (defined $$self{_CFG}{'defaults'}{'system icon theme override'} ? $$self{_CFG}{'defaults'}{'system icon theme override'} : '') . "' theme='" . ($$self{_CFG}{'defaults'}{'theme'} // '') . "'\n" if $ENV{ASBRU_DEBUG};
    _decipherCFG($$self{_CFG});

    $$self{_CFG}{'defaults'}{'layout'} = defined $$self{_CFG}{'defaults'}{'layout'} ? $$self{_CFG}{'defaults'}{'layout'} : 'Traditional';
    return 1;
}

sub _loadTreeConfiguration {
    my $self = shift;
    my $group = shift;
    my $tree = shift // $$self{_GUI}{treeConnections};

    @{ $$self{_GUI}{treeConnections}{'data'} } =
    ({
        value => [ $GROUPICON_ROOT, $self->__treeBuildNodeName('__PAC__ROOT__', 'My Connections'), '__PAC__ROOT__' ],
        children => []
    });
    foreach my $child (keys %{ $$self{_CFG}{environments}{'__PAC__ROOT__'}{children} }) {
        push(@{ $$tree{data} }, $self->__recurLoadTree($child));
    }

    # Select the root path
    $tree->set_cursor($tree->_getPath('__PAC__ROOT__'), undef, 0);

    return 1;
}

sub __recurLoadTree {
    my $self = shift;
    my $uuid = shift;

    my $node_name = $self->__treeBuildNodeName($uuid);
    my @list;

    if (!$$self{_CFG}{environments}{$uuid}{'_is_group'}) {
        # Leaf connection node (not a group)
        my $icon = $$self{_CFG}{environments}{$uuid}{'icon'};
        if (!$icon) {
            $icon = $self->_getConnectionTypeIcon($$self{_CFG}{environments}{$uuid}{'method'} // '');
        }
        my $label = $node_name;
        my $node = {
            value => [ $icon, $label, $uuid ],
            children => []
        };
        if ($ENV{ASBRU_TREE_DEBUG}) {
            print STDERR "TREE_DEBUG: add connection uuid=$uuid name=$label icon=$icon\n";
        }
        push(@list, $node);
    } else {
        my @clist;
        foreach my $child (keys %{ $$self{_CFG}{environments}{$uuid}{children} }) {
            push(@clist, $self->__recurLoadTree($child));
        }
        push(@list, {
            value => [ $GROUPICONCLOSED, $node_name, $uuid ],
            children => \@clist
        });
    }

    return @list;
}

sub _saveTreeExpanded {
    my $self = shift;
    return 0 if $ENV{ASBRU_EARLY_VERSION}; # silent skip in early --version mode
    my $tree = shift // $$self{_GUI}{treeConnections};

    # Migration A hardening: treeConnections may be undefined if invoked very early (e.g., during startup autosave)
    if (!defined $tree || !ref($tree) || !eval { $tree->isa('Gtk3::TreeView') }) {
        # This is normal during startup - tree not yet initialized
        return 0;
    }
    my $modelsort = eval { $tree->get_model };
    if (!$modelsort) {
        # Tree model not yet ready during startup
        return 0;
    }

    my $selection = eval { $tree->get_selection() };
    $modelsort = eval { $tree->get_model() } unless $modelsort; # re-fetch if needed
    if (!$modelsort) {
        warn "WARN: _saveTreeExpanded aborted: model retrieval failed\n" if $ENV{ASBRU_DEBUG};
        return 0;
    }
    my $model = $modelsort->get_model();

    open(F,">:utf8","$CFG_FILE.tree") or die "ERROR: Could not save Tree Config file '$CFG_FILE.tree': $!";
    $modelsort->foreach(sub {
        my ($store, $path, $iter, $tmp) = @_;
        my $uuid = $store->get_value($iter, 2);
        if (!($tree->row_expanded($path) && $uuid ne '__PAC__ROOT__')) {
            return 0;
        }
        print F $uuid . "\n";
        return 0;
    });

    my $page0 = $$self{_GUI}{nbTree}->get_nth_page(0);
    my $page1 = $$self{_GUI}{nbTree}->get_nth_page(1);
    my $page2 = $$self{_GUI}{nbTree}->get_nth_page(2);
    my $page3 = $$self{_GUI}{nbTree}->get_nth_page(3);

    # Connections
    $$self{_GUI}{scroll1} eq $page0 and print F "tree_page_0:scroll1\n";
    $$self{_GUI}{scroll1} eq $page1 and print F "tree_page_1:scroll1\n";
    $$self{_GUI}{scroll1} eq $page2 and print F "tree_page_2:scroll1\n";
    $$self{_GUI}{scroll1} eq $page3 and print F "tree_page_3:scroll1\n";
    # Favourites
    $$self{_GUI}{scroll2} eq $page0 and print F "tree_page_0:scroll2\n";
    $$self{_GUI}{scroll2} eq $page1 and print F "tree_page_1:scroll2\n";
    $$self{_GUI}{scroll2} eq $page2 and print F "tree_page_2:scroll2\n";
    $$self{_GUI}{scroll2} eq $page3 and print F "tree_page_3:scroll2\n";
    # History
    $$self{_GUI}{scroll3} eq $page0 and print F "tree_page_0:scroll3\n";
    $$self{_GUI}{scroll3} eq $page1 and print F "tree_page_1:scroll3\n";
    $$self{_GUI}{scroll3} eq $page2 and print F "tree_page_2:scroll3\n";
    $$self{_GUI}{scroll3} eq $page3 and print F "tree_page_3:scroll3\n";
    # Clusters
    $$self{_GUI}{vboxclu} eq $page0 and print F "tree_page_0:vboxclu\n";
    $$self{_GUI}{vboxclu} eq $page1 and print F "tree_page_1:vboxclu\n";
    $$self{_GUI}{vboxclu} eq $page2 and print F "tree_page_2:vboxclu\n";
    $$self{_GUI}{vboxclu} eq $page3 and print F "tree_page_3:vboxclu\n";

    close F;

    return 1;
}

sub _loadTreeExpanded {
    my $self = shift;
    my $tree = shift // $$self{_GUI}{treeConnections};

    my %TREE_TABS;

    if (-f "$CFG_FILE.tree") {
        open(F,"<:utf8","$CFG_FILE.tree") or die "ERROR: Could not read Tree Config file '$CFG_FILE.tree': $!";;
        foreach my $uuid (<F>) {

            chomp $uuid;
            if ($uuid =~ /^tree_page_(\d):(.+)$/go) {
                $TREE_TABS{$1} = $2;
            } else {
                my $path = $$self{_GUI}{treeConnections}->_getPath($uuid) or next;
                $tree->expand_row($path, 0);
            }
        }
        close F;
    }

    defined $TREE_TABS{0} and $$self{_GUI}{nbTree}->reorder_child($$self{_GUI}{$TREE_TABS{0}}, 0);
    defined $TREE_TABS{1} and $$self{_GUI}{nbTree}->reorder_child($$self{_GUI}{$TREE_TABS{1}}, 1);
    defined $TREE_TABS{2} and $$self{_GUI}{nbTree}->reorder_child($$self{_GUI}{$TREE_TABS{2}}, 2);
    defined $TREE_TABS{3} and $$self{_GUI}{nbTree}->reorder_child($$self{_GUI}{$TREE_TABS{3}}, 3);

    return 1;
}

sub _saveGUIData {
    my $self = shift;

    open(F,">:utf8","$CFG_FILE.gui") or die "ERROR: Could not save GUI Config file '$CFG_FILE.gui': $!";;

    # Save Top Window size/position
    if ($$self{_GUI}{maximized}) {
        print F 'maximized';
    } else {
        my ($x, $y) = $$self{_GUI}{main}->get_position();
        my ($w, $h) = $$self{_GUI}{main}->get_size();
        print F $x . ':' . $y . ':' . $w . ':' . $h;

        if ($$self{_VERBOSE}) {
            print STDERR "DEBUG: Saving window position = ($x, $y) ; window size ($w, $h)\n";
        }
    }
    print F "\n";

    # Save connections list width
    my $treepos = $$self{_GUI}{hpane}->get_position();
    print F $treepos . "\n";

    close F;

    return 1;
}

sub _loadGUIData {
    my $self = shift;

    if (!-f "$CFG_FILE.gui") {
        return 1;
    }

    open(F,"<:utf8","$CFG_FILE.gui") or die "ERROR: Could not read GUI Config file '$CFG_FILE.gui': $!";

    # Read top level window's psize/position
    my $win = <F>;
    chomp $win;

    ($$self{_GUI}{posx}, $$self{_GUI}{posy}, $$self{_GUI}{sw}, $$self{_GUI}{sh}) =
        $win eq 'maximized'
        ? ('maximized', 'maximized', 'maximized', 'maximized')
        : split(':', $win);

    if ($$self{_VERBOSE}) {
        print STDERR "DEBUG: Starting window position = ($$self{_GUI}{posx}, $$self{_GUI}{posy}} ; window size ($$self{_GUI}{sw}, $$self{_GUI}{sh})\n";
    }

    # Read connections list width
    my $tree = <F> // '-1';
    chomp $tree;
    $$self{_GUI}{hpanepos} = $tree;

    close F;

    return 1;
}

sub _updateGUIWithUUID {
    my $self = shift;
    my $uuid = shift;

    my $is_root = $uuid eq '__PAC__ROOT__';

    if ($is_root) {
        $$self{_GUI}{descBuffer}->set_text(qq"

 * Welcome to $APPNAME version $APPVERSION *

 - To create a New GROUP of Connections:

   1- 'click' over 'My Connections' (to create it at root) or any other GROUP
   2- 'click' on the most left icon over the connections tree (or right-click over selected GROUP)
   3- Follow instructions

 - To create a New CONNECTION in a selected Group or at root:

   1- Select the container group to create the new connection into (or 'My Connections' to create it at root)
   2- 'click' on the second most left icon over the connections tree (or right-click over selected GROUP)
   3- Follow instructions

 - For the latest news, check the project website (https://asbru-cm.net/).

");
    } else {
        if (!$$self{_CFG}{'environments'}{$uuid}{'description'}) {
            $$self{_CFG}{'environments'}{$uuid}{'description'} = 'Insert your comments for this connection here ...';
        }
        $$self{_GUI}{descBuffer}->set_text("$$self{_CFG}{'environments'}{$uuid}{'description'}");
    }

    if ($$self{_CFG}{'defaults'}{'show statistics'}) {
        $$self{_GUI}{statistics}->update($uuid, $$self{_CFG});
        $$self{_GUI}{frameStatistics}->show();
    } else {
        $$self{_GUI}{frameStatistics}->hide();
    }

    if ($$self{_CFG}{'defaults'}{'show screenshots'}) {
        $$self{_GUI}{screenshots}->update($$self{_CFG}{'environments'}{$uuid}, $uuid);
        $$self{_GUI}{frameScreenshots}->show_all();
    } else {
        $$self{_GUI}{frameScreenshots}->hide();
    }

    return 1;
}

sub _clearLeftMenuTabLabels {
    my $self = shift;

    $$self{_GUI}{nbTreeTabLabel}->set_text('');
    $$self{_GUI}{nbFavTabLabel}->set_text('');
    $$self{_GUI}{nbHistTabLabel}->set_text('');
    $$self{_GUI}{nbCluTabLabel}->set_text('');
}

sub _updateGUIPreferences {
    my $self = shift;

    my @sel_uuids = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
    my $total = scalar(@sel_uuids);

    my $is_group = 0;
    my $is_root = 0;
    my $protected = 0;
    my $uuid = $sel_uuids[0];
    defined $uuid or return 1;

    foreach my $uuid (@sel_uuids) {
        $uuid eq '__PAC__ROOT__' and $is_root = 1;
        $$self{_CFG}{'environments'}{$uuid}{'_is_group'} and $is_group = 1;
        $$self{_CFG}{'environments'}{$uuid}{'_protected'} and $protected = 1;
    }

    $self->_clearLeftMenuTabLabels();
    if ($$self{_CFG}{defaults}{'show tree titles'}) {
        $$self{_GUI}{nbTreeTabLabel}->set_text(' Connections');
    }
    $$self{_GUI}{connSearch}->set_sensitive(1);
    $$self{_GUI}{groupAddBtn}->set_sensitive($total eq 1 && ($is_group || $is_root) && !$protected);
    $$self{_GUI}{connAddBtn}->set_sensitive($total eq 1 && ($is_group || $is_root) && !$protected);
    $$self{_GUI}{connEditBtn}->set_sensitive($total >= 1 && ! $is_root);
    $$self{_GUI}{nodeRenBtn}->set_sensitive($total eq 1 && ! $is_root && ! $protected);
    $$self{_GUI}{nodeDelBtn}->set_sensitive($total >= 1 && ! $is_root && ! $protected);
    $$self{_GUI}{connExecBtn}->set_sensitive($total >= 1);
    $$self{_GUI}{descView}->set_sensitive($total eq 1 && ! $is_root);
    $$self{_GUI}{frameStatistics}->set_sensitive($total eq 1);
    $$self{_GUI}{frameScreenshots}->set_sensitive($total eq 1 && ! $is_root);
    $$self{_GUI}{connFavourite}->set_sensitive($total >= 1 && ! ($is_root || $is_group));
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 1;
    $$self{_GUI}{connFavourite}->set_active($total eq 1 && ! ($is_root || $is_group) && $$self{_CFG}{'environments'}{$uuid}{'favourite'});
    $$self{_GUI}{connFavourite}->set_image(PACIcons::icon_image($$self{_CFG}{'environments'}{$uuid}{'favourite'} ? 'favourite_on' : 'favourite_off','asbru-favourite-' . ($$self{_CFG}{'environments'}{$uuid}{'favourite'} ? 'on' : 'off')));
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 0;

    $$self{_GUI}{nb}->set_tab_pos($$self{_CFG}{'defaults'}{'tabs position'});
    $$self{_GUI}{treeConnections}->set_enable_tree_lines($$self{_CFG}{'defaults'}{'enable tree lines'});
    $$self{_GUI}{scroll1}->set_overlay_scrolling($$self{_CFG}{'defaults'}{'tree overlay scrolling'});
    $$self{_GUI}{descView}->modify_font(Pango::FontDescription::from_string($$self{_CFG}{'defaults'}{'info font'}));

    if ($$self{_TRAY} && ref($$self{_TRAY}) && $$self{_TRAY}->can('set_active')) {
        !$$self{_GUI}{main}->get_visible() || $$self{_CFG}{defaults}{'show tray icon'} ? $$self{_TRAY}->set_active() : $$self{_TRAY}->set_passive();
    } else {
        print "INFO: Tray object unavailable or not initialized (skipping visibility toggle)\n" if $ENV{ASBRU_DEBUG};
    }

    $$self{_GUI}{lockApplicationBtn}->set_sensitive($$self{_CFG}{'defaults'}{'use gui password'});

    $self->_updateGUIWithUUID($sel_uuids[0]) if $total == 1;

    return 1;
}

# Refresh visible icons after icon theme change (system/internal) without restart
sub _refresh_all_icons {
    my $self = shift;
    eval { require PACIcons; } or return; # safety
    my $builder = $$self{_GUI_BUILDER};
    # Fallback: attempt to detect builder from known GUI hash
    if (!$builder && eval { $$self{_GUI}{builder} }) { $builder = $$self{_GUI_BUILDER} = $$self{_GUI}{builder}; }
    # If still no builder, attempt manual traversal starting from main window
    my @objects;
    if ($builder) {
        @objects = eval { $builder->get_objects };
    } elsif (my $main = eval { $$self{_GUI}{main} }) {
        # breadth-first traverse to collect GtkImage
        my @queue = ($main);
        my %seen;
        while (@queue) {
            my $w = shift @queue; next if $seen{$w}++;
            push @objects, $w;
            if (eval { $w->can('get_children') }) {
                push @queue, ($w->get_children);
            } elsif (eval { $w->can('get_child') }) {
                my $child = eval { $w->get_child }; push @queue, $child if $child;
            }
        }
    } else {
        return; # nothing to refresh yet
    }
    my %map_basic = (
        imgTrayIcon => ($$self{_CFG}{'defaults'}{'use bw icon'} ? 'tray_bw' : 'tray_color'),
        imgKeePassOpts => 'keepass',
        imageMethod => 'ssh',
        imageConnOptions => 'preferences-system',
        imgProtectedEdit => 'protected',
    # Link help buttons (they are GtkLinkButton containing image set earlier, some may also be GtkImage by name)
    linkHelpConn1 => 'help_link', linkHelpNetwokSettings => 'help_link',
    linkHelpMOBE => 'help_link', linkHelpMOLF => 'help_link', linkHelpMOAD => 'help_link', linkHelpTOBE => 'help_link',
    linkHelpTOLF => 'help_link', linkHelpTOAD => 'help_link', linkHelpLocalShell => 'help_link', linkHelpGlobalNetwork => 'help_link',
    );
    my %system_name_map = (
        tray_bw => 'network-transmit-receive',
        tray_color => 'network-workgroup',
        keepass => 'dialog-password',
        ssh => 'network-server',
        'preferences-system' => 'preferences-system',
        protected => 'changes-prevent',
    );
    my $system_active = ($$self{_CFG}{defaults}{theme} // '') eq 'system';
    my $force_internal = $$self{_CFG}{defaults}{'force_internal_icons'} ? 1 : 0;
    my $icon_theme = eval { Gtk3::IconTheme::get_default() };
    for my $obj (@objects) {
        next unless eval { $obj->isa('Gtk3::Image') };
        my $name = eval { $obj->get_name } // '';
        my $logical = $map_basic{$name};
        if (!$logical && $name =~ /method/i) { $logical = 'ssh'; }
        if (!$logical && $name =~ /lock|protected/i) { $logical = 'protected'; }
        if (!$logical && $name =~ /tray/i) { $logical = ($$self{_CFG}{'defaults'}{'use bw icon'} ? 'tray_bw' : 'tray_color'); }
        next unless $logical;
    if ($system_active && !$force_internal && $icon_theme) {
            my $std = $system_name_map{$logical};
            if ($std && eval { $icon_theme->has_icon($std) }) {
                eval { $obj->set_from_icon_name($std, 'dialog'); };
        print STDERR "DEBUG: refresh system icon $std ($logical)\n" if $ENV{ASBRU_DEBUG};
                next;
            }
        }
        my $img = PACIcons::icon_image($logical, undef);
        if ($img && $img->get_storage_type eq 'pixbuf') { $obj->set_from_pixbuf($img->get_pixbuf); }
    }
    # Refresh images inside primary buttons (if they contain GtkImage children)
    for my $btn_name (qw(connectBtn shellBtn configBtn quitBtn)) {
        my $btn = eval { $self->{_GUI}{$btn_name} } or next;
        next unless eval { $btn->can('get_children') };
        my @kids = eval { $btn->get_children };
        for my $kid (@kids) {
            next unless eval { $kid->isa('Gtk3::Image') };
            my $logical = ($btn_name eq 'connectBtn') ? 'connect' :
                          ($btn_name eq 'shellBtn')   ? 'shell'   :
                          ($btn_name eq 'configBtn')  ? 'preferences' :
                          ($btn_name eq 'quitBtn')    ? 'quit_action' : undef;
            next unless $logical;
        if ($system_active && !$force_internal && $icon_theme) {
                my $std = $system_name_map{$logical};
                if ($std && eval { $icon_theme->has_icon($std) }) {
                    eval { $kid->set_from_icon_name($std, 'button'); };
            print STDERR "DEBUG: refresh system icon $std ($logical) [button]\n" if $ENV{ASBRU_DEBUG};
                    next;
                }
            }
            my $img = PACIcons::icon_image($logical, undef);
            if ($img && $img->get_storage_type eq 'pixbuf') { $kid->set_from_pixbuf($img->get_pixbuf); }
            elsif ($img && eval { $img->get_storage_type } ne 'pixbuf') { # icon_name-based
                # Recreate by name if possible
                # (No direct API to extract name; rely on logical mapping already applied above if needed)
            }
        }
    }
    # Refresh GtkLinkButton images (help links)
    for my $lnk (qw(linkHelpConn1 linkHelpNetwokSettings linkHelpMOBE linkHelpMOLF linkHelpMOAD linkHelpTOBE linkHelpTOLF linkHelpTOAD linkHelpLocalShell linkHelpGlobalNetwork)) {
        my $btn = eval { $self->{_GUI}{$lnk} } or next;
        next unless eval { $btn->can('get_children') };
        my @kids = eval { $btn->get_children };
        for my $kid (@kids) {
            next unless eval { $kid->isa('Gtk3::Image') };
            if ($system_active && !$force_internal && $icon_theme) {
                my $std = 'help-browser';
                if (eval { $icon_theme->has_icon($std) }) { eval { $kid->set_from_icon_name($std,'button'); }; next; }
            }
            my $img = PACIcons::icon_image('help_link', undef);
            if ($img && $img->get_storage_type eq 'pixbuf') { $kid->set_from_pixbuf($img->get_pixbuf); }
        }
    }
    return 1;
}

# Refresh tree node colors after theme change
sub _refresh_tree_colors {
    my $self = shift;
    
    return unless $$self{_GUI}{treeConnections};
    
    print STDERR "DEBUG: Refreshing tree colors for theme change\n" if $ENV{ASBRU_DEBUG};
    
    # Get current model
    my $modelsort = $$self{_GUI}{treeConnections}->get_model();
    return unless $modelsort;
    my $model = $modelsort->get_model();
    return unless $model;
    
    # Traverse all tree nodes and update their text
    $model->foreach(sub {
        my ($store, $path, $iter) = @_;
        my $uuid = $store->get_value($iter, 2);
        return 0 unless defined $uuid && $uuid ne '';
        
        # Rebuild node name with current theme colors
        my $gui_name = $self->__treeBuildNodeName($uuid);
        $store->set($iter, 1, $gui_name);
        
        return 0; # continue traversal
    });
    
    print STDERR "DEBUG: Tree colors refreshed\n" if $ENV{ASBRU_DEBUG};
}

# Apply a system icon theme at runtime (used by preferences preview)
sub _apply_system_icon_theme {
    my ($self, $theme) = @_;
    return unless defined $theme && length $theme;
    return 1 if ($$self{_SYSTEM_THEME_SET} && $$self{_CURRENT_SYSTEM_ICON_THEME} && $$self{_CURRENT_SYSTEM_ICON_THEME} eq $theme);
    my $now = time;
    if (defined $$self{_CURRENT_SYSTEM_ICON_THEME} && $$self{_CURRENT_SYSTEM_ICON_THEME} eq $theme && defined $$self{_LAST_SYSTEM_ICON_THEME_APPLY} && ($now - $$self{_LAST_SYSTEM_ICON_THEME_APPLY}) < 1) {
        return 1; # throttle duplicate rapid apply
    }
    eval { require PACIcons; PACIcons::clear_cache(); };
    eval { Gtk3::IconTheme::get_default()->set_custom_theme($theme); 1 } or do {
        print STDERR "WARN: Failed to apply system icon theme '$theme': $@\n" if $@;
        return 0;
    };
    $$self{_CURRENT_SYSTEM_ICON_THEME} = $theme; $$self{_SYSTEM_THEME_SET}=1;
    $$self{_LAST_SYSTEM_ICON_THEME_APPLY} = $now;
    eval { Gtk3::IconTheme::get_default()->rescan_if_needed(); };
    print STDERR "INFO: Applied system icon theme '$theme'\n" if $ENV{ASBRU_DEBUG};
    $self->_refresh_all_icons();
    return 1;
}

# Apply internal (bundled) theme at runtime and refresh icons
sub _apply_internal_theme {
    my ($self, $theme) = @_;
    return 0 unless defined $theme && $theme =~ /^(asbru-dark|asbru-color|default)$/;
    my $dir = "$RES_DIR/themes/$theme";
    return 0 unless -d $dir;
    $$self{_CFG}{'defaults'}{'theme'} = $theme;
    delete $$self{_CFG}{'defaults'}{'system icon theme override'}; # clear system override when switching to internal theme
    $$self{_THEME} = $dir;
    # PACIcons module removed - icon registration will be handled by PACUtils
    _registerPACIcons($dir);
    
    # Reload CSS styling for theme
    if (-f "$dir/asbru.css") {
        my $css_provider = Gtk3::CssProvider->new();
        eval { $css_provider->load_from_path("$dir/asbru.css"); };
        unless ($@) {
            eval {
                my $screen = Gtk3::Gdk::Screen::get_default();
                if ($screen) {
                    # Remove old theme provider if exists
                    if ($$self{_THEME_CSS_PROVIDER}) {
                        Gtk3::StyleContext::remove_provider_for_screen($screen, $$self{_THEME_CSS_PROVIDER});
                    }
                    # Add new theme provider  
                    Gtk3::StyleContext::add_provider_for_screen($screen, $css_provider, 600);
                    $$self{_THEME_CSS_PROVIDER} = $css_provider;
                } else {
                    my $dummy = Gtk3::Window->new();
                    $dummy->get_style_context->add_provider($css_provider, 600);
                }
                1;
            } or do { };
            print STDERR "INFO: Reloaded CSS for theme '$theme'\n" if $ENV{ASBRU_DEBUG};
        }
    }
    
    eval { $self->_refresh_all_icons(); };
    eval { $self->_refresh_tree_colors(); };
    print STDERR "INFO: Applied internal icon theme '$theme'\n" if $ENV{ASBRU_DEBUG};
    return 1;
}

sub _updateGUIFavourites {
    my $self = shift;

    my @sel_uuids = $$self{_GUI}{treeFavourites}->_getSelectedUUIDs();
    my $total = scalar(@sel_uuids);
    my $uuid = $sel_uuids[0];

    $self->_clearLeftMenuTabLabels();
    if ($$self{_CFG}{defaults}{'show tree titles'}) {
        $$self{_GUI}{nbFavTabLabel}->set_text(' Favourites');
    }

    $$self{_GUI}{connSearch}->set_sensitive(0);
    $$self{_GUI}{groupAddBtn}->set_sensitive(0);
    $$self{_GUI}{connAddBtn}->set_sensitive(0);
    $$self{_GUI}{connEditBtn}->set_sensitive($total >= 1 && $uuid ne '__PAC__ROOT__');
    $$self{_GUI}{nodeRenBtn}->set_sensitive(0);
    $$self{_GUI}{nodeDelBtn}->set_sensitive(0);
    $$self{_GUI}{connExecBtn}->set_sensitive($total >= 1 && $uuid ne '__PAC__ROOT__');
    $$self{_GUI}{descView}->set_sensitive(0);
    $$self{_GUI}{frameStatistics}->set_sensitive(0);
    $$self{_GUI}{frameScreenshots}->set_sensitive(0);
    $$self{_GUI}{connFavourite}->set_sensitive(1 && $uuid ne '__PAC__ROOT__');
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 1;
    $$self{_GUI}{connFavourite}->set_active($uuid ne '__PAC__ROOT__');
    $$self{_GUI}{connFavourite}->set_image(PACIcons::icon_image('favourite_on','asbru-favourite-on'));
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 0;

    if ($total == 1) {
        $self->_updateGUIWithUUID($sel_uuids[0]);
    }

    return 1;
}

sub _updateGUIHistory {
    my $self = shift;

    my @sel_uuids = $$self{_GUI}{treeHistory}->_getSelectedUUIDs();
    my $total = scalar(@sel_uuids);
    my $uuid = $sel_uuids[0];

    $self->_clearLeftMenuTabLabels();
    if ($$self{_CFG}{defaults}{'show tree titles'}) {
        $$self{_GUI}{nbHistTabLabel}->set_text(' History');
    }
    $$self{_GUI}{connSearch}->set_sensitive(0);
    $$self{_GUI}{groupAddBtn}->set_sensitive(0);
    $$self{_GUI}{connAddBtn}->set_sensitive(0);
    $$self{_GUI}{connEditBtn}->set_sensitive($total >= 1 && $uuid ne '__PAC__ROOT__' && $uuid ne '__PAC_SHELL__');
    $$self{_GUI}{nodeRenBtn}->set_sensitive(0);
    $$self{_GUI}{nodeDelBtn}->set_sensitive(0);
    $$self{_GUI}{connExecBtn}->set_sensitive($total >= 1 && $uuid ne '__PAC__ROOT__');
    $$self{_GUI}{descView}->set_sensitive(0);
    $$self{_GUI}{frameStatistics}->set_sensitive(0);
    $$self{_GUI}{frameScreenshots}->set_sensitive(0);
    $$self{_GUI}{connFavourite}->set_sensitive(0);
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 1;
    $$self{_GUI}{connFavourite}->set_active($$self{_CFG}{'environments'}{$uuid}{'favourite'});
    $$self{_GUI}{connFavourite}->set_image(PACIcons::icon_image($$self{_CFG}{'environments'}{$uuid}{'favourite'} ? 'favourite_on' : 'favourite_off', $$self{_CFG}{'environments'}{$uuid}{'favourite'} ? 'asbru-favourite-on' : 'asbru-favourite-off'));
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 0;

    $self->_updateGUIWithUUID($sel_uuids[0]) if $total == 1;

    return 1;
}

sub _updateGUIClusters {
    my $self = shift;

    my @sel_uuids = $$self{_GUI}{treeClusters}->_getSelectedNames();
    my $total = scalar(@sel_uuids);
    my $uuid = $sel_uuids[0];

    $self->_clearLeftMenuTabLabels();
    if ($$self{_CFG}{defaults}{'show tree titles'}) {
        $$self{_GUI}{nbCluTabLabel}->set_text(' Clusters');
    }
    $$self{_GUI}{connSearch}->set_sensitive(0);
    $$self{_GUI}{groupAddBtn}->set_sensitive(0);
    $$self{_GUI}{connAddBtn}->set_sensitive(0);
    $$self{_GUI}{connEditBtn}->set_sensitive(0);
    $$self{_GUI}{nodeRenBtn}->set_sensitive(0);
    $$self{_GUI}{nodeDelBtn}->set_sensitive(0);
    $$self{_GUI}{connExecBtn}->set_sensitive($total == 1);
    $$self{_GUI}{descView}->set_sensitive(0);
    $$self{_GUI}{frameStatistics}->set_sensitive(0);
    $$self{_GUI}{frameScreenshots}->set_sensitive(0);
    $$self{_GUI}{connFavourite}->set_sensitive(0);
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 1;
    $$self{_GUI}{connFavourite}->set_active(0);
    $$self{_NO_PROPAGATE_FAV_TOGGLE} = 0;

    $self->_updateGUIWithUUID('__PAC__ROOT__');

    return 1;
}

sub _updateClustersList {
    my $self = shift;

    @{ $$self{_GUI}{treeClusters}{data} } = ();
    foreach my $ac (sort { $a cmp $b } keys %{ $$self{_CFG}{defaults}{'auto cluster'} }) {
        push(@{ $$self{_GUI}{treeClusters}{data} }, ({ value => [ $AUTOCLUSTERICON, $ac ]}));
    }
    foreach my $cluster (sort { $a cmp $b } keys %{ $$self{_CLUSTER}->getCFGClusters() }) {
        push(@{ $$self{_GUI}{treeClusters}{data} }, ({ value => [ $CLUSTERICON, $cluster ]}));
    }

    return 1;
}

sub _updateFavouritesList {
    my $self = shift;
    my ($name);

    @{ $$self{_GUI}{treeFavourites}{data} } = ();
    foreach my $uuid (keys %{ $$self{_CFG}{'environments'} }) {
        if (!$$self{_CFG}{'environments'}{$uuid}{'favourite'}) {
            next;
        }
        my $icon = $$self{_METHODS}{ $$self{_CFG}{'environments'}{$uuid}{'method'} }{'icon'};
        my $group = $$self{_CFG}{'environments'}{$uuid}{'parent'};
        if ($group) {
            $name = __($$self{_CFG}{'environments'}{$uuid}{'name'});
            $group = __("$$self{_CFG}{'environments'}{$group}{'name'} : ");
            $name = "$group$name";
        } else {
            $name = __($$self{_CFG}{'environments'}{$uuid}{'name'});
        }
        push(@{ $$self{_GUI}{treeFavourites}{data} }, ({ value => [ $icon, $name, $uuid ] }));
    }

    $self->_updateGUIFavourites();

    return 1;
}

sub _delNodes {
    my $self = shift;
    my @uuids = @_;

    foreach my $uuid (@uuids) {
        if (!defined $$self{_CFG}{'environments'}{$uuid}) {
            next;
        }

        # Delete every possible "sweet child of mine"
        $$self{_CFG}{'environments'}{$uuid}{'_is_group'} and $self->_delNodes($_) foreach (keys %{ $$self{_CFG}{'environments'}{$uuid}{'children'} });

        # Delete me from my parent's children list
        my $parent_uuid = $$self{_CFG}{'environments'}{$uuid}{'parent'};
        if (!((defined $parent_uuid) && (defined $$self{_CFG}{'environments'}{$parent_uuid}))) {
            next;
        }
        if (defined $$self{_CFG}{'environments'}{$parent_uuid}{'children'}{$uuid}) {
            delete $$self{_CFG}{'environments'}{$parent_uuid}{'children'}{$uuid};
        }

        # Delete me from the configuration
        delete $$self{_CFG}{'environments'}{$uuid};
    }

    return 1;
}

sub _showConnectionsList {
    my $self = shift;
    my $force = shift // 1;

    if ($force) {
        # Force hidden state so that the show operation is properly handled
        # (otherwise the window may remain in the 'scratchpad' / 'withdrawn' state, as with i3wm)
        $$self{_GUI}{main}->hide();
        $$self{_GUI}{main}->show();
    }

    # Ensure compact panel is shown (could still be hidden if started iconified)
    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        $$self{_GUI}{vboxCommandPanel}->show_all();
        $$self{_GUI}{hpane}->show();
    }

    # The first first display when started iconified must be a show_all
    if ($$self{_CMDLINETRAY} == 1) {
        $$self{_GUI}{main}->show_all();
        $$self{_CMDLINETRAY} = 2;
    }


    # Do show the main window
    $$self{_GUI}{main}->present();

    if ($force) {
        $$self{_GUI}{main}->move($$self{_GUI}{posx} // 0, $$self{_GUI}{posy} // 0);
    }
}

sub _hideConnectionsList {
    my $self = shift;

    if ($$self{_GUI}{main}->get_visible()) {
        my ($x, $y) = $$self{_GUI}{main}->get_position();
        if ($x > 0 || $y > 0) {
            ($$self{_GUI}{posx}, $$self{_GUI}{posy}) = ($x, $y);
        }
    }

    $$self{_GUI}{main}->hide();
}

sub _toggleConnectionsList {
    my $self = shift;
    $$self{_GUI}{showConnBtn}->set_active(!$$self{_GUI}{showConnBtn}->get_active());
}

sub _doToggleDisplayConnectionsList {
    my $self = shift;

    if ($$self{_CFG}{'defaults'}{'layout'} eq 'Compact') {
        if ($$self{_GUI}{showConnBtn}->get_active()) {
            $PACMain::FUNCS{_MAIN}->_showConnectionsList();
        } else {
            $PACMain::FUNCS{_MAIN}->_hideConnectionsList();
        }
    } else {
        if ($$self{_GUI}{showConnBtn}->get_active()) {
            $$self{_GUI}{vboxCommandPanel}->show();
        } else {
            $$self{_GUI}{vboxCommandPanel}->hide();
        }
        if ($$self{_GUI}{showConnBtn}->get_active()) {
            # Remeber that no VTE has te focus anymore
            $$self{_HAS_FOCUS} = '';
            # Get the currently displayed tray and move keyboard focus to it
            my $tree = $self->_getCurrentTree();
            if ($tree) {
                $tree->grab_focus();
            }
        } else {
            # Look for the current tab page and move keyboard focus to it
            my $pnum = $$self{_GUI}{nb}->get_current_page();
            $self->_doFocusPage($pnum);
        }
    }
}

sub _copyNodes {
    my $self = shift;
    my $cut = shift // '0';
    my $parent = shift // '__PAC__COPY__';
    my $sel_uuids = shift // [ $$self{_GUI}{treeConnections}->_getSelectedUUIDs() ];

    $LAST_COPIED_NODES = [@{ $sel_uuids }];
    # Empty the copy-vault
    $$self{_COPY}{'data'} = {};
    $$self{_COPY}{'cut'} = $cut;

    my $total = scalar(@{ $sel_uuids });
    if (!$total || ($$sel_uuids[0] eq '__PAC__ROOT__')) {
        return 1;
    }
    foreach my $sel (@{ $sel_uuids }) {
        $self->__dupNodes($parent, $sel, $$self{_COPY}{'data'}, $cut);
    }

    return 1;
}

sub _cutNodes {
    my $self = shift;

    my @sel_uuids = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
    my $total = scalar(@sel_uuids);

    if (!$total) {
        print("ERROR: Nothing to cut\n");
        return 1;
    }
    if ($sel_uuids[0] eq '__PAC__ROOT__') {
        print("ERROR: Cannot cut the root node\n");
        return 1;
    }
    if ($self->_hasProtectedChildren(\@sel_uuids)) {
        return _wMessage($$self{_GUI}{main}, "Cannot cut selection.\n\nThere are <b>protected</b> nodes selected.");
    }

    # Check that the cut node is not protected
    if ($$self{_CFG}{'environments'}{$sel_uuids[0]}{'_is_group'} && $$self{_CFG}{'environments'}{$sel_uuids[0]}{'_protected'}) {
        print("ERROR: Cannot cut a protected folder [$$self{_CFG}{'environments'}{$sel_uuids[0]}{name}]\n");
        return _wMessage($$self{_GUI}{main}, "Cannot cut a protected folder:\n\n\t<b>$$self{_CFG}{'environments'}{$sel_uuids[0]}{name}</b>");
    }

    # Check that parent node is not protected
    foreach my $uuid (@sel_uuids) {
        my $parent =  $$self{_CFG}{'environments'}{$uuid}{'parent'};
        if ($$self{_CFG}{'environments'}{$parent}{'_is_group'} && $$self{_CFG}{'environments'}{$parent}{'_protected'}) {
            print("ERROR: Cannot cut from a protected folder [$$self{_CFG}{'environments'}{$parent}{name}]\n");
            return _wMessage($$self{_GUI}{main}, "Cannot cut from a protected folder:\n\n\t<b>$$self{_CFG}{'environments'}{$parent}{name}</b>");
        }
    }

    # Copy the selected nodes
    $self->_copyNodes('cut', '__PAC__COPY__', \@sel_uuids);
    if (! scalar(keys %{ $$self{_COPY}{'data'} })) {
        print("ERROR: Failed to copy-cut selected data\n");
        return 1;
    }

    # Delete selected nodes from treeConnections
    foreach my $uuid (@sel_uuids) {
        $$self{_GUI}{treeConnections}->_delNode($uuid);
    }

    # Delete selected nodes from the configuration
    $self->_delNodes(@sel_uuids);

    $self->_setCFGChanged(1);
    return 1;
};

sub _pasteNodes {
    my $self = shift;
    my $parent = shift // '__PAC__COPY__';
    my $uuid = shift;
    my $first = shift // 1;

    if (!scalar(keys %{ $$self{_COPY}{'data'} })) {
        print("ERROR: No data to copy...\n");
        return 1;
    }
    if (!$$self{_CFG}{'environments'}{$parent}{'_is_group'} && $parent ne '__PAC__ROOT__') {
        print("ERROR: Cannot paste outside of root parent\n");
        return 1;
    }

    if ($$self{_CFG}{'environments'}{$parent}{'_is_group'} && $$self{_CFG}{'environments'}{$parent}{'_protected'}) {
        print("ERROR: Cannot paste into a protected folder [$$self{_CFG}{'environments'}{$parent}{name}]\n");
        return _wMessage($$self{_GUI}{main}, "Cannot paste into a protected folder:\n\n\t<b>$$self{_CFG}{'environments'}{$parent}{name}</b>");
    }

    if ($parent ne $$self{_COPY}{'data'}{$uuid}{'original_parent'}) {
        # If paste is under different parent, remove copy message, it is not necessary
        $$self{_COPY}{'data'}{$uuid}{'name'} =~ s/ - copy//;
    }
    # Remove original_parent value is not part of the configuration standard
    delete $$self{_COPY}{'data'}{$uuid}{'original_parent'};

    # Add new node to configuration
    $$self{_CFG}{'environments'}{$uuid} = $$self{_COPY}{'data'}{$uuid};
    $$self{_CFG}{'environments'}{$uuid}{'parent'} = $parent;
    $$self{_CFG}{'environments'}{$parent}{'children'}{$uuid} = 1;
    # DevNote: a pasted folder cannot be protected otherwise recursiveness will likely fail
    $$self{_CFG}{'environments'}{$uuid}{'_protected'} = $$self{_CFG}{'environments'}{$uuid}{'_protected'} && !$$self{_CFG}{'environments'}{$uuid}{'_is_group'};

    # Add new node to Connections Tree
    $$self{_GUI}{treeConnections}->_addNode(
        $$self{_CFG}{'environments'}{$uuid}{'parent'},       # Parent UUID
        $uuid,                                               # UUID
        $self->__treeBuildNodeName($uuid),                   # Name
        ! $$self{_CFG}{'environments'}{$uuid}{'_is_group'} ? # Icon
            $$self{_METHODS}{ $$self{_CFG}{'environments'}{$uuid}{'method'} }{'icon'} :
            $GROUPICONCLOSED);

    # Repeat procedure for every 1st level child
    foreach my $child (keys %{ $$self{_COPY}{'data'}{$uuid}{'children'} }) {
        $self->_pasteNodes($uuid, $child, 0);
        delete $$self{_COPY}{'data'}{$uuid};
    }

    if ($first) {
        $FUNCS{_TRAY}->set_tray_menu();
    }

    $self->_setCFGChanged(1);
    return 1;
};

sub __dupNodes {
    my $self = shift;
    my $parent = shift;
    my $uuid = shift;
    my $cfg = shift;
    my $cut = shift // '0';

    # Generate a new UUID for the copied element
    my $new_uuid = OSSP::uuid->new(); $new_uuid->make("v4");
    my $new_txt_uuid = $new_uuid->export("str");
    undef $new_uuid;

    # Clone the node with the NEW UUID
    $$cfg{$new_txt_uuid} = dclone($$self{_CFG}{'environments'}{$uuid});
    # Save original parent node for reference on paste
    $$cfg{$new_txt_uuid}{'original_parent'} = $$cfg{$new_txt_uuid}{'parent'};
    $$cfg{$new_txt_uuid}{'parent'} = $parent;
    if (!$cut) {
        # If action is not a cut, add 'copy' to the name, so it is different from previous node
        $$cfg{$new_txt_uuid}{'name'} = "$$self{_CFG}{'environments'}{$uuid}{'name'} - copy";
    }
    $$cfg{$parent}{'children'}{$new_txt_uuid} = 1;
    $$cfg{$new_txt_uuid}{'cluster'} = [];
    $$cfg{$new_txt_uuid}{'_protected'} = 0;

    # Delete screenshots and statistics on duplicated node
    $$cfg{$new_txt_uuid}{'screenshots'} = ();
    delete $FUNCS{_STATS}{statistics}{$new_txt_uuid};

    delete $$cfg{$parent}{'children'}{$uuid};

    # Repeat procedure for every 1st level child
    foreach my $child ($$self{_GUI}{treeConnections}->_getChildren($uuid, 'all', 0)) {
        $self->__dupNodes($new_txt_uuid, $child, $cfg, $cut);
    }

    return $cfg;
}

sub _cloneNodes {
    my $self = shift;
    my @sel = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();
    if (scalar(@sel) != 1) {
        # We can only clone a single selection
        return;
    }

    # The parent node
    my $parent_uuid = $$self{_CFG}{'environments'}{$sel[0]}{'parent'};

    # Prevent cloning into a protected folder
    if (!defined($parent_uuid) || $$self{_CFG}{'environments'}{$parent_uuid}{_protected}) {
        print("ERROR: " . (defined($parent_uuid) ? "Cannot duplicate into a protected folder [$$self{_CFG}{'environments'}{$parent_uuid}{name}]\n" : "Cannot duplicate the root folder.\n"));
        return _wMessage($$self{_GUI}{main}, (defined($parent_uuid) ? "Cannot duplicate into a protected folder:\n\n\t<b>$$self{_CFG}{'environments'}{$parent_uuid}{name}</b>" : "Cannot duplicate the root folder."));
    }

    # Actually perform cloning
    $self->_copyNodes();
    foreach my $child (keys %{ $$self{_COPY}{'data'}{'__PAC__COPY__'}{'children'} }) {
        $self->_pasteNodes($parent_uuid, $child);
    };
    $$self{_COPY}{'data'} = {};
}

sub __exportNodes {
    my $self = shift;
    my $sel = shift // [ $$self{_GUI}{treeConnections}->_getSelectedUUIDs() ];

    my ($list, $all, $cipher) = $self->_bulkEdit("$APPNAME (v.$APPVERSION) Choose fields to skip during Export phase", "Please, <b>check</b> the fields to be changed during the Export phase\nand put a new (may be empty) value for them.\n<b>Unchecked</b> elements will be exported with their original values.", 0, 'ask for cipher');

    if (!defined $list) {
        return 0;
    }

    my $choose = Gtk3::FileChooserDialog->new(
        "$APPNAME (v.$APPVERSION) Choose file to Export",
        $$self{_WINDOWCONFIG},
        'GTK_FILE_CHOOSER_ACTION_SAVE',
        'Export' , 'GTK_RESPONSE_ACCEPT',
        'Cancel' , 'GTK_RESPONSE_CANCEL',
    );
    $choose->set_do_overwrite_confirmation(1);
    $choose->set_current_folder($ENV{'HOME'} // '/tmp');
    $choose->set_current_name("asbru_export.yml");

    my $out = $choose->run();
    my $file = $choose->get_filename();
    $file =~ /^(.+)\.yml$/ or $file .= '.yml';
    $choose->destroy();

    if ($out ne 'accept') {
        return 1;
    }

    my $w = _wMessage($$self{_WINDOWCONFIG}, "Please, wait while file <b>$file</b> is being exported...", 0);
    Gtk3::main_iteration() while Gtk3::events_pending();

    # Make a backup of the original CFG
    my $backup_cfg = dclone($$self{_CFG}{'environments'});

    # Modify the config (_substCFG) based on the provided list (_bulkEdit)
    foreach my $uuid (keys %{ $$self{_CFG}{'environments'} }) {
        _substCFG($$self{_CFG}{'environments'}{$uuid}, $list);
    }

    # Cipher the configuration
    $cipher and _cipherCFG($$self{_CFG});

    # Copy the selected nodes
    $self->_copyNodes(0, '__PAC__EXPORTED__', $sel);
    my $cfg = dclone($$self{_COPY}{'data'});
    delete $$self{_COPY}{'data'}{'children'};

    # Restore the original configuration
    $$self{_CFG}{'environments'} = $backup_cfg;

    require YAML;
    if (YAML::DumpFile($file, $cfg)) {
        $w->destroy();
        _wMessage($$self{_WINDOWCONFIG}, "Connection(s) succesfully exported to:\n\n$file");
    } else {
        $w->destroy();
        _wMessage($$self{_WINDOWCONFIG}, "ERROR: Could not export connection(s) to file <b>$file</b>:\n\n$!");
    }

    return 1;
}

sub __importNodes {
    my $self = shift;

    my @sel = $$self{_GUI}{treeConnections}->_getSelectedUUIDs();

    my $parent_uuid = $sel[0];
    my $parent_name = $$self{_CFG}{'environments'}{$sel[0]}{'name'};

    my $choose = Gtk3::FileChooserDialog->new(
        "$APPNAME (v.$APPVERSION) Choose a YAML file to Import",
        $$self{_WINDOWCONFIG},
        'GTK_FILE_CHOOSER_ACTION_OPEN',
        'Import' , 'GTK_RESPONSE_ACCEPT',
        'Cancel' , 'GTK_RESPONSE_CANCEL',
    );
    $choose->set_do_overwrite_confirmation(1);
    $choose->set_current_folder($ENV{'HOME'} // '/tmp');
    my $filter = Gtk3::FileFilter->new();
    $filter->set_name('YAML Files');
    $filter->add_pattern('*.yml');
    $choose->add_filter($filter);

    my $out = $choose->run();
    my $file = $choose->get_filename();
    $choose->destroy();
    if (($out ne 'accept') || (!-f $file) || ($file !~ /^(.+)\.yml$/go)) {
        return 1;
    }

    my $w = _wMessage($$self{_GUI}{main}, "Please, wait while file <b>$file</b> is being imported...", 0);
    Gtk3::main_iteration() while Gtk3::events_pending();

    require YAML;
    Gtk3::main_iteration() while Gtk3::events_pending();
    eval { $$self{_COPY}{'data'} = YAML::LoadFile($file); };
    if ($@) {
        $w->destroy();
        _wMessage($$self{_WINDOWCONFIG}, "ERROR: Could not import connection from file <b>$file</b>:\n\n$@");
        return 1;
    }

    Gtk3::main_iteration() while Gtk3::events_pending();

    # Full export file? (including config!)
    if (defined $$self{_COPY}{'data'}{'__PAC__EXPORTED__FULL__'}) {
        if (! _wConfirm($$self{_GUI}{main}, "Selected config file is a <b>FULL</b> backup.\nImporting it will result in all current data being <b>substituted</b> by the new one.\n<b>Plus, it REQUIRES restarting the application</b>.\nReplace current configuration?")) {
            delete $$self{_COPY}{'data'}{'children'};
            $w->destroy();
            return 1;
        }

        Gtk3::main_iteration() while Gtk3::events_pending();
        @{ $$self{_GUI}{treeConnections}{'data'} } = ();
        @{ $$self{_GUI}{treeConnections}{'data'} } = ({
            value => [ $GROUPICON_ROOT, $self->__treeBuildNodeName('__PAC__ROOT__', 'My Connections'), '__PAC__ROOT__' ],
            children => []
        });
        Gtk3::main_iteration() while Gtk3::events_pending();

        copy($file, $CFG_FILE) and unlink $CFG_FILE_NFREEZE;
        delete $$self{_CFG};
        $self->_readConfiguration(0);
        $self->_loadTreeConfiguration('__PAC__ROOT__');
        delete $$self{_COPY}{'data'};
        $w->destroy();
        $self->_setCFGChanged(1);
        delete $$self{_CFG}{'__PAC__EXPORTED__'};
        delete $$self{_CFG}{'__PAC__EXPORTED__FULL__'};
        _wMessage($$self{_WINDOWCONFIG}, "File <b>$file</b> succesfully imported.\n now <b>restarting</b>!", 0);
        sleep 1;
        Gtk3::main_iteration() while Gtk3::events_pending();
        sleep 1;
        Gtk3::main_iteration() while Gtk3::events_pending();
        sleep 1;
        Gtk3::main_iteration() while Gtk3::events_pending();
        print STDERR "[DEBUG] Restarting using executable '$^X' with arg '$0'";
        exec($^X, $0) or print STDERR "[ERROR] Couldn't exec {$^X} $0: $!";
        exit 1;

    # Bad export file
    } elsif (! defined $$self{_COPY}{'data'}{'__PAC__EXPORTED__'}) {
        delete $$self{_COPY}{'data'}{'children'};
        $w->destroy();
        _wMessage($$self{_WINDOWCONFIG}, "File <b>$file</b> does not look like a valid exported connection!");
        return 1;

    # Correct partial export file
    } else {
        my $i = 0;
        foreach my $child (keys %{ $$self{_COPY}{'data'}{'__PAC__EXPORTED__'}{'children'} }) {
            $self->_pasteNodes($parent_uuid, $child);
            ++$i;
        }
        $$self{_COPY}{'data'} = {};
        _decipherCFG($$self{_CFG});
        $w->destroy();
        _wMessage($$self{_WINDOWCONFIG}, "File <b>$file</b> succesfully imported:\n<b>$i</b> element(s) added");
        delete $$self{_CFG}{'__PAC__EXPORTED__'};
        delete $$self{_CFG}{'__PAC__EXPORTED__FULL__'};
        $self->_setCFGChanged(1);
    }

    $FUNCS{_TRAY}->set_tray_menu();

    return 1;
}

sub _bulkEdit {
    my $self = shift;
    my $title = shift // "$APPNAME (v$APPVERSION) : Bulk Edit";
    my $label = shift // "Select and change the values you want to modify in the list below.\n<b>Only those checked will be affected.</b>\nFor Regular Expressions, <b>Match pattern</b> will be substituted with <b>New value</b>,\nmuch like Perl's: <b>s/Match pattern/New value/g</b>";
    my $groups = shift // 0;
    my $cipher = shift // 0;
    my %list;
    my %w;

    # Create the 'bulkEdit' dialog window,
    $w{data} = Gtk3::Dialog->new_with_buttons($title, undef, 'modal');
    # Replace deprecated stock buttons with custom buttons + PACIcons
    require PACIcons;
    my $btn_ok = Gtk3::Button->new();
    $btn_ok->set_image(PACIcons::icon_image('ok','gtk-ok'));
    $btn_ok->set_always_show_image(1);
    $btn_ok->set_label('OK');
    my $btn_cancel = Gtk3::Button->new();
    $btn_cancel->set_image(PACIcons::icon_image('cancel','gtk-cancel'));
    $btn_cancel->set_always_show_image(1);
    $btn_cancel->set_label('Cancel');
    $w{data}->add_action_widget($btn_cancel, 'cancel');
    $w{data}->add_action_widget($btn_ok, 'ok');

    $w{data}->signal_connect('delete_event' => sub {
        $w{data}->destroy();
        undef %w;
        return 1;
    });

    # and setup some dialog properties.
    $w{data}->set_border_width(5);
    $w{data}->set_position('center');
    $w{data}->set_icon_from_file($APPICON);
    $w{data}->set_resizable(0);
    $w{data}->set_default_response('ok');

    $w{gui}{hboxIconLabel} = create_box('horizontal', 5);
    $w{data}->get_content_area->pack_start($w{gui}{hboxIconLabel}, 0, 1, 5);

    require PACIcons; $w{gui}{imgUP} = PACIcons::icon_image('edit','gtk-edit');
    $w{gui}{hboxIconLabel}->pack_start($w{gui}{imgUP}, 0, 1, 0);

    $w{gui}{lblUP} = create_label();
    $w{gui}{lblUP}->set_markup($label);
    $w{gui}{hboxIconLabel}->pack_start($w{gui}{lblUP}, 0, 1, 0);

    $w{data}->get_content_area->pack_start(create_separator(), 0, 1, 0);

    #$w{gui}{frameAffect} = create_frame(' There are GROUP(S) in the selection. Apply to: ');
    $w{gui}{frameAffect} = create_frame();
    my $lblaffect = create_label();
    $lblaffect->set_markup(' There are <b>GROUP(S)</b> in the selection. Apply to: ');
    $w{gui}{frameAffect}->set_label_widget($lblaffect);
    $w{data}->get_content_area->pack_start($w{gui}{frameAffect}, 0, 1, 0);

    $w{gui}{vboxaffect} = create_box('vertical', 0);
    $w{gui}{frameAffect}->add($w{gui}{vboxaffect});

    $w{gui}{rb1level} = Gtk3::RadioButton->new_with_label('level affected', "1st level children");
    $w{gui}{vboxaffect}->pack_start($w{gui}{rb1level}, 0, 1, 0);
    $w{gui}{rballlevel} = create_radio_button($w{gui}{rb1level}, "ALL sub-levels children");
    $w{gui}{vboxaffect}->pack_start($w{gui}{rballlevel}, 0, 1, 0);

    # Create a vbox for the list os elements to bulk-edit - AI-assisted modernization: Updated for GTK4 compatibility
    $w{gui}{vboxlist} = create_box('vertical', 0);
    $w{data}->get_content_area->pack_start($w{gui}{vboxlist}, 1, 1, 0);

    $w{gui}{framecommon} = create_frame();
    my $lblcom = create_label();
    $lblcom->set_markup(' <b><span foreground="orange">COMMON</span></b> entries: ');
    $w{gui}{framecommon}->set_label_widget($lblcom);
    $w{data}->get_content_area->pack_start($w{gui}{framecommon}, 0, 1, 0);

    $w{gui}{vboxcommon} = create_box('vertical', 0);
    $w{gui}{framecommon}->add($w{gui}{vboxcommon});

    # Build the COMMON elements - AI-assisted modernization: Updated for GTK4 compatibility
    foreach my $key ('title', 'ip', 'port', 'user', 'pass', 'passphrase user', 'passphrase') {
        $w{gui}{"hb$key"} = create_box('horizontal', 0);
        $w{gui}{vboxcommon}->pack_start($w{gui}{"hb$key"}, 0, 1, 0);

        $w{gui}{"cb$key"} = Gtk3::CheckButton->new("Set '$key': ");
        $w{gui}{"hb$key"}->pack_start($w{gui}{"cb$key"}, 0, 1, 0);
        $w{gui}{"cb$key"}->set('can_focus', 0);

        $w{gui}{"hboxre$key"} = create_box('horizontal', 0);
        $w{gui}{"hb$key"}->pack_start($w{gui}{"hboxre$key"}, 1, 1, 0);

        $w{gui}{"hboxre$key"}->pack_start(create_label('change '), 0, 1, 0);

        $w{gui}{"entryWhat$key"} = create_entry();
        $w{gui}{"hboxre$key"}->pack_start($w{gui}{"entryWhat$key"}, 1, 1, 0);
        $w{gui}{"entryWhat$key"}->set_activates_default(1);
        $w{gui}{"entryWhat$key"}->hide();

        $w{gui}{"hboxre$key"}->pack_start(create_label(' with '), 0, 1, 0);

        $w{gui}{"entry$key"} = create_entry();
        $w{gui}{"hb$key"}->pack_start($w{gui}{"entry$key"}, 1, 1, 0);
        $w{gui}{"entry$key"}->set_activates_default(1);

        $w{gui}{"cbRE$key"} = create_check_button('RegExp');
        $w{gui}{"hb$key"}->pack_start($w{gui}{"cbRE$key"}, 0, 1, 0);
        $w{gui}{"cbRE$key"}->set('can_focus', 0);
        $w{gui}{"cbRE$key"}->set_active(1);

    $w{gui}{"image$key"} = PACIcons::icon_image('edit','document-edit');
        $w{gui}{"hb$key"}->pack_start($w{gui}{"image$key"}, 0, 1, 0);

        # And setup some signals
        $w{gui}{"entry$key"}->signal_connect('changed', sub { $w{gui}{"cb$key"}->set_active($w{gui}{"entry$key"}->get_chars(0, -1) ne ''); });
    $w{gui}{"cb$key"}->signal_connect('toggled', sub { require PACIcons; my $img = PACIcons::icon_image(($w{gui}{"cb$key"}->get_active() ? 'ok' : 'edit'), ($w{gui}{"cb$key"}->get_active() ? 'gtk-ok' : 'gtk-edit')); $w{gui}{"image$key"}->set_from_pixbuf($img->get_pixbuf) if $img->get_storage_type eq 'pixbuf'; });
        $w{gui}{"cbRE$key"}->signal_connect('toggled', sub { $w{gui}{"cbRE$key"}->get_active() ? $w{gui}{"hboxre$key"}->show() : $w{gui}{"hboxre$key"}->hide(); });

        # Asign a callback to populate this entry with its own context menu
        $w{gui}{"entry$key"}->signal_connect('button_press_event' => sub {
            my ($widget, $event) = @_;
            return 0 unless $event->button eq 3;
            my @menu_items;

            # Populate with global defined variables
            my @global_variables_menu;
            foreach my $var (sort { $a cmp $b } keys %{ $PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'global variables'} }) {
                my $val = $PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'global variables'}{$var}{'value'};
                push(@global_variables_menu, {
                    label => "<GV:$var> ($val)",
                    code => sub { $w{gui}{"entry$key"}->insert_text("<GV:$var>", -1, $w{gui}{"entry$key"}->get_position()); }
                    });
                }
                push(@menu_items, {
                    label => 'Global variables...',
                    sensitive => scalar(@global_variables_menu),
                    submenu => \@global_variables_menu
                });

                # Populate with environment variables
                my @environment_menu;
                foreach my $key (sort { $a cmp $b } keys %ENV) {
                    # Do not offer Master Password, or any other environment variable with word PRIVATE, TOKEN
                    if ($key =~ /KPXC|PRIVATE|TOKEN/i) {
                        next;
                    }
                    my $value = $ENV{$key};
                    push(@environment_menu, {
                        label => "<ENV:$key>",
                        tooltip => "$key=$value",
                        code => sub { $w{gui}{"entry$key"}->insert_text("<ENV:$key>", -1, $w{gui}{"entry$key"}->get_position()); }
                    });
                }
                push(@menu_items, {
                    label => 'Environment variables...',
                    submenu => \@environment_menu
                });
                # Put an option to ask user for variable substitution
                push(@menu_items, {
                    label => 'Runtime substitution (<ASK:change_by_number>)',
                    code => sub {
                        my $pos = $w{gui}{"entry$key"}->get_property('cursor_position');
                        $w{gui}{"entry$key"}->insert_text("<ASK:change_by_number>", -1, $w{gui}{"entry$key"}->get_position());
                        $w{gui}{"entry$key"}->select_region($pos + 5, $pos + 21);
                    }
                });
                # Populate with <ASK:*|> special string
                push(@menu_items, {
                    label => 'Interactive user choose from list',
                    tooltip => 'User will be prompted to choose a value form a user defined list separated with "|" (pipes without quotes)',
                    code => sub {
                        my $pos = $w{gui}{"entry$key"}->get_property('cursor_position');
                        $w{gui}{"entry$key"}->insert_text('<ASK:descriptive line|opt1|opt2|...|optN>', -1, $w{gui}{"entry$key"}->get_position());
                        $w{gui}{"entry$key"}->select_region($pos + 5, $pos + 40);
                    }
                });
                # Populate with <CMD:*> special string
                push(@menu_items, {
                    label => 'Use a command output as value',
                    tooltip => 'The given command line will be locally executed, and its output (both STDOUT and STDERR) will be used to replace this value',
                    code => sub {
                        my $pos = $w{gui}{"entry$key"}->get_property('cursor_position');
                        $w{gui}{"entry$key"}->insert_text('<CMD:command to launch>', -1, $w{gui}{"entry$key"}->get_position());
                        $w{gui}{"entry$key"}->select_region($pos + 5, $pos + 22);
                    }
                });

                _wPopUpMenu(\@menu_items, $event);

                return 1;
        });
    }

    $w{gui}{frameExpect} = create_frame();
    my $lblexp = create_label();
    $lblexp->set_markup(' <b><span foreground="orange">EXPECT</span></b> entries: ');
    $w{gui}{frameExpect}->set_label_widget($lblexp);
    $w{data}->get_content_area->pack_start($w{gui}{frameExpect}, 0, 1, 0);

    $w{gui}{vboxexpect} = create_box('vertical', 0);
    $w{gui}{frameExpect}->add($w{gui}{vboxexpect});

    # Build the EXPECT elements - AI-assisted modernization: Updated for GTK4 compatibility
    foreach my $key ('expect', 'send') {
        $w{gui}{"hb$key"} = create_box('horizontal', 0);
        $w{gui}{vboxexpect}->pack_start($w{gui}{"hb$key"}, 0, 1, 0);

        $w{gui}{"cb$key"} = Gtk3::CheckButton->new("Set '$key': ");
        $w{gui}{"hb$key"}->pack_start($w{gui}{"cb$key"}, 0, 1, 0);
        $w{gui}{"cb$key"}->set('can_focus', 0);

        $w{gui}{"hboxre$key"} = create_box('horizontal', 0);
        $w{gui}{"hb$key"}->pack_start($w{gui}{"hboxre$key"}, 1, 1, 0);

        $w{gui}{"hboxre$key"}->pack_start(create_label('change '), 0, 1, 0);

        $w{gui}{"entryWhat$key"} = create_entry();
        $w{gui}{"hboxre$key"}->pack_start($w{gui}{"entryWhat$key"}, 1, 1, 0);
        $w{gui}{"entryWhat$key"}->set_activates_default(1);
        $w{gui}{"entryWhat$key"}->hide();

        $w{gui}{"hboxre$key"}->pack_start(create_label(' with '), 0, 1, 0);

        $w{gui}{"entry$key"} = create_entry();
        $w{gui}{"hb$key"}->pack_start($w{gui}{"entry$key"}, 1, 1, 0);
        $w{gui}{"entry$key"}->set_activates_default(1);

        $w{gui}{"cbRE$key"} = create_check_button('RegExp');
        $w{gui}{"hb$key"}->pack_start($w{gui}{"cbRE$key"}, 0, 1, 0);
        $w{gui}{"cbRE$key"}->set('can_focus', 0);
        $w{gui}{"cbRE$key"}->set_active(1);

    $w{gui}{"image$key"} = PACIcons::icon_image('edit','document-edit');
        $w{gui}{"hb$key"}->pack_start($w{gui}{"image$key"}, 0, 1, 0);

        # And setup some signals
        $w{gui}{"entry$key"}->signal_connect('changed', sub { $w{gui}{"cb$key"}->set_active($w{gui}{"entry$key"}->get_chars(0, -1) ne ''); });
    $w{gui}{"cb$key"}->signal_connect('toggled', sub { require PACIcons; my $img = PACIcons::icon_image(($w{gui}{"cb$key"}->get_active() ? 'ok' : 'edit'), ($w{gui}{"cb$key"}->get_active() ? 'gtk-ok' : 'gtk-edit')); $w{gui}{"image$key"}->set_from_pixbuf($img->get_pixbuf) if $img->get_storage_type eq 'pixbuf'; });
        $w{gui}{"cbRE$key"}->signal_connect('toggled', sub { $w{gui}{"cbRE$key"}->get_active() ? $w{gui}{"hboxre$key"}->show() : $w{gui}{"hboxre$key"}->hide(); });

        # Asign a callback to populate this entry with its own context menu
        $w{gui}{"entry$key"}->signal_connect('button_press_event' => sub {
            my ($widget, $event) = @_;

            return 0 unless $event->button eq 3;

            my @menu_items;

            # Populate with global defined variables
            my @global_variables_menu;
            foreach my $var (sort { $a cmp $b } keys %{ $PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'global variables'} }) {
                my $val = $PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'global variables'}{$var}{'value'};
                push(@global_variables_menu, {
                    label => "<GV:$var> ($val)",
                    code => sub { $w{gui}{"entry$key"}->insert_text("<GV:$var>", -1, $w{gui}{"entry$key"}->get_position()); }
                });
            }
            push(@menu_items, {
                label => 'Global variables...',
                sensitive => scalar(@global_variables_menu),
                submenu => \@global_variables_menu
            });
            # Populate with environment variables
            my @environment_menu;
            foreach my $key (sort { $a cmp $b } keys %ENV) {
                # Do not offer Master Password, or any other environment variable with word PRIVATE, TOKEN
                if ($key =~ /KPXC|PRIVATE|TOKEN/i) {
                    next;
                }
                my $value = $ENV{$key};
                push(@environment_menu, {
                    label => "<ENV:$key>",
                    tooltip => "$key=$value",
                    code => sub { $w{gui}{"entry$key"}->insert_text("<ENV:$key>", -1, $w{gui}{"entry$key"}->get_position()); }
                });
            }
            push(@menu_items, {
                label => 'Environment variables...',
                submenu => \@environment_menu
            });

            # Put an option to ask user for variable substitution
            push(@menu_items, {
                label => 'Runtime substitution (<ASK:change_by_number>)',
                code => sub {
                    my $pos = $w{gui}{"entry$key"}->get_property('cursor_position');
                    $w{gui}{"entry$key"}->insert_text("<ASK:change_by_number>", -1, $w{gui}{"entry$key"}->get_position());
                    $w{gui}{"entry$key"}->select_region($pos + 5, $pos + 21);
                }
            });

            # Populate with <ASK:*|> special string
            push(@menu_items, {
                label => 'Interactive user choose from list',
                tooltip => 'User will be prompted to choose a value form a user defined list separated with "|" (pipes without quotes)',
                code => sub {
                    my $pos = $w{gui}{"entry$key"}->get_property('cursor_position');
                    $w{gui}{"entry$key"}->insert_text('<ASK:descriptive line|opt1|opt2|...|optN>', -1, $w{gui}{"entry$key"}->get_position());
                    $w{gui}{"entry$key"}->select_region($pos + 5, $pos + 40);
                }
            });

            # Populate with <CMD:*> special string
            push(@menu_items, {
                label => 'Use a command output as value',
                tooltip => 'The given command line will be locally executed, and its output (both STDOUT and STDERR) will be used to replace this value',
                code => sub {
                    my $pos = $w{gui}{"entry$key"}->get_property('cursor_position');
                    $w{gui}{"entry$key"}->insert_text('<CMD:command to launch>', -1, $w{gui}{"entry$key"}->get_position());
                    $w{gui}{"entry$key"}->select_region($pos + 5, $pos + 22);
                }
            });

            _wPopUpMenu(\@menu_items, $event);

            return 1;
        });
    }

    $w{gui}{cbDelHidden} = Gtk3::CheckButton->new("Remove strings checked 'Hide' from the 'Expect' configuration");
    $w{gui}{vboxexpect}->pack_start($w{gui}{cbDelHidden}, 0, 1, 0);
    $w{gui}{cbDelHidden}->set_tooltip_text("If checked, every field marked as 'hide' (for example, under 'Expect' TAB) will be erased.\nThis overrides any value set for both 'pass' and 'passphrase'");

    if ($cipher) {
        $w{gui}{cbCipher} = Gtk3::CheckButton->new("Cipher secure strings");
        $w{data}->get_content_area->pack_start($w{gui}{cbCipher}, 0, 1, 0);
        $w{gui}{cbCipher}->set_tooltip_text("If checked, every passord-like and field marked as 'hide' (for example, under 'Expect' TAB) will be ciphered.\nThis may cause incompatibilities when importing from a server other than this.");
    }

    $w{data}->get_content_area->pack_start(create_separator(), 0, 1, 0);

    $w{data}->show_all();
    $groups or $w{gui}{frameAffect}->hide();
    if ($w{data}->run ne 'ok') {
        defined $w{data} and $w{data}->destroy();
        return undef;
    }

    # Get the GUI data
    foreach my $key ('title', 'ip', 'port', 'user', 'pass', 'passphrase user', 'passphrase', 'expect', 'send') {
        my $tkey = $key;
        ($key eq 'expect') and $tkey = 'EXPECT:' . $key;
        ($key eq 'send')  and $tkey = 'EXPECT:' . $key;
        $list{$tkey}{change} = $w{gui}{"cb$key"}->get_active();
        $list{$tkey}{match} = $w{gui}{"entryWhat$key"}->get_chars(0, -1);
        $list{$tkey}{value} = $w{gui}{"entry$key"}->get_chars(0, -1);
        $list{$tkey}{regexp} = $w{gui}{"cbRE$key"}->get_active();
    }
    $list{'__delete_hidden_fields__'} = $w{gui}{cbDelHidden}->get_active();

    $w{data}->destroy();
    return \%list, $w{gui}{rballlevel}->get_active(), $cipher ? $w{gui}{cbCipher}->get_active() : undef;
}

sub _setCFGChanged {
    my $self = shift;
    my $stat = shift;

    if ($$self{_READONLY}) {
        $$self{_GUI}{saveBtn}->set_label('READ ONLY INSTANCE');
        $$self{_GUI}{saveBtn}->set_sensitive(0);
    } elsif ($$self{_CFG}{defaults}{'auto save'}) {
        $$self{_GUI}{saveBtn}->set_label('Auto saving ACTIVE');
        $$self{_GUI}{saveBtn}->set_tooltip_text('Every configuration change will be saved automatically.  You can disable this feature in Preferences > Main Options.');
        $$self{_GUI}{saveBtn}->set_sensitive(0);
        $self->_saveConfiguration(undef, 0);
    } else {
        $$self{_CFG}{tmp}{changed} = $stat;
        $$self{_GUI}{saveBtn}->set_sensitive($stat);
        $$self{_GUI}{saveBtn}->set_label('_Save');
        $$self{_GUI}{saveBtn}->set_tooltip_text('Save your configuration');
    }
    return 1;
}

# Sends a message to the Ásbrú application that is already running
sub _sendAppMessage {
    my $app = shift;
    my $msg = shift;
    my $text = shift // '';

    # Do not open any file but pass the message as 'hint'
    $app->open ([], $msg.'|'.$text);
}

# Set and recover conflictive options
sub _setSafeLayoutOptions {
    my ($self,$layout) = @_;
    # Compact layout removed (Migration A 2025-08). Preserve existing settings only; no mutations.
    $$self{_CFG}{'defaults'}{'layout previous'} = $layout if defined $$self{_CFG}{'defaults'};
}

# Apply layout to window and widgets
sub _ApplyLayout {
    my ($self,$layout) = @_;
    return 1; # No-op layout handler (Compact removed)
}

# Test various options supported by the VTE library
# to centralize all tests concerning VTE into a single function
sub _setVteCapabilities {
    my $self = shift;
    
    # Use modern VTE compatibility layer
    my $capabilities = PACVte::get_vte_capabilities();
    
    # Copy capabilities to internal structure
    $$self{_Vte} = {
        major_version => $capabilities->{major_version},
        minor_version => $capabilities->{minor_version},
        binding_version => $capabilities->{binding_version},
        gtk4_compatible => $capabilities->{gtk4_compatible},
        is_legacy => $capabilities->{is_legacy},
        has_bright => $capabilities->{has_bright},
        vte_feed_child => $capabilities->{vte_feed_child},
        vte_feed_binary => $capabilities->{vte_feed_binary}
    };
    
    # Create temporary terminal for testing (only if VTE is available)
    my $vte;
    if ($HAVE_VTE) {
        $vte = PACVte::new_terminal();
        
        if ($vte) {
            # Test set_bold_is_bright support (VTE 0.52+)
            eval {
                $vte->set_bold_is_bright(0);
                $$self{_Vte}{has_bright} = 1;
            };
            if ($@) {
                $$self{_Vte}{has_bright} = 0;
            }
            
            # Test feed_child parameter count
            $$self{_Vte}{vte_feed_child} = 0;
            eval {
                local $SIG{__WARN__} = sub { die @_ };
                $vte->feed_child('abc', 3);
                1;
            } or do {
                $$self{_Vte}{vte_feed_child} = 1;
            };
            
            # Test feed_child_binary (VTE 0.46+)
            $$self{_Vte}{vte_feed_binary} = 0;
            if ($$self{_Vte}{major_version} >= 1 or $$self{_Vte}{minor_version} >= 46) {
                $$self{_Vte}{vte_feed_binary} = 1;
            }
        }
    }
    
    # Report VTE capabilities (AI-assisted modernization)
    if ($HAVE_VTE) {
        my $binding_info = $$self{_Vte}{binding_version} ? " (binding: $$self{_Vte}{binding_version})" : "";
        my $gtk4_info = $$self{_Vte}{gtk4_compatible} ? " [GTK4 Compatible]" : " [GTK3 Legacy]";
        print STDERR "INFO: Virtual terminal emulator (VTE) version is $$self{_Vte}{major_version}.$$self{_Vte}{minor_version}$binding_info$gtk4_info\n";
        if ($$self{_VERBOSE}) {
            foreach my $k (sort keys %{$$self{_Vte}}) {
                print STDERR "       - $k = $$self{_Vte}{$k}\n";
            }
        }
    } else {
        print STDERR "WARNING: VTE not available - terminal functionality limited\n";
    }
    
    # Cleanup temporary VTE widget
    eval {
        if ($vte && ref($vte) && $vte->can('destroy')) {
            $vte->destroy();
        }
    };
    undef $vte;
}

# Returns the currently selected tree
sub _getCurrentTree {
    my $self = shift;
    my $pnum = $$self{_GUI}{nbTree}->get_current_page();
    my $page = $$self{_GUI}{nbTree}->get_nth_page($pnum);
    my $tree;

    # Search for the PACTree into the selected tab
    $page->foreach(sub {
        my $child = shift;
        if (ref($child) eq 'PACTree') {
            $tree = $child;
        }
    });

    return $tree;
}

# Forces focus to the terminal inside the focused page
sub _doFocusPage {
    my $self = shift;
    my $pnum = shift;
    my $tab_page = $$self{_GUI}{nb}->get_nth_page($pnum);

    $$self{_HAS_FOCUS} = '';
    foreach my $tmp_uuid (keys %RUNNING) {
        my $check_gui = $RUNNING{$tmp_uuid}{terminal}{_SPLIT} ? $RUNNING{$tmp_uuid}{terminal}{_SPLIT_VPANE} : $RUNNING{$tmp_uuid}{terminal}{_GUI}{_VBOX};

        if (!defined($check_gui) || ($check_gui ne $tab_page)) {
            next;
        }

        my $uuid = $RUNNING{$tmp_uuid}{uuid};
        my $path = $$self{_GUI}{treeConnections}->_getPath($uuid);
        if ($path) {
            $$self{_GUI}{treeConnections}->expand_to_path($path);
            $$self{_GUI}{treeConnections}->set_cursor($path, undef, 0);
        }

        $RUNNING{$tmp_uuid}{terminal}->_setTabColour();

        if (!$RUNNING{$tmp_uuid}{terminal}{EMBED}) {
            eval {
                if (defined $RUNNING{$tmp_uuid}{terminal}{FOCUS}->get_window()) {
                    $RUNNING{$tmp_uuid}{terminal}{FOCUS}->get_window()->focus(time);
                }
            };
            $RUNNING{$tmp_uuid}{terminal}{_GUI}{_VTE}->grab_focus();
        }
        $$self{_HAS_FOCUS} = $RUNNING{$tmp_uuid}{terminal}{_GUI}{_VTE};

        # When found, do not process further
        last;
    }
}

sub _checkDependencies {
    my $self = shift;
    
    print STDERR "INFO: Checking system dependencies...\n";
    
    # Define tools with their installation hints and version detection
    my %tools = (
        # RDP clients
        'xfreerdp' => {
            'description' => 'FreeRDP client for RDP connections',
            'install_hint' => 'freerdp2-wayland or freerdp-x11',
            'critical' => 0,
            'version_cmd' => 'xfreerdp --version 2>&1 | head -1',
            'alternatives' => ['rdesktop']
        },
        'rdesktop' => {
            'description' => 'Alternative RDP client',
            'install_hint' => 'rdesktop',
            'critical' => 0,
            'version_cmd' => 'rdesktop 2>&1 | grep "Version" | head -1',
            'alternatives' => ['xfreerdp']
        },
        
        # VNC clients
        'vncviewer' => {
            'description' => 'VNC viewer client',
            'install_hint' => 'tigervnc-viewer or xtightvncviewer',
            'critical' => 0,
            'version_cmd' => 'vncviewer --version 2>&1 | head -1',
            'alternatives' => ['xtightvncviewer', 'vinagre']
        },
        'xtightvncviewer' => {
            'description' => 'TightVNC viewer client',
            'install_hint' => 'xtightvncviewer',
            'critical' => 0,
            'version_cmd' => 'xtightvncviewer -h 2>&1 | grep -i version | head -1',
            'alternatives' => ['vncviewer']
        },
        'vinagre' => {
            'description' => 'GNOME VNC/RDP viewer',
            'install_hint' => 'vinagre',
            'critical' => 0,
            'version_cmd' => 'vinagre --version 2>&1 | head -1',
            'alternatives' => ['vncviewer', 'remmina']
        },
        'remmina' => {
            'description' => 'Multi-protocol remote desktop client',
            'install_hint' => 'remmina',
            'critical' => 0,
            'version_cmd' => 'remmina --version 2>&1 | head -1',
            'alternatives' => ['vinagre']
        },
        
        # SSH and secure connections
        'ssh' => {
            'description' => 'SSH client for secure connections',
            'install_hint' => 'openssh-client',
            'critical' => 1,
            'version_cmd' => 'ssh -V 2>&1 | head -1'
        },
        'mosh' => {
            'description' => 'Mobile shell for unstable connections',
            'install_hint' => 'mosh',
            'critical' => 0,
            'version_cmd' => 'mosh --version 2>&1 | head -1'
        },
        'sshpass' => {
            'description' => 'SSH password authentication helper',
            'install_hint' => 'sshpass',
            'critical' => 0,
            'version_cmd' => 'sshpass -V 2>&1 | head -1'
        },
        
        # Legacy protocols
        'telnet' => {
            'description' => 'Telnet client for legacy connections',
            'install_hint' => 'telnet',
            'critical' => 0
        },
        'ftp' => {
            'description' => 'FTP client for file transfers',
            'install_hint' => 'ftp',
            'critical' => 0,
            'version_cmd' => 'ftp -? 2>&1 | head -1 | sed "s/usage: /ftp /" || echo "ftp (available)"'
        },
        'sftp' => {
            'description' => 'Secure FTP client',
            'install_hint' => 'openssh-client',
            'critical' => 0,
            'version_cmd' => 'sftp -V 2>&1 | head -1'
        },
        
        # Serial connection tools
        'cu' => {
            'description' => 'Serial connection utility',
            'install_hint' => 'cu or uucp',
            'critical' => 0,
            'version_cmd' => 'cu --version 2>&1 | head -1 || echo "cu (version unknown)"',
            'alternatives' => ['screen', 'minicom']
        },
        'screen' => {
            'description' => 'Terminal multiplexer (can handle serial)',
            'install_hint' => 'screen',
            'critical' => 0,
            'version_cmd' => 'screen -v 2>&1 | head -1',
            'alternatives' => ['cu', 'minicom']
        },
        'minicom' => {
            'description' => 'Serial communication program',
            'install_hint' => 'minicom',
            'critical' => 0,
            'version_cmd' => 'minicom --version 2>&1 | head -1',
            'alternatives' => ['cu', 'screen']
        },
        
        # Additional useful tools
        'expect' => {
            'description' => 'Automation tool for interactive applications',
            'install_hint' => 'expect',
            'critical' => 0,
            'version_cmd' => 'expect -v 2>&1 | head -1'
        },
        'socat' => {
            'description' => 'Multipurpose relay tool',
            'install_hint' => 'socat',
            'critical' => 0,
            'version_cmd' => 'socat -V 2>&1 | head -1'
        }
    );
    
    my $missing_critical = 0;
    my $missing_optional = 0;
    my %available_tools = ();
    
    # Check tool availability and get versions
    foreach my $tool (sort keys %tools) {
        my $available = system("which $tool >/dev/null 2>&1") == 0;
        
        if ($available) {
            $available_tools{$tool} = 1;
            my $version_info = "";
            
            if ($tools{$tool}{'version_cmd'}) {
                my $version_output = `$tools{$tool}{'version_cmd'} 2>/dev/null`;
                chomp($version_output);
                $version_info = $version_output ? " [$version_output]" : "";
            }
            
            print STDERR "✅ $tool: Available$version_info ($tools{$tool}{'description'})\n";
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
    
    # Check for alternative tools and provide suggestions
    print STDERR "\nINFO: Alternative tool analysis:\n";
    my %categories = (
        'RDP' => ['xfreerdp', 'rdesktop', 'remmina'],
        'VNC' => ['vncviewer', 'xtightvncviewer', 'vinagre', 'remmina'],
        'Serial' => ['cu', 'screen', 'minicom']
    );
    
    foreach my $category (sort keys %categories) {
        my @available_in_category = grep { $available_tools{$_} } @{$categories{$category}};
        my @missing_in_category = grep { !$available_tools{$_} } @{$categories{$category}};
        
        if (@available_in_category) {
            print STDERR "✅ $category connections: " . join(', ', @available_in_category) . " available\n";
        } else {
            print STDERR "❌ $category connections: No tools available. Consider installing: " . 
                         join(' or ', @missing_in_category) . "\n";
        }
    }
    
    # Detect distribution and provide specific installation commands
    my $distro = _detectDistribution();
    if ($distro && ($missing_critical > 0 || $missing_optional > 0)) {
        print STDERR "\nINFO: Distribution-specific installation suggestions for $distro:\n";
        _provideInstallationSuggestions($distro, \%tools, \%available_tools);
    }
    
    # Summary
    print STDERR "\n";
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

sub _detectDistribution {
    # Try to detect the Linux distribution
    if (-f '/etc/os-release') {
        my $os_release = `cat /etc/os-release 2>/dev/null`;
        if ($os_release =~ /^ID=(.+)$/m) {
            my $id = $1;
            $id =~ s/["']//g;
            return $id;
        }
    }
    
    # Fallback methods
    if (-f '/etc/debian_version') {
        return 'debian';
    } elsif (-f '/etc/redhat-release') {
        return 'rhel';
    } elsif (-f '/etc/arch-release') {
        return 'arch';
    } elsif (-f '/etc/SuSE-release') {
        return 'suse';
    }
    
    return undef;
}

sub _provideInstallationSuggestions {
    my ($distro, $tools, $available_tools) = @_;
    
    my %package_maps = (
        'ubuntu' => {
            'xfreerdp' => 'freerdp2-x11',
            'rdesktop' => 'rdesktop',
            'vncviewer' => 'tigervnc-viewer',
            'xtightvncviewer' => 'xtightvncviewer',
            'vinagre' => 'vinagre',
            'remmina' => 'remmina',
            'ssh' => 'openssh-client',
            'mosh' => 'mosh',
            'sshpass' => 'sshpass',
            'telnet' => 'telnet',
            'ftp' => 'ftp',
            'sftp' => 'openssh-client',
            'cu' => 'cu',
            'screen' => 'screen',
            'minicom' => 'minicom',
            'expect' => 'expect',
            'socat' => 'socat'
        },
        'debian' => {
            'xfreerdp' => 'freerdp2-x11',
            'rdesktop' => 'rdesktop',
            'vncviewer' => 'tigervnc-viewer',
            'xtightvncviewer' => 'xtightvncviewer',
            'vinagre' => 'vinagre',
            'remmina' => 'remmina',
            'ssh' => 'openssh-client',
            'mosh' => 'mosh',
            'sshpass' => 'sshpass',
            'telnet' => 'telnet',
            'ftp' => 'ftp',
            'sftp' => 'openssh-client',
            'cu' => 'cu',
            'screen' => 'screen',
            'minicom' => 'minicom',
            'expect' => 'expect',
            'socat' => 'socat'
        },
        'fedora' => {
            'xfreerdp' => 'freerdp',
            'rdesktop' => 'rdesktop',
            'vncviewer' => 'tigervnc',
            'vinagre' => 'vinagre',
            'remmina' => 'remmina',
            'ssh' => 'openssh-clients',
            'mosh' => 'mosh',
            'sshpass' => 'sshpass',
            'telnet' => 'telnet',
            'ftp' => 'ftp',
            'sftp' => 'openssh-clients',
            'cu' => 'uucp',
            'screen' => 'screen',
            'minicom' => 'minicom',
            'expect' => 'expect',
            'socat' => 'socat'
        },
        'arch' => {
            'xfreerdp' => 'freerdp',
            'rdesktop' => 'rdesktop',
            'vncviewer' => 'tigervnc',
            'vinagre' => 'vinagre',
            'remmina' => 'remmina',
            'ssh' => 'openssh',
            'mosh' => 'mosh',
            'sshpass' => 'sshpass',
            'telnet' => 'inetutils',
            'ftp' => 'inetutils',
            'sftp' => 'openssh',
            'cu' => 'uucp',
            'screen' => 'screen',
            'minicom' => 'minicom',
            'expect' => 'expect',
            'socat' => 'socat'
        }
    );
    
    my $package_map = $package_maps{$distro} || $package_maps{'ubuntu'}; # fallback to ubuntu
    my @missing_packages = ();
    
    foreach my $tool (sort keys %$tools) {
        if (!$available_tools->{$tool} && $package_map->{$tool}) {
            push @missing_packages, $package_map->{$tool};
        }
    }
    
    if (@missing_packages) {
        # Remove duplicates
        my %seen = ();
        @missing_packages = grep { !$seen{$_}++ } @missing_packages;
        
        my $install_cmd;
        if ($distro =~ /^(ubuntu|debian)$/) {
            $install_cmd = "sudo apt-get install " . join(' ', @missing_packages);
        } elsif ($distro =~ /^(fedora|rhel|centos)$/) {
            $install_cmd = "sudo dnf install " . join(' ', @missing_packages);
        } elsif ($distro eq 'arch') {
            $install_cmd = "sudo pacman -S " . join(' ', @missing_packages);
        } elsif ($distro =~ /suse/) {
            $install_cmd = "sudo zypper install " . join(' ', @missing_packages);
        } else {
            $install_cmd = "# Install packages: " . join(' ', @missing_packages);
        }
        
        print STDERR "   $install_cmd\n";
    }
}

# END: Define PRIVATE CLASS functions
###################################################################

1;

__END__

=encoding utf8

=head1 NAME

PACMain.pm

=head1 SYNOPSIS

Creates the GTK application, main window, event handlers, and elements.

    $main = PACMain->new(@ARGV);

B<@ARGV> : List of command line parameters (perldoc asbru-cm)

=head1 DESCRIPTION

=head2 Important Global Variables

    %RUNNING :  Table of PACTerminal Objects. $RUNNING{UUID}
                For a description of Terminal objects (perldoc PACTerminal.pm)

B<UUID> = 'asbru_PID' + I<pid number> + '_n' + I<Counter>

=head2 PACMain Internal Variables

    _APP            : Main Gtk object
    _CFG            : Reference tu structure object loaded by YAML::LoadFile
    _OPTS           : User options from command line
    _GUI            : Access to Gtk elements of the application (defined at _initGUI)
    _TABSINWINDOW   : 0 No , 1 Yes
    _UPDATING       : 0 No , 1 Yes
    _READONLY       : 0 No , 1 Yes
    _HAS_FOCUS      : VTE Object with the current focus
    _GUILOCKED      : 0 No , 1 Yes
    _PING           : Access to Net::Ping object

=head3 _CFG

Check asbru.yml for a reference for the complete list of options

    default         Access to global options
    environments    List of UUIDS in the nodes tree
    tmp             Access to temporary file references

    Example access:

    $$self{'_CFG'}{'defaults'}{'allow more instances'}
    $$self{'_CFG'}{'environments'}{$uuid}{'_protected'}

=head3 _GUI

Check _initGUI for object names

    Example access:

    $$self{'_GUI'}{object_name}      (as named in _initGUI)


=head2 sub new

    Creates a new instance of PACMain

=head2 sub DESTROY

    Destroys object when finished

=head2 sub start

    Start GTK application

=head2 sub _initGUI

Creates the main window and elements

=head2 sub _setupCallbacks

Sets up all callbacks to elements in the window

=head2 sub _lockAsbru

Locks the application to leave unattended.

Sets different objects property sesitive = 0

=head2 sub _unlockAsbru

Asks for a GUI password to unlock the application

If password OK, set sensitive = 1

=head2 sub __search (text,tree,where)

Search action over nodes : {CFG}{environments}{uuid}{name,ip,description}

    text    text to search
    tree    gtk tree object to search from
    where   name , host or desc

=head2 sub __treeBuildNodeName (uuid)

Gets node name as html tags applied with color depending on protected status

=head2 sub _hasProtectedChildren (@uuids[,search children])

Range over uuids to determine if node or any children are protected

=head2 sub __treeToggleProtection

Protects the full tree of nodes

=head2 sub _treeConnections_menu_lite (tree)

Creates a window popup menu for selected nodes

=head2 sub _treeConnections_menu

Create window popup on right click over connections tree

It will enable or disable options based on:

  * if there are elements selected
  * if there are elements to paste

=head2 sub _showAboutWindow

Shows about window

=head2 sub _startCluster (cluster name)

Start a cluster

    Finds all related nodes
    adds them to array @idx
    Calls _launchTerminals(\@ids), to start all toguether

=head2 sub _launchTerminals (@array_reference)

    Calls PACTerminal->new() for each $uuid in array_reference

=head2 sub _quitProgram

Execute quit program logic.

    Close terminals
    Ask for confirmations
    Gtk->main_quit

=head2 sub _saveConfiguration (_CFG)

Saves configuration data to $CFG_DIR

Saves Tree configuration

Last state en nfreez

=head2 sub _readConfiguration

Reads Configuraions into _CFG

=head2 sub _loadTreeConfiguration

Loads the last saved Tree Configuration using __recurLoadTree

=head2 sub __recurLoadTree

Recursively loads all tree configuration

=head2 sub _saveTreeExpanded

Saves configuration about node tree expanded in $CFG_FILE.tree

=head2 sub _loadTreeExpanded

Loas last information of expanded nodes from $CFG_FILE.tree

=head2 sub _saveGUIData

Saves general information about the GUI : x,y position and dimentions

=head2 sub _loadGUIData

Loads last saves GUI Data

=head2 sub _updateGUIWithUUID

Displays Welcome information in Message Area

=head2 sub _updateGUIPreferences

Update runtime GUI Preferences

=head2 sub _updateGUIFavourites

Updates GUI Favorites

Updates GUII Favorites

=head2 sub _updateGUIHistory

Updates information on History

=head2 sub _updateGUIClusters

Updates Clusters

=head2 sub _updateClustersList

Updates cluster List

=head2 sub _updateFavouritesList

Update Favourited List

=head2 sub _delNodes (@uuids)

Deletes all @uuids from the nodes tree

=head2 sub _showConnectionsList

Pending

=head2 sub _hideConnectionsList

Hides the Connections list

=head2 sub _toggleConnectionsList

Activates or deactivate the button to toggle the display of the connections list.

=head2 sub _doToggleConnectionsList

Actually show or hide the connections list.
Do not call this function directly but use _toggleConnectionsList that will also correctly
set the corresponding button state.

=head2 sub _copyNodes (cut [0,'cut'], parent, @selected_uuids)

For each uuid, execute __dupNodes()

This duplicates nodes in memory, storing the nodes in : $$self{_COPY}{'data'}

if cut == true { removes existing nodes from the tree }

=head2 sub _cutNodes ()

Event Handler

Gets Selected UUIDS, validates they are not protected

Calls _copyNodes('cut')

=head2 sub _pasteNodes (parent, uuid_to_copy, first)

Creates a new node on $parent root, then adds a node and possible children that come in : $$self{_COPY}{'data'}

Calls _pasteNodes for each children

=head2 sub __dupNodes (parent, uuid, cfg)

    Creates a copy of the existing uuid and assigns secuencial number to new node
    The copies are stored in $cfg which points to -> $$self{_COPY}{'data'}
    If node has children calls recusively to add children nodes, taking as parent the current new node
      $self->__dupNodes($new_txt_uuid, $child, $cfg);

=head2 sub __exportNodes

Exporst current nodes to file

=head2 sub __importNodes

Imports nodes from previous generated file

=head2 sub _bulkEdit

Creates GUI for a bulk editing of common properties to all selected nodes

=head2 sub _setCFGChanged

Updates runtime Configuration changes that affect the Main GUI: Readonly, Auto Save

=head2 sub _sendAppMessage

Pending

=head2 sub _getCurrentTree

Returns the currently selected tree (from the left menu)

=head2 sub _doFocusPage

Forces focus to the terminal inside the focused page
