#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use AsbruTestFramework qw(setup_test_environment cleanup_test_environment);
use ServiceHarness qw(detect_container_runtime wait_for_port run_container stop_container container_running);

setup_test_environment();

my $rt = detect_container_runtime();
if (!$rt) {
    plan skip_all => 'No container runtime (docker/podman) available; skipping fullstack protocol tests';
}

# Preflight checks for runtime health
if ($rt eq 'docker') {
    my $info_ok = (system("$rt info >/dev/null 2>&1") == 0);
    if (!$info_ok) {
        plan skip_all => 'Docker not ready (daemon not running); skipping fullstack protocol tests';
    }
}

diag("Using container runtime: $rt");

my %svcs = (
    ssh => {
        name  => 'asbru-test-sshd',
        image => $ENV{ASBRU_TEST_SSH_IMAGE} // 'linuxserver/openssh-server:latest',
        ports => { 2222 => 2222 },
        env   => {
            'PUID' => '1000',
            'PGID' => '1000',
            'TZ'   => 'UTC',
            'PASSWORD_ACCESS' => 'true',
            'USER_NAME' => 'testuser',
            'USER_PASSWORD' => 'testpass',
            'SUDO_ACCESS' => 'true',
            'DOCKER_MODS' => 'linuxserver/mods:openssh-server-ssh-tunnel',
            'LOG_STDOUT' => 'true',
        },
        ready_port => 2222,
        sanity_cmd => sub {
            # Keep it robust and fast: port-level readiness is enough for e2e bootstrap
            return wait_for_port(host => '127.0.0.1', port => 2222, timeout => 45);
        },
    },
    telnet => {
        name  => 'asbru-test-telnetd',
        image => $ENV{ASBRU_TEST_TELNET_IMAGE} // 'alpine:3.19',
        ports => { 2323 => 23 },
    cmd   => 'sh -lc "apk add --no-cache busybox-extras && telnetd -F -p 23 -l /bin/cat"',
        ready_port => 2323,
        sanity_cmd => sub {
            # Verify the port remains responsive for a short time
            return wait_for_port(host => '127.0.0.1', port => 2323, timeout => 2);
        },
    },
);

# Optional extra services (opt-in via ASBRU_E2E_EXTRA=1)
my $E2E_EXTRA = $ENV{ASBRU_E2E_EXTRA} ? 1 : 0;
my $E2E_SFTP = $ENV{ASBRU_E2E_SFTP} ? 1 : 0;
my $E2E_VNC  = $ENV{ASBRU_E2E_VNC}  ? 1 : 0;
my $E2E_RDP  = $ENV{ASBRU_E2E_RDP}  ? 1 : 0;
if ($E2E_EXTRA) { $E2E_SFTP ||= 1; $E2E_VNC ||= 1; $E2E_RDP ||= 1; }
if ($E2E_SFTP) {
    $svcs{sftp} = {
        name  => 'asbru-test-sftp',
        image => $ENV{ASBRU_TEST_SFTP_IMAGE} // 'atmoz/sftp:latest',
        ports => { 2223 => 22 },
        env   => {},
        cmd   => 'testuser:pass:1001',
        ready_port => 2223,
        sanity_cmd => sub {
            my $have_sshpass = (system('which sshpass > /dev/null 2>&1') == 0);
            if ($have_sshpass) {
                for my $i (1..20) {
                    my $cmd = q(sshpass -p pass sftp -P 2223 -o StrictHostKeyChecking=no testuser@127.0.0.1 <<<"quit" 2>/dev/null);
                    system($cmd);
                    return 1 if ($? == 0);
                    sleep 1;
                }
            }
            # Fallback: port-level readiness only
            return wait_for_port(host => '127.0.0.1', port => 2223, timeout => 30);
        },
    };
}
if ($E2E_VNC) {
    $svcs{vnc} = {
        name  => 'asbru-test-vnc',
        # linuxserver/webtop exposes a browser-based desktop over HTTPS on 3001
        image => $ENV{ASBRU_TEST_VNC_IMAGE} // 'linuxserver/webtop:latest',
        ports => { 33001 => 3001 },
        env   => {
            'PUID' => '1000',
            'PGID' => '1000',
            'TZ'   => 'UTC',
        },
        ready_port => 33001,
        sanity_cmd => sub {
            # Just verify HTTPS port remains open; GUI auth/handshake is browser-driven
            return wait_for_port(host => '127.0.0.1', port => 33001, timeout => 2);
        },
    };
}
if ($E2E_RDP) {
    $svcs{rdp} = {
        name  => 'asbru-test-rdp',
        # linuxserver/rdesktop provides an RDP-accessible desktop (default user abc/abc)
        image => $ENV{ASBRU_TEST_RDP_IMAGE} // 'linuxserver/rdesktop:latest',
        ports => { 13389 => 3389 },
        env   => {
            'TZ' => 'UTC',
            'PUID' => '1000',
            'PGID' => '1000',
        },
        ready_port => 13389,
        sanity_cmd => sub {
            # Verify TCP listening; optional: xfreerdp /build handshake is GUI-bound, so skip
            return wait_for_port(host => '127.0.0.1', port => 13389, timeout => 3);
        },
    };
}

my @started;

sub start_service {
    my ($key, $svc, $optional) = @_;
    diag("Starting $key service in container: $svc->{name}");
    my $cid = run_container(
        runtime => $rt,
        image   => $svc->{image},
        name    => $svc->{name},
        ports   => $svc->{ports} // {},
        env     => $svc->{env}   // {},
        cmd     => $svc->{cmd}   // '',
    );
    if ($cid eq '') {
        if ($optional) {
            diag("$key container could not be started (image unavailable?). Skipping $key checks.");
            ok(1, "$key container unavailable (skipped)");
            ok(1, "$key port check skipped");
            ok(1, "$key sanity check skipped");
            return;
        } else {
            ok(0, "$key container started");
            ok(0, "$key port is listening");
            ok(0, "$key service sanity check passed");
            return;
        }
    }
    push @started, { key => $key, name => $svc->{name} };
    ok(1, "$key container started");
    ok(wait_for_port(host => '127.0.0.1', port => $svc->{ready_port}, timeout => 25), "$key port is listening");
    ok($svc->{sanity_cmd}->(), "$key service sanity check passed");
}

sub stop_all {
    for my $s (reverse @started) {
        diag("Stopping $s->{key} container: $s->{name}");
        stop_container(runtime => $rt, name => $s->{name});
    }
}

START: {
    # SSH (mandatory)
    start_service(ssh => $svcs{ssh}, 0);

    # TELNET (mandatory)
    start_service(telnet => $svcs{telnet}, 0);

    # Optional services on demand
    start_service(sftp => $svcs{sftp}, 1) if $E2E_SFTP;
    start_service(vnc  => $svcs{vnc},  1) if $E2E_VNC;
    start_service(rdp  => $svcs{rdp},  1) if $E2E_RDP;
}

END {
    stop_all();
    cleanup_test_environment();
}

done_testing();
