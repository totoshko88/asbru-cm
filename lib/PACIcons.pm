package PACIcons;
use strict;use warnings;
use Gtk3;
our $INTERNAL_THEME_PREFIX = 'asbru';
my %THEME_FILE_MAP; # logical => file path for current internal theme
use FindBin qw($RealBin);
my $DEFAULT_THEME_DIR = "$RealBin/res/themes/default"; # canonical default assets
my $OVERLAY_ENV = $ENV{ASBRU_INTERNAL_OVERLAY} ? 1 : 0; # if set, draw debug overlay on internal icons

# Logical name -> GTK icon name (symbolic preferred)
my %MAP = (
  edit        => 'document-edit-symbolic',
  add         => 'list-add-symbolic',
  delete      => 'edit-delete-symbolic',
  connect     => 'network-connect-symbolic',
  disconnect  => 'network-disconnect-symbolic',
    # Method specific icons use project-bundled SVG assets to guarantee distinction across themes
    ssh         => 'asbru-method-ssh',
    rdp         => 'asbru-method-rdesktop',
    vnc         => 'asbru-method-vncviewer',
    sftp        => 'asbru-method-sftp',
    telnet      => 'asbru-method-telnet',
    ftp         => 'asbru-method-ftp',
  favourite_on  => 'starred-symbolic',
  favourite_off => 'non-starred-symbolic',
  refresh     => 'view-refresh-symbolic',
  search      => 'system-search-symbolic',
  settings    => 'emblem-system-symbolic',
  shell       => 'utilities-terminal-symbolic',
  folder      => 'folder-symbolic',
  group       => 'user-group-symbolic',
    history     => 'document-open-recent-symbolic',
    previous    => 'go-previous-symbolic',
    next        => 'go-next-symbolic',
    save        => 'document-save-symbolic',
    wol         => 'network-wired-symbolic',
    quick       => 'system-run-symbolic',
    cluster     => 'applications-system-symbolic',
    scripts     => 'text-x-script-symbolic',
        lock_on     => 'changes-prevent-symbolic',
        lock_off    => 'changes-allow-symbolic',
        about       => 'help-about-symbolic',
        quit        => 'application-exit-symbolic',
        execute     => 'system-run-symbolic',
        close       => 'window-close-symbolic',
        help        => 'help-browser-symbolic',
        undo        => 'edit-undo-symbolic',
        save_as     => 'document-save-as-symbolic',
        keepass     => 'dialog-password-symbolic',
        info        => 'dialog-information-symbolic',
        copy        => 'edit-copy-symbolic',
        buttonbar_show => 'view-list-symbolic',
        buttonbar_hide => 'view-list-symbolic',
    status_disconnected => 'network-offline-symbolic',
    status_connected    => 'network-transmit-receive-symbolic',
    status_expect       => 'media-playback-start-symbolic',
    status_cluster_off  => 'emblem-remove-symbolic',
    status_cluster_on   => 'emblem-ok-symbolic',
    tab_close           => 'window-close-symbolic',
    treelist            => 'view-list-symbolic',
    favourite_start     => 'starred-symbolic',
    history_start       => 'document-open-recent-symbolic',
    cluster_start       => 'applications-system-symbolic',
    protected           => 'changes-prevent-symbolic',
    save_as             => 'document-save-as-symbolic',
    kpx                 => 'dialog-password-symbolic',
    reset_defaults      => 'edit-undo-symbolic',
    help_link           => 'help-browser-symbolic',
    add_row             => 'list-add-symbolic',
    delete_row          => 'edit-delete-symbolic',
    exec_run            => 'system-run-symbolic',
    move_up             => 'go-up-symbolic',
    move_down           => 'go-down-symbolic',
    ok                  => 'emblem-ok-symbolic',
    cancel              => 'window-close-symbolic',
    warning             => 'dialog-warning-symbolic',
    error               => 'dialog-error-symbolic',
    question            => 'dialog-question-symbolic',
    yes                 => 'emblem-ok-symbolic',
    no                  => 'window-close-symbolic',
    success             => 'emblem-ok-symbolic',
    failure             => 'dialog-error-symbolic',
    tray_bw             => 'image-x-generic-symbolic',
    tray_color          => 'image-x-generic-symbolic',
    # legacy menu logical names (replacing former stock 'gtk-*' tokens)
    new                 => 'document-new-symbolic',
    open                => 'document-open-symbolic',
    save_as             => 'document-save-as-symbolic',
    copy_action         => 'edit-copy-symbolic',
    paste_action        => 'edit-paste-symbolic',
    cut_action          => 'edit-cut-symbolic',
    delete_action       => 'edit-delete-symbolic',
    execute_action      => 'system-run-symbolic',
    question_action     => 'dialog-question-symbolic',
    help_action         => 'help-browser-symbolic',
    refresh_action      => 'view-refresh-symbolic',
    stop_action         => 'process-stop-symbolic',
    zoom_fit            => 'view-fullscreen-symbolic',
    fullscreen          => 'view-fullscreen-symbolic',
    leave_fullscreen    => 'view-restore-symbolic',
    media_record        => 'media-record-symbolic',
    media_play          => 'media-playback-start-symbolic',
    media_stop          => 'media-playback-stop-symbolic',
    find_action         => 'edit-find-symbolic',
    preferences         => 'emblem-system-symbolic',
    about_action        => 'help-about-symbolic',
    quit_action         => 'application-exit-symbolic',
    spell_check         => 'tools-check-spelling-symbolic',
    jump_to             => 'go-jump-symbolic',
    home_action         => 'go-home-symbolic',
);

