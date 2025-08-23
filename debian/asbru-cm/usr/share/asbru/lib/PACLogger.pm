package PACLogger;

use strict;
use warnings;
use utf8;
use Term::ANSIColor qw(colored);
use PACUtils ();

# Configure UTF-8 output for emoji support
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

# ANSI Color support detection
our $USE_COLORS = (-t STDERR) && $ENV{'TERM'} && $ENV{'TERM'} ne 'dumb';

# Modern logging with emojis and colors
sub log_info {
    my ($msg) = @_;
    my $emoji = PACUtils::emoji('ℹ️ ');
    my $colored_msg = $USE_COLORS ? colored(['bright_blue'], $msg) : $msg;
    print STDERR "${emoji}INFO: ${colored_msg}\n";
}

sub log_success {
    my ($msg) = @_;
    my $emoji = PACUtils::emoji('✅ ');
    my $colored_msg = $USE_COLORS ? colored(['bright_green'], $msg) : $msg;
    print STDERR "${emoji}SUCCESS: ${colored_msg}\n";
}

sub log_warning {
    my ($msg) = @_;
    my $emoji = PACUtils::emoji('⚠️ ');
    my $colored_msg = $USE_COLORS ? colored(['bright_yellow'], $msg) : $msg;
    print STDERR "${emoji}WARN: ${colored_msg}\n";
}

sub log_error {
    my ($msg) = @_;
    my $emoji = PACUtils::emoji('❌ ');
    my $colored_msg = $USE_COLORS ? colored(['bright_red'], $msg) : $msg;
    print STDERR "${emoji}ERROR: ${colored_msg}\n";
}

sub log_debug {
    my ($msg) = @_;
    return unless $ENV{ASBRU_DEBUG};
    my $emoji = PACUtils::emoji('🔍 ');
    my $colored_msg = $USE_COLORS ? colored(['bright_cyan'], $msg) : $msg;
    print STDERR "${emoji}DEBUG: ${colored_msg}\n";
}

sub log_start {
    my ($msg) = @_;
    my $emoji = PACUtils::emoji('🚀 ');
    my $colored_msg = $USE_COLORS ? colored(['bright_magenta'], $msg) : $msg;
    print STDERR "${emoji}START: ${colored_msg}\n";
}

1;
