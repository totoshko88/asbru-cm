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
        # Position top-right after first frame (guard screen availability)
    my $screen = eval { Gtk3::Gdk::Screen::get_default(); };
        Glib::Idle->add(sub {
            my $w = 800; # fallback width
            if ($screen) {
                eval { $w = $screen->get_width; 1 } or do { $w = 800; };
            }
            $helper->move($w-32,8);
            0;
        });
        $$self{_TRAY_HELPER} = $helper;
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

1;
