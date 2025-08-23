#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../protocols";

use AsbruTestFramework qw(setup_test_environment cleanup_test_environment check_tool_availability);
use ServiceHarness qw(detect_container_runtime wait_for_port run_container stop_container);

use File::Temp qw(tempfile tempdir);
use File::Spec;
use Time::HiRes qw(sleep time);
use Storable qw(nstore);
use IO::Select;

# Plan dynamically: we will run 6 core asserts; skip all if no runtime
setup_test_environment(headless => 1);

my $rt = detect_container_runtime();
if (!$rt) {
    plan skip_all => 'No container runtime (docker/podman) available; skipping app E2E test';
}

my %tools = check_tool_availability('ssh');
if (!$tools{ssh}) {
    plan skip_all => 'ssh client not available; skipping app E2E test';
}

plan tests => 6;

diag("Using container runtime: $rt");

# Start SSH test service (linuxserver/openssh-server)
my $svc_name = 'asbru-e2e-sshd';
my $image = $ENV{ASBRU_TEST_SSH_IMAGE} // 'linuxserver/openssh-server:latest';
my $host_port = 2222; my $cont_port = 2222;
my $cid = run_container(
    runtime => $rt,
    image   => $image,
    name    => $svc_name,
    ports   => { $host_port => $cont_port },
    env     => {
        PUID => '1000',
        PGID => '1000',
        TZ => 'UTC',
        PASSWORD_ACCESS => 'true',
        USER_NAME => 'testuser',
        USER_PASSWORD => 'testpass',
        SUDO_ACCESS => 'true',
        LOG_STDOUT => 'true',
    }
);

ok($cid ne '', 'ssh container started');
ok(wait_for_port(host => '127.0.0.1', port => $host_port, timeout => 45), 'ssh port ready');

# Give the container a few seconds to finish user/password setup
sleep 5;

# Build minimal Storable config for asbru_conn
my $uuid = 'e2e-ssh';
my $tmpdir = tempdir(CLEANUP => 1);
my $cfg_path = File::Spec->catfile($tmpdir, 'asbru_e2e_cfg.sto');
my $log_path = File::Spec->catfile($tmpdir, 'asbru_e2e.log');
my $sock_path = File::Spec->catfile($tmpdir, 'asbru.sock');
my $sock_exec_path = File::Spec->catfile($tmpdir, 'asbru.exec.sock');

my $cfg = {
    defaults => {
        debug => 1,
        'command prompt' => '\\$ |# |% |> |\\]\\$ ',
        'username prompt' => 'login:|user(name)?:',
        'password prompt' => 'assword:',
        'hostkey changed prompt' => 'REMOTE HOST IDENTIFICATION HAS CHANGED',
        'press any key prompt' => 'Press any key',
        'remote host changed prompt' => 'Are you sure you want to continue connecting',
        'auto accept key' => 1,
        'timeout connect' => 30,
        'timeout command' => 10,
        'sudo prompt' => '\\[sudo\\] password for',
        'sudo password' => '',
        'remove control chars' => 1,
        'log timestamp' => 0,
        keepass => { use_keepass => 0 },
        'jump ip' => '', 'jump user' => '', 'jump pass' => '',
        'proxy ip' => '', 'proxy user' => '', 'proxy pass' => '',
    },
    tmp => {
        uuid => $uuid,
        'log file' => $log_path,
        socket => $sock_path,
        'socket exec' => $sock_exec_path,
    },
    environments => {
        $uuid => {
            name => 'E2E SSH',
            title => 'E2E SSH',
            method => 'ssh',
            ip => '127.0.0.1',
            port => $host_port,
            user => 'testuser',
            pass => 'testpass',
            'auth type' => 'password',
            'use sudo' => 0,
            'save session logs' => 0,
            'remove control chars' => 1,
            'log timestamp' => 0,
            options => '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
        },
    },
};

ok(nstore($cfg, $cfg_path), 'wrote asbru_conn config');

# Launch asbru_conn in headless mode (GETCMD=1 prevents PACMain socket usage)
my $asbru_conn = File::Spec->catfile($Bin, '..', '..', 'lib', 'asbru_conn');
ok(-f $asbru_conn, 'asbru_conn present');
my $cmd = sprintf('ASBRU_CFG=%s ASBRU_SKIP_SOCKETS=1 ASBRU_TEST_VERBOSE=1 ASBRU_DEBUG=1 perl %s %s %s 0 0 2>&1', $tmpdir, $asbru_conn, $cfg_path, $uuid);

open(my $PH, '-|', $cmd) or die "Unable to start asbru_conn: $!";

# Capture output for CONNECTED marker (handle non-newline ctrl() prints)
my $deadline = time() + 60;
my $got_connected = 0;
my $buf = '';
my $sel = IO::Select->new();
$sel->add($PH);
while (time() < $deadline) {
    my @ready = $sel->can_read(0.5);
    if (@ready) {
        my $chunk = '';
        my $read = sysread($PH, $chunk, 4096);
        last unless defined $read;
        if ($read == 0) { last; }
        $buf .= $chunk;
    if ($buf =~ /CONNECTED/) { $got_connected = 1; last; }
    }
}

ok($got_connected, 'asbru_conn reported CONNECTED') or diag(substr($buf, -2000));

# Terminate process if still running
close $PH; # best effort

# Quick smoke: ensure ssh actually accepts a command
my %more_tools = check_tool_availability('sshpass');
my $ssh_ok;
if ($more_tools{sshpass}) {
    $ssh_ok = system('sshpass', '-p', 'testpass', 'ssh', '-p', $host_port, '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null', 'testuser@127.0.0.1', 'echo ok >/dev/null') == 0;
    ok($ssh_ok, 'direct ssh smoke test succeeded');
} else {
    ok(1, 'sshpass not available; skipping direct ssh smoke test');
}

# Teardown
stop_container(runtime => $rt, name => $svc_name);

done_testing();
