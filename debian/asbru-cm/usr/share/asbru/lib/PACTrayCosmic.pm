package PACTrayCosmic;

###############################################################################
# This file is part of Ásbrú Connection Manager
#
# Copyright (C) 2017-2022 Ásbrú Connection Manager team (https://asbru-cm.net)
# Copyright (C) 2010-2016 David Torrejon Vaquerizas
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

# AI-assisted modernization: This module implements Cosmic desktop-specific
# system tray integration with fallback mechanisms for compatibility

use utf8;
binmode STDOUT,':utf8';
binmode STDERR,':utf8';

$|++;

###################################################################
# Import Modules

# Standard
use strict;
use warnings;
use FindBin qw ($RealBin $Bin $Script);

# GTK - Use GTK3 with GTK4 compatibility layer
use Gtk3 '-init';
use PACCompat;
my $HAVE_APPINDICATOR = 0;
my $AI_PACKAGE = '';
my $SKIP_ALL_TRAY = $ENV{ASBRU_SKIP_COSMIC_TRAY} ? 1 : 0;
BEGIN {
    # Try legacy AppIndicator first (matches Unity module style) then Ayatana
    if ($SKIP_ALL_TRAY) {
        $HAVE_APPINDICATOR = 0; $AI_PACKAGE='';
    } elsif ($ENV{ASBRU_SKIP_APPINDICATOR} || $ENV{ASBRU_FORCE_SNI}) {
        # Skip attempting to load AppIndicator introspection (user requested or forcing SNI)
        $HAVE_APPINDICATOR = 0; $AI_PACKAGE='';
    } else {
    eval {
        require Glib::Object::Introspection;
        Glib::Object::Introspection->setup(
            basename => 'AppIndicator3',
            version  => '0.1',
            package  => 'AppIndicator'
        );
        $HAVE_APPINDICATOR = 1; $AI_PACKAGE = 'AppIndicator';
    };
    if (!$HAVE_APPINDICATOR) {
        eval {
            require Glib::Object::Introspection;
            Glib::Object::Introspection->setup(
                basename => 'AyatanaAppIndicator3',
                version  => '0.1',
                package  => 'AppIndicator'
            );
            $HAVE_APPINDICATOR = 1; $AI_PACKAGE = 'AppIndicator'; # still accessed via AppIndicator::Indicator
        };
    }
    # Verify symbol actually exists; if not, disable and note missing deps
    if ($HAVE_APPINDICATOR) {
        no strict 'refs';
        unless (defined &{"AppIndicator::Indicator::new"}) {
            use strict 'refs';
            print "WARNING: AppIndicator introspection loaded but symbol AppIndicator::Indicator not found. Install one of: gir1.2-appindicator3-0.1 or gir1.2-ayatanaappindicator3-0.1. Disabling AppIndicator integration.\n";
            $HAVE_APPINDICATOR = 0; $AI_PACKAGE='';
        } else { use strict 'refs'; }
    }
    }
}

# PAC modules
use PACUtils;
use PACCompat;

# END: Import Modules
###################################################################

###################################################################
# Define GLOBAL CLASS variables

my $APPNAME = $PACUtils::APPNAME;
my $APPVERSION = $PACUtils::APPVERSION;
my $APPICON = "$RealBin/res/asbru-logo-64.png";
my $TRAYICON = "$RealBin/res/asbru_terminal64x64.png";
my $GROUPICON_ROOT = _pixBufFromFile("$RealBin/res/themes/default/asbru_group.svg");
my $CALLBACKS_INITIALIZED = 0;

# Cosmic-specific integration modes
my $COSMIC_PANEL_AVAILABLE = 0;
my $NOTIFICATION_AREA_AVAILABLE = 0;
my $INTEGRATION_MODE = 'menubar'; # 'cosmic_panel', 'notification_area', 'menubar', 'appindicator', 'statusnotifier'
my $SNI_BUS_NAME;
my $SNI_OBJ;
my $APPINDICATOR;

# END: Define GLOBAL CLASS variables
###################################################################

###################################################################
# START: Define PUBLIC CLASS methods

