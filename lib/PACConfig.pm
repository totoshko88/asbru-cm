package PACConfig;

###############################################################################
# This file is part of Ásbrú Connection Manager
#
# Copyright (C) 2017-2022 Ásbrú Connection Manager team (https://asbru-cm.net)
# Copyright (C) 2010-2016 David Torrejon Vaquerizas
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

$|++;

###################################################################
# Import Modules
use utf8;
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

# Standard
use strict;
use warnings;

use FindBin qw ($RealBin $Bin $Script);
use PACConfigData qw(load_yaml_config save_yaml_config clone_data validate_config_structure);
use YAML::XS;  # Modern YAML processor
use Storable;
# use Glib::IO; # GSettings - commented out as not available on all systems
use PACCryptoCompat;

# GTK
use Gtk3 '-init';
use Gtk3::SimpleList;
# use PACIcons; # symbolic icon mapping - REMOVED, will use standard GTK icons

# PAC modules
use PACUtils;
use PACWidgetUtils;
use PACTermOpts;
use PACGlobalVarEntry;
use PACExecEntry;
use PACKeePass;
use PACKeyBindings;

# END: Import Modules
###################################################################

###################################################################
# Define GLOBAL CLASS variables

my $APPNAME = $PACUtils::APPNAME;
my $APPVERSION = $PACUtils::APPVERSION;
my $AUTOSTART_FILE = "$RealBin/res/asbru_start.desktop";

my $GLADE_FILE = "$RealBin/res/asbru.glade";
my $CFG_DIR = $ENV{"ASBRU_CFG"};
my $RES_DIR = "$RealBin/res";
my $THEME_DIR = "$RES_DIR/themes/default";
# Modern cryptographic system - AI-assisted modernization 2024
my $CIPHER = PACCryptoCompat->new(-key => 'PAC Manager (David Torrejon Vaquerizas, david.tv@gmail.com)', -migration => 1) or die "ERROR: Failed to initialize crypto system";
# Legacy salt constant for compatibility
my $SALT = '12345678';
 # Cache for system icon themes enumeration
our ($CACHED_ICON_THEMES, $CACHED_ICON_SCAN_TIME); $CACHED_ICON_SCAN_TIME ||= 0;

# END: Define GLOBAL CLASS variables
###################################################################

###################################################################
# START: Define PUBLIC CLASS methods

sub new {
    my $class = shift;
    my $self = {};

    $self->{_CFG} = shift;
    $self->{_WINDOWCONFIG} = undef;
    $self->{_TXTOPTSBUFFER} = undef;
    $self->{_GLADE} = undef;

    %{$self->{_CURSOR}} = (
        'block' => 0,
        'ibeam' => 1,
        'underline' => 2
    );
    $self->{_ENCODINGS_HASH} = _getEncodings();
    $self->{_ENCODINGS_ARRAY} = [];
    $self->{_ENCODINGS_MAP} = {};
    $self->{_CFGTOGGLEPASS} = 1;

    %{$self->{_BACKSPACE_BINDING}} = (
        'auto' => 0,
        'ascii-backspace' => 1,
        'ascii-delete' => 2,
        'delete-sequence' => 3,
        'tty' => 4
    );

    # Build the GUI
    if (!_initGUI($self)) {
        return 0;
    }

    # Setup callbacks
    _setupCallbacks($self);

    bless($self, $class);
    return $self;
}

# DESTRUCTOR
sub DESTROY {
    my $self = shift;
    undef $self;
    return 1;
}

# Start GUI
sub show {
    my $self = shift;
    my $update = shift // 1;
    if ($update) {
        _updateGUIPreferences($self);
    }
    $self->{_WINDOWCONFIG}->set_title("Default Global Options : $APPNAME (v$APPVERSION)");
    $$self{_WINDOWCONFIG}->present();
    return 1;
}

# END: Define PUBLIC CLASS methods
###################################################################

###################################################################
# START: Define PRIVATE CLASS functions

sub _initGUI {
    my $self = shift;

    # Load XML Glade file
    defined $$self{_GLADE} or $$self{_GLADE} = Gtk3::Builder->new_from_file($GLADE_FILE) or die "ERROR: Could not load GLADE file '$GLADE_FILE' ($!)";

    # Save main, about and add windows
    $$self{_WINDOWCONFIG} = $$self{_GLADE}->get_object ('windowConfig');
    $$self{_WINDOWCONFIG}->set_size_request(-1, -1);

    _($self, 'imgBannerIcon')->set_from_file("$THEME_DIR/asbru-preferences.svg");
    _($self, 'imgBannerText')->set_text('Preferences');

    # Setup the check-button that defined whether PAC is auto-started on session init
    _($self, 'cbCfgAutoStart')->set_active(-f $ENV{'HOME'} . '/.config/autostart/asbru_start.desktop');

    # Initialize main window
    $$self{_WINDOWCONFIG}->set_icon_name('asbru-app-big');

    _($self, 'btnResetDefaults')->set_image(Gtk3::Image->new_from_icon_name('edit-undo', 'button'));
    _($self, 'btnResetDefaults')->set_label('_Reset to DEFAULT values');
    foreach my $o ('MO', 'TO') {
        foreach my $t ('BE', 'LF', 'AD') {
            _($self, "linkHelp$o$t")->set_label('');
            _($self, "linkHelp$o$t")->set_image(Gtk3::Image->new_from_icon_name('help-browser', 'button'));
        }
    }
    foreach my $t ('linkHelpLocalShell', 'linkHelpGlobalNetwork') {
        _($self, $t)->set_label('');
    _($self, $t)->set_image(Gtk3::Image->new_from_icon_name('help-browser', 'button'));
    }

    # Option currently disabled (legacy Gtk3 stock image call removed)
    # _($self, 'btnCheckVersion')->set_image(PACIcons::icon_image('refresh','view-refresh'));
    # _($self, 'btnCheckVersion')->set_label('Check _now');

    _($self, 'rbCfgStartTreeConn')->set_image(Gtk3::Image->new_from_icon_name('view-list', 'button'));
    _($self, 'rbCfgStartTreeFavs')->set_image(Gtk3::Image->new_from_icon_name('starred', 'button'));
    _($self, 'rbCfgStartTreeHist')->set_image(Gtk3::Image->new_from_icon_name('document-open-recent', 'button'));
    _($self, 'rbCfgStartTreeCluster')->set_image(Gtk3::Image->new_from_icon_name('applications-system', 'button'));
    _($self, 'imgKeePassOpts')->set_from_icon_name('dialog-password', 'button');
    _($self, 'btnCfgSetGUIPassword')->set_image(Gtk3::Image->new_from_icon_name('changes-prevent', 'button'));
    _($self, 'btnCfgSetGUIPassword')->set_label('Set...');
    _($self, 'btnExportYAML')->set_image(Gtk3::Image->new_from_icon_name('document-save-as', 'button'));
    _($self, 'btnExportYAML')->set_label('Export config...');
    _($self, 'alignShellOpts')->add(($$self{_SHELL} = PACTermOpts->new())->{container});
    _($self, 'alignGlobalVar')->add(($$self{_VARIABLES} = PACGlobalVarEntry->new())->{container});
    _($self, 'alignCmdRemote')->add(($$self{_CMD_REMOTE} = PACExecEntry->new(undef, undef, 'remote'))->{container});
    _($self, 'alignCmdLocal')->add(($$self{_CMD_LOCAL} = PACExecEntry->new(undef, undef, 'local'))->{container});
    _($self, 'alignKeePass')->add(($$self{_KEEPASS} = PACKeePass->new(1, $$self{_CFG}{defaults}{keepass}))->{container});
    _($self, 'alignKeyBindings')->add(($$self{_KEYBINDS} = PACKeyBindings->new($$self{_CFG}{defaults}{keybindings}, $$self{_WINDOWCONFIG}))->{container});
    _($self, 'nbPreferences')->show_all();

    _($self, 'btnCfgProxyCheckKPX')->set_image(Gtk3::Image->new_from_icon_name('dialog-password', 'button'));
    _($self, 'btnCfgProxyCheckKPX')->set_label('');

    $$self{cbShowHidden} = Gtk3::CheckButton->new_with_mnemonic('Show _hidden files');
    _($self, 'btnCfgSaveSessionLogs')->set_extra_widget($$self{cbShowHidden});

    _($self, 'spCfgTerminalScrollback')->set_range(-1, 99999);

    # Populate the Encodings combobox
    my $i = -1;
    $$self{_ENCODINGS_ARRAY} = _getEncodings();
    foreach my $enc (sort {uc($a) cmp uc($b)} keys %{$$self{_ENCODINGS_ARRAY}}) {
        _($self, 'cfgComboCharEncode')->append_text($enc);
        $$self{_SHELL}{gui}{'comboEncoding'}->append_text($enc);
        $$self{_ENCODINGS_MAP}{$enc} = ++$i;
    }

    if (!$PACMain::STRAY) {
        _($self, 'lblRestartRequired')->set_markup(_($self, 'lblRestartRequired')->get_text() . "\nTray icon not available, install an extension for tray functionality, <a href='https://docs.asbru-cm.net/Manual/Preferences/SytemTrayExtensions/'>see online help for more details</a>.");
    }

    # Show preferences
    _updateGUIPreferences($self);
    return 1;
}

