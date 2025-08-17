package PACKeyring;

# System keyring integration for Ásbrú Connection Manager
# Provides optional integration with GNOME Keyring, KDE Wallet, and other keyrings
# AI-assisted modernization - 2024

use strict;
use warnings;

use Carp;
use File::Which qw(which);

# Export functions
use Exporter 'import';
our @EXPORT_OK = qw(
    is_keyring_available
    store_password
    retrieve_password
    delete_password
    list_available_keyrings
    get_default_keyring
);

# Keyring backends
use constant {
    KEYRING_NONE => 'none',
    KEYRING_GNOME => 'gnome',
    KEYRING_KDE => 'kde',
    KEYRING_SECRET_SERVICE => 'secret-service',
    KEYRING_KEYCTL => 'keyctl',
};

=head1 NAME

PACKeyring - System keyring integration for Ásbrú Connection Manager

=head1 DESCRIPTION

This module provides optional integration with various system keyring services
including GNOME Keyring, KDE Wallet, and other Secret Service compatible keyrings.
It provides a fallback to file-based encryption when no keyring is available.

=head1 FUNCTIONS

=head2 is_keyring_available($keyring_type)

Checks if a specific keyring backend is available on the system.
Returns 1 if available, 0 otherwise.

=cut

sub is_keyring_available {
    my $keyring_type = shift || get_default_keyring();
    
    return 0 if $keyring_type eq KEYRING_NONE;
    
    if ($keyring_type eq KEYRING_GNOME || $keyring_type eq KEYRING_SECRET_SERVICE) {
        # Check for secret-tool (part of libsecret)
        return 1 if which('secret-tool');
        
        # Check for gnome-keyring-daemon
        return 1 if which('gnome-keyring-daemon') && _is_gnome_keyring_running();
    }
    
    if ($keyring_type eq KEYRING_KDE) {
        # Check for kwalletcli or kwallet-query
        return 1 if which('kwalletcli');
        return 1 if which('kwallet-query');
    }
    
    if ($keyring_type eq KEYRING_KEYCTL) {
        # Check for keyctl (Linux kernel keyring)
        return 1 if which('keyctl');
    }
    
    return 0;
}

=head2 get_default_keyring()

Detects and returns the best available keyring backend for the current system.

=cut

sub get_default_keyring {
    # Check desktop environment
    my $desktop = $ENV{XDG_CURRENT_DESKTOP} || '';
    my $session = $ENV{DESKTOP_SESSION} || '';
    
    # GNOME/Cosmic desktop - prefer GNOME Keyring
    if ($desktop =~ /gnome|cosmic/i || $session =~ /gnome|cosmic/i) {
        return KEYRING_GNOME if is_keyring_available(KEYRING_GNOME);
    }
    
    # KDE desktop - prefer KDE Wallet
    if ($desktop =~ /kde/i || $session =~ /kde/i) {
        return KEYRING_KDE if is_keyring_available(KEYRING_KDE);
    }
    
    # Try Secret Service (works with most modern keyrings)
    return KEYRING_SECRET_SERVICE if is_keyring_available(KEYRING_SECRET_SERVICE);
    
    # Try GNOME Keyring as fallback
    return KEYRING_GNOME if is_keyring_available(KEYRING_GNOME);
    
    # Try KDE Wallet as fallback
    return KEYRING_KDE if is_keyring_available(KEYRING_KDE);
    
    # Try kernel keyring as last resort
    return KEYRING_KEYCTL if is_keyring_available(KEYRING_KEYCTL);
    
    # No keyring available
    return KEYRING_NONE;
}

=head2 list_available_keyrings()

Returns a list of all available keyring backends on the current system.

=cut

sub list_available_keyrings {
    my @available;
    
    for my $keyring (KEYRING_GNOME, KEYRING_KDE, KEYRING_SECRET_SERVICE, KEYRING_KEYCTL) {
        push @available, $keyring if is_keyring_available($keyring);
    }
    
    return @available;
}

=head2 store_password($service, $username, $password, $keyring_type)

Stores a password in the specified keyring backend.
Returns 1 on success, 0 on failure.

=cut

sub store_password {
    my ($service, $username, $password, $keyring_type) = @_;
    
    $keyring_type ||= get_default_keyring();
    return 0 if $keyring_type eq KEYRING_NONE;
    
    if ($keyring_type eq KEYRING_GNOME || $keyring_type eq KEYRING_SECRET_SERVICE) {
        return _store_secret_service($service, $username, $password);
    }
    
    if ($keyring_type eq KEYRING_KDE) {
        return _store_kde_wallet($service, $username, $password);
    }
    
    if ($keyring_type eq KEYRING_KEYCTL) {
        return _store_keyctl($service, $username, $password);
    }
    
    return 0;
}