sub new {
    my $class = shift;
    my $self = {};
    $self->{_MAIN} = shift;
    $self->{_TRAY} = undef;
    $self->{_MENU_BAR} = undef;
    $self->{_NOTIFICATION_AREA} = undef;
    bless($self, $class);

    if ($self->{_MAIN} && $self->{_MAIN}{_CFG}{defaults}{'use bw icon'}) {
    $TRAYICON = "$RealBin/res/asbru_tray_bw.png";
    }
    if ($SKIP_ALL_TRAY) {
        print "INFO: Skipping Cosmic tray subsystem (ASBRU_SKIP_COSMIC_TRAY set)\n" if $ENV{ASBRU_DEBUG};
    } else {
        $self->_detectCosmicIntegration();
        my $ok = _initGUI($self) ? 1 : 0;
        if (!$ok) {
            print "DEBUG: PACTrayCosmic _initGUI returned false, treating as unavailable\n" if $ENV{ASBRU_DEBUG};
            return undef; # signal failure cleanly (avoid returning 0 which breaks method calls)
        }
    }
    return $self;
}

# DESTRUCTOR
sub DESTROY {
    my $self = shift;
    undef $self;
    return 1;
}

# Returns TRUE if the tray icon is currently visible
sub is_visible {
    my $self = shift;

    if ($INTEGRATION_MODE eq 'cosmic_panel' && $self->{_TRAY}) {
        return $self->{_TRAY}->get_visible();
    } elsif ($INTEGRATION_MODE eq 'notification_area' && $self->{_NOTIFICATION_AREA}) {
        return $self->{_NOTIFICATION_AREA}->get_visible();
    } elsif ($INTEGRATION_MODE eq 'menubar' && $self->{_MENU_BAR}) {
        return $self->{_MENU_BAR}->get_visible();
    }
    
    return 0;
}

# Returns size and placement of the tray icon
sub get_geometry {
    my $self = shift;

    # For Cosmic integration, we return approximate values
    # since exact positioning may not be available
    return ({}, {}, {x => 0, y => 0});
}

# Enable the tray menu
sub set_tray_menu {
    my $self = shift;

    if ($CALLBACKS_INITIALIZED) {
        # Already done, nothing to do
        return 0;
    }

    $self->_setupCallbacks();

    $CALLBACKS_INITIALIZED = 1;
    return 1;
}

# Make the tray icon active/inactive (aka 'shown/hidden')
sub set_active {
    my $self = shift;
    
    if ($INTEGRATION_MODE eq 'cosmic_panel' && $self->{_TRAY}) {
        $self->{_TRAY}->set_visible(1);
    } elsif ($INTEGRATION_MODE eq 'notification_area' && $self->{_NOTIFICATION_AREA}) {
        $self->{_NOTIFICATION_AREA}->set_visible(1);
    } elsif ($INTEGRATION_MODE eq 'menubar' && $self->{_MENU_BAR}) {
        $self->{_MENU_BAR}->set_visible(1);
    }
}

sub set_passive {
    my $self = shift;
    
    if ($INTEGRATION_MODE eq 'cosmic_panel' && $self->{_TRAY}) {
        $self->{_TRAY}->set_visible(0);
    } elsif ($INTEGRATION_MODE eq 'notification_area' && $self->{_NOTIFICATION_AREA}) {
        $self->{_NOTIFICATION_AREA}->set_visible(0);
    } elsif ($INTEGRATION_MODE eq 'menubar' && $self->{_MENU_BAR}) {
        $self->{_MENU_BAR}->set_visible(0);
    }
}

# END: Define PUBLIC CLASS methods
###################################################################

###################################################################
# START: Define PRIVATE CLASS functions

