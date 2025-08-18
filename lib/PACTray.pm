package PACTray;

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

# GTK
use Gtk3 '-init';

# PAC modules
use PACUtils;
use Glib qw/TRUE FALSE/;

# END: Import Modules
###################################################################

###################################################################
# Define GLOBAL CLASS variables

my $APPNAME = $PACUtils::APPNAME;
my $APPVERSION = $PACUtils::APPVERSION;
my $APPICON = "$RealBin/res/asbru-logo-64.png";
my $TRAYICON = "$RealBin/res/asbru-logo-tray.png";
my $GROUPICON_ROOT = _pixBufFromFile("$RealBin/res/themes/default/asbru_group.svg");
my $CALLBACKS_INITIALIZED = 0;

# END: Define GLOBAL CLASS variables
###################################################################

###################################################################
# START: Define PUBLIC CLASS methods

sub new {
    my $class = shift;

    my $self = {};

    $self->{_MAIN} = shift;

    $self->{_TRAY} = undef;

    if ($$self{_MAIN}{_CFG}{defaults}{'use bw icon'}) {
        $TRAYICON = "$RealBin/res/asbru_tray_bw.png";
    }

    # Build the GUI
    _initGUI($self) or return 0;

    bless($self, $class);
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

    return $$self{_TRAY}->get_visible();
}

