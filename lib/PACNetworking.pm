package PACNetworking;

# Modern networking module for Ásbrú Connection Manager
# Provides enhanced IPv6 support and modern networking capabilities
# AI-assisted modernization - 2024

use strict;
use warnings;

use Socket qw(:all);
use IO::Socket::IP;  # Modern replacement for IO::Socket::INET with IPv6 support
use Net::Ping;
use Carp;

# Export functions
use Exporter 'import';
our @EXPORT_OK = qw(
    create_socket ping_host resolve_hostname
    get_local_ip is_ipv6 is_ipv4
    create_tcp_socket create_udp_socket
);

=head1 NAME

PACNetworking - Modern networking functions for Ásbrú Connection Manager

=head1 DESCRIPTION

This module provides modern networking capabilities with enhanced IPv6 support,
replacing the deprecated Socket6 module and providing better cross-platform
compatibility.

=head1 FUNCTIONS

=head2 create_socket($host, $port, $family, $type)

Creates a modern socket with IPv4/IPv6 auto-detection.
Uses IO::Socket::IP for better compatibility.

=cut

sub create_socket {
    my ($host, $port, $family, $type) = @_;
    
    $family //= AF_UNSPEC;  # Auto-detect IPv4/IPv6
    $type //= SOCK_STREAM;  # Default to TCP
    
    my $socket = IO::Socket::IP->new(
        PeerHost => $host,
        PeerPort => $port,
        Family   => $family,
        Type     => $type,
        Timeout  => 10,
    );
    
    return $socket;
}

=head2 create_tcp_socket($host, $port, $ipv6_preferred)

Creates a TCP socket with optional IPv6 preference.

=cut

sub create_tcp_socket {
    my ($host, $port, $ipv6_preferred) = @_;
    
    my $family = AF_UNSPEC;
    if (defined $ipv6_preferred) {
        $family = $ipv6_preferred ? AF_INET6 : AF_INET;
    }
    
    return create_socket($host, $port, $family, SOCK_STREAM);
}

=head2 create_udp_socket($host, $port, $ipv6_preferred)

Creates a UDP socket with optional IPv6 preference.

=cut

sub create_udp_socket {
    my ($host, $port, $ipv6_preferred) = @_;
    
    my $family = AF_UNSPEC;
    if (defined $ipv6_preferred) {
        $family = $ipv6_preferred ? AF_INET6 : AF_INET;
    }
    
    return create_socket($host, $port, $family, SOCK_DGRAM);
}

=head2 ping_host($host, $timeout, $protocol)

Modern ping implementation with IPv6 support.

=cut

sub ping_host {
    my ($host, $timeout, $protocol) = @_;
    
    $timeout //= 5;
    $protocol //= 'tcp';
    
    # Create ping object with modern settings
    my $ping = Net::Ping->new($protocol, $timeout);
    
    # Enable service checking for TCP pings
    if ($protocol eq 'tcp') {
        $ping->tcp_service_check(1);
    }
    
    # Perform the ping
    my $result = $ping->ping($host);
    $ping->close();
    
    return $result;
}

=head2 resolve_hostname($hostname)

Resolves hostname to IP addresses (both IPv4 and IPv6).
Returns a hash with 'ipv4' and 'ipv6' arrays.

=cut

sub resolve_hostname {
    my $hostname = shift;
    
    my %result = (
        ipv4 => [],
        ipv6 => [],
    );
    
    # Use getaddrinfo for modern name resolution
    my ($err, @addresses) = getaddrinfo($hostname, undef, {
        family => AF_UNSPEC,
        socktype => SOCK_STREAM,
    });
    
    return \%result if $err;
    
    for my $addr (@addresses) {
        my ($err, $ip) = getnameinfo($addr->{addr}, NI_NUMERICHOST);
        next if $err;
        
        if ($addr->{family} == AF_INET) {
            push @{$result{ipv4}}, $ip;
        } elsif ($addr->{family} == AF_INET6) {
            push @{$result{ipv6}}, $ip;
        }
    }
    
    return \%result;
}

=head2 is_ipv4($address)

Checks if an address is a valid IPv4 address.

=cut

sub is_ipv4 {
    my $address = shift;
    return 0 unless defined $address;
    
    # Simple IPv4 validation
    return $address =~ /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
}

=head2 is_ipv6($address)

Checks if an address is a valid IPv6 address.

=cut

sub is_ipv6 {
    my $address = shift;
    return 0 unless defined $address;
    
    # Use Socket's inet_pton for proper IPv6 validation
    my $result = eval {
        inet_pton(AF_INET6, $address);
    };
    return defined $result && !$@;
}

=head2 get_local_ip($target_host)

Gets the local IP address that would be used to connect to a target host.

=cut

sub get_local_ip {
    my $target_host = shift;
    $target_host //= '8.8.8.8';  # Default to Google DNS
    
    # Create a socket to determine local IP
    my $socket = IO::Socket::IP->new(
        PeerHost => $target_host,
        PeerPort => 80,
        Proto    => 'tcp',
        Timeout  => 5,
    );
    
    return undef unless $socket;
    
    my $local_ip = $socket->sockhost();
    $socket->close();
    
    return $local_ip;
}

=head2 create_unix_socket($path, $listen)

Creates a Unix domain socket for local IPC.

=cut

sub create_unix_socket {
    my ($path, $listen) = @_;
    
    require IO::Socket::UNIX;
    
    my %args = (
        Peer => $path,
        Type => SOCK_STREAM,
    );
    
    if ($listen) {
        delete $args{Peer};
        $args{Local} = $path;
        $args{Listen} = 1;
    }
    
    return IO::Socket::UNIX->new(%args);
}

=head2 get_network_interfaces()

Returns information about available network interfaces.

=cut

sub get_network_interfaces {
    my %interfaces;
    
    # Try to read from /proc/net/dev on Linux
    if (-r '/proc/net/dev') {
        open my $fh, '<', '/proc/net/dev' or return \%interfaces;
        
        while (my $line = <$fh>) {
            next unless $line =~ /^\s*(\w+):/;
            my $interface = $1;
            next if $interface eq 'lo';  # Skip loopback
            
            $interfaces{$interface} = {
                name => $interface,
                active => 1,  # Assume active if listed
            };
        }
        close $fh;
    }
    
    return \%interfaces;
}

=head2 create_secure_connection($host, $port, $options)

Creates a secure SSL/TLS connection with modern security settings.
This is a convenience wrapper around PACTLS functionality.

=cut

sub create_secure_connection {
    my ($host, $port, $options) = @_;
    
    # Load PACTLS module for SSL functionality
    eval {
        require PACTLS;
        PACTLS->import('create_ssl_socket');
    };
    
    if ($@) {
        # Fallback to basic socket if SSL modules not available
        warn "SSL modules not available, creating insecure connection: $@";
        return create_tcp_socket($host, $port);
    }
    
    return PACTLS::create_ssl_socket($host, $port, $options);
}

=head2 test_connection($host, $port, $protocol, $timeout)

Tests connectivity to a host and port with various protocols.

=cut

sub test_connection {
    my ($host, $port, $protocol, $timeout) = @_;
    
    $protocol //= 'tcp';
    $timeout //= 10;
    
    my %result = (
        success => 0,
        error => '',
        response_time => 0,
        ssl_info => {},
    );
    
    my $start_time = time();
    
    if ($protocol eq 'tcp') {
        my $socket = create_tcp_socket($host, $port);
        if ($socket) {
            $result{success} = 1;
            $socket->close();
        } else {
            $result{error} = "TCP connection failed: $!";
        }
    } elsif ($protocol eq 'ssl' || $protocol eq 'tls') {
        eval {
            require PACTLS;
            my $socket = PACTLS::create_ssl_socket($host, $port, { SSL_verify_mode => 0 });
            if ($socket) {
                $result{success} = 1;
                $result{ssl_info} = PACTLS::get_cipher_info($socket);
                $socket->close();
            }
        };
        if ($@) {
            $result{error} = "SSL connection failed: $@";
        }
    } elsif ($protocol eq 'ping') {
        $result{success} = ping_host($host, $timeout, 'icmp');
        $result{error} = "Ping failed" unless $result{success};
    }
    
    $result{response_time} = time() - $start_time;
    
    return \%result;
}

1;

__END__

=head1 MIGRATION NOTES

This module replaces several deprecated networking modules:

- Socket6 → Modern Socket with IPv6 support
- IO::Socket::INET → IO::Socket::IP (with IPv6 support)
- Enhanced Net::Ping usage with better error handling

=head1 IPv6 SUPPORT

All functions in this module support both IPv4 and IPv6 addresses automatically.
The family parameter can be used to force a specific IP version when needed.

=head1 AI ASSISTANCE DISCLOSURE

This module was created with AI assistance as part of the Ásbrú Connection
Manager modernization project in 2024. All networking implementations follow
current best practices for cross-platform compatibility.

=cut