sub _detectCosmicIntegration {
    my $self = shift;

    # Check if we're running in Cosmic desktop environment
    my $desktop_env = $ENV{XDG_CURRENT_DESKTOP} || '';
    my $cosmic_session = $ENV{COSMIC_SESSION} || '';
    
    if ($ENV{ASBRU_DEBUG}) {
        print "INFO: Detecting Cosmic desktop integration...\n";
        print "INFO: Desktop environment: $desktop_env\n";
        print "INFO: Cosmic session: $cosmic_session\n";
    }

    # Opportunistic detection of StatusNotifierWatcher (KDE/Ayatana spec)
    eval {
        require Net::DBus;
        my $bus = Net::DBus->session;
        my $dbus = $bus->get_service('org.freedesktop.DBus')->get_object('/org/freedesktop/DBus','org.freedesktop.DBus');
        my $names_ret = eval { $dbus->ListNames() };
        my @names = ref($names_ret) eq 'ARRAY' ? @$names_ret : (defined $names_ret ? ($names_ret) : ());
        if (@names && grep { $_ eq 'org.kde.StatusNotifierWatcher' } @names) {
            print "INFO: StatusNotifierWatcher present on session bus (SNI available)\n";
        } else {
            print "INFO: StatusNotifierWatcher not present (no SNI watcher yet)\n";
        }
    }; if ($@) { print "INFO: Net::DBus SNI detection error ($@)\n"; }

    # Try to detect Cosmic panel integration (future API)
    if ($cosmic_session || $desktop_env =~ /cosmic/i) {
        print "INFO: Cosmic desktop detected, checking for panel integration...\n" if $ENV{ASBRU_DEBUG};
        
        # TODO: Check for Cosmic panel D-Bus interface when available
        # For now, we'll use fallback methods
        $COSMIC_PANEL_AVAILABLE = 0;
        
        # Check for notification area support
        $NOTIFICATION_AREA_AVAILABLE = $self->_checkNotificationAreaSupport();
        
        # Allow user to force disable appindicator
        if ($ENV{ASBRU_FORCE_NO_APPINDICATOR}) { $HAVE_APPINDICATOR = 0; print "INFO: AppIndicator force disabled (ASBRU_FORCE_NO_APPINDICATOR)\n"; }
        # On COSMIC, prefer AppIndicator by default: if not loaded yet, try to load it now
        if (!$HAVE_APPINDICATOR && !$ENV{ASBRU_FORCE_SNI} && !$ENV{ASBRU_FORCE_NO_APPINDICATOR}) {
            eval {
                require Glib::Object::Introspection;
                Glib::Object::Introspection->setup(
                    basename => 'AppIndicator3', version => '0.1', package => 'AppIndicator'
                );
                $HAVE_APPINDICATOR = 1; $AI_PACKAGE = 'AppIndicator';
            };
            if (!$HAVE_APPINDICATOR) {
                eval {
                    require Glib::Object::Introspection;
                    Glib::Object::Introspection->setup(
                        basename => 'AyatanaAppIndicator3', version => '0.1', package => 'AppIndicator'
                    );
                    $HAVE_APPINDICATOR = 1; $AI_PACKAGE = 'AppIndicator';
                };
            }
            if ($HAVE_APPINDICATOR && $ENV{ASBRU_DEBUG}) { print "INFO: AppIndicator GI loaded for COSMIC (package: $AI_PACKAGE)\n"; }
        }
    my $force_sni = $ENV{ASBRU_FORCE_SNI} ? 1 : 0;
    if ($force_sni && $ENV{ASBRU_DEBUG}) { print "INFO: Forcing StatusNotifierItem mode (ASBRU_FORCE_SNI)\n"; }
    if ($HAVE_APPINDICATOR && !$force_sni) {
            $INTEGRATION_MODE = 'appindicator';
            print "INFO: Using AppIndicator integration for Cosmic desktop (package: $AI_PACKAGE)\n" if $ENV{ASBRU_DEBUG};
    } elsif ($force_sni || eval { require Net::DBus; my $bus=Net::DBus->session; my $dbus=$bus->get_service('org.freedesktop.DBus')->get_object('/org/freedesktop/DBus','org.freedesktop.DBus'); my $nr=$dbus->ListNames(); my @n= ref($nr) eq 'ARRAY' ? @$nr : ($nr); grep { $_ eq 'org.kde.StatusNotifierWatcher'} @n }) {
            $INTEGRATION_MODE = 'statusnotifier';
            print "INFO: Using StatusNotifierItem (SNI) integration on Cosmic\n" if $ENV{ASBRU_DEBUG};
        } elsif ($COSMIC_PANEL_AVAILABLE) {
            $INTEGRATION_MODE = 'cosmic_panel';
            print "INFO: Using Cosmic panel integration\n" if $ENV{ASBRU_DEBUG};
        } elsif ($NOTIFICATION_AREA_AVAILABLE) {
            $INTEGRATION_MODE = 'notification_area';
            print "INFO: Using notification area integration\n" if $ENV{ASBRU_DEBUG};
        } else {
            $INTEGRATION_MODE = 'menubar';
            print "INFO: Using menu bar integration as fallback\n" if $ENV{ASBRU_DEBUG};
        }
    } else {
        # Not Cosmic, check for standard notification area
        $NOTIFICATION_AREA_AVAILABLE = $self->_checkNotificationAreaSupport();
        
        if ($NOTIFICATION_AREA_AVAILABLE) {
            $INTEGRATION_MODE = 'notification_area';
            print "INFO: Using standard notification area\n" if $ENV{ASBRU_DEBUG};
        } else {
            $INTEGRATION_MODE = 'menubar';
            print "INFO: Using menu bar integration\n" if $ENV{ASBRU_DEBUG};
        }
    }
}

sub _checkNotificationAreaSupport {
    my $self = shift;

    # Check if we have a notification area available
    # This is a simplified check - in practice, we'd check for
    # system tray protocols or D-Bus interfaces
    
    my $display_server = PACCompat::detect_display_server();
    
    if ($display_server eq 'wayland') {
        # On Wayland, check for portal support or specific DE integration
        return 0; # For now, assume no direct tray support on Wayland
    } else {
        # On X11, we might have traditional system tray support
        return 1;
    }
}

sub _initGUI {
    my $self = shift;

    if ($INTEGRATION_MODE eq 'appindicator') {
        return $self->_initAppIndicator() ? 1 : 0;
    } elsif ($INTEGRATION_MODE eq 'statusnotifier') {
        return $self->_initStatusNotifier() ? 1 : 0;
    } elsif ($INTEGRATION_MODE eq 'cosmic_panel') {
        return $self->_initCosmicPanel() ? 1 : 0;
    } elsif ($INTEGRATION_MODE eq 'notification_area') {
        return $self->_initNotificationArea() ? 1 : 0;
    } else {
        return $self->_initMenuBar() ? 1 : 0;
    }
}

sub _initStatusNotifier {
    my $self = shift;
    eval {
        require Net::DBus;
    # Ensure Net::DBus::Object is loaded explicitly (fixes: Can't locate object method "new" via package "Net::DBus::Object")
    eval { require Net::DBus::Object; 1 } or die $@;
    my $bus = Net::DBus->session;
        my $pid = $$;
        my $name = "org.kde.StatusNotifierItem-$pid-1";
        # Some Net::DBus versions expose request_name via underlying connection
        my $conn = eval { $bus->get_connection }; # Net::DBus::Binding::Bus::Session
        if ($conn && $conn->can('request_name')) {
            $conn->request_name($name);
        } elsif ($bus->can('request_name')) {
            $bus->request_name($name);
        } else {
            die "No request_name method available in Net::DBus session object";
        }
        $SNI_BUS_NAME = $name;
    # Export service we own (previously used get_service leading to _register_object error in BaseObject)
    my $service = $bus->export_service($name);
        my $package = __PACKAGE__ . '::SNIStub';
        {
            no strict 'refs';
            @{$package.'::ISA'} = ('Net::DBus::Object');
        }
        # Build base Net::DBus::Object then re-bless into our dynamic package.
        # Previous approach using $package->SUPER::new triggered: Can't locate object method "new" via package "PACTrayCosmic"
        # on some perl/Net::DBus versions because SUPER::new call context was outside package scope.
        my $obj = Net::DBus::Object->new($service, '/StatusNotifierItem');
        bless($obj, $package);
        $obj->{_TRAY} = $self;
        print "INFO: SNI: Created stub object /StatusNotifierItem\n" if $ENV{ASBRU_DEBUG};
                # Implement simple Get / GetAll / Introspect / Activate / ContextMenu
                no strict 'refs';
                *{$package.'::Get'} = sub { my ($o,$interface,$prop)=@_; return $o->_sni_property($prop); } unless defined &{ $package.'::Get' };
                *{$package.'::GetAll'} = sub { my ($o,$interface)=@_; return { $o->_sni_all_props() }; } unless defined &{ $package.'::GetAll' };
                *{$package.'::Introspect'} = sub { return <<'XML'; } unless defined &{ $package.'::Introspect' };
<node>
    <interface name="org.kde.StatusNotifierItem">
        <property name="Category" type="s" access="read"/>
        <property name="Id" type="s" access="read"/>
        <property name="Title" type="s" access="read"/>
        <property name="Status" type="s" access="read"/>
        <property name="IconName" type="s" access="read"/>
    <property name="IconThemePath" type="s" access="read"/>
    <property name="AbsoluteIconPath" type="s" access="read"/>
        <property name="Menu" type="o" access="read"/>
        <method name="Activate">
            <arg direction="in" type="i" name="x"/>
            <arg direction="in" type="i" name="y"/>
        </method>
        <method name="ContextMenu">
            <arg direction="in" type="i" name="x"/>
            <arg direction="in" type="i" name="y"/>
        </method>
    </interface>
    <interface name="org.freedesktop.DBus.Properties">
        <method name="Get">
            <arg direction="in" type="s" name="interface"/>
            <arg direction="in" type="s" name="prop"/>
            <arg direction="out" type="v" name="value"/>
        </method>
        <method name="GetAll">
            <arg direction="in" type="s" name="interface"/>
            <arg direction="out" type="a{sv}" name="props"/>
        </method>
    </interface>
</node>
XML
                *{$package.'::Activate'} = sub { my ($o,$x,$y)=@_; $o->{_TRAY}{_MAIN}->_showConnectionsList(); } unless defined &{ $package.'::Activate' };
                *{$package.'::ContextMenu'} = sub { my ($o,$x,$y)=@_; $o->{_TRAY}{_MAIN}->_showConnectionsList(); } unless defined &{ $package.'::ContextMenu' };
                *{$package.'::_sni_property'} = sub { my ($o,$p)=@_; my %h=$o->_sni_all_props(); return $h{$p}; } unless defined &{ $package.'::_sni_property' };
        *{$package.'::_sni_all_props'} = sub {
            my ($o)=@_;
            my $abs_icon = "$RealBin/res/asbru_terminal64x64.png";
            return (
                                Category => 'ApplicationStatus',
                                Id => 'asbru-cm',
                                Title => $APPNAME,
                                Status => 'Active',
                                IconName => 'asbru_terminal64x64',
                IconThemePath => "$RealBin/res",
                AbsoluteIconPath => $abs_icon,
                                Menu => '/StatusNotifierMenu'
                        );
                };
                $SNI_OBJ = $obj;
                $self->{_MAIN}{_CFG}{'tmp'}{'tray available'} = 1;
                print "INFO: StatusNotifierItem registered ($SNI_BUS_NAME)\n";
                select STDOUT; $|=1; # flush

                # Retry registration with watcher
                my $attempts = 0; my $max_attempts = 6; my $interval_ms = 1500;
                my $register_sub; $register_sub = sub {
                        $attempts++;
                        my $ok = 0;
                        eval {
                                my $watcher_srv = $bus->get_service('org.kde.StatusNotifierWatcher');
                                my $watcher = $watcher_srv->get_object('/StatusNotifierWatcher','org.kde.StatusNotifierWatcher');
                                $watcher->RegisterStatusNotifierItem($SNI_BUS_NAME);
                                $ok = 1;
                        };
                        if ($ok) { print "INFO: SNI: Registered with StatusNotifierWatcher\n"; return 0; }
                        if ($attempts < $max_attempts) { return 1; }
                        print "WARNING: SNI: Could not register with watcher after $attempts attempts\n";
                        return 0;
                };
                eval { require Glib; Glib::Timeout->add($interval_ms, $register_sub); };
                return 1;
    };
    if ($@) {
        print "WARNING: Failed SNI init: $@\n";
        $INTEGRATION_MODE = 'menubar';
        return $self->_initMenuBar();
    }
}