sub _setupCallbacks {
    my $self = shift;

    # Capture 'Show hidden files' checkbox for session log files
    $$self{cbShowHidden}->signal_connect('toggled' => sub {_($self, 'btnCfgSaveSessionLogs')->set_show_hidden($$self{cbShowHidden}->get_active());});

    _($self, 'cbConnShowPass')->signal_connect('toggled' => sub {
        _($self, 'entryPassword')->set_visibility(_($self, 'cbConnShowPass')->get_active());
    });
    _($self, 'cbCfgSaveSessionLogs')->signal_connect('toggled' => sub {
        _($self, 'hboxCfgSaveSessionLogs')->set_sensitive(_($self, 'cbCfgSaveSessionLogs')->get_active());
    });
    _($self, 'rbCfgInternalViewer')->signal_connect('toggled' => sub {
        _($self, 'entryCfgExternalViewer')->set_sensitive(! _($self, 'rbCfgInternalViewer')->get_active());
    });
    _($self, 'btnSaveConfig')->signal_connect('clicked' => sub {
        $self->_saveConfiguration();
        $self->_closeConfiguration();
    });
    _($self, 'cbBoldAsText')->signal_connect('toggled' => sub {
        _($self, 'colorBold')->set_sensitive(! _($self, 'cbBoldAsText')->get_active());
    });
    _($self, 'cbCfgTabsInMain')->signal_connect('toggled' => sub {
        _($self, 'cbCfgConnectionsAutoHide')->set_sensitive(_($self, 'cbCfgTabsInMain')->get_active());
        _($self, 'cbCfgButtonBarAutoHide')->set_sensitive(_($self, 'cbCfgTabsInMain')->get_active());
        _($self, 'cbCfgPreventMOShowTree')->set_sensitive(_($self, 'cbCfgTabsInMain')->get_active());
        if (!_($self, 'cbCfgTabsInMain')->get_active()) {
            # Set safe values other wise options would be unaccesible
            _($self, 'cbCfgConnectionsAutoHide')->set_active(0);
            _($self, 'cbCfgButtonBarAutoHide')->set_active(0);
        }
    });
    _($self, 'cbCfgStatusBar')->signal_connect('toggled' => sub {
        _($self, 'rbCfgStatusShort')->set_sensitive(_($self, 'cbCfgStatusBar')->get_active());
        _($self, 'rbCfgStatusFull')->set_sensitive(_($self, 'cbCfgStatusBar')->get_active());
        if (!_($self, 'cbCfgStatusBar')->get_active()) {
            # Set safe values other wise options would be unaccesible
            _($self, 'rbCfgStatusShort')->set_active(0);
            _($self, 'rbCfgStatusFull')->set_active(0);
        }
    });
    _($self, 'cbCfgNewInTab')->signal_connect('toggled' => sub {
        _($self, 'vboxCfgTabsOptions')->set_sensitive(_($self, 'cbCfgNewInTab')->get_active());
    });
    _($self, 'cbCfgNewInWindow')->signal_connect('toggled' => sub {
        _($self, 'hboxWidthHeight')->set_sensitive(_($self, 'cbCfgNewInWindow')->get_active());
    });
    _($self, 'btnCfgOpenSessionLogs')->signal_connect('clicked' => sub {
        system("$ENV{'ASBRU_ENV_FOR_EXTERNAL'} /usr/bin/xdg-open " . (_($self, 'btnCfgSaveSessionLogs')->get_current_folder()));
    });
    _($self, 'btnCloseConfig')->signal_connect('clicked' => sub {
        $self->_closeConfiguration();
    });
    _($self, 'btnResetDefaults')->signal_connect('clicked' => sub {
        $self->_resetDefaults();
    });
    _($self, 'btnCfgSetGUIPassword')->signal_connect('clicked' => sub {
        _wSetPACPassword($self, 1);
        return 1;
    });
    _($self, 'cfgComboCharEncode')->signal_connect('changed' => sub {
        my $desc = __($self->{_ENCODINGS_HASH}{_($self, 'cfgComboCharEncode')->get_active_text()} // '');
        if ($desc) {
            $desc = "<span size='x-small'>$desc</span>";
        }
        _($self, 'cfgLblCharEncode')->set_markup($desc);
    });
    _($self, 'cbCfgBWTrayIcon')->signal_connect('toggled' => sub {
    my $icon_name = _($self, 'cbCfgBWTrayIcon')->get_active() ? 'asbru-tray-bw' : 'asbru-tray'; _($self, 'imgTrayIcon')->set_from_icon_name($icon_name, 'button');
    });
    _($self, 'cbCfgShowSudoPassword')->signal_connect('toggled' => sub {
        _($self, 'entryCfgSudoPassword')->set_visibility(_($self, 'cbCfgShowSudoPassword')->get_active());
    });
    _($self, 'cbCfgAutoSave')->signal_connect('toggled' => sub {
        _updateSaveOnExit($self);
    });

    #DevNote: option currently disabled
    #_($self, 'btnCheckVersion')->signal_connect('clicked' => sub {
    #    $PACMain::FUNCS{_MAIN}{_UPDATING} = 1;
    #    $self->_updateGUIPreferences();
    #    PACUtils::_getREADME($$);
    #
    #    return 1;
    #});

    # Capture 'export' button clicked
    _($self, 'btnExportYAML')->signal_connect('button_press_event' => sub {
        my ($widget, $event) = @_;
        my $format = 'yaml';
        my @type;
        push(@type, {label => 'Settings as yml', code => sub {$self->_exporter('yaml');} });
        #push(@type, {label => 'as Perl Data', code => sub {$self->_exporter('perl');} });
        push(@type, {label => 'Anonymized Data for DEBUG', code => sub {$self->_exporter('debug');} });
        _wPopUpMenu(\@type, $event, 1);
        return 1;
    });

    # Capture the "Protect Ásbrú with startup password" checkbutton
    _($self, 'cbCfgUseGUIPassword')->signal_connect('toggled' => sub {
        if (!$$self{_CFGTOGGLEPASS}) {
            return $$self{_CFGTOGGLEPASS} = 1;
        }

        if (_($self, 'cbCfgUseGUIPassword')->get_active()) {
            my $pass_ok = _wSetPACPassword($self, 0);
            if (!$pass_ok) {
                $$self{_CFGTOGGLEPASS} = 0;
            }
            _($self, 'cbCfgUseGUIPassword')->set_active($pass_ok);
            _($self, 'hboxCfgPACPassword')->set_sensitive($pass_ok);
            if ($pass_ok) {
                $PACMain::FUNCS{_MAIN}->_setCFGChanged(1);
            }
        } else {
            if (!$CIPHER->salt()) {
                $CIPHER->salt(pack('Q',$SALT));
            }
            my $pass = _wEnterValue($$self{_WINDOWCONFIG}, 'Ásbrú GUI Password Removal', 'Enter current Ásbrú GUI Password to remove protection...', undef, 0, 'asbru-protected');
            if ((! defined $pass) || ($pass ne $CIPHER->decrypt_hex($$self{_CFG}{'defaults'}{'gui password'}))) {
                $$self{_CFGTOGGLEPASS} = 0;
                _($self, 'cbCfgUseGUIPassword')->set_active(1);
                _($self, 'hboxCfgPACPassword')->set_sensitive(1);
                _wMessage($$self{_WINDOWCONFIG}, 'ERROR: Wrong password!!');
                return 1;
            }

            $$self{_CFG}{'defaults'}{'gui password'} = $CIPHER->encrypt_hex('');
            _($self, 'hboxCfgPACPassword')->set_sensitive(0);
            $PACMain::FUNCS{_MAIN}->_setCFGChanged(1);
        }
        return 0;
    });

    _($self, 'entryCfgSudoPassword')->signal_connect('button_press_event' => sub {
        my ($widget, $event) = @_;

        if ($event->button ne 3) {
            return 0;
        }

        my @menu_items;

        # Populate with <<ASK_PASS>> special string
        push(@menu_items, {
            label => 'Interactive Password input',
            code => sub {
                _($self, 'entryCfgSudoPassword')->delete_text(0, -1);
                _($self, 'entryCfgSudoPassword')->insert_text('<<ASK_PASS>>', -1, 0);
            }
        });

        # Populate with user defined variables
        my @variables_menu;
        my $i = 0;
        foreach my $value (map{$_->{txt} // ''} @{$$self{variables}}) {
            my $j = $i;
            push(@variables_menu, {
                label => "<V:$j> ($value)",
                code => sub {
                    _($self, 'entryCfgSudoPassword')->insert_text("<V:$j>", -1, _($self, 'entryCfgSudoPassword')->get_position());
                }
            });
            ++$i;
        }
        push(@menu_items, {
            label => 'User variables...',
            sensitive => scalar @{$$self{variables}},
            submenu => \@variables_menu
        });


        # Populate with global defined variables
        my @global_variables_menu;
        foreach my $var (sort {$a cmp $b} keys %{$PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'global variables'}}) {
            my $val = $PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'global variables'}{$var}{'value'};
            push(@global_variables_menu, {
                label => "<GV:$var> ($val)",
                code => sub {_($self, 'entryCfgSudoPassword')->insert_text("<GV:$var>", -1, _($self, 'entryCfgSudoPassword')->get_position());}
            });
        }
        push(@menu_items, {
            label => 'Global variables...',
            sensitive => scalar(@global_variables_menu),
            submenu => \@global_variables_menu
        });

        # Populate with environment variables
        my @environment_menu;
        foreach my $key (sort {$a cmp $b} keys %ENV) {
            # Do not offer Master Password, or any other environment variable with word PRIVATE, TOKEN
            if ($key =~ /KPXC|PRIVATE|TOKEN/i) {
                next;
            }
            my $value = $ENV{$key};
            push(@environment_menu, {
                label => "<ENV:" . __($key) . ">",
                tooltip => "$key=$value",
                code => sub {_($self, 'entryCfgSudoPassword')->insert_text("<ENV:$key>", -1, _($self, 'entryCfgSudoPassword')->get_position());}
            });
        }
        push(@menu_items, {
            label => 'Environment variables...',
            submenu => \@environment_menu
        });

        # Populate with <ASK:#> special string
        push(@menu_items, {
            label => 'Interactive user input',
            tooltip => 'User will be prompted to provide a value with a text box (free data type)',
            code => sub {
                my $pos = _($self, 'entryCfgSudoPassword')->get_property('cursor_position');
                _($self, 'entryCfgSudoPassword')->insert_text('<ASK:number>', -1, _($self, 'entryCfgSudoPassword')->get_position());
                _($self, 'entryCfgSudoPassword')->select_region($pos + 5, $pos + 11);
            }
        });

        # Populate with <ASK:*|> special string
        push(@menu_items, {
            label => 'Interactive user choose from list',
            tooltip => 'User will be prompted to choose a value form a user defined list separated with "|" (pipes without quotes)',
            code => sub {
                my $pos = _($self, 'entryCfgSudoPassword')->get_property('cursor_position');
                _($self, 'entryCfgSudoPassword')->insert_text('<ASK:descriptive line|opt1|opt2|...|optN>', -1, _($self, 'entryCfgSudoPassword')->get_position());
                _($self, 'entryCfgSudoPassword')->select_region($pos + 5, $pos + 40);
            }
        });

        # Populate with <CMD:*> special string
        push(@menu_items, {
            label => 'Use a command output as value',
            tooltip => 'The given command line will be locally executed, and its output (both STDOUT and STDERR) will be used to replace this value',
            code => sub {
                my $pos = _($self, 'entryCfgSudoPassword')->get_property('cursor_position');
                _($self, 'entryCfgSudoPassword')->insert_text('<CMD:command to launch>', -1, _($self, 'entryCfgSudoPassword')->get_position());
                _($self, 'entryCfgSudoPassword')->select_region($pos + 5, $pos + 22);
            }
        });

        _wPopUpMenu(\@menu_items, $event);

        return 1;
    });

    $$self{_WINDOWCONFIG}->signal_connect('delete_event' => sub {
        _($self, 'btnCloseConfig')->clicked;
        return 1;
    });
    $$self{_WINDOWCONFIG}->signal_connect('key_press_event' => sub {
        my ($widget, $event) = @_;
        if ($event->keyval == 65307) {
            $self->_closeConfiguration();
        }
        return 0;
    });

    # Layout signal
    _($self, 'comboLayout')->signal_connect('changed' => sub {
        if (_($self, 'comboLayout')->get_active_text() eq 'Traditional') {
            _($self, 'frameTabsInMainWindow')->show();
            _($self, 'frameTabsInMainWindow')->show();
            _($self, 'cbCfgStartMainMaximized')->show();
            _($self, 'cbCfgRememberSize')->show();
            _($self, 'cbCfgSaveOnExit')->show();
            _($self, 'cbCfgStartIconified')->show();
            _($self, 'cbCfgCloseToTray')->show();
            _($self, 'cbCfgShowTreeTitles')->show();
            _($self, 'cbCfgShowTreeTitles')->set_active(1);
        } else {
            _($self, 'frameTabsInMainWindow')->hide();
            _($self, 'cbCfgStartMainMaximized')->hide();
            _($self, 'cbCfgRememberSize')->hide();
            _($self, 'cbCfgSaveOnExit')->hide();
            _($self, 'cbCfgSaveOnExit')->set_active(1);
            _($self, 'cbCfgAutoSave')->set_active(1);
            _($self, 'cbCfgShowTreeTitles')->hide();
            _($self, 'cbCfgShowTreeTitles')->set_active(0);
            if (!$PACMain::STRAY) {
                _($self, 'cbCfgStartIconified')->hide();
                _($self, 'cbCfgCloseToTray')->hide();
            }
        }
    });

    # Capture proxy usage change
    _($self, 'cbCfgProxyManual')->signal_connect('toggled' => sub {
        _($self, 'hboxPrefProxyManualOptions')->set_sensitive(_($self, 'cbCfgProxyManual')->get_active());
        _updateCfgProxyKeePass($self);
    });

    # Capture jump host change
    _($self, 'cbCfgProxyJump')->signal_connect('toggled' => sub {
        _($self, 'vboxPrefJumpCfgOptions')->set_sensitive(_($self, 'cbCfgProxyJump')->get_active());
        _updateCfgProxyKeePass($self);
    });

    # Clear private key
    _($self, 'btnConfigClearJumpPrivateKey')->signal_connect('clicked' => sub {
        _($self, 'entryCfgJumpKey')->set_uri("file://$ENV{'HOME'}");
        _($self, 'entryCfgJumpKey')->unselect_uri("file://$ENV{'HOME'}");
    });

    # Capture support transparency change
    _($self, 'cbCfgTerminalSupportTransparency')->signal_connect('toggled' => sub {
        _($self, 'spCfgTerminalTransparency')->set_sensitive(_($self, 'cbCfgTerminalSupportTransparency')->get_active());
    });

    # Associated proxy settings to KeePass entries
    _($self, 'btnCfgProxyCheckKPX')->signal_connect('clicked' => sub {
        # User selects an entry in KeePass
        my $title = $PACMain::FUNCS{_KEEPASS}->listEntries($$self{_WINDOWCONFIG});

        if ($title) {
            if (_($self, 'cbCfgProxyManual')->get_active) {
                _($self, 'entryCfgProxyIP')->set_text("<url|$title>");
                _($self, 'entryCfgProxyUser')->set_text("<username|$title>");
                _($self, 'entryCfgProxyPassword')->set_text("<password|$title>");
            } elsif (_($self, 'cbCfgProxyJump')->get_active) {
                _($self, 'entryCfgJumpIP')->set_text("<url|$title>");
                _($self, 'entryCfgJumpUser')->set_text("<username|$title>");
                _($self, 'entryCfgJumpPass')->set_text("<password|$title>");
            }
        }
    });

    # Monitor the main notebook and detects when we are switching to the keybindings frame
    # When the keybindings frame is shown, all 'mnemonics' has to be disabled to avoid conflicts when assigning keyboard shortcuts
    # When another frame is shown, original mnemonics are restored
    # DevNote: did not find a way to ignore the mnemonic, if use 'mnemonic_activate' ; the shortcut was not processed by the keybindings frame at all
    my $hasMnemonics = 1;
    my $labelClose = _($self, 'label86')->get_label();
    my $textClose = _($self, 'label86')->get_text();
    my $labelSave = _($self, 'label16')->get_label();
    my $textSave = _($self, 'label16')->get_text();
    my $labelReset = _($self, 'btnResetDefaults')->get_label();
    my $textReset = $labelReset =~ s/_//r;
    _($self, 'nbPreferences')->signal_connect('switch_page' => sub {
        my ($nb, $frame, $data) = @_;
        if ($frame eq _($self, 'frameKeyBindings')) {
            if ($hasMnemonics) {
                _($self, 'label86')->set_text($textClose);
                _($self, 'label16')->set_text($textSave);
                _($self, 'btnResetDefaults')->set_label($textReset);
                $hasMnemonics = 0;
            }
        } else {
            if (!$hasMnemonics) {
                _($self, 'label86')->set_text_with_mnemonic($labelClose);
                _($self, 'label16')->set_text_with_mnemonic($labelSave);
                _($self, 'btnResetDefaults')->set_label($labelReset);
                $hasMnemonics = 1;
            }
        }
        return 0;
    });

    return 1;
}