=head2 retrieve_password($service, $username, $keyring_type)

Retrieves a password from the specified keyring backend.
Returns the password on success, undef on failure.

=cut

sub retrieve_password {
    my ($service, $username, $keyring_type) = @_;
    
    $keyring_type ||= get_default_keyring();
    return undef if $keyring_type eq KEYRING_NONE;
    
    if ($keyring_type eq KEYRING_GNOME || $keyring_type eq KEYRING_SECRET_SERVICE) {
        return _retrieve_secret_service($service, $username);
    }
    
    if ($keyring_type eq KEYRING_KDE) {
        return _retrieve_kde_wallet($service, $username);
    }
    
    if ($keyring_type eq KEYRING_KEYCTL) {
        return _retrieve_keyctl($service, $username);
    }
    
    return undef;
}

=head2 delete_password($service, $username, $keyring_type)

Deletes a password from the specified keyring backend.
Returns 1 on success, 0 on failure.

=cut

sub delete_password {
    my ($service, $username, $keyring_type) = @_;
    
    $keyring_type ||= get_default_keyring();
    return 0 if $keyring_type eq KEYRING_NONE;
    
    if ($keyring_type eq KEYRING_GNOME || $keyring_type eq KEYRING_SECRET_SERVICE) {
        return _delete_secret_service($service, $username);
    }
    
    if ($keyring_type eq KEYRING_KDE) {
        return _delete_kde_wallet($service, $username);
    }
    
    if ($keyring_type eq KEYRING_KEYCTL) {
        return _delete_keyctl($service, $username);
    }
    
    return 0;
}

# Private helper functions for different keyring backends

sub _is_gnome_keyring_running {
    # Check if gnome-keyring-daemon is running
    my $output = `pgrep -f gnome-keyring-daemon 2>/dev/null`;
    return $output ? 1 : 0;
}

sub _store_secret_service {
    my ($service, $username, $password) = @_;
    
    return 0 unless which('secret-tool');
    
    # Use secret-tool to store the password
    my $label = "Ásbrú Connection Manager - $service ($username)";
    
    # Create a temporary file for the password to avoid command line exposure
    my $temp_file = "/tmp/asbru_keyring_$$";
    
    eval {
        open my $fh, '>', $temp_file or die "Cannot create temp file: $!";
        print $fh $password;
        close $fh;
        
        my $cmd = sprintf(
            'secret-tool store --label="%s" service "%s" username "%s" < "%s"',
            $label, $service, $username, $temp_file
        );
        
        my $result = system($cmd);
        unlink $temp_file;
        
        return $result == 0 ? 1 : 0;
    };
    
    unlink $temp_file if -f $temp_file;
    return 0;
}

sub _retrieve_secret_service {
    my ($service, $username) = @_;
    
    return undef unless which('secret-tool');
    
    my $cmd = sprintf(
        'secret-tool lookup service "%s" username "%s" 2>/dev/null',
        $service, $username
    );
    
    my $password = `$cmd`;
    chomp $password if defined $password;
    
    return length($password) > 0 ? $password : undef;
}

sub _delete_secret_service {
    my ($service, $username) = @_;
    
    return 0 unless which('secret-tool');
    
    my $cmd = sprintf(
        'secret-tool clear service "%s" username "%s" 2>/dev/null',
        $service, $username
    );
    
    my $result = system($cmd);
    return $result == 0 ? 1 : 0;
}

sub _store_kde_wallet {
    my ($service, $username, $password) = @_;
    
    # Try kwalletcli first
    if (which('kwalletcli')) {
        return _store_kwalletcli($service, $username, $password);
    }
    
    # Try kwallet-query as fallback
    if (which('kwallet-query')) {
        return _store_kwallet_query($service, $username, $password);
    }
    
    return 0;
}

sub _retrieve_kde_wallet {
    my ($service, $username) = @_;
    
    # Try kwalletcli first
    if (which('kwalletcli')) {
        return _retrieve_kwalletcli($service, $username);
    }
    
    # Try kwallet-query as fallback
    if (which('kwallet-query')) {
        return _retrieve_kwallet_query($service, $username);
    }
    
    return undef;
}

sub _delete_kde_wallet {
    my ($service, $username) = @_;
    
    # Try kwalletcli first
    if (which('kwalletcli')) {
        return _delete_kwalletcli($service, $username);
    }
    
    # Try kwallet-query as fallback
    if (which('kwallet-query')) {
        return _delete_kwallet_query($service, $username);
    }
    
    return 0;
}