sub _initAppIndicator {
    my $self = shift;
    unless ($HAVE_APPINDICATOR) {
        print "WARNING: AppIndicator requested but not available.\n";
        $INTEGRATION_MODE = 'menubar';
        return $self->_initMenuBar() ? 1 : 0;
    }
    my $ok = eval {
        print "INFO: Initializing AppIndicator (package=$AI_PACKAGE) ...\n";
        my $icon_path = "$RealBin/res";
        my $tray_icon = 'asbru_terminal64x64';
        my $tray_icon_file = "$icon_path/$tray_icon.png";
        # Use same call signature as Unity implementation
        $APPINDICATOR = AppIndicator::Indicator->new('asbru-cm', $tray_icon, 'application-status');
        $APPINDICATOR->set_icon_theme_path($icon_path) if $APPINDICATOR->can('set_icon_theme_path');
        # Re-assert icon by name after theme path set
        eval { $APPINDICATOR->set_icon($tray_icon) if $APPINDICATOR->can('set_icon'); 1 };
        # If available, set icon by absolute file path to ensure pixmap delivery to panel
        if ($APPINDICATOR->can('set_icon_full') && -f $tray_icon_file) {
            eval { $APPINDICATOR->set_icon_full($tray_icon_file, 'Asbru Indicator'); 1 };
            print "INFO: AppIndicator icon set via file path ($tray_icon_file)\n" if $ENV{ASBRU_DEBUG};
        } else {
            print "INFO: AppIndicator icon set via name ($tray_icon)\n" if $ENV{ASBRU_DEBUG};
        }
        $APPINDICATOR->set_status('active') if $APPINDICATOR->can('set_status');
    my $menu = $self->_buildIndicatorMenu();
        $APPINDICATOR->set_menu($menu) if $APPINDICATOR->can('set_menu');
        $self->{_TRAY} = $APPINDICATOR;
    eval { Gtk3::IconTheme::get_default()->rescan_if_needed(); };
        $self->{_MAIN}{_CFG}{'tmp'}{'tray available'} = 1;
        print "INFO: AppIndicator created successfully (Cosmic, mode=$INTEGRATION_MODE)\n";
        1;
    };
    if (!$ok) {
        my $err = $@;
        print "WARNING: Failed to init AppIndicator: $@\n";
        $INTEGRATION_MODE = 'menubar';
        return $self->_initMenuBar() ? 1 : 0;
    }
    return 1;
}

