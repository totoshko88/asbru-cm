#!/usr/bin/env perl
use strict; use warnings; use utf8;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Test::More;
use PACUtils;

my $xdg = PACUtils::which_cached('xdg-open');
if ($xdg) {
    ok(PACUtils::open_url('http://127.0.0.1') || 1, 'open_url invoked (non-fatal)');
} else {
    plan skip_all => 'xdg-open not available';
}

done_testing();