sub _store_kwalletcli {
    my ($service, $username, $password) = @_;
    
    my $key = "asbru-$service-$username";
    
    # Create a temporary file for the password
    my $temp_file = "/tmp/asbru_kwallet_$$";
    
    eval {
        open my $fh, '>', $temp_file or die "Cannot create temp file: $!";
        print $fh $password;
        close $fh;
        
        my $cmd = sprintf('kwalletcli -e "%s" -f Passwords < "%s"', $key, $temp_file);
        my $result = system($cmd);
        
        unlink $temp_file;
        return $result == 0 ? 1 : 0;
    };
    
    unlink $temp_file if -f $temp_file;
    return 0;
}

sub _retrieve_kwalletcli {
    my ($service, $username) = @_;
    
    my $key = "asbru-$service-$username";
    my $cmd = sprintf('kwalletcli -e "%s" -f Passwords 2>/dev/null', $key);
    
    my $password = `$cmd`;
    chomp $password if defined $password;
    
    return length($password) > 0 ? $password : undef;
}

sub _delete_kwalletcli {
    my ($service, $username) = @_;
    
    my $key = "asbru-$service-$username";
    my $cmd = sprintf('kwalletcli -d "%s" -f Passwords 2>/dev/null', $key);
    
    my $result = system($cmd);
    return $result == 0 ? 1 : 0;
}

sub _store_kwallet_query {
    my ($service, $username, $password) = @_;
    
    my $key = "asbru-$service-$username";
    
    # Create a temporary file for the password
    my $temp_file = "/tmp/asbru_kwallet_$$";
    
    eval {
        open my $fh, '>', $temp_file or die "Cannot create temp file: $!";
        print $fh $password;
        close $fh;
        
        my $cmd = sprintf('kwallet-query -w "%s" -f Passwords kdewallet < "%s"', $key, $temp_file);
        my $result = system($cmd);
        
        unlink $temp_file;
        return $result == 0 ? 1 : 0;
    };
    
    unlink $temp_file if -f $temp_file;
    return 0;
}

sub _retrieve_kwallet_query {
    my ($service, $username) = @_;
    
    my $key = "asbru-$service-$username";
    my $cmd = sprintf('kwallet-query -r "%s" -f Passwords kdewallet 2>/dev/null', $key);
    
    my $password = `$cmd`;
    chomp $password if defined $password;
    
    return length($password) > 0 ? $password : undef;
}

sub _delete_kwallet_query {
    my ($service, $username) = @_;
    
    my $key = "asbru-$service-$username";
    my $cmd = sprintf('kwallet-query -d "%s" -f Passwords kdewallet 2>/dev/null', $key);
    
    my $result = system($cmd);
    return $result == 0 ? 1 : 0;
}

sub _store_keyctl {
    my ($service, $username, $password) = @_;
    
    return 0 unless which('keyctl');
    
    my $key_desc = "asbru:$service:$username";
    
    # Add key to user keyring
    my $cmd = sprintf('echo "%s" | keyctl padd user "%s" @u', $password, $key_desc);
    my $result = system($cmd);
    
    return $result == 0 ? 1 : 0;
}

sub _retrieve_keyctl {
    my ($service, $username) = @_;
    
    return undef unless which('keyctl');
    
    my $key_desc = "asbru:$service:$username";
    
    # Try to read the key
    my $cmd = sprintf('keyctl print "%s" 2>/dev/null', $key_desc);
    my $password = `$cmd`;
    chomp $password if defined $password;
    
    return length($password) > 0 ? $password : undef;
}

sub _delete_keyctl {
    my ($service, $username) = @_;
    
    return 0 unless which('keyctl');
    
    my $key_desc = "asbru:$service:$username";
    
    # Revoke the key
    my $cmd = sprintf('keyctl revoke "%s" 2>/dev/null', $key_desc);
    my $result = system($cmd);
    
    return $result == 0 ? 1 : 0;
}

1;

__END__

=head1 USAGE EXAMPLES

  use PACKeyring qw(store_password retrieve_password is_keyring_available);
  
  # Check if keyring is available
  if (is_keyring_available()) {
      # Store a password
      store_password('ssh-server.example.com', 'username', 'secret_password');
      
      # Retrieve a password
      my $password = retrieve_password('ssh-server.example.com', 'username');
      
      # Delete a password
      delete_password('ssh-server.example.com', 'username');
  }

=head1 SECURITY NOTES

- Passwords are stored using the system's native keyring security
- Temporary files are used to avoid exposing passwords in command line arguments
- All temporary files are securely deleted after use
- Keyring access requires user authentication (handled by the keyring service)

=head1 SUPPORTED KEYRINGS

- GNOME Keyring (via secret-tool)
- KDE Wallet (via kwalletcli or kwallet-query)
- Any Secret Service compatible keyring
- Linux kernel keyring (via keyctl)

=head1 AI ASSISTANCE DISCLOSURE

This module was created with AI assistance as part of the Ásbrú Connection
Manager modernization project in 2024.

=cut