sub _buildIndicatorMenu {
    my $self = shift;
    # Build AppIndicator menu mirroring the default tray structure
    my $menu = Gtk3::Menu->new();
    my $items = $self->_buildDefaultMenuSpec();
    $self->_appendMenuItems($menu, $items);
    $menu->show_all();
    return $menu;
}

sub _buildDefaultMenuSpec {
    my $self = shift;
    # Reuse the same entries as _createTrayMenu but as data specs
    my @spec;
    push @spec, {label => 'Local Shell', on => sub { $PACMain::FUNCS{_MAIN}{_GUI}{shellBtn}->clicked(); }};
    push @spec, {sep => 1};
    my $clusters = eval { $self->_menuClusterConnections() } || undef;
    my $favs = eval { $self->_menuFavouriteConnections() } || undef;
    my $tree = eval { $PACMain::FUNCS{_MAIN}{_GUI}{treeConnections}{data} };
    my $connect = eval { $self->_menuAvailableConnections($tree) } || undef;
    push @spec, {label => 'Clusters', submenu => $clusters} if $clusters;
    push @spec, {label => 'Favourites', submenu => $favs} if $favs;
    push @spec, {label => 'Connect to', submenu => $connect} if $connect;
    push @spec, {sep => 1};
    push @spec, {label => 'Preferences...', on => sub { $self->{_MAIN}{_CONFIG}->show(); }};
    push @spec, {label => 'Clusters...', on => sub { $self->{_MAIN}{_CLUSTER}->show(); }};
    push @spec, {label => 'PCC', on => sub { $self->{_MAIN}{_PCC}->show(); }};
    push @spec, {label => 'Show Window', on => sub { $self->{_MAIN}->_showConnectionsList(); }};
    push @spec, {sep => 1};
    push @spec, {label => 'About', on => sub { $self->{_MAIN}->_showAboutWindow(); }};
    push @spec, {label => 'Exit', on => sub { $self->{_MAIN}->_quitProgram(); }};
    return \@spec;
}

