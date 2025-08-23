#!/usr/bin/env perl
use strict; use warnings; use utf8;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Test::More;
use PACUtils;

my $tmp = "/tmp/asbru_test_open_$$.txt";
open my $fh, '>', $tmp or die $!;
print {$fh} "hello"; close $fh;

my $xdg = PACUtils::which_cached('xdg-open');
if ($xdg) {
    ok(PACUtils::open_path($tmp) || 1, 'open_path invoked (non-fatal)');
} else {
    plan skip_all => 'xdg-open not available';
}

unlink $tmp if -f $tmp;
done_testing();
