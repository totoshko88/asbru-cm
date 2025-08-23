#!/usr/bin/env perl
use strict; use warnings; use utf8;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Test::More;
use PACUtils;

my $vnc = PACUtils::which_cached('vncpasswd');
if (!$vnc) {
    plan skip_all => 'vncpasswd not available';
}

my ($out,$err,$code) = PACUtils::run_cmd({ argv => ['vncpasswd','-f'], stdin => 'secret' });
ok(defined $out && $out ne '', 'vncpasswd produced output');
is($code, 0, 'vncpasswd exited 0');

# Write to a temp file similar to runtime usage
my $pfile = "/tmp/asbru_test_vncpass_$$";
open my $fh, '>:raw', $pfile or die $!;
print {$fh} $out; close $fh;
ok(-s $pfile, 'password file written');
unlink $pfile if -f $pfile;

done_testing();