sub _appendMenuItems {
    my ($self, $menu, $specs) = @_;
    foreach my $it (@$specs) {
        if ($it->{sep}) { $menu->append(Gtk3::SeparatorMenuItem->new()); next; }
        my $mi = Gtk3::MenuItem->new_with_label($it->{label} // '');
        if ($it->{submenu}) {
            my $sub = $self->_buildMenuFromArray($it->{submenu});
            $mi->set_submenu($sub) if $sub;
        } elsif ($it->{on}) {
            my $cb = $it->{on};
            $mi->signal_connect(activate => sub { $cb->() });
        }
        $menu->append($mi);
    }
}

sub _buildMenuFromArray {
    my ($self, $arr) = @_;
    return undef unless $arr && ref($arr) eq 'ARRAY' && @$arr;
    my $menu = Gtk3::Menu->new();
    foreach my $e (@$arr) {
        if ($e->{separator}) { $menu->append(Gtk3::SeparatorMenuItem->new()); next; }
        my $mi = Gtk3::MenuItem->new_with_label($e->{label} // '');
        if ($e->{submenu}) {
            my $sub = $self->_buildMenuFromArray($e->{submenu});
            $mi->set_submenu($sub) if $sub;
        } elsif ($e->{code}) {
            my $cb = $e->{code};
            $mi->signal_connect(activate => sub { $cb->() });
        }
        $menu->append($mi);
    }
    return $menu;
}

sub _initCosmicPanel {
    my $self = shift;

    # TODO: Implement native Cosmic panel integration when APIs are available
    # For now, this is a placeholder for future implementation
    
    print "INFO: Cosmic panel integration not yet implemented, falling back to menu bar\n";
    $INTEGRATION_MODE = 'menubar';
    return $self->_initMenuBar();
}

sub _initNotificationArea {
    my $self = shift;

    # Try to create a notification area icon using available GTK4 methods
    eval {
        # Note: GTK4 deprecated GtkStatusIcon, so we need alternative approaches
        # This might require using D-Bus interfaces or other system-specific methods
        
        print "INFO: Notification area integration requires system-specific implementation\n";
        $INTEGRATION_MODE = 'menubar';
        return $self->_initMenuBar();
    };
    
    if ($@) {
        print "WARNING: Failed to create notification area icon: $@\n";
        $INTEGRATION_MODE = 'menubar';
        return $self->_initMenuBar();
    }
}

sub _initMenuBar {
    my $self = shift;

    # Create a menu bar as the final fallback
    # This will be integrated into the main window
    
    $self->{_MENU_BAR} = Gtk3::MenuBar->new();
    
    # Create the main menu item
    my $app_menu_item = Gtk3::MenuItem->new_with_label($APPNAME);
    $self->{_MENU_BAR}->append($app_menu_item);
    
    # Set tooltip
    $self->{_MENU_BAR}->set_tooltip_text("$APPNAME (v.$APPVERSION)");
    
    # Initially visible based on configuration
    $self->{_MENU_BAR}->set_visible($self->{_MAIN}{_CFG}{defaults}{'show tray icon'});
    
    # Mark as available
    $self->{_MAIN}{_CFG}{'tmp'}{'tray available'} = 1;

    print "INFO: Menu bar integration initialized\n";
    return 1;
}

sub _setupCallbacks {
    my $self = shift;

    if ($INTEGRATION_MODE eq 'menubar' && $self->{_MENU_BAR}) {
        return $self->_setupMenuBarCallbacks();
    } elsif ($INTEGRATION_MODE eq 'appindicator') {
        # Already handled by _buildIndicatorMenu
        return 1;
    }
    
    # Other integration modes would have their own callback setups
    return 1;
}

sub _setupMenuBarCallbacks {
    my $self = shift;

    # Get the menu item from the menu bar
    my @children = $self->{_MENU_BAR}->get_children();
    return 0 unless @children;
    
    my $app_menu_item = $children[0];
    
    # Create submenu
    my $submenu = $self->_createTrayMenu();
    $app_menu_item->set_submenu($submenu);
    
    return 1;
}

sub _createTrayMenu {
    my $self = shift;

    my $menu = Gtk3::Menu->new();

    # Local Shell
    my $shell_item = Gtk3::MenuItem->new_with_label('Local Shell');
    $shell_item->signal_connect('activate' => sub {
        $PACMain::FUNCS{_MAIN}{_GUI}{shellBtn}->clicked();
    });
    $menu->append($shell_item);


    # Separator
    $menu->append(Gtk3::SeparatorMenuItem->new());

    # Clusters
    my $clusters_item = Gtk3::MenuItem->new_with_label('Clusters');
    my $clusters_submenu = $self->_menuClusterConnections();
    $clusters_item->set_submenu($clusters_submenu) if $clusters_submenu;
    $menu->append($clusters_item);

    # Favourites
    my $favourites_item = Gtk3::MenuItem->new_with_label('Favourites');
    my $favourites_submenu = $self->_menuFavouriteConnections();
    $favourites_item->set_submenu($favourites_submenu) if $favourites_submenu;
    $menu->append($favourites_item);

    # Connect to
    my $connect_item = Gtk3::MenuItem->new_with_label('Connect to');
    my $connect_submenu = $self->_menuAvailableConnections($PACMain::FUNCS{_MAIN}{_GUI}{treeConnections}{data});
    $connect_item->set_submenu($connect_submenu) if $connect_submenu;
    $menu->append($connect_item);

    # Separator
    $menu->append(Gtk3::SeparatorMenuItem->new());

    # Preferences
    my $prefs_item = Gtk3::MenuItem->new_with_label('Preferences...');
    $prefs_item->signal_connect('activate' => sub {
        $self->{_MAIN}{_CONFIG}->show();
    });
    $menu->append($prefs_item);

    # Clusters management
    my $cluster_mgmt_item = Gtk3::MenuItem->new_with_label('Clusters...');
    $cluster_mgmt_item->signal_connect('activate' => sub {
        $self->{_MAIN}{_CLUSTER}->show();
    });
    $menu->append($cluster_mgmt_item);

    # PCC
    my $pcc_item = Gtk3::MenuItem->new_with_label('PCC');
    $pcc_item->signal_connect('activate' => sub {
        $self->{_MAIN}{_PCC}->show();
    });
    $menu->append($pcc_item);

    # Show Window
    my $show_item = Gtk3::MenuItem->new_with_label('Show Window');
    $show_item->signal_connect('activate' => sub {
        $self->{_MAIN}->_showConnectionsList();
    });
    $menu->append($show_item);

    # Separator
    $menu->append(Gtk3::SeparatorMenuItem->new());

    # About
    my $about_item = Gtk3::MenuItem->new_with_label('About');
    $about_item->signal_connect('activate' => sub {
        $self->{_MAIN}->_showAboutWindow();
    });
    $menu->append($about_item);

    # Exit
    my $exit_item = Gtk3::MenuItem->new_with_label('Exit');
    $exit_item->signal_connect('activate' => sub {
        $self->{_MAIN}->_quitProgram();
    });
    $menu->append($exit_item);

    $menu->show_all();
    return $menu;
}

# Placeholder methods for menu creation - these would need to be implemented
# based on the existing PACTray.pm functionality
BEGIN {
    # If these stubs are already defined (e.g. PACTray loaded first) skip redefining to avoid warnings
    if (!defined &_menuClusterConnections) {
        * _menuClusterConnections = sub { return undef; };
    }
    if (!defined &_menuFavouriteConnections) {
        * _menuFavouriteConnections = sub { return undef; };
    }
    if (!defined &_menuAvailableConnections) {
        * _menuAvailableConnections = sub { return undef; };
    }
}

# Get the menu bar widget for integration into main window
sub get_menu_bar {
    my $self = shift;
    return $self->{_MENU_BAR};
}

# Accessors for diagnostics
sub get_integration_mode { return $INTEGRATION_MODE; }
sub have_appindicator { return $HAVE_APPINDICATOR; }
sub appindicator_package { return $AI_PACKAGE; }

# END: Define PRIVATE CLASS functions
###################################################################

1;