# Return suggested CSS class for auto hi-dpi (currently same as manual large icons)
sub hi_dpi_class { return 'asbru-large-icons'; }

my %CACHE;

# Internal-only logical icons (always use bundled assets / allow default fallback + tint)
my %INTERNAL_ONLY = map { $_ => 1 } qw(
    ssh rdp vnc sftp telnet ftp
    favourite_on favourite_off
    protected keepass
    tray_bw tray_color
    help_link
);

# Accent colors (R,G,B) applied when a non-default internal theme reuses default assets
my %ACCENTS = (
    'asbru-dark'  => [0xFF,0xB3,0x00], # amber
    'asbru-color' => [0x2E,0x7D,0x32], # green
);

sub _accent_for_theme {
    my ($theme) = @_;
    return $ACCENTS{$theme} if exists $ACCENTS{$theme};
    return undef;
}

sub _tint_pixbuf {
    my ($pix, $accent) = @_;
    return $pix unless $pix && $accent;
    my ($rA,$gA,$bA) = @$accent;
    my $has_alpha   = $pix->get_has_alpha;
    my $n_channels  = $pix->get_n_channels; # expect 3 or 4
    my $rowstride   = $pix->get_rowstride;
    my $width       = $pix->get_width;
    my $height      = $pix->get_height;
    my $pixels      = $pix->get_pixels; # returns scalar referencing underlying data
    # Safety: only operate if channels >=3
    return $pix if $n_channels < 3;
    use bytes;
    for my $y (0..$height-1) {
        my $row_off = $y * $rowstride;
        for my $x (0..$width-1) {
            my $pos = $row_off + $x * $n_channels;
            my $r = ord(substr($pixels,$pos,1));
            my $g = ord(substr($pixels,$pos+1,1));
            my $b = ord(substr($pixels,$pos+2,1));
            my $a = $has_alpha ? ord(substr($pixels,$pos+3,1)) : 255;
            next if $a < 16; # skip near-transparent
            my $lum = ($r*0.299 + $g*0.587 + $b*0.114)/255; # 0..1
            my $nr = int($rA * $lum);
            my $ng = int($gA * $lum);
            my $nb = int($bA * $lum);
            substr($pixels,$pos,1)     = chr($nr);
            substr($pixels,$pos+1,1)   = chr($ng);
            substr($pixels,$pos+2,1)   = chr($nb);
        }
    }
    # modifying $pixels in place updates pixbuf
    return $pix;
}

sub _overlay_pixbuf {
    return unless $OVERLAY_ENV;
    my ($pix) = @_;
    return unless $pix;
    my $w = $pix->get_width; my $h = $pix->get_height; return unless $w > 4 && $h > 4;
    my $nch = $pix->get_n_channels; return unless $nch >= 3;
    my $row = $pix->get_rowstride; my $data = $pix->get_pixels;
    use bytes;
    # Draw 3x3 magenta square at bottom-right corner as visual marker
    for my $dy (0..2) {
        my $y = $h-1-$dy; last if $y < 0;
        my $row_off = $y * $row;
        for my $dx (0..2) {
            my $x = $w-1-$dx; last if $x < 0;
            my $pos = $row_off + $x * $nch;
            substr($data,$pos,1) = chr(0xFF);
            substr($data,$pos+1,1) = chr(0x00);
            substr($data,$pos+2,1) = chr(0xFF);
        }
    }
}
# Logical -> theme file name mapping (relative to theme dir)
my %FILE_MAP = (
    favourite_on  => 'asbru_favourite_on.svg',
    favourite_off => 'asbru_favourite_off.svg',
    keepass       => 'asbru_keepass.png',
    ssh           => 'asbru_method_ssh.svg',
    tray_bw       => 'asbru_prompt.png', # placeholder; no dedicated bw tray asset provided
    tray_color    => 'asbru_prompt.png',
    protected     => 'asbru_protected.png',
    'preferences-system' => 'asbru_preferences.svg',
    cluster       => 'asbru_cluster_connection.svg',
    scripts       => 'asbru_scripts_manager.svg',
    history       => 'asbru_history.svg',
    shell         => 'asbru_shell.svg',
    group         => 'asbru_group.svg',
    add           => 'asbru_node_add_16x16.svg',
    edit          => 'asbru_edit.svg',
    delete        => 'gtk-delete.svg',
    refresh       => 'gtk-find.svg', # placeholder
    settings      => 'asbru_preferences.svg',
    preferences   => 'asbru_preferences.svg',
    wol           => 'asbru_wol.svg',
    cluster_start => 'asbru_cluster_connection.svg',
    treelist      => 'asbru_treelist.svg',
);

sub clear_cache { %CACHE = (); }

our $PACICONS_LAST_DIR;
our $PACICONS_LAST_SCAN_TIME = 0;
our $PACICONS_SCAN_COUNT = 0;
sub set_theme_dir {
    my ($dir,%opts) = @_;
    return unless defined $dir && -d $dir;
    my $force = $opts{force} || $ENV{ASBRU_FORCE_ICON_RESCAN} || 0;
    if (defined $PACICONS_LAST_DIR && $PACICONS_LAST_DIR eq $dir && !$force) {
        return; # skip duplicate scan unless forced
    }
    $PACICONS_LAST_DIR = $dir; $PACICONS_LAST_SCAN_TIME = time; $PACICONS_SCAN_COUNT++;
    %THEME_FILE_MAP = ();
    opendir(my $dh, $dir) or return;
    while (my $f = readdir($dh)) {
        next unless $f =~ /^asbru[-_](.+)\.(svg|png|jpg)$/i; # accept asbru_ and asbru-
        my $base = $1;
        my $logical;
        if ($base =~ /^method_(.+)$/) { $logical = $1; }
        elsif ($base =~ /^node_add/) { $logical = 'add'; }
        elsif ($base =~ /^favourite_on/) { $logical = 'favourite_on'; }
        elsif ($base =~ /^favourite_off/) { $logical = 'favourite_off'; }
        elsif ($base =~ /^cluster_connection/) { $logical = 'cluster'; }
        elsif ($base =~ /^cluster(_manager.*)?$/) { $logical = 'cluster'; }
        elsif ($base =~ /^preferences$/ || $base =~ /^preferences\b/ || $base =~ /^preferences-system$/) { $logical = 'preferences'; }
        elsif ($base eq 'shell') { $logical = 'shell'; }
        elsif ($base eq 'history') { $logical = 'history'; }
        elsif ($base eq 'group' || $base =~ /^group_(open|closed)/) { $logical = 'group'; }
        elsif ($base eq 'edit') { $logical = 'edit'; }
        elsif ($base eq 'wol' || $base eq 'wol') { $logical = 'wol'; }
        elsif ($base eq 'treelist') { $logical = 'treelist'; }
        elsif ($base eq 'protected') { $logical = 'protected'; }
        elsif ($base eq 'unprotected') { $logical = 'lock_off'; }
        elsif ($base eq 'keepass') { $logical = 'keepass'; }
        elsif ($base eq 'prompt') { $logical = 'tray_color'; }
        elsif ($base eq 'script' || $base eq 'scripts-manager') { $logical = 'scripts'; }
        elsif ($base eq 'quick_connect') { $logical = 'quick'; }
        elsif ($base eq 'buttonbar_show') { $logical = 'buttonbar_show'; }
        elsif ($base eq 'buttonbar_hide') { $logical = 'buttonbar_hide'; }
        elsif ($base eq 'chain') { $logical = 'kpx'; }
        next unless $logical;
        $THEME_FILE_MAP{$logical} = "$dir/$f";
    }
    closedir $dh;
    %CACHE = ();
    if ($ENV{ASBRU_DEBUG}) {
        print STDERR "DEBUG: PACIcons scanned theme dir $dir (" . scalar(keys %THEME_FILE_MAP) . " logical icons, scan#$PACICONS_SCAN_COUNT" . ($force?" forced":"") . ")\n";
        if ($PACICONS_SCAN_COUNT>1 && ($ENV{ASBRU_DEBUG_STACK}||0)) {
            eval { require Carp; Carp::cluck("DEBUG: Duplicate theme scan stack trace" . ($force?" (forced)":"")); };
        }
    }
}

sub icon_image {
    my ($logical, $fallback_stock) = @_;
    my $key = "$logical|" . ($fallback_stock // '');
    return $CACHE{$key} if $CACHE{$key};
    my $name = $MAP{$logical} // $fallback_stock // 'applications-system-symbolic';
    my $theme_dir = eval { $PACMain::FUNCS{_MAIN}->{_THEME} };
    my $theme_name = eval { $PACMain::FUNCS{_MAIN}->{_CFG}{defaults}{theme} } || 'default';
    my $internal = ($theme_name ne 'system') && defined $theme_dir && -d $theme_dir;
    my $force_internal = eval { $PACMain::FUNCS{_MAIN}->{_CFG}{defaults}{'force_internal_icons'} } ? 1 : 0;
    my $image;
    my $used_default_fallback = 0; # track if asset came from default theme while on another internal theme
    my $loaded_from_path;
    my $internal_whitelisted = $force_internal ? 1 : ($INTERNAL_ONLY{$logical} ? 1 : 0);
    my $internal_used = 0;
    # Internal theme specific file first (restores legacy behaviour)
    if ($internal) {
        # dynamic map first (only if present in current theme dir)
        if (my $p = $THEME_FILE_MAP{$logical}) {
            if (-f $p) {
                eval { my $pix = Gtk3::Gdk::Pixbuf->new_from_file_at_size($p,16,16); $loaded_from_path=$p; $image = Gtk3::Image->new_from_pixbuf($pix) if $pix; };
                if ($image) { $internal_used=1; print STDERR "DEBUG: PACIcons dynamic hit $p for $logical\n" if $ENV{ASBRU_DEBUG}; }
            }
        }
        # static file map & generic naming
        if (!$image) {
            my @rel_candidates;
            if (my $rel = $FILE_MAP{$logical}) { push @rel_candidates, $rel; }
            push @rel_candidates, "asbru_${logical}.svg", "asbru_${logical}.png";
            # Search current theme dir, then default theme dir (for complete internal look) for all icons;
            # recolor only when using default fallback and theme != default
            my @dirs = ($theme_dir);
            push @dirs, ($DEFAULT_THEME_DIR) if $theme_name ne 'default';
            DIR2: for my $dir_try (@dirs) {
                for my $rel (@rel_candidates) {
                    my $path = "$dir_try/$rel";
                    next unless -f $path;
                    eval {
                        my $pix = Gtk3::Gdk::Pixbuf->new_from_file_at_size($path, 16, 16);
                        if ($pix) {
                            if ($dir_try ne $theme_dir && $theme_name ne 'default') {
                                $used_default_fallback = 1;
                                my $accent = _accent_for_theme($theme_name);
                                _tint_pixbuf($pix,$accent) if $accent;
                            }
                            $loaded_from_path = $path;
                            $image = Gtk3::Image->new_from_pixbuf($pix);
                            $internal_used=1;
                        }
                    };
                    if ($image) {
                        print STDERR "DEBUG: PACIcons internal hit $rel for $logical (" . ($used_default_fallback? 'fallback+recolor':'theme') . ")\n" if $ENV{ASBRU_DEBUG};
                        last DIR2;
                    }
                }
            }
        }
    }
    # Try theme icon name (symbolic) if still not resolved
    if (!$image && $name !~ /^asbru-method-/) {
        eval { $image = Gtk3::Image->new_from_icon_name($name, 'button'); };
        print STDERR "DEBUG: PACIcons system icon $name for $logical\n" if $ENV{ASBRU_DEBUG} && $image && !$internal_used;
    }
    if (!$image || ($name =~ /^asbru-method-/)) {
        if ($name =~ /^asbru-method-(.+)$/) {
            my $file = "$RealBin/res/themes/default/asbru_method_$1.svg"; # default fallback
            if (-f $file) {
                eval {
                    my $pix = Gtk3::Gdk::Pixbuf->new_from_file_at_size($file, 16, 16);
                    $image = Gtk3::Image->new_from_pixbuf($pix) if $pix;
                };
            }
        }
    }
    if (!$image && $fallback_stock) {
        eval { $image = Gtk3::Image->new_from_stock($fallback_stock, 'button'); };
    }
    $image ||= Gtk3::Image->new_from_icon_name('image-missing', 'button');
    $CACHE{$key} = $image;
    return $image;
}

1;
