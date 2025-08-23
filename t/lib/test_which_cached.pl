#!/usr/bin/env perl
use strict; use warnings; use utf8;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Test::More;
use PACUtils;

my $u1 = PACUtils::which_cached('uname');
my $u2 = PACUtils::which_cached('uname');
ok(defined $u1 && $u1 ne '', 'which_cached found uname');
is($u1, $u2, 'which_cached returns cached same result on second call');

done_testing();