# Returns size and placement of the tray icon
sub get_geometry {
    my $self = shift;

    return $$self{_TRAY}->get_geometry();
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
sub set_active() {
    my $self = shift;
    $$self{_TRAY}->set_visible(1);
}
sub set_passive() {
    my $self = shift;
    $$self{_TRAY}->set_visible(0);
}

# END: Define PUBLIC CLASS methods
###################################################################

###################################################################
# START: Define PRIVATE CLASS functions

sub _initGUI {
    my $self = shift;

    $$self{_TRAY} = Gtk3::StatusIcon->new_from_file($TRAYICON) or die "ERROR: Could not create tray icon: $!";
    $$self{_TRAY}->set_property('tooltip-markup', "<b>$APPNAME</b> (v.$APPVERSION)");
    $$self{_TRAY}->set_visible($$self{_MAIN}{_CFG}{defaults}{'show tray icon'});
    my $embedded = $$self{_TRAY}->is_embedded();
    $$self{_MAIN}{_CFG}{'tmp'}{'tray available'} = $embedded ? 1 : 'warning';

    # Cosmic shell (Pop!_OS) no legacy tray: provide small helper window substitute
    if (!$embedded && (($ENV{XDG_CURRENT_DESKTOP} // '') =~ /COSMIC/i)) {
        print "INFO: Desktop environment detected: cosmic\n";
        print "INFO: Using Cosmic tray integration (initializing)\n";
        
        # Try to integrate with system StatusNotifierItem protocol first
        my $sni_success = eval {
            require Net::DBus;
            my $bus = Net::DBus->session;
            
            # Check if StatusNotifierWatcher is available
            my $watcher_service = eval { $bus->get_service('org.kde.StatusNotifierWatcher') };
            
            if ($watcher_service) {
                print "INFO: StatusNotifierWatcher present on session bus (SNI available)\n";
                
                # Create a unique service name based on PID
                my $pid = $$;
                my $service_name = "org.kde.StatusNotifierItem-$pid-1";
                
                # Export our StatusNotifierItem service
                my $sni_service = $bus->export_service($service_name);
                my $sni_object = PACTrayStatusNotifierItem->new($sni_service, $self);
                
                # Use the correct DBus export method
                $sni_service->export_object('/StatusNotifierItem', 
                    'org.kde.StatusNotifierItem', $sni_object);
                
                # Register with watcher
                my $watcher = $watcher_service->get_object('/StatusNotifierWatcher');
                $watcher->RegisterStatusNotifierItem($service_name);
                
                print "INFO: StatusNotifierItem registered ($service_name)\n";
                print "INFO: SNI: Registered with StatusNotifierWatcher\n";
                
                return 1;
            } else {
                print "INFO: StatusNotifierWatcher not available\n";
                return 0;
            }
        };
        
        if ($@) {
            print "WARN: SNI integration failed: $@\n";
            $sni_success = 0;
        }
        
        # If SNI integration failed, fall back to helper window
        unless ($sni_success) {
            print "INFO: Falling back to standard tray (Cosmic tray unavailable)\n";
            
            my $helper = Gtk3::Window->new('popup');
            $helper->set_title($APPNAME . ' Tray');
            $helper->set_resizable(FALSE);
            my $img = Gtk3::Image->new_from_file($TRAYICON);
            my $ebox = Gtk3::EventBox->new();
            $ebox->add($img);
            $helper->add($ebox);
            $helper->set_default_size(24,24);
            $helper->set_decorated(FALSE);
            $helper->set_keep_above(TRUE);
            $helper->stick;
            
            # Set window type hint for better panel integration  
            $helper->set_type_hint('dock');
            $helper->set_skip_taskbar_hint(TRUE);
            $helper->set_skip_pager_hint(TRUE);
            
            $ebox->set_events(['button-press-mask','button-release-mask','pointer-motion-mask']);
            my ($dragging,$dx,$dy) = (0,0,0);
            $ebox->signal_connect('button-press-event' => sub {
                my ($w,$ev) = @_;
                if ($ev->button == 1) {
                    $dragging = 1; ($dx,$dy) = ($ev->x_root, $ev->y_root);
                } elsif ($ev->button == 3) {
                    $self->_trayMenu($w,$ev);
                }
                return 1;
            });
            $ebox->signal_connect('button-release-event' => sub {
                my ($w,$ev) = @_;
                if ($ev->button == 1 && $dragging) {
                    $dragging = 0;
                    # Toggle main window if it was a click (no movement)
                    if (abs($ev->x_root - $dx) < 3 && abs($ev->y_root - $dy) < 3) {
                        if ($$self{_MAIN}{_GUI}{main}->get_visible()) { $$self{_MAIN}->_hideConnectionsList(); }
                        else { $$self{_MAIN}->_showConnectionsList(); }
                    }
                }
                return 1;
            });
            $ebox->signal_connect('motion-notify-event' => sub {
                my ($w,$ev) = @_;
                return 0 unless $dragging;
                my $nx = $ev->x_root - 12; my $ny = $ev->y_root - 12;
                $helper->move($nx,$ny);
                return 1;
            });
            $helper->show_all();
            
            # Position in the top-right corner for COSMIC
            my $screen = eval { Gtk3::Gdk::Screen::get_default(); };
            Glib::Idle->add(sub {
                my $w = 1600; # Cosmic default width for your screen  
                my $h = 900;  # Cosmic default height for your screen
                if ($screen) {
                    eval { $w = $screen->get_width; $h = $screen->get_height; 1 } or do { $w = 1600; $h = 900; };
                }
                
                # Position in top-right corner for COSMIC desktop
                my $x = $w - 48;  # 48px from right edge 
                my $y = 8;        # 8px from top edge (COSMIC has top panel)
                
                $helper->move($x, $y);
                print "INFO: Positioned tray helper window at ($x, $y) on ${w}x${h} screen\n";
                return 0;
            });
            $$self{_TRAY_HELPER} = $helper;
        }
    }

    return 1;
}

sub _setupCallbacks {
    my $self = shift;

    $$self{_TRAY}->signal_connect('button_press_event' => sub {
        my ($widget, $event) = @_;

        if ($event->button eq 3 && !$$self{_MAIN}{_GUI}{lockApplicationBtn}->get_active()) {
            $self->_trayMenu($widget, $event);
        }

        # Left click: show/hide main window
        if ($event->button ne 1) {
            return 1;
        }

        # If main window is at top level, hides it (otherwise shows it)
        if ($$self{_MAIN}{_GUI}{main}->get_visible() && $$self{_MAIN}{_GUI}{main}->is_active()) {
            # Trigger the "lock" procedure
            if ($$self{_MAIN}{_CFG}{'defaults'}{'use gui password'} && $$self{_MAIN}{_CFG}{'defaults'}{'use gui password tray'}) {
                $$self{_MAIN}{_GUI}{lockApplicationBtn}->set_active(1);
            }
            $$self{_MAIN}->_hideConnectionsList();
        } else {
            # Check if show password is required
            if ($$self{_MAIN}{_CFG}{'defaults'}{'use gui password'} && $$self{_MAIN}{_CFG}{'defaults'}{'use gui password tray'}) {
                # Trigger the "unlock" procedure
                $$self{_MAIN}{_GUI}{lockApplicationBtn}->set_active(0);
                if (! $$self{_MAIN}{_GUI}{lockApplicationBtn}->get_active()) {
                    $$self{_TRAY}->set_visible($$self{_MAIN}{_CFG}{defaults}{'show tray icon'});
                    $$self{_MAIN}->_showConnectionsList();
                }
            } else {
                $$self{_TRAY}->set_visible($$self{_MAIN}{_CFG}{defaults}{'show tray icon'});
                $$self{_MAIN}->_showConnectionsList();
                if ($$self{_MAIN}{_CFG}{'defaults'}{'layout'} eq 'Compact') {
                    my ($x,$y) = $self->_pos($event);
                    if ($x > 0 || $y > 0) {
                        $$self{_MAIN}{_GUI}{main}->move($x, $y);
                    }
                }
            }
        }
        return 1;
    });

    return 1;
}

sub _pos {
    my ($self,$event) = @_;
    my $h = $$self{_MAIN}{wheight};
    my $w = $$self{_MAIN}{_GUI}{main}->get_preferred_size()->width/2;
    my $ymax = $event->get_screen()->get_height();
    my $dy = $event->window->get_height();
    my ($x, $y) = $event->window->get_origin();

    # Over the event widget
    if ($dy + $y + $h > $ymax) {
        $y -= $h;
        if ($y < 0) {
            $y = 0;
        }
    } else {
        # Below the event widget
        $y += $dy;
    }
    return ($x - $w,$y);
}

sub _trayMenu {
    my $self = shift;
    my $widget = shift;
    my $event = shift;

    my @m;

    push(@m, {label => 'Local Shell', logical_icon => 'home_action', stockicon => 'gtk-home', code => sub {$PACMain::FUNCS{_MAIN}{_GUI}{shellBtn}->clicked();}});
    push(@m, {separator => 1});
    push(@m, {label => 'Clusters', stockicon => 'asbru-cluster-manager', submenu => _menuClusterConnections});
    push(@m, {label => 'Favourites', stockicon => 'asbru-favourite-on', submenu => _menuFavouriteConnections});
    push(@m, {label => 'Connect to', stockicon => 'asbru-group', submenu => _menuAvailableConnections($PACMain::FUNCS{_MAIN}{_GUI}{treeConnections}{data})});
    push(@m, {separator => 1});
    push(@m, {label => 'Preferences...', logical_icon => 'preferences', stockicon => 'gtk-preferences', code => sub {$$self{_MAIN}{_CONFIG}->show();}});
    push(@m, {label => 'Clusters...', logical_icon => 'cluster', stockicon => 'gtk-justify-fill', code => sub {$$self{_MAIN}{_CLUSTER}->show();}});
    push(@m, {label => 'PCC', logical_icon => 'cluster', stockicon => 'gtk-justify-fill', code => sub {$$self{_MAIN}{_PCC}->show();}});
    push(@m, {label => 'Show Window', logical_icon => 'home_action', stockicon => 'gtk-home', code => sub {$$self{_MAIN}->_showConnectionsList();}});
    push(@m, {separator => 1});
    push(@m, {label => 'About', logical_icon => 'about_action', stockicon => 'gtk-about', code => sub {$$self{_MAIN}->_showAboutWindow();}});
    push(@m, {label => 'Exit', logical_icon => 'quit_action', stockicon => 'gtk-quit', code => sub {$$self{_MAIN}->_quitProgram();}});

    _wPopUpMenu(\@m, $event, 'below calling widget');

    return 1;
}

# END: Define PRIVATE CLASS functions
###################################################################

###################################################################
# StatusNotifierItem implementation for proper SNI integration
package PACTrayStatusNotifierItem;

sub new {
    my ($class, $service, $tray_obj) = @_;
    my $self = {
        service => $service,
        tray => $tray_obj,
    };
    bless $self, $class;
    return $self;
}

# Required StatusNotifierItem methods
sub Activate {
    my ($self, $x, $y) = @_;
    # Toggle main window visibility
    my $tray = $self->{tray};
    if ($$tray{_MAIN}{_GUI}{main}->get_visible()) { 
        $$tray{_MAIN}->_hideConnectionsList(); 
    } else { 
        $$tray{_MAIN}->_showConnectionsList(); 
    }
}

sub ContextMenu {
    my ($self, $x, $y) = @_;
    # Show context menu
    my $tray = $self->{tray};
    my $event = { x_root => $x, y_root => $y, button => 3 };
    $tray->_trayMenu(undef, $event);
}

sub SecondaryActivate {
    my ($self, $x, $y) = @_;
    # Middle click - same as context menu
    $self->ContextMenu($x, $y);
}

# SNI properties (required)
sub Id { return "asbru-cm"; }
sub Title { return "Ásbrú Connection Manager"; }  
sub Category { return "ApplicationStatus"; }
sub Status { return "Active"; }
sub IconName { return "asbru-cm"; }
sub ToolTip { 
    return ("", [], "Ásbrú Connection Manager", "Connection Manager");
}

1;