sub _exporter {
    my $self = shift;
    my $format = shift // 'dumper';
    my $file = shift // '';
    my $name = 'asbru';

    my $suffix = '';
    my $func = '';

    if ($format eq 'yaml') {
        $suffix = '.yml';
        $func = 'require YAML; YAML::DumpFile($file, $$self{_CFG}) or die "ERROR: Could not save file \'$file\' ($!)";';
    } elsif ($format eq 'perl') {
        $suffix = '.dumper';
        $func = 'use Data::Dumper; $Data::Dumper::Indent = 1; $Data::Dumper::Purity = 1; open(F, ">:utf8",$file) or die "ERROR: Could not open file \'$file\' for writting ($!)"; print F Dumper($$self{_CFG}); close F;';
    } elsif ($format eq 'debug') {
        $name = 'debug';
        $suffix = '.yml';
        $func = 'require YAML; YAML::DumpFile($file, $$self{_CFG}) or die "ERROR: Could not save file \'$file\' ($!)";';
        my $answ = _wConfirm($$self{_WINDOWCONFIG}, "You are about to create a file containing an anonymized version of your settings.\n\nThis file will contain your configuration settings without any sensitive personal data in it.  It is only useful for debugging purposes only. Do not use this file for backup purposes.\n\nCare has been taken to remove all personal information but no guarantee is given, you are the only responsible for any disclosed information.\nPlease review the exported data before sharing it with a third party.\n\n<b>Do you wish to continue?</b>");
        if (!$answ) {
            _wMessage($$self{_WINDOWCONFIG}, "Export process has been canceled.");
            return 1;
        }
    }

    my $w;
    if (!$file) {
        my $choose = Gtk3::FileChooserDialog->new(
            "$APPNAME (v.$APPVERSION) Choose file to Export configuration as '$format'",
            $$self{_WINDOWCONFIG},
            'GTK_FILE_CHOOSER_ACTION_SAVE',
            'Cancel' , 'GTK_RESPONSE_CANCEL',
            'Export' , 'GTK_RESPONSE_ACCEPT',
        );
        $choose->set_do_overwrite_confirmation(1);
        $choose->set_current_folder($ENV{'HOME'} // '/tmp');
        $choose->set_current_name("$name$suffix");

        my $out = $choose->run();
        $file = $choose->get_filename();
        $choose->destroy();
        if ($out ne 'accept') {
            return 1;
        }
        $$self{_WINDOWCONFIG}->get_window()->set_cursor(Gtk3::Gdk::Cursor->new('watch') );
        $w = _wMessage($$self{_WINDOWCONFIG}, "Please, wait while file '$file' is being created...", 0);
        while (Gtk3::events_pending) {
            Gtk3::main_iteration;
        }
    }

    _cfgSanityCheck($$self{_CFG});
    _cipherCFG($$self{_CFG});

    $$self{_CFG}{'__PAC__EXPORTED__FULL__'} = 1;
    eval "$func";
    if ((!$@) && (defined $w)) {
        if ($format eq 'debug') {
            $file = cleanUpPersonalData($file);
        }
        $w->destroy();
        _wMessage($$self{_WINDOWCONFIG}, "'$format' file succesfully saved to:\n\n$file");
    } elsif (defined $w) {
        $w->destroy();
        _wMessage($$self{_WINDOWCONFIG}, "ERROR: Could not save Ásrbú Config file '$file':\n\n$@");
    }
    delete $$self{_CFG}{'__PAC__EXPORTED__'};
    delete $$self{_CFG}{'__PAC__EXPORTED__FULL__'};

    _decipherCFG($$self{_CFG});
    if (defined $$self{_WINDOWCONFIG}->get_window()) {
        $$self{_WINDOWCONFIG}->get_window()->set_cursor(Gtk3::Gdk::Cursor->new('left-ptr'));
    }

    return $file;
}

sub cleanUpPersonalData {
    my $file = shift;
    my $out = $file;

    system "$ENV{'ASBRU_ENV_FOR_EXTERNAL'} mv -f $file $file.txt";
    $file .= ".txt";

    $SIG{__WARN__} = sub{};
    print STDERR "SAVED IN : $file\nOUT: $out\n";
    # Remove all personal information
    open(F, "<:utf8", $file);
    open(D, ">:utf8", $out);
    my $C = 0;
    while (my $line = <F>) {
        my $next = 0;
        foreach my $key ('name', 'send', 'ip', 'user', 'prepend command', 'postpend_command', 'database', 'gui password', 'sudo password') {
            if ($line =~ /^[\t ]+$key:/) {
                $line =~ s/$key:.+/$key: 'removed'/;
                $next = 1;
            }
            if ($next) {
                next;
            }
        }
        if ($line =~ /KPX title regexp/) {
            $line =~ s/KPX title regexp:.+/KPX title regexp: ''/;
        } elsif ($line =~ /^[\t ]+(title|name):/) {
            my $p = $1;
            if ($p eq 'name') {
                $C++;
            }
            $line =~ s/$p:.+/$p: '$p $C'/;
        } elsif (($line =~ /^[\t ]+(global variables|remote commands|local commands|expect|local before|local after|local connected):/) && ($line !~ /^[\t ]+(global variables|remote commands|local commands|expect|local before|local after|local connected): \[\]/)) {
            my $global = 0;
            my $indent = '';
            if ($line =~ /global variables/) {
                $global = 1;
            }
            if ($line =~ /^([\t ]+)/) {
                $indent = $1;
            }
            print D $line;
            while (my $l = <F>) {
                if ($l =~ /^${indent}\w/) {
                    print D $l;
                    last;
                } elsif ($global) {
                    next;
                } elsif ($l =~ /description|expect|send|txt/) {
                    $l =~ s|(.+?):.+|$1: 'removed'|;
                }
                print D $l;
            }
            next;
        } elsif ($line =~ /^[\t ]+options:/) {
            $line =~ s/\/drive:.+?( |\')/\/drive: removed$1/;
            $line =~ s/ disk:.+?( |\')/ disk: removed$1/;
            $line =~ s/\/d:.+?( |\')/\/d: removed$1/;
            $line =~ s/-d .+?( |\')/-d removed$1/;
            if ($line =~ / -(D|L|R)/) {
                $line =~ s/(^[\t ]+options):.+/$1: 'removed'/;
            }
        } elsif (($line =~ /^[\t ]+proxy (ip|pass|user):/)&&($line !~ /^[\t ]+proxy (ip|pass|user): \'\'/)) {
            $line =~ s/(proxy.+?):.+/$1: 'removed'/;
        } elsif (($line =~ /^[\t ]+jump (config|ip|pass|user|key):/)&&($line !~ /^[\t ]+jump (config|ip|pass|user|key): \'\'/)) {
            $line =~ s/(jump.+?):.+/$1: 'removed'/;
        } elsif ($line =~ /^[\t ]+description:/) {
            $line =~ s/description:.+/description: 'Description'/;
        } elsif ($line =~ /^[\t ]+public key: (.+)/) {
            $line =~ s/public key:.+/public key: 'uses public key'/;
        } elsif ($line =~ /^[\t ]+pass(word|phrase)?:/) {
            $line =~ s/pass(word|phrase)?:.+/pass$1: 'removed'/;
        } elsif ($line =~ /^[\t ]+use gui password( tray)?:/) {
            $line =~ s/use gui password( tray)?:.+/use gui password$1: \'\'/;
        } elsif ($line =~ /^[\t ]+passphrase user:/) {
            $line =~ s/passphrase user:.+/passphrase user: 'removed'/;
        }
        $line =~ s|/home/.+?/|/home/PATH/|;
        $line =~ s|$ENV{USER}|USER|;
        print D $line;
    }
    # Add runtime information
    print D "\n\n#$APPNAME : $APPVERSION\n\n# ENV Data\n";
    my $user = $ENV{USER} ? $ENV{USER} : $ENV{LOGNAME};
    foreach my $k (sort keys %ENV) {
        if ($k =~ /token|hostname|startup|KPXC|AUTH/i) {
            next;
        }
        my $str = $ENV{$k};
        $str =~ s|$user|USER|g;
        print D "#$k : $str\n";
    }
    print D "\n\n";
    close F;
    close D;
    unlink $file;
    return $out;
}

sub _resetDefaults {
    my $self = shift;

    my %default_cfg;
    defined $default_cfg{'defaults'}{1} or 1;

    PACUtils::_cfgSanityCheck(\%default_cfg);
    $self->_updateGUIPreferences(\%default_cfg);

    return 1;
}

sub _updateGUIPreferences {
    my $self = shift;
    my $cfg = shift // $$self{_CFG};
    
    # Prevent recursion
    return if $self->{_updating_gui_preferences};
    local $self->{_updating_gui_preferences} = 1;
    
    my %layout = ('Traditional', 0, 'Compact', 1);
    # NOTE: Theme order in Glade must match this list. To avoid mismatch issues when
    # Glade order changes, we no longer rely exclusively on this static index map
    # when selecting; instead we will look up the active row by text. We keep the
    # hash for backwards compatibility if order still matches.
    # Dynamic themes: scan res/themes for directories (prefix asbru- or default) and add 'system'
    my %theme; # keep index mapping only for legacy fallback
    if (my $combo_theme_obj = eval { _($self,'comboTheme') }) {
        my $store = eval { $combo_theme_obj->get_model };
        if ($store && eval { $store->can('clear') }) {
            eval { $store->clear; };
            my $idx = 0;
            my $res_dir = $PACMain::FUNCS{_MAIN}->{_RES_DIR} || 'res';
            my $themes_root = "$res_dir/themes";
            if (-d $themes_root) {
                opendir(my $dh,$themes_root);
                my @dirs = grep { -d "$themes_root/$_" && !/^\./ } readdir($dh);
                closedir $dh;
                # Prioritize default first, then others sorted
                my @ordered = ('default', sort grep { $_ ne 'default' } @dirs);
                for my $t (@ordered) {
                    next unless $t =~ /^(default|asbru-[-a-z0-9]+)$/i;
                    eval { $combo_theme_obj->append_text($t); };
                    $theme{$t} = $idx++;
                }
            }
            eval { $combo_theme_obj->append_text('system'); $theme{'system'} = $idx++; };
        }
    } else {
        %theme = ('default',0,'asbru-color',1,'asbru-dark',2,'system',3);
    }

    if (!defined $$cfg{'defaults'}{'layout'}) {
        $$cfg{'defaults'}{'layout'} = 'Traditional';
    }
    if (!defined $layout{$$cfg{'defaults'}{'layout'}}) {
        $layout{$$cfg{'defaults'}{'layout'}} = 0;
    }
    if (!defined $$cfg{'defaults'}{'bold is brigth'}) {
        $$cfg{'defaults'}{'bold is brigth'} = 0;
    }
    if (!defined $$cfg{'defaults'}{'unprotected set'}) {
        $$cfg{'defaults'}{'unprotected set'} = 'foreground';
    }
    if (!defined $$cfg{'defaults'}{'theme'}) {
        $$cfg{'defaults'}{'theme'} = 'default';
    }
    if (!-d $$cfg{'defaults'}{'session logs folder'}) {
        $$cfg{'defaults'}{'session logs folder'} = "$CFG_DIR/session_logs";
    }
    # Main options
    #_($self, 'btnCfgLocation')->set_uri('file://' . $$self{_CFG}{'defaults'}{'config location'});
    _($self, 'cbCfgAutoAcceptKeys')->set_active($$cfg{'defaults'}{'auto accept key'});
    _($self, 'cbCfgHideOnConnect')->set_active($$cfg{'defaults'}{'hide on connect'});
    _($self, 'cbCfgForceSplitSize')->set_active($$cfg{'defaults'}{'force split tabs to 50%'});
    _($self, 'cbCfgCloseToTray')->set_active($$cfg{'defaults'}{'close to tray'});
    _($self, 'cbCfgStartMainMaximized')->set_active($$cfg{'defaults'}{'start main maximized'});
    _($self, 'cbCfgRememberSize')->set_active($$cfg{'defaults'}{'remember main size'});
    _($self, 'cbCfgStartIconified')->set_active($$cfg{'defaults'}{'start iconified'});
    _($self, 'cbCfgAutoSave')->set_active($$cfg{'defaults'}{'auto save'});
    _($self, 'cbCfgSaveOnExit')->set_active($$cfg{'defaults'}{'save on exit'});
    _($self, 'cbCfgBWTrayIcon')->set_active($$cfg{'defaults'}{'use bw icon'});
    _($self, 'cbCfgSaveShowScreenshots')->set_active($$cfg{'defaults'}{'show screenshots'});
    _($self, 'cbCfgConfirmExit')->set_active($$cfg{'defaults'}{'confirm exit'});
    _($self, 'rbCfgInternalViewer')->set_active(! $$cfg{'defaults'}{'screenshots use external viewer'});
    _($self, 'rbCfgExternalViewer')->set_active($$cfg{'defaults'}{'screenshots use external viewer'});
    _($self, 'entryCfgExternalViewer')->set_text($$cfg{'defaults'}{'screenshots external viewer'});
    _($self, 'entryCfgExternalViewer')->set_sensitive($$cfg{'defaults'}{'screenshots use external viewer'});
    _($self, 'cbCfgTabsInMain')->set_active($$cfg{'defaults'}{'tabs in main window'});
    _($self, 'cbCfgConnectionsAutoHide')->set_active($$cfg{'defaults'}{'auto hide connections list'});
    _($self, 'cbCfgButtonBarAutoHide')->set_active($$cfg{'defaults'}{'auto hide button bar'});
    _($self, 'cbCfgPreventMOShowTree')->set_sensitive(_($self, 'cbCfgTabsInMain')->get_active());
    _($self, 'cbCfgStatusBar')->set_active($$cfg{'defaults'}{'info in status bar'});
    _($self, 'rbCfgStatusShort')->set_active(! $$cfg{'defaults'}{'forwarding short names'});
    _($self, 'rbCfgStatusFull')->set_active($$cfg{'defaults'}{'forwarding full names'});
    _($self, 'entryCfgPrompt')->set_text($$cfg{'defaults'}{'command prompt'});
    _($self, 'entryCfgUserPrompt')->set_text($$cfg{'defaults'}{'username prompt'});
    _($self, 'entryCfgPasswordPrompt')->set_text($$cfg{'defaults'}{'password prompt'});
    _($self, 'entryCfgPasswordPrompt')->select_region(0, 0);
    _($self, 'entryCfgHostKeyVerification')->set_text($$cfg{'defaults'}{'hostkey changed prompt'});
    _($self, 'entryCfgPressAnyKey')->set_text($$cfg{'defaults'}{'press any key prompt'});
    _($self, 'entryCfgRemoteHostChanged')->set_text($$cfg{'defaults'}{'remote host changed prompt'});
    _($self, 'entryCfgSudoPrompt')->set_text($$cfg{'defaults'}{'sudo prompt'});
    _($self, 'entryCfgSudoPassword')->set_text($$cfg{'defaults'}{'sudo password'});
    _($self, 'cbCfgShowSudoPassword')->set_active($$cfg{'defaults'}{'sudo show password'});
    _($self, 'entryCfgSudoPassword')->set_visibility(_($self, 'cbCfgShowSudoPassword')->get_active());
    _($self, 'entryCfgSelectByWordChars')->set_text($$cfg{'defaults'}{'word characters'});
    _($self, 'cbCfgShowTrayIcon')->set_active($$cfg{'defaults'}{'show tray icon'});
    _($self, 'cbCfgAutoStart')->set_active(-f "$ENV{'HOME'}/.config/autostart/asbru_start.desktop");
    #DevNote: option currently disabled
    #_($self, 'cbCfgCheckVersions')->set_active($$cfg{'defaults'}{'check versions at start'});
    #_($self, 'btnCheckVersion')->set_sensitive(! $PACMain::FUNCS{_MAIN}{_UPDATING});
    _($self, 'cbCfgShowStatistics')->set_active($$cfg{'defaults'}{'show statistics'});

    _($self, 'rbCfgUnForeground')->set_active($$cfg{'defaults'}{'unprotected set'} eq 'foreground');
    _($self, 'rbCfgUnBackground')->set_active($$cfg{'defaults'}{'unprotected set'} eq 'background');
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorCfgUnProtected', 'unprotected color', _($self, 'colorCfgUnProtected')->get_color()->to_string());

    _($self, 'rbCfgForeground')->set_active($$cfg{'defaults'}{'protected set'} eq 'foreground');
    _($self, 'rbCfgBackground')->set_active($$cfg{'defaults'}{'protected set'} eq 'background');
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorCfgProtected', 'protected color', _($self, 'colorCfgProtected')->get_color()->to_string());

    _($self, 'cbCfgUseGUIPassword')->set_active($$cfg{'defaults'}{'use gui password'});
    _($self, 'hboxCfgPACPassword')->set_sensitive($$cfg{'defaults'}{'use gui password'});
    _($self, 'cbCfgUseGUIPasswordTray')->set_active($$cfg{'defaults'}{'use gui password tray'});
    _($self, 'cbCfgAutoStartShell')->set_active($$cfg{'defaults'}{'autostart shell upon PAC start'});
    _($self, 'cbCfgTreeOnRight')->set_active($$cfg{'defaults'}{'tree on right side'});
    _($self, 'cbCfgTreeOnLeft')->set_active(! $$cfg{'defaults'}{'tree on right side'});
    _($self, 'cbCfgPreventMOShowTree')->set_active(!$$cfg{'defaults'}{'prevent mouse over show tree'});
    _($self, 'rbCfgStartTreeConn')->set_active($$cfg{'defaults'}{'start PAC tree on'} eq 'connections');
    _($self, 'rbCfgStartTreeFavs')->set_active($$cfg{'defaults'}{'start PAC tree on'} eq 'favourites');
    _($self, 'rbCfgStartTreeHist')->set_active($$cfg{'defaults'}{'start PAC tree on'} eq 'history');
    _($self, 'rbCfgStartTreeCluster')->set_active($$cfg{'defaults'}{'start PAC tree on'} eq 'clusters');
    _($self, 'cbCfgShowTreeTooltips')->set_active($$cfg{'defaults'}{'show connections tooltips'});
    _($self, 'cbCfgUseShellToConnect')->set_active($$cfg{'defaults'}{'use login shell to connect'});
    _($self, 'cbCfgAutoAppendGroupName')->set_active($$cfg{'defaults'}{'append group name'});
    my $icon_name2 = $$cfg{'defaults'}{'use bw icon'} ? 'asbru-tray-bw' : 'asbru-tray'; _($self, 'imgTrayIcon')->set_from_icon_name($icon_name2, 'button');
    _($self, 'rbOnNoTabsNothing')->set_active($$cfg{'defaults'}{'when no more tabs'} == 0);
    _($self, 'rbOnNoTabsClose')->set_active($$cfg{'defaults'}{'when no more tabs'} == 1);
    _($self, 'rbOnNoTabsHide')->set_active($$cfg{'defaults'}{'when no more tabs'} == 2);
    _($self, 'cbCfgSelectionToClipboard')->set_active($$cfg{'defaults'}{'selection to clipboard'});
    _($self, 'cbCfgRemoveCtrlCharsConf')->set_active($$cfg{'defaults'}{'remove control chars'});
    _($self, 'cbCfgLogTimestam')->set_active($$cfg{'defaults'}{'log timestamp'});
    _($self, 'cbCfgAllowMoreInstances')->set_active($$cfg{'defaults'}{'allow more instances'});
    _($self, 'cbCfgShowFavOnUnity')->set_active($$cfg{'defaults'}{'show favourites in unity'});
    my $layout_idx = exists $layout{$$cfg{'defaults'}{'layout'}} ? $layout{$$cfg{'defaults'}{'layout'}} : 0;
    my $theme_key = $$cfg{'defaults'}{'theme'} // 'default';
    _($self, 'comboLayout')->set_active($layout_idx);
    # Robust theme selection: search combo entries by text instead of trusting index
    if (my $combo_theme = eval { _($self, 'comboTheme') }) {
        my $model = eval { $combo_theme->get_model }; my $iter = ($model && eval { $model->can('get_iter_first') }) ? $model->get_iter_first : undef;
        my $idx = 0; my $found = -1;
    while ($iter) { my $val = eval { $model->get($iter,0) }; last if !defined $val && $@; if (defined $val && $val eq $theme_key) { $found = $idx; last; } $idx++; $iter = $model->iter_next($iter); }
        if ($found >= 0) { eval { $combo_theme->set_active($found); }; }
    else { eval { $combo_theme->set_active(exists $theme{$theme_key} ? $theme{$theme_key} : 0); }; }
        # Connect change handler once (idempotent)
        if (!$self->{_combo_theme_connected}) {
            $combo_theme->signal_connect(changed => sub {
                my $sel = eval { $combo_theme->get_active_text } // '';
                $sel =~ s/\s+$//; $sel =~ s/^\s+//;
                return if $sel eq '';
                
                # Prevent recursion by checking if we're already updating
                return if $self->{_updating_gui_preferences};
                
                $$self{_CFG}{'defaults'}{'theme'} = $sel;
                if ($sel eq 'system') {
                    # Trigger rebuild of system icon theme widgets (avoid recursion)
                    eval { $PACMain::FUNCS{_MAIN}->_refresh_all_icons(); };
                } else {
                    # Apply internal theme immediately
                    eval { $PACMain::FUNCS{_MAIN}->_apply_internal_theme($sel); };
                }
                # Persist selection (system override saved separately when chosen)
                eval { $PACMain::FUNCS{_MAIN}->_setCFGChanged(1); $PACMain::FUNCS{_MAIN}->_saveConfiguration($PACMain::FUNCS{_MAIN}->{_CFG},0); };
            });
            $self->{_combo_theme_connected} = 1;
        }
        # Inject force-internal-icons checkbox (idempotent)
        my $parent = eval { $combo_theme->get_parent };
        if ($parent && !$self->{_force_internal_icons_added}) {
            # Skip if already present (duplicate rebuild)
            unless (_parent_has_child_named($parent,'cbForceInternalIcons')) {
                my $chk = Gtk3::CheckButton->new_with_label('Force internal icon files (override system icons)');
                $chk->set_name('cbForceInternalIcons');
                $chk->set_active( $$cfg{'defaults'}{'force_internal_icons'} ? 1 : 0 );
                PACWidgetUtils::safe_pack_start($parent, $chk, 0,0,4);
                $chk->signal_connect(toggled => sub {
                    my $val = $chk->get_active ? 1 : 0;
                    $$self{_CFG}{'defaults'}{'force_internal_icons'} = $val;
                    # Icon cache clearing no longer needed with standard GTK icons
                    eval { $PACMain::FUNCS{_MAIN}->_refresh_all_icons(); };
                    eval { $PACMain::FUNCS{_MAIN}->_setCFGChanged(1); $PACMain::FUNCS{_MAIN}->_saveConfiguration($PACMain::FUNCS{_MAIN}->{_CFG},0); };
                });
                $chk->show_all();
            }
            $self->{_force_internal_icons_added} = 1;
        }
        # If 'system' theme chosen, ensure a combo with enumerated GTK system icon themes is available
        if ($theme_key eq 'system') {
            my $combo_theme = eval { _($self, 'comboTheme') };
            my $parent = $combo_theme ? eval { $combo_theme->get_parent } : undef;
            if ($parent) {
                # Always purge existing dynamic widgets to guarantee no duplication
                my @children = eval { $parent->get_children };
                for my $ch (@children) {
                    my $nm = eval { $ch->get_name } // '';
                    next unless $nm =~ /^(comboSystemIconTheme|btnPreviewSystemIconTheme|btnRefreshSystemIconTheme|lblNoSystemIconThemes)$/;
                    eval { $parent->remove($ch) };
                    eval { $ch->destroy };
                }
                return if $self->{_building_system_theme_widgets};
                local $self->{_building_system_theme_widgets} = 1;
                my $themes = _enumerate_system_icon_themes();
                if (!$themes || !@$themes) {
                    unless (_parent_has_child_named($parent,'lblNoSystemIconThemes')) {
                    my $lbl = Gtk3::Label->new('No system icon themes found in ~/.local/share/icons or /usr/share/icons');
                    $lbl->set_name('lblNoSystemIconThemes');
                    PACWidgetUtils::safe_pack_start($parent, $lbl, 0,0,6);
                    $lbl->show_all();
                }
                }
                my $combo_sys = Gtk3::ComboBoxText->new();
                $combo_sys->set_name('comboSystemIconTheme');
                $combo_sys->append_text('');
                foreach my $t (@$themes) { $combo_sys->append_text($t); }
                # Avoid duplicate pack if already exists (race)
                unless (_parent_has_child_named($parent,'comboSystemIconTheme')) {
                PACWidgetUtils::safe_pack_start($parent, $combo_sys, 0,0,6);
                }
                my $saved = $$cfg{'defaults'}{'system icon theme override'} // '';
                if ($saved ne '') {
                    my $idx = 0; my $found = 0; my $model = eval { $combo_sys->get_model }; my $iter = ($model && eval { $model->can('get_iter_first') }) ? $model->get_iter_first : undef;
                    while ($iter) {
                        my $val = eval { $model->get($iter,0) }; last if !defined $val && $@;
                        if (defined $val && $val eq $saved) { eval { $combo_sys->set_active($idx); }; $found=1; last; }
                        $idx++; $iter = $model->iter_next($iter);
                    }
                    if (!$found) { $combo_sys->append_text($saved); eval { $combo_sys->set_active($idx); }; }
                } else { eval { $combo_sys->set_active(0); }; }
                # Also persist when user changes active item in the system theme combo (without pressing preview)
                $combo_sys->signal_connect(changed => sub {
                    my $sel = $combo_sys->get_active_text // '';
                    $sel =~ s/^\s+|\s+$//g;
                    if ($sel ne '' && _validate_system_icon_theme($sel)) {
                        $$cfg{'defaults'}{'system icon theme override'} = $sel;
                        $$cfg{'defaults'}{'theme'} = 'system';
                        eval { $PACMain::FUNCS{_MAIN}->_setCFGChanged(1); $PACMain::FUNCS{_MAIN}->_saveConfiguration($PACMain::FUNCS{_MAIN}->{_CFG},0); };
                    }
                });
                # Create Preview button (declare before use)
                my $btn_prev = Gtk3::Button->new_with_label('Preview');
                $btn_prev->set_name('btnPreviewSystemIconTheme');
                eval { $btn_prev->set_tooltip_text('Preview & apply the selected system icon theme now'); };
                eval { $combo_sys->set_tooltip_text('List of detected system icon themes (from ~/.local/share/icons, /usr/share/icons)'); };
                $btn_prev->signal_connect(clicked => sub {
                    my $sel = $combo_sys->get_active_text // '';
                    $sel =~ s/^\s+|\s+$//g;
                    if ($sel ne '' && _validate_system_icon_theme($sel)) {
                        eval { $PACMain::FUNCS{_MAIN}->_apply_system_icon_theme($sel); };
                        $$cfg{'defaults'}{'system icon theme override'} = $sel;
                        $$cfg{'defaults'}{'theme'} = 'system';
                        eval { $PACMain::FUNCS{_MAIN}->_setCFGChanged(1); $PACMain::FUNCS{_MAIN}->_saveConfiguration($PACMain::FUNCS{_MAIN}->{_CFG},0); };
                    } else {
                        _show_theme_warning($self, $sel eq '' ? 'Select a theme first.' : "Theme '$sel' not found.");
                    }
                });
                unless (_parent_has_child_named($parent,'btnPreviewSystemIconTheme')) { PACWidgetUtils::safe_pack_start($parent, $btn_prev, 0,0,6); }
                # Refresh button
                my $btn_refresh = Gtk3::Button->new_with_label('Refresh');
                $btn_refresh->set_name('btnRefreshSystemIconTheme');
                eval { $btn_refresh->set_tooltip_text('Re-scan system icon themes (clears 60s cache)'); };
                $btn_refresh->signal_connect(clicked => sub {
                    $CACHED_ICON_THEMES = undef; $CACHED_ICON_SCAN_TIME = 0;
                    my $themes_new = _enumerate_system_icon_themes();
                    if (my $par = eval { $combo_sys->get_parent }) {
                        my @chs = eval { $par->get_children };
                        for my $c (@chs) { my $nm = eval { $c->get_name } // ''; next unless $nm eq 'lblNoSystemIconThemes'; eval { $par->remove($c) }; eval { $c->destroy }; }
                    }
                    eval { $combo_sys->remove_text(0) while 1; };
                    $combo_sys->append_text('');
                    foreach my $t (@$themes_new) { $combo_sys->append_text($t); }
                    if (!$themes_new || !@$themes_new) {
                        if (my $par2 = eval { $combo_sys->get_parent }) {
                            my $lbl2 = Gtk3::Label->new('No system icon themes found in ~/.local/share/icons or /usr/share/icons');
                            $lbl2->set_name('lblNoSystemIconThemes');
                            PACWidgetUtils::safe_pack_start($par2, $lbl2, 0,0,6); $lbl2->show_all();
                        }
                    }
                });
                unless (_parent_has_child_named($parent,'btnRefreshSystemIconTheme')) { PACWidgetUtils::safe_pack_start($parent, $btn_refresh, 0,0,6); }
                $combo_sys->show_all();
                $btn_prev->show_all();
                $btn_refresh->show_all();
            }
        } else {
            # Theme changed away from 'system': remove dynamic system icon theme widgets scanning container
            if (my $combo_theme = eval { _($self,'comboTheme') }) {
                if (my $parent = eval { $combo_theme->get_parent }) {
                    my @children = eval { $parent->get_children };
                    for my $ch (@children) {
                        my $nm = eval { $ch->get_name } // '';
                        next unless $nm =~ /^(comboSystemIconTheme|btnPreviewSystemIconTheme|btnRefreshSystemIconTheme|lblThemeWarning|lblRestartHint|lblNoSystemIconThemes)$/;
                        eval { $parent->remove($ch) };
                        eval { $ch->destroy }; # finalize
                    }
                    delete $self->{_theme_warn_label};
                    delete $self->{_restart_hint_label};
                }
            }
        }
    }

    # Terminal Options
    _($self, 'spCfgTmoutConnect')->set_value($$cfg{'defaults'}{'timeout connect'});
    _($self, 'spCfgTmoutCommand')->set_value($$cfg{'defaults'}{'timeout command'});
    _($self, 'spCfgNewWindowWidth')->set_value($$cfg{'defaults'}{'terminal windows hsize'} // 800);
    _($self, 'spCfgNewWindowHeight')->set_value($$cfg{'defaults'}{'terminal windows vsize'} // 600);
    _($self, 'vboxCfgTabsOptions')->set_sensitive(_($self, 'cbCfgNewInTab')->get_active());
    _($self, 'hboxWidthHeight')->set_sensitive(_($self, 'cbCfgNewInWindow')->get_active());
    #_($self, 'hboxOnNoMoreTabs')->set_sensitive(_($self, 'cbCfgNewInTab')->get_active());
    _($self, 'spCfgTerminalScrollback')->set_value($$cfg{'defaults'}{'terminal scrollback lines'} // 5000);
    _($self, 'spCfgTerminalTransparency')->set_value($$cfg{'defaults'}{'terminal transparency'});
    _($self, 'cbCfgTerminalSupportTransparency')->set_active($$cfg{'defaults'}{'terminal support transparency'} // ($$cfg{'defaults'}{'terminal transparency'} > 0));
    _($self, 'spCfgTerminalTransparency')->set_sensitive(_($self, 'cbCfgTerminalSupportTransparency')->get_active());
    _($self, 'cbCfgExpectDebug')->set_active($$cfg{'defaults'}{'debug'});
    _($self, 'cbCfgStartMaximized')->set_active($$cfg{'defaults'}{'start maximized'});
    _($self, 'radioCfgTabsTop')->set_active($$cfg{'defaults'}{'tabs position'} eq 'top');
    _($self, 'radioCfgTabsBottom')->set_active($$cfg{'defaults'}{'tabs position'} eq 'bottom');
    _($self, 'radioCfgTabsLeft')->set_active($$cfg{'defaults'}{'tabs position'} eq 'left');
    _($self, 'radioCfgTabsRight')->set_active($$cfg{'defaults'}{'tabs position'} eq 'right');
    _($self, 'cbCfgCloseTermOnDisconn')->set_active($$cfg{'defaults'}{'close terminal on disconnect'});
    _($self, 'cbCfgNewInTab')->set_active($$cfg{'defaults'}{'open connections in tabs'} // 1);
    _($self, 'cbCfgNewInWindow')->set_active(! ($$cfg{'defaults'}{'open connections in tabs'} // 1) );
    _($self, 'rbCfgComBoxNever')->set_active(! $$cfg{'defaults'}{'show commands box'});
    _($self, 'rbCfgComBoxCombo')->set_active($$cfg{'defaults'}{'show commands box'} == 1);
    _($self, 'rbCfgComBoxButtons')->set_active($$cfg{'defaults'}{'show commands box'} == 2);
    _($self, 'cbCfgShowGlobalComm')->set_active($$cfg{'defaults'}{'show global commands box'});
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorText', 'text color', _($self, 'colorText')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBack', 'back color', _($self, 'colorBack')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBold', 'bold color', _($self, 'colorBold')->get_color()->to_string());
    _($self, 'colorBold')->set_sensitive(! _($self, 'cbBoldAsText')->get_active());
    _($self, 'chkBoldIsBrigth')->set_active($$cfg{'defaults'}{'bold is brigth'});
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorConnected', 'connected color', _($self, 'colorText')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorDisconnected', 'disconnected color', _($self, 'colorBlack')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorNewData', 'new data color', _($self, 'colorNewData')->get_color()->to_string());
    _($self, 'fontTerminal')->set_font_name($$cfg{'defaults'}{'terminal font'} // _($self, 'fontTerminal')->get_font_name());
    _($self, 'comboCursorShape')->set_active($self->{_CURSOR}{$$cfg{'defaults'}{'cursor shape'} // 'block'});
    _($self, 'cbCfgSaveSessionLogs')->set_active($$cfg{'defaults'}{'save session logs'});
    _($self, 'entryCfgLogFileName')->set_text($$cfg{'defaults'}{'session log pattern'});
    _($self, 'hboxCfgSaveSessionLogs')->set_sensitive($$cfg{'defaults'}{'save session logs'});
    _($self, 'btnCfgSaveSessionLogs')->set_current_folder($$cfg{'defaults'}{'session logs folder'});
    _($self, 'spCfgSaveSessionLogs')->set_value($$cfg{'defaults'}{'session logs amount'});
    _($self, 'cfgComboCharEncode')->set_active($self->{_ENCODINGS_MAP}{$$cfg{'defaults'}{'terminal character encoding'} // 'UTF-8'});
    my $desc = __($self->{_ENCODINGS_HASH}{$$cfg{'defaults'}{'terminal character encoding'}} // 'RFC-3629');
    _($self, 'cfgLblCharEncode')->set_markup("<span size='x-small'>$desc</span>");
    _($self, 'cfgComboBackspace')->set_active($$self{_BACKSPACE_BINDING}{$$cfg{'defaults'}{'terminal backspace'} // '0'});
    _($self, 'cbCfgUnsplitDisconnected')->set_active($$cfg{'defaults'}{'unsplit disconnected terminals'} // '0');
    _($self, 'cbCfgConfirmChains')->set_active($$cfg{'defaults'}{'confirm chains'} // 1);
    _($self, 'cbCfgSkip1stChainExpect')->set_active($$cfg{'defaults'}{'skip first chain expect'} // 1);
    _($self, 'cbCfgEnableTreeLines')->set_active($$cfg{'defaults'}{'enable tree lines'} // 0);
    _($self, 'cbCfgShowTreeTitles')->set_active($$cfg{'defaults'}{'show tree titles'} // 1);
    _($self, 'cbCfgEnableOverlayScrolling')->set_active($$cfg{'defaults'}{'tree overlay scrolling'} // 1);
    _($self, 'cbCfgShowStatistics')->set_active($$cfg{'defaults'}{'show statistics'} // 1);
    _($self, 'cbCfgHideConnSubMenu')->set_active($$cfg{'defaults'}{'hide connections submenu'});
    _($self, 'fontTree')->set_font_name($$cfg{'defaults'}{'tree font'});
    _($self, 'fontInfo')->set_font_name($$cfg{'defaults'}{'info font'});
    _($self, 'cbCfgAudibleBell')->set_active($$cfg{'defaults'}{'audible bell'});
    _($self, 'cbCfgShowTerminalStatus')->set_active($$cfg{'defaults'}{'terminal show status bar'});
    _($self, 'cbCfgChangeMainTitle')->set_active($$cfg{'defaults'}{'change main title'});

    # Terminal Colors
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBlack', 'color black', _($self, 'colorBlack')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorRed', 'color red', _($self, 'colorRed')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorGreen', 'color green', _($self, 'colorGreen')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorYellow', 'color yellow', _($self, 'colorYellow')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBlue', 'color blue', _($self, 'colorBlue')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorMagenta', 'color magenta', _($self, 'colorMagenta')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorCyan', 'color cyan', _($self, 'colorCyan')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorWhite', 'color white', _($self, 'colorWhite')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightBlack', 'color bright black', _($self, 'colorBrightBlack')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightRed', 'color bright red', _($self, 'colorBrightRed')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightGreen', 'color bright green', _($self, 'colorBrightGreen')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightYellow', 'color bright yellow', _($self, 'colorBrightYellow')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightBlue', 'color bright blue', _($self, 'colorBrightBlue')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightMagenta', 'color bright magenta', _($self, 'colorBrightMagenta')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightCyan', 'color bright cyan', _($self, 'colorBrightCyan')->get_color()->to_string());
    _updateWidgetColor($self, $$cfg{'defaults'}, 'colorBrightWhite', 'color bright white', _($self, 'colorBrightWhite')->get_color()->to_string());

    # Local Shell Options
    _($self, 'entryCfgShellBinary')->set_text($$cfg{'defaults'}{'shell binary'} || '/bin/bash');
    _($self, 'entryCfgShellOptions')->set_text($$cfg{'defaults'}{'shell options'});
    _($self, 'entryCfgShellDirectory')->set_text($$cfg{'defaults'}{'shell directory'});

    if (defined $$cfg{'defaults'}{'proxy'}) {
        if ($$cfg{'defaults'}{'proxy'} eq 'Jump') {
            _($self, 'cbCfgProxyJump')->set_active(1);
        } elsif ($$cfg{'defaults'}{'proxy'} eq 'Proxy') {
            _($self, 'cbCfgProxyManual')->set_active(1);
        } else {
            _($self, 'cbCfgProxyNo')->set_active(1);
        }
    } else {
        $$cfg{'defaults'}{'proxy'} = '';
        _($self, 'cbCfgProxyNo')->set_active(1);
    }
    # Proxy Configuration
    _($self, 'entryCfgProxyIP')->set_text($$cfg{'defaults'}{'proxy ip'});
    _($self, 'entryCfgProxyPort')->set_value(($$cfg{'defaults'}{'proxy port'} // 0) || 8080);
    _($self, 'entryCfgProxyUser')->set_text($$cfg{'defaults'}{'proxy user'});
    _($self, 'entryCfgProxyPassword')->set_text($$cfg{'defaults'}{'proxy pass'});

    # Jump Configuration
    _($self, 'entryCfgJumpIP')->set_text($$cfg{'defaults'}{'jump ip'} // '');
    _($self, 'entryCfgJumpPort')->set_value(($$cfg{'defaults'}{'jump port'} // 22) || 22);
    _($self, 'entryCfgJumpUser')->set_text($$cfg{'defaults'}{'jump user'} // '');
    _($self, 'entryCfgJumpPass')->set_text($$cfg{'defaults'}{'jump pass'} // '');
    if (($$cfg{'defaults'}{'proxy'} eq 'Jump')&&(defined $$self{_CFG}{'defaults'}{'jump key'})&&($$self{_CFG}{'defaults'}{'jump key'} ne '')) {
        _($self, 'entryCfgJumpKey')->set_uri("file://$$self{_CFG}{'defaults'}{'jump key'}");
    }

    # Disable options that are currently not used
    _($self, 'hboxPrefProxyManualOptions')->set_sensitive(_($self, 'cbCfgProxyManual')->get_active());
    _($self, 'vboxPrefJumpCfgOptions')->set_sensitive(_($self, 'cbCfgProxyJump')->get_active());

    # Global TABS
    $$self{_SHELL}->update($$self{_CFG}{'environments'}{'__PAC_SHELL__'}{'terminal options'});
    $$self{_VARIABLES}->update($$self{_CFG}{'defaults'}{'global variables'});
    $$self{_CMD_LOCAL}->update($$self{_CFG}{'defaults'}{'local commands'}, undef, 'local');
    $$self{_CMD_REMOTE}->update($$self{_CFG}{'defaults'}{'remote commands'}, undef, 'remote');
    $$self{_KEEPASS}->update($$self{_CFG}{'defaults'}{'keepass'});
    $$self{_KEYBINDS}->update($$self{_CFG}{'defaults'}{'keybindings'});
    $$self{_KEYBINDS}->LoadHotKeys($$self{_CFG});

    if (defined $PACMain::FUNCS{_EDIT}) {
        _($PACMain::FUNCS{_EDIT}, 'btnCheckKPX')->set_sensitive($$self{'_CFG'}{'defaults'}{'keepass'}{'use_keepass'});
    }

    # Hide show options not available on choosen layout
    if ($$cfg{'defaults'}{'layout'} eq 'Compact') {
        _($self, 'frameTabsInMainWindow')->hide();
        _($self, 'cbCfgStartMainMaximized')->hide();
        _($self, 'cbCfgRememberSize')->hide();
        _($self, 'cbCfgSaveOnExit')->hide();
        _($self, 'cbCfgCloseToTray')->hide();
        if ($$cfg{'defaults'}{'close to tray'} == 0) {
            # Force close to tray on Compact mode
            _($self, 'cbCfgCloseToTray')->set_active(1);
            $$cfg{'defaults'}{'close to tray'} = 1;
        }
        if (!$PACMain::STRAY) {
            _($self, 'cbCfgStartIconified')->hide();
        }
    }

    # Disable "save on exit" if "auto save" is enabled
    _updateSaveOnExit($self);

    # Update KeePass button
    _updateCfgProxyKeePass($self);

    return 1;
}

sub _closeConfiguration {
    my $self = shift;

    $$self{_WINDOWCONFIG}->hide();
}

sub _saveConfiguration {
    my $self = shift;

    my $old_theme = $$self{_CFG}{'defaults'}{'theme'};
    my $old_sys = $$self{_CFG}{'defaults'}{'system icon theme override'};

    # Increase and document config version changes
    $$self{_CFG}{'config version'} = 2;
    $$self{_CFG}{'config version change'} = 'Added keybindings settings';

    $$self{_CFG}{'defaults'}{'command prompt'} = _($self, 'entryCfgPrompt')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'username prompt'} = _($self, 'entryCfgUserPrompt')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'password prompt'} = _($self, 'entryCfgPasswordPrompt')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'hostkey changed prompt'} = _($self, 'entryCfgHostKeyVerification')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'press any key prompt'} = _($self, 'entryCfgPressAnyKey')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'sudo prompt'} = _($self, 'entryCfgSudoPrompt')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'sudo password'} = _($self, 'entryCfgSudoPassword')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'sudo show password'} = _($self, 'cbCfgShowSudoPassword')->get_active();
    $$self{_CFG}{'defaults'}{'remote host changed prompt'} = _($self, 'entryCfgRemoteHostChanged')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'timeout connect'} = _($self, 'spCfgTmoutConnect')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'timeout command'} = _($self, 'spCfgTmoutCommand')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'terminal windows hsize'} = _($self, 'spCfgNewWindowWidth')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'terminal windows vsize'} = _($self, 'spCfgNewWindowHeight')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'terminal scrollback lines'} = _($self, 'spCfgTerminalScrollback')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'terminal transparency'} = _($self, 'spCfgTerminalTransparency')->get_value();
    $$self{_CFG}{'defaults'}{'terminal transparency'} =~ s/,/\./go;
    $$self{_CFG}{'defaults'}{'terminal support transparency'} = _($self, 'cbCfgTerminalSupportTransparency')->get_active();
    $$self{_CFG}{'defaults'}{'terminal backspace'} = _($self, 'cfgComboBackspace')->get_active_text();
    $$self{_CFG}{'defaults'}{'auto accept key'} = _($self, 'cbCfgAutoAcceptKeys')->get_active();
    $$self{_CFG}{'defaults'}{'debug'} = _($self, 'cbCfgExpectDebug')->get_active();
    $$self{_CFG}{'defaults'}{'use bw icon'} = _($self, 'cbCfgBWTrayIcon')->get_active();
    $$self{_CFG}{'defaults'}{'close to tray'} = _($self, 'cbCfgCloseToTray')->get_active();
    $$self{_CFG}{'defaults'}{'show screenshots'} = _($self, 'cbCfgSaveShowScreenshots')->get_active();
    $$self{_CFG}{'defaults'}{'tabs in main window'} = _($self, 'cbCfgTabsInMain')->get_active();
    $$self{_CFG}{'defaults'}{'auto hide connections list'} = _($self, 'cbCfgConnectionsAutoHide')->get_active();
    $$self{_CFG}{'defaults'}{'auto hide button bar'} = _($self, 'cbCfgButtonBarAutoHide')->get_active();
    $$self{_CFG}{'defaults'}{'info in status bar'} = _($self, 'cbCfgStatusBar')->get_active();
    $$self{_CFG}{'defaults'}{'forwarding short names'} = _($self, 'rbCfgStatusShort')->get_active();
    $$self{_CFG}{'defaults'}{'forwarding full names'} = _($self, 'rbCfgStatusFull')->get_active();
    $$self{_CFG}{'defaults'}{'hide on connect'} = _($self, 'cbCfgHideOnConnect')->get_active();
    $$self{_CFG}{'defaults'}{'force split tabs to 50%'} = _($self, 'cbCfgForceSplitSize')->get_active();
    $$self{_CFG}{'defaults'}{'start iconified'} = _($self, 'cbCfgStartIconified')->get_active();
    $$self{_CFG}{'defaults'}{'start maximized'} = _($self, 'cbCfgStartMaximized')->get_active();
    $$self{_CFG}{'defaults'}{'start main maximized'} = _($self, 'cbCfgStartMainMaximized')->get_active();
    $$self{_CFG}{'defaults'}{'remember main size'} = _($self, 'cbCfgRememberSize')->get_active();
    $$self{_CFG}{'defaults'}{'save on exit'} = _($self, 'cbCfgSaveOnExit')->get_active();
    $$self{_CFG}{'defaults'}{'auto save'} = _($self, 'cbCfgAutoSave')->get_active();
    if (_($self, 'cbCfgProxyManual')->get_active()) {
        $$self{_CFG}{'defaults'}{'proxy'} = 'Proxy';
        $$self{_CFG}{'defaults'}{'jump key'} = '';
    } elsif (_($self, 'cbCfgProxyJump')->get_active()) {
        $$self{_CFG}{'defaults'}{'proxy'} = 'Jump';
    } else {
        $$self{_CFG}{'defaults'}{'proxy'} = 'No';
        $$self{_CFG}{'defaults'}{'jump key'} = '';
    }
    # SOCKS PROXY
    $$self{_CFG}{'defaults'}{'proxy ip'} = _($self, 'entryCfgProxyIP')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'proxy port'} = _($self, 'entryCfgProxyPort')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'proxy user'} = _($self, 'entryCfgProxyUser')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'proxy pass'} = _($self, 'entryCfgProxyPassword')->get_chars(0, -1);
    # JUMP SERVER
    $$self{_CFG}{'defaults'}{'jump ip'} = _($self, 'entryCfgJumpIP')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'jump port'} = _($self, 'entryCfgJumpPort')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'jump user'} = _($self, 'entryCfgJumpUser')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'jump pass'} = _($self, 'entryCfgJumpPass')->get_chars(0, -1);

    # Remove un used settings in network settings to avoid unexpected conflicts
    if ($$self{_CFG}{'defaults'}{'proxy'} eq 'No') {
        $$self{_CFG}{'defaults'}{'proxy ip'} = '';
        $$self{_CFG}{'defaults'}{'proxy user'} = '';
        $$self{_CFG}{'defaults'}{'proxy pass'} = '';
        $$self{_CFG}{'defaults'}{'jump ip'} = '';
        $$self{_CFG}{'defaults'}{'jump user'} = '';
        $$self{_CFG}{'defaults'}{'jump pass'} = '';
    } elsif ($$self{_CFG}{'defaults'}{'proxy'} eq 'Proxy') {
        $$self{_CFG}{'defaults'}{'jump ip'} = '';
        $$self{_CFG}{'defaults'}{'jump user'} = '';
        $$self{_CFG}{'defaults'}{'jump pass'} = '';
    } elsif ($$self{_CFG}{'defaults'}{'proxy'} eq 'Jump') {
        $$self{_CFG}{'defaults'}{'proxy ip'} = '';
        $$self{_CFG}{'defaults'}{'proxy user'} = '';
        $$self{_CFG}{'defaults'}{'proxy pass'} = '';
    }


    $$self{_CFG}{'defaults'}{'shell binary'} = _($self, 'entryCfgShellBinary')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'shell options'} = _($self, 'entryCfgShellOptions')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'shell directory'} = _($self, 'entryCfgShellDirectory')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'tabs position'} = 'top'    if _($self, 'radioCfgTabsTop')->get_active();
    $$self{_CFG}{'defaults'}{'tabs position'} = 'bottom' if _($self, 'radioCfgTabsBottom')->get_active();
    $$self{_CFG}{'defaults'}{'tabs position'} = 'left'   if _($self, 'radioCfgTabsLeft')->get_active();
    $$self{_CFG}{'defaults'}{'tabs position'} = 'right'  if _($self, 'radioCfgTabsRight')->get_active();
    $$self{_CFG}{'defaults'}{'close terminal on disconnect'} = _($self, 'cbCfgCloseTermOnDisconn')->get_active();
    $$self{_CFG}{'defaults'}{'open connections in tabs'} = _($self, 'cbCfgNewInTab')->get_active();
    $$self{_CFG}{'defaults'}{'text color'} = _($self, 'colorText')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'back color'} = _($self, 'colorBack')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'bold color'} = _($self, 'colorBold')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'bold color like text'} = _($self, 'cbBoldAsText')->get_active();
    $$self{_CFG}{'defaults'}{'bold is brigth'} = _($self, 'chkBoldIsBrigth')->get_active();
    $$self{_CFG}{'defaults'}{'connected color'} = _($self, 'colorConnected')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'disconnected color'} = _($self, 'colorDisconnected')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'new data color'} = _($self, 'colorNewData')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'terminal font'} = _($self, 'fontTerminal')->get_font_name();
    $$self{_CFG}{'defaults'}{'cursor shape'} = _($self, 'comboCursorShape')->get_active_text();
    $$self{_CFG}{'defaults'}{'save session logs'} = _($self, 'cbCfgSaveSessionLogs')->get_active();
    $$self{_CFG}{'defaults'}{'session log pattern'} = _($self, 'entryCfgLogFileName')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'session logs folder'} = _($self, 'btnCfgSaveSessionLogs')->get_current_folder();
    $$self{_CFG}{'defaults'}{'session logs amount'} = _($self, 'spCfgSaveSessionLogs')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'confirm exit'} = _($self, 'cbCfgConfirmExit')->get_active();
    $$self{_CFG}{'defaults'}{'screenshots use external viewer'} = ! _($self, 'rbCfgInternalViewer')->get_active();
    $$self{_CFG}{'defaults'}{'screenshots external viewer'} = _($self, 'entryCfgExternalViewer')->get_chars(0, -1);
    $$self{_CFG}{'defaults'}{'terminal character encoding'} = _($self, 'cfgComboCharEncode')->get_active_text();
    $$self{_CFG}{'defaults'}{'word characters'} = _($self, 'entryCfgSelectByWordChars')->get_chars(0, -1);
    if (_($self, 'rbCfgComBoxNever')->get_active()) {
        $$self{_CFG}{'defaults'}{'show commands box'} = 0;
    } elsif (_($self, 'rbCfgComBoxCombo')->get_active()) {
        $$self{_CFG}{'defaults'}{'show commands box'} = 1;
    } elsif (_($self, 'rbCfgComBoxButtons')->get_active()) {
        $$self{_CFG}{'defaults'}{'show commands box'} = 2;
    }
    $$self{_CFG}{'defaults'}{'show global commands box'} = _($self, 'cbCfgShowGlobalComm')->get_active();
    $$self{_CFG}{'defaults'}{'show tray icon'} = _($self, 'cbCfgShowTrayIcon')->get_active();
    $$self{_CFG}{'defaults'}{'unsplit disconnected terminals'} = _($self, 'cbCfgUnsplitDisconnected')->get_active();
    $$self{_CFG}{'defaults'}{'confirm chains'} = _($self, 'cbCfgConfirmChains')->get_active();
    $$self{_CFG}{'defaults'}{'skip first chain expect'} = _($self, 'cbCfgSkip1stChainExpect')->get_active();
    $$self{_CFG}{'defaults'}{'enable tree lines'} = _($self, 'cbCfgEnableTreeLines')->get_active();
    $$self{_CFG}{'defaults'}{'show tree titles'} = _($self, 'cbCfgShowTreeTitles')->get_active();
    $$self{_CFG}{'defaults'}{'tree overlay scrolling'} = _($self, 'cbCfgEnableOverlayScrolling')->get_active();
    #DevNote: option currently disabled
    #$$self{_CFG}{'defaults'}{'check versions at start'} = _($self, 'cbCfgCheckVersions')->get_active();
    $$self{_CFG}{'defaults'}{'show statistics'} = _($self, 'cbCfgShowStatistics')->get_active();

    $$self{_CFG}{'defaults'}{'unprotected set'} = _($self, 'rbCfgUnForeground')->get_active() ? 'foreground' : 'background' ;
    $$self{_CFG}{'defaults'}{'unprotected color'} = _($self, 'colorCfgUnProtected')->get_color()->to_string();

    $$self{_CFG}{'defaults'}{'protected set'} = _($self, 'rbCfgForeground')->get_active() ? 'foreground' : 'background' ;
    $$self{_CFG}{'defaults'}{'protected color'} = _($self, 'colorCfgProtected')->get_color()->to_string();

    $$self{_CFG}{'defaults'}{'use gui password'} = _($self, 'cbCfgUseGUIPassword')->get_active();
    $$self{_CFG}{'defaults'}{'use gui password tray'} = _($self, 'cbCfgUseGUIPasswordTray')->get_active();
    $$self{_CFG}{'defaults'}{'autostart shell upon PAC start'} = _($self, 'cbCfgAutoStartShell')->get_active();
    $$self{_CFG}{'defaults'}{'tree on right side'} = _($self, 'cbCfgTreeOnRight')->get_active();
    $$self{_CFG}{'defaults'}{'prevent mouse over show tree'} = ! _($self, 'cbCfgPreventMOShowTree')->get_active();
    $$self{_CFG}{'defaults'}{'show connections tooltips'} = _($self, 'cbCfgShowTreeTooltips')->get_active();
    $$self{_CFG}{'defaults'}{'hide connections submenu'} = _($self, 'cbCfgHideConnSubMenu')->get_active();
    $$self{_CFG}{'defaults'}{'tree font'} = _($self, 'fontTree')->get_font_name();
    $$self{_CFG}{'defaults'}{'info font'} = _($self, 'fontInfo')->get_font_name();
    $$self{_CFG}{'defaults'}{'use login shell to connect'} = _($self, 'cbCfgUseShellToConnect')->get_active();
    $$self{_CFG}{'defaults'}{'audible bell'} = _($self, 'cbCfgAudibleBell')->get_active();
    $$self{_CFG}{'defaults'}{'terminal show status bar'} = _($self, 'cbCfgShowTerminalStatus')->get_active();
    $$self{_CFG}{'defaults'}{'change main title'} = _($self, 'cbCfgChangeMainTitle')->get_active();
    $$self{_CFG}{'defaults'}{'when no more tabs'} = _($self, 'rbOnNoTabsNothing')->get_active() ? 'last' : 'next';
    $$self{_CFG}{'defaults'}{'selection to clipboard'} = _($self, 'cbCfgSelectionToClipboard')->get_active();
    $$self{_CFG}{'defaults'}{'remove control chars'} = _($self, 'cbCfgRemoveCtrlCharsConf')->get_active();
    $$self{_CFG}{'defaults'}{'log timestamp'} = _($self, 'cbCfgLogTimestam')->get_active();
    $$self{_CFG}{'defaults'}{'allow more instances'} = _($self, 'cbCfgAllowMoreInstances')->get_active();
    $$self{_CFG}{'defaults'}{'show favourites in unity'} = _($self, 'cbCfgShowFavOnUnity')->get_active();
    $$self{_CFG}{'defaults'}{'layout'} = _($self, 'comboLayout')->get_active_text();
    $$self{_CFG}{'defaults'}{'theme'} = _($self, 'comboTheme')->get_active_text();
    if ($$self{_CFG}{'defaults'}{'theme'} eq 'system') {
        my $combo_sys = eval { _($self, 'comboSystemIconTheme') };
        if ($combo_sys) {
            my $txt = $combo_sys->get_active_text // '';
            $txt =~ s/^\s+|\s+$//g;
            if ($txt ne '') { $$self{_CFG}{'defaults'}{'system icon theme override'} = $txt; }
            else { delete $$self{_CFG}{'defaults'}{'system icon theme override'}; }
            if ($txt ne '' && !_validate_system_icon_theme($txt)) {
                _show_theme_warning($self, "Icon theme '$txt' not found (will fall back)." );
            }
        } else { delete $$self{_CFG}{'defaults'}{'system icon theme override'}; }
    } else {
        delete $$self{_CFG}{'defaults'}{'system icon theme override'};
    }

    # Terminal colors
    $$self{_CFG}{'defaults'}{'color black'} = _($self, 'colorBlack')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color red'} = _($self, 'colorRed')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color green'} = _($self, 'colorGreen')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color yellow'} = _($self, 'colorYellow')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color blue'} = _($self, 'colorBlue')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color magenta'} = _($self, 'colorMagenta')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color cyan'} = _($self, 'colorCyan')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color white'} = _($self, 'colorWhite')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright black'} = _($self, 'colorBrightBlack')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright red'} = _($self, 'colorBrightRed')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright green'} = _($self, 'colorBrightGreen')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright yellow'} = _($self, 'colorBrightYellow')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright blue'} = _($self, 'colorBrightBlue')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright magenta'} = _($self, 'colorBrightMagenta')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright cyan'} = _($self, 'colorBrightCyan')->get_color()->to_string();
    $$self{_CFG}{'defaults'}{'color bright white'} = _($self, 'colorBrightWhite')->get_color()->to_string();

    if (_($self, 'rbOnNoTabsNothing')->get_active()) {
        $$self{_CFG}{'defaults'}{'when no more tabs'} = 0;
    } elsif (_($self, 'rbOnNoTabsClose')->get_active()) {
        $$self{_CFG}{'defaults'}{'when no more tabs'} = 1;
    } else {
        $$self{_CFG}{'defaults'}{'when no more tabs'} = 2;
    }

    if (_($self, 'rbCfgStartTreeConn')->get_active()) {
        $$self{_CFG}{'defaults'}{'start PAC tree on'} = 'connections';
    }
    if (_($self, 'rbCfgStartTreeFavs')->get_active()) {
        $$self{_CFG}{'defaults'}{'start PAC tree on'} = 'favourites';
    }
    if (_($self, 'rbCfgStartTreeHist')->get_active()) {
        $$self{_CFG}{'defaults'}{'start PAC tree on'} = 'history';
    }
    if (_($self, 'rbCfgStartTreeCluster')->get_active()) {
        $$self{_CFG}{'defaults'}{'start PAC tree on'} = 'clusters';
    }

    unlink("$ENV{'HOME'}/.config/autostart/asbru_start.desktop");
    $$self{_CFG}{'defaults'}{'start at session startup'} = 0;
    if (_($self, 'cbCfgAutoStart')->get_active()) {
        my $autostart_dir = "$ENV{HOME}/.config/autostart";

        $PACUtils::PACDESKTOP[6] = 'Exec=env GDK_BACKEND=x11 /usr/bin/asbru-cm --no-splash' . ($$self{_CFG}{'defaults'}{'start iconified'} ? ' --iconified' : '');
        if (!-e $autostart_dir) {
            mkdir($autostart_dir);
        }
        if (-d $autostart_dir) {
            open(F, ">:utf8", "$autostart_dir/asbru_start.desktop");
            print F join("\n", @PACUtils::PACDESKTOP);
            close F;
            $$self{_CFG}{'defaults'}{'start at session startup'} = 1;
        } else {
            print("ERROR: Unable to create autostart directory [$autostart_dir]\n");
        }
    }

    # Save the global variables tab options
    $$self{_CFG}{'environments'}{'__PAC_SHELL__'}{'terminal options'} = $$self{_SHELL}->get_cfg();
    # Save the global variables tab options
    $$self{_CFG}{'defaults'}{'global variables'} = $$self{_VARIABLES}->get_cfg();
    # Save the global local commands tab options
    $$self{_CFG}{'defaults'}{'local commands'} = $$self{_CMD_LOCAL}->get_cfg();
    # Save the global remote commands tab options
    $$self{_CFG}{'defaults'}{'remote commands'} = $$self{_CMD_REMOTE}->get_cfg();
    # Save KeePass options
    $$self{_CFG}{'defaults'}{'keepass'} = $$self{_KEEPASS}->get_cfg(1);
    # Save KeyBindings options
    $$self{_CFG}{'defaults'}{'keybindings'} = $$self{_KEYBINDS}->get_cfg();

    $PACMain::FUNCS{_MAIN}->_setCFGChanged(1);
    $self->_updateGUIPreferences();

    $PACMain::FUNCS{_MAIN}->_updateGUIPreferences();
    # Refresh only when theme or override changed
    my $changed = ($old_theme // '') ne ($$self{_CFG}{'defaults'}{'theme'} // '') || ($old_sys // '') ne ($$self{_CFG}{'defaults'}{'system icon theme override'} // '');
    if ($changed) { eval { $PACMain::FUNCS{_MAIN}->_refresh_all_icons(); }; }
    if ($changed) {
        _show_restart_hint($self);
    }

    # Send a signal to every started terminal for this $uuid to realize the new global CFG
    map {eval {$$_{'terminal'}->_updateCFG;};} (values %PACMain::RUNNING);

    return 1;
}

sub _updateSaveOnExit {
    my $self = shift;

    _($self, 'cbCfgSaveOnExit')->set_sensitive(!_($self, 'cbCfgAutoSave')->get_active());
}

sub _updateCfgProxyKeePass {
    my $self = shift;

    _($self, 'btnCfgProxyCheckKPX')->set_sensitive($$self{'_CFG'}{'defaults'}{'keepass'}{'use_keepass'} && !_($self, 'cbCfgProxyNo')->get_active());
}

# END: Define PRIVATE CLASS functions
###################################################################

# Enumerate available system icon themes (simple directory scan)
sub _enumerate_system_icon_themes {
    # Re-scan at most every 60 seconds
    if ($CACHED_ICON_THEMES && (time - $CACHED_ICON_SCAN_TIME) < 60) {
        return $CACHED_ICON_THEMES;
    }
    my @dirs = ("$ENV{HOME}/.local/share/icons", '/usr/share/icons');
    my %themes;
    for my $d (@dirs) {
        next unless -d $d;
        opendir(my $dh, $d) or next;
        while (my $entry = readdir($dh)) {
            next if $entry =~ /^\./;
            my $path = "$d/$entry";
            next unless -d $path;
            if (-f "$path/index.theme") { $themes{$entry} = 1; }
        }
        closedir $dh;
    }
    my @list = sort grep { $_ !~ /cursor/i } keys %themes;
    $CACHED_ICON_THEMES = \@list; $CACHED_ICON_SCAN_TIME = time;
    return $CACHED_ICON_THEMES;
}

sub _validate_system_icon_theme {
    my ($name) = @_;
    return 1 unless defined $name && length $name;
    my @dirs = ("$ENV{HOME}/.local/share/icons", '/usr/share/icons');
    for my $d (@dirs) { return 1 if -f "$d/$name/index.theme"; }
    return 0;
}

sub _show_theme_warning {
    my ($self, $msg) = @_;
    my $parent = eval { _($self, 'comboTheme')->get_parent } or return;
    # Reuse existing label if present
    if (!$self->{_theme_warn_label}) {
        my $lbl = Gtk3::Label->new();
        $lbl->set_name('lblThemeWarning');
        $lbl->set_halign('start');
        PACWidgetUtils::safe_pack_start($parent, $lbl, 0,0,6);
        $lbl->show_all();
        $self->{_theme_warn_label} = $lbl;
    }
    $self->{_theme_warn_label}->set_markup('<span foreground="orange" size="small">' . Glib::Markup::escape_text($msg) . '</span>');
    # Auto-clear after 6 seconds
    Glib::Timeout->add(6000, sub { if ($self->{_theme_warn_label}) { $self->{_theme_warn_label}->set_text(''); } 0; });
}

sub _show_restart_hint {
    my ($self) = @_;
    my $parent = eval { _($self, 'comboTheme')->get_parent } or return;
    if (!$self->{_restart_hint_label}) {
        my $lbl = Gtk3::Label->new();
        $lbl->set_name('lblRestartHint');
        $lbl->set_halign('start');
        PACWidgetUtils::safe_pack_start($parent, $lbl, 0,0,6);
        $lbl->show_all();
        $self->{_restart_hint_label} = $lbl;
    }
    $self->{_restart_hint_label}->set_markup('<span foreground="steelblue" size="small">Some icons may require restart to fully update.</span>');
}

# After global vars, inject utility (idempotent) to guard duplicate packing
our $_PACCONFIG__HAVE_WIDGET_BY_NAME ||= 1;
sub _parent_has_child_named {
    my ($parent,$name)=@_;
    return 0 unless $parent && $parent->can('get_children');
    my @chs = eval { $parent->get_children };
    for my $c (@chs){
        my $nm = eval { $c->get_name } // ''; return 1 if $nm eq $name;
    }
    return 0;
}

###################################################################
# START: Multithreaded Configuration Import Functions

=head2 _importConfigurationAsync($config_file, $progress_callback)

Implements asynchronous configuration processing using threads.
Creates a thread-safe configuration processing pipeline with progress tracking.

=cut

sub _importConfigurationAsync {
    my ($self, $config_file, $progress_callback) = @_;
    
    # Validate inputs
    return 0 unless defined $config_file && -f $config_file;
    return 0 unless defined $progress_callback && ref $progress_callback eq 'CODE';
    
    # Load required modules for threading
    eval {
        require threads;
        require Thread::Queue;
        require threads::shared;
    };
    if ($@) {
        warn "Threading modules not available: $@";
        # Fallback to synchronous processing
        return $self->_importConfigurationSync($config_file, $progress_callback);
    }
    
    my $queue = Thread::Queue->new();
    my $error_queue = Thread::Queue->new();
    
    # Create worker thread for configuration processing
    my $worker_thread = threads->create(sub {
        eval {
            # Count total items for progress tracking
            my $total_items = $self->_countConfigItems($config_file);
            $queue->enqueue({
                type => 'total',
                total => $total_items
            });
            
            my $processed = 0;
            
            # Process configuration in chunks for better performance
            my $chunk_size = 50; # Process 50 items at a time
            
            while (my $chunk = $self->_getNextConfigChunk($config_file, $chunk_size, $processed)) {
                last unless @$chunk; # No more chunks
                
                # Process this chunk
                my $chunk_result = $self->_processConfigChunk($chunk);
                
                if ($chunk_result) {
                    $processed += scalar(@$chunk);
                    $queue->enqueue({
                        type => 'progress',
                        processed => $processed,
                        total => $total_items,
                        chunk_size => scalar(@$chunk)
                    });
                } else {
                    $error_queue->enqueue("Failed to process configuration chunk");
                    last;
                }
                
                # Small delay to prevent overwhelming the system
                select(undef, undef, undef, 0.01);
            }
            
            $queue->enqueue({ type => 'complete' });
        };
        
        if ($@) {
            $error_queue->enqueue("Configuration processing error: $@");
            $queue->enqueue({ type => 'error', message => $@ });
        }
    });
    
    # Set up UI thread processing of queue updates
    my $timeout_id = Glib::Timeout->add(100, sub {
        # Process progress updates
        while (defined(my $msg = $queue->dequeue_nb())) {
            if ($msg->{type} eq 'progress') {
                $progress_callback->($msg->{processed}, $msg->{total});
            } elsif ($msg->{type} eq 'total') {
                $progress_callback->(0, $msg->{total});
            } elsif ($msg->{type} eq 'complete') {
                $worker_thread->join();
                return 0; # Remove timeout
            } elsif ($msg->{type} eq 'error') {
                warn "Configuration import error: " . $msg->{message};
                $worker_thread->join();
                return 0; # Remove timeout
            }
        }
        
        # Check for errors
        while (defined(my $error = $error_queue->dequeue_nb())) {
            warn "Configuration import error: $error";
        }
        
        return 1; # Continue timeout
    });
    
    return 1;
}

=head2 _importConfigurationSync($config_file, $progress_callback)

Fallback synchronous configuration processing for systems without threading support.

=cut

sub _importConfigurationSync {
    my ($self, $config_file, $progress_callback) = @_;
    
    eval {
        my $total_items = $self->_countConfigItems($config_file);
        $progress_callback->(0, $total_items);
        
        my $processed = 0;
        my $chunk_size = 50;
        
        while (my $chunk = $self->_getNextConfigChunk($config_file, $chunk_size, $processed)) {
            last unless @$chunk;
            
            $self->_processConfigChunk($chunk);
            $processed += scalar(@$chunk);
            
            $progress_callback->($processed, $total_items);
            
            # Process pending GTK events to keep UI responsive
            while (Gtk3::events_pending) {
                Gtk3::main_iteration;
            }
        }
        
        return 1;
    };
    
    if ($@) {
        warn "Synchronous configuration import error: $@";
        return 0;
    }
}

=head2 _countConfigItems($config_file)

Counts the total number of configuration items for progress tracking.

=cut

sub _countConfigItems {
    my ($self, $config_file) = @_;
    
    return 0 unless -f $config_file;
    
    my $count = 0;
    
    eval {
        # Load configuration to count items
        my $config = PACConfigData::load_config($config_file);
        return 0 unless $config;
        
        # Count environments (connections and groups)
        if (exists $config->{environments} && ref $config->{environments} eq 'HASH') {
            $count += scalar(keys %{$config->{environments}});
        }
        
        # Count global variables
        if (exists $config->{defaults}{'global variables'} && 
            ref $config->{defaults}{'global variables'} eq 'HASH') {
            $count += scalar(keys %{$config->{defaults}{'global variables'}});
        }
        
        # Count other configuration sections
        $count += 10; # Approximate for other settings
    };
    
    if ($@) {
        warn "Error counting configuration items: $@";
        return 100; # Default estimate
    }
    
    return $count || 1; # Ensure at least 1 to avoid division by zero
}

=head2 _getNextConfigChunk($config_file, $chunk_size, $offset)

Gets the next chunk of configuration items for processing.

=cut

sub _getNextConfigChunk {
    my ($self, $config_file, $chunk_size, $offset) = @_;
    
    $chunk_size ||= 50;
    $offset ||= 0;
    
    # This is a simplified implementation
    # In a real scenario, you would implement proper chunking based on the config structure
    
    # Use package variables for persistence across calls
    our $config_data;
    our $all_items;
    
    # Load config data once
    unless ($config_data) {
        eval {
            $config_data = PACConfigData::load_config($config_file);
            
            # Flatten all items into a processable array
            $all_items = [];
            
            if ($config_data && ref $config_data eq 'HASH') {
                # Add environment items
                if (exists $config_data->{environments}) {
                    foreach my $uuid (keys %{$config_data->{environments}}) {
                        push @$all_items, {
                            type => 'environment',
                            uuid => $uuid,
                            data => $config_data->{environments}{$uuid}
                        };
                    }
                }
                
                # Add global variables
                if (exists $config_data->{defaults}{'global variables'}) {
                    foreach my $var (keys %{$config_data->{defaults}{'global variables'}}) {
                        push @$all_items, {
                            type => 'global_variable',
                            name => $var,
                            data => $config_data->{defaults}{'global variables'}{$var}
                        };
                    }
                }
                
                # Add other settings as single items
                push @$all_items, {
                    type => 'defaults',
                    data => $config_data->{defaults}
                };
            }
        };
        
        if ($@) {
            warn "Error loading configuration for chunking: $@";
            return [];
        }
    }
    
    return [] unless $all_items && @$all_items;
    
    # Return the requested chunk
    my $end_index = $offset + $chunk_size - 1;
    $end_index = $#$all_items if $end_index > $#$all_items;
    
    return [] if $offset > $#$all_items;
    
    my @chunk = @$all_items[$offset..$end_index];
    return \@chunk;
}

=head2 _processConfigChunk($chunk)

Processes a chunk of configuration items with error handling.

=cut

sub _processConfigChunk {
    my ($self, $chunk) = @_;
    
    return 0 unless $chunk && ref $chunk eq 'ARRAY';
    
    eval {
        foreach my $item (@$chunk) {
            next unless $item && ref $item eq 'HASH';
            
            if ($item->{type} eq 'environment') {
                $self->_processEnvironmentItem($item->{uuid}, $item->{data});
            } elsif ($item->{type} eq 'global_variable') {
                $self->_processGlobalVariableItem($item->{name}, $item->{data});
            } elsif ($item->{type} eq 'defaults') {
                $self->_processDefaultsItem($item->{data});
            }
        }
        
        return 1;
    };
    
    if ($@) {
        warn "Error processing configuration chunk: $@";
        return 0;
    }
}

=head2 _processEnvironmentItem($uuid, $data)

Processes a single environment (connection/group) item.

=cut

sub _processEnvironmentItem {
    my ($self, $uuid, $data) = @_;
    
    return unless $uuid && $data;
    
    # Validate and sanitize the environment data
    if (ref $data eq 'HASH') {
        # Ensure required fields exist
        $data->{name} ||= "Connection $uuid";
        $data->{method} ||= 'ssh';
        
        # Store in main configuration
        $self->{_CFG}{environments}{$uuid} = PACConfigData::clone_data($data);
    }
}

=head2 _processGlobalVariableItem($name, $data)

Processes a single global variable item.

=cut

sub _processGlobalVariableItem {
    my ($self, $name, $data) = @_;
    
    return unless $name && $data;
    
    # Store global variable
    $self->{_CFG}{defaults}{'global variables'}{$name} = PACConfigData::clone_data($data);
}

=head2 _processDefaultsItem($data)

Processes default configuration settings.

=cut

sub _processDefaultsItem {
    my ($self, $data) = @_;
    
    return unless $data && ref $data eq 'HASH';
    
    # Merge defaults, preserving existing settings
    foreach my $key (keys %$data) {
        next if $key eq 'global variables'; # Handled separately
        $self->{_CFG}{defaults}{$key} = PACConfigData::clone_data($data->{$key});
    }
}

# END: Multithreaded Configuration Import Functions
###################################################################

###################################################################
# START: Theme-aware Progress Window Functions

=head2 _createProgressWindow($title, $message)

Creates a theme-aware progress window using PACCompat for GTK3/GTK4 compatibility.
Applies appropriate styling for dark/light modes.

=cut

sub _createProgressWindow {
    my ($self, $title, $message) = @_;
    
    $title ||= "Processing Configuration";
    $message ||= "Please wait while configuration is being processed...";
    
    # Create main window
    my $window = PACCompat::create_window('toplevel', $title);
    $window->set_default_size(400, 150);
    $window->set_position('center');
    $window->set_modal(1);
    $window->set_resizable(0);
    $window->set_deletable(0);
    
    # Set parent window if available
    if ($self->{_WINDOWCONFIG}) {
        $window->set_transient_for($self->{_WINDOWCONFIG});
    }
    
    # Create main container
    my $vbox = PACCompat::create_box('vertical', 10);
    $vbox->set_border_width(20);
    $window->add($vbox);
    
    # Create message label
    my $label = PACCompat::create_label($message);
    $label->set_line_wrap(1);
    $label->set_justify('center');
    $vbox->pack_start($label, 0, 0, 0);
    
    # Create progress bar
    my $progress_bar = PACCompat::create_progress_bar();
    $progress_bar->set_show_text(1);
    $progress_bar->set_text("Initializing...");
    $vbox->pack_start($progress_bar, 0, 0, 10);
    
    # Create status label for detailed information
    my $status_label = PACCompat::create_label("");
    $status_label->set_line_wrap(1);
    $status_label->set_justify('center');
    $vbox->pack_start($status_label, 0, 0, 0);
    
    # Apply theme-appropriate styling
    $self->_applyProgressWindowTheme($window, $vbox, $label, $progress_bar, $status_label);
    
    # Show all widgets
    $window->show_all();
    
    # Process pending events to ensure window is displayed
    while (Gtk3::events_pending) {
        Gtk3::main_iteration;
    }
    
    return {
        window => $window,
        progress_bar => $progress_bar,
        status_label => $status_label,
        message_label => $label
    };
}

=head2 _applyProgressWindowTheme($window, $vbox, $label, $progress_bar, $status_label)

Applies theme-aware styling to progress window components.

=cut

sub _applyProgressWindowTheme {
    my ($self, $window, $vbox, $label, $progress_bar, $status_label) = @_;
    
    eval {
        # Detect current theme
        my ($theme_name, $prefer_dark) = $self->_detectSystemTheme();
        
        # Create CSS provider
        my $css_provider = PACCompat::create_css_provider();
        
        my $css_content;
        if ($prefer_dark) {
            # Dark theme styling
            $css_content = qq{
                window {
                    background-color: #2d2d2d;
                    color: #ffffff;
                }
                
                label {
                    color: #ffffff;
                }
                
                progressbar {
                    background-color: #404040;
                }
                
                progressbar progress {
                    background-color: #4a90d9;
                }
                
                progressbar trough {
                    background-color: #404040;
                    border: 1px solid #555555;
                }
            };
        } else {
            # Light theme styling
            $css_content = qq{
                window {
                    background-color: #ffffff;
                    color: #000000;
                }
                
                label {
                    color: #000000;
                }
                
                progressbar {
                    background-color: #f0f0f0;
                }
                
                progressbar progress {
                    background-color: #4a90d9;
                }
                
                progressbar trough {
                    background-color: #f0f0f0;
                    border: 1px solid #cccccc;
                }
            };
        }
        
        # Load CSS
        $css_provider->load_from_data($css_content);
        
        # Apply CSS to widgets
        my @widgets = ($window, $vbox, $label, $progress_bar, $status_label);
        foreach my $widget (@widgets) {
            next unless $widget;
            my $context = $widget->get_style_context();
            $context->add_provider($css_provider, PACCompat::STYLE_PROVIDER_PRIORITY_APPLICATION());
        }
        
    };
    
    if ($@) {
        warn "Failed to apply progress window theme: $@";
        # Continue without custom styling
    }
}

=head2 _detectSystemTheme()

Detects the current system theme and dark mode preference.
Returns theme name and dark mode boolean.

=cut

sub _detectSystemTheme {
    my $self = shift;
    
    my $theme_name = 'default';
    my $prefer_dark = 0;
    
    eval {
        # Try to get GTK settings
        my $settings = PACCompat::get_default_settings();
        
        if ($settings) {
            $theme_name = $settings->get_property('gtk-theme-name') || 'default';
            $prefer_dark = $settings->get_property('gtk-application-prefer-dark-theme') || 0;
        }
        
        # Additional dark theme detection
        if (!$prefer_dark) {
            # Check if theme name suggests dark theme
            $prefer_dark = 1 if $theme_name =~ /dark/i;
            
            # Check environment variables
            my $gtk_theme = $ENV{GTK_THEME} || '';
            $prefer_dark = 1 if $gtk_theme =~ /dark/i;
        }
    };
    
    if ($@) {
        warn "Failed to detect system theme: $@";
    }
    
    return ($theme_name, $prefer_dark);
}

=head2 _updateProgressWindow($progress_window, $processed, $total, $status_text)

Updates the progress window with current progress information.

=cut

sub _updateProgressWindow {
    my ($self, $progress_window, $processed, $total, $status_text) = @_;
    
    return unless $progress_window && ref $progress_window eq 'HASH';
    
    my $progress_bar = $progress_window->{progress_bar};
    my $status_label = $progress_window->{status_label};
    
    return unless $progress_bar;
    
    # Calculate progress fraction
    my $fraction = $total > 0 ? $processed / $total : 0;
    $fraction = 1.0 if $fraction > 1.0;
    
    # Update progress bar
    $progress_bar->set_fraction($fraction);
    
    # Update progress text
    my $percentage = int($fraction * 100);
    my $progress_text = sprintf("Processing... %d%% (%d of %d)", $percentage, $processed, $total);
    $progress_bar->set_text($progress_text);
    
    # Update status label if provided
    if ($status_label && defined $status_text) {
        $status_label->set_text($status_text);
    }
    
    # Process pending GTK events to update display
    while (Gtk3::events_pending) {
        Gtk3::main_iteration;
    }
}

=head2 _closeProgressWindow($progress_window)

Closes and destroys the progress window.

=cut

sub _closeProgressWindow {
    my ($self, $progress_window) = @_;
    
    return unless $progress_window && ref $progress_window eq 'HASH';
    
    my $window = $progress_window->{window};
    return unless $window;
    
    eval {
        $window->destroy();
    };
    
    if ($@) {
        warn "Error closing progress window: $@";
    }
}

# END: Theme-aware Progress Window Functions
###################################################################

1;
