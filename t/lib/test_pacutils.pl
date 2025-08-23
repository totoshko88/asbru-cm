#!/usr/bin/env perl
use strict; use warnings; use utf8;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Test::More;
use PACUtils;

subtest 'which_cached finds uname' => sub {
    my $u = PACUtils::which_cached('uname');
    ok(defined $u && $u ne '', 'uname found or cached');
};

subtest 'run_cmd captures stdout/stderr/exit' => sub {
    my ($out,$err,$code) = PACUtils::run_cmd({ argv => ['/bin/sh','-lc','echo ok; echo err 1>&2; exit 3'] });
    is($out, "ok\n", 'stdout captured');
    is($err, "err\n", 'stderr captured');
    is($code, 3, 'exit code captured');
};

subtest 'run_cmd stdin support' => sub {
    my ($out,$err,$code) = PACUtils::run_cmd({ argv => ['/bin/cat'], stdin => "hello" });
    is($out, 'hello', 'stdin piped to child');
    is($code, 0, 'exit code 0');
};

done_testing();
