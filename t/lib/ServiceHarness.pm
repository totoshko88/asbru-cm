#!/usr/bin/perl

package ServiceHarness;

use strict;
use warnings;
use v5.20;

use Exporter 'import';
use IO::Socket::INET;
use Time::HiRes qw(sleep time);

our @EXPORT_OK = qw(
  detect_container_runtime
  wait_for_port
  run_container
  stop_container
  container_running
);

# Detect docker or podman; prefer podman if available rootless
sub detect_container_runtime {
    my $prefer = $ENV{CONTAINER_RUNTIME} // '';
    my @cands = $prefer ? ($prefer) : ('podman', 'docker');
    for my $bin (@cands) {
        my $ok = system("which $bin > /dev/null 2>&1") == 0;
        return $bin if $ok;
    }
    return undef;
}

# Wait until TCP port on host is accepting connections
sub wait_for_port {
    my (%p) = @_;
    my $host = $p{host} // '127.0.0.1';
    my $port = $p{port} or die "port required";
    my $timeout = $p{timeout} // 15;
    my $deadline = time() + $timeout;
    while (time() < $deadline) {
        my $sock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
        if ($sock) { $sock->close; return 1; }
        sleep 0.25;
    }
    return 0;
}

# Run a container detached, mapping ports and environment
sub run_container {
    my (%o) = @_;
    my $rt = $o{runtime} // detect_container_runtime();
    die "No container runtime found" unless $rt;
    my $image = $o{image} or die "image required";
    my $name  = $o{name}  or die "name required";
    my $ports = $o{ports} // {};   # { host_port => container_port }
    my $env   = $o{env}   // {};   # { KEY => VAL }
    my $cmd   = $o{cmd}   // '';

    # Build command
    my @args = ($rt, 'run', '-d', '--rm', '--name', $name);
    for my $hp (keys %$ports) {
        my $cp = $ports->{$hp};
        push @args, ('-p', "$hp:$cp");
    }
    for my $k (keys %$env) {
        my $v = $env->{$k};
        push @args, ('-e', "$k=$v");
    }
    push @args, $image;
    push @args, split(/\s+/, $cmd) if $cmd;

    my $cmdline = join(' ', map { quotemeta($_) =~ s/\//\//gr } @args);
    # Use system with list to avoid shell
    my $pid = open(my $fh, '-|', @args);
    my $cid = '';
    if ($pid) {
        local $/; $cid = <$fh> // '';
        close $fh;
        chomp $cid;
    }
    return $cid;
}

sub stop_container {
    my (%o) = @_;
    my $rt = $o{runtime} // detect_container_runtime();
    my $name_or_id = $o{id} // $o{name} or return 0;
    return system($rt, 'rm', '-f', $name_or_id) == 0;
}

sub container_running {
    my (%o) = @_;
    my $rt = $o{runtime} // detect_container_runtime();
    my $name = $o{name} or return 0;
    my $out = `$rt ps --format {{.Names}} 2>/dev/null`;
    return scalar(grep { $_ eq $name } split(/\s+/, $out)) ? 1 : 0;
}

1;
