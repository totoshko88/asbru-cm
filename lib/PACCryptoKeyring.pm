package PACCryptoKeyring;

# Enhanced cryptographic module with keyring integration
# Provides seamless integration between file-based encryption and system keyrings
# AI-assisted modernization - 2024

use strict;
use warnings;

use PACCrypto qw(encrypt_password decrypt_password);
use PACKeyring qw(
    is_keyring_available store_password retrieve_password delete_password
    get_default_keyring list_available_keyrings
);
use Carp;
use Digest::SHA qw(sha256_hex);

# Export functions
use Exporter 'import';
our @EXPORT_OK = qw(
    store_connection_password
    retrieve_connection_password
    delete_connection_password
    is_keyring_enabled
    enable_keyring
    disable_keyring
    migrate_to_keyring
    migrate_from_keyring
    get_keyring_status
);

# Configuration
my $KEYRING_ENABLED = 0;
my $KEYRING_TYPE = undef;
my $FALLBACK_TO_FILE = 1;

=head1 NAME

PACCryptoKeyring - Enhanced cryptographic module with keyring integration

=head1 DESCRIPTION

This module provides a unified interface for password storage that can use
either system keyrings or file-based encryption. It automatically falls back
to file-based encryption when keyrings are not available.

=head1 FUNCTIONS

=head2 is_keyring_enabled()

Returns 1 if keyring integration is enabled, 0 otherwise.

=cut

sub is_keyring_enabled {
    return $KEYRING_ENABLED && is_keyring_available($KEYRING_TYPE);
}

=head2 enable_keyring($keyring_type)

Enables keyring integration with the specified backend.
If no backend is specified, uses the system default.

=cut

sub enable_keyring {
    my $keyring_type = shift;
    
    $keyring_type ||= get_default_keyring();
    
    if (is_keyring_available($keyring_type)) {
        $KEYRING_ENABLED = 1;
        $KEYRING_TYPE = $keyring_type;
        return 1;
    }
    
    return 0;
}

=head2 disable_keyring()

Disables keyring integration, falling back to file-based encryption.

=cut

sub disable_keyring {
    $KEYRING_ENABLED = 0;
    $KEYRING_TYPE = undef;
}

=head2 get_keyring_status()

Returns a hash with information about the current keyring status.

=cut

sub get_keyring_status {
    return {
        enabled => $KEYRING_ENABLED,
        type => $KEYRING_TYPE,
        available => is_keyring_available($KEYRING_TYPE),
        available_backends => [list_available_keyrings()],
        fallback_enabled => $FALLBACK_TO_FILE,
    };
}

=head2 store_connection_password($connection_id, $username, $password, $master_key)

Stores a connection password using keyring if available, otherwise file encryption.
Returns a storage reference that can be used to retrieve the password later.

=cut

sub store_connection_password {
    my ($connection_id, $username, $password, $master_key) = @_;
    
    return '' unless defined $password && length $password;
    
    # Generate a unique service identifier
    my $service = _generate_service_id($connection_id);
    
    # Try keyring storage first if enabled
    if (is_keyring_enabled()) {
        if (store_password($service, $username, $password, $KEYRING_TYPE)) {
            # Return a keyring reference
            return _encode_keyring_reference($service, $username, $KEYRING_TYPE);
        }
    }
    
    # Fall back to file-based encryption
    if ($FALLBACK_TO_FILE) {
        return PACCrypto::encrypt_password($password, $master_key);
    }
    
    # No storage method available
    return '';
}

=head2 retrieve_connection_password($storage_ref, $connection_id, $username, $master_key)

Retrieves a connection password from keyring or file encryption based on the storage reference.

=cut

sub retrieve_connection_password {
    my ($storage_ref, $connection_id, $username, $master_key) = @_;
    
    return '' unless defined $storage_ref && length $storage_ref;
    
    # Check if this is a keyring reference
    if (_is_keyring_reference($storage_ref)) {
        my ($service, $keyring_username, $keyring_type) = _decode_keyring_reference($storage_ref);
        
        if (is_keyring_available($keyring_type)) {
            my $password = retrieve_password($service, $keyring_username, $keyring_type);
            return $password if defined $password;
        }
        
        # Keyring not available, but we have a keyring reference
        # This might indicate a configuration issue
        warn "Keyring reference found but keyring not available: $keyring_type";
        return '';
    }
    
    # Assume it's encrypted data, try to decrypt
    return PACCrypto::decrypt_password($storage_ref, $master_key);
}

=head2 delete_connection_password($storage_ref, $connection_id, $username)

Deletes a connection password from keyring if it's stored there.
For file-based encryption, this is a no-op since the encrypted data is in the config.

=cut

sub delete_connection_password {
    my ($storage_ref, $connection_id, $username) = @_;
    
    return 1 unless defined $storage_ref && length $storage_ref;
    
    # Check if this is a keyring reference
    if (_is_keyring_reference($storage_ref)) {
        my ($service, $keyring_username, $keyring_type) = _decode_keyring_reference($storage_ref);
        
        if (is_keyring_available($keyring_type)) {
            return delete_password($service, $keyring_username, $keyring_type);
        }
    }
    
    # For file-based encryption, deletion is handled by removing from config
    return 1;
}

=head2 migrate_to_keyring($config, $master_key)

Migrates all passwords in a configuration from file-based encryption to keyring storage.
Returns the number of passwords migrated.

=cut

sub migrate_to_keyring {
    my ($config, $master_key) = @_;
    
    return 0 unless is_keyring_enabled();
    
    my $migrated_count = 0;
    
    # Migrate connection passwords
    if (exists $config->{environments}) {
        foreach my $uuid (keys %{$config->{environments}}) {
            my $env = $config->{environments}{$uuid};
            
            # Skip groups
            next if $env->{_is_group};
            
            # Migrate main password
            if ($env->{pass} && !_is_keyring_reference($env->{pass})) {
                my $password = PACCrypto::decrypt_password($env->{pass}, $master_key);
                if ($password) {
                    my $new_ref = store_connection_password($uuid, $env->{user} || 'default', $password, $master_key);
                    if (_is_keyring_reference($new_ref)) {
                        $env->{pass} = $new_ref;
                        $migrated_count++;
                    }
                }
            }
            
            # Migrate passphrase
            if ($env->{passphrase} && !_is_keyring_reference($env->{passphrase})) {
                my $passphrase = PACCrypto::decrypt_password($env->{passphrase}, $master_key);
                if ($passphrase) {
                    my $new_ref = store_connection_password("$uuid-passphrase", $env->{user} || 'default', $passphrase, $master_key);
                    if (_is_keyring_reference($new_ref)) {
                        $env->{passphrase} = $new_ref;
                        $migrated_count++;
                    }
                }
            }
        }
    }
    
    return $migrated_count;
}

=head2 migrate_from_keyring($config, $master_key)

Migrates all passwords in a configuration from keyring storage to file-based encryption.
Returns the number of passwords migrated.

=cut

sub migrate_from_keyring {
    my ($config, $master_key) = @_;
    
    my $migrated_count = 0;
    
    # Migrate connection passwords
    if (exists $config->{environments}) {
        foreach my $uuid (keys %{$config->{environments}}) {
            my $env = $config->{environments}{$uuid};
            
            # Skip groups
            next if $env->{_is_group};
            
            # Migrate main password
            if ($env->{pass} && _is_keyring_reference($env->{pass})) {
                my $password = retrieve_connection_password($env->{pass}, $uuid, $env->{user} || 'default', $master_key);
                if ($password) {
                    $env->{pass} = PACCrypto::encrypt_password($password, $master_key);
                    $migrated_count++;
                }
            }
            
            # Migrate passphrase
            if ($env->{passphrase} && _is_keyring_reference($env->{passphrase})) {
                my $passphrase = retrieve_connection_password($env->{passphrase}, "$uuid-passphrase", $env->{user} || 'default', $master_key);
                if ($passphrase) {
                    $env->{passphrase} = PACCrypto::encrypt_password($passphrase, $master_key);
                    $migrated_count++;
                }
            }
        }
    }
    
    return $migrated_count;
}

# Private helper functions

sub _generate_service_id {
    my $connection_id = shift;
    return "asbru-cm-$connection_id";
}

sub _encode_keyring_reference {
    my ($service, $username, $keyring_type) = @_;
    
    # Create a special reference format that we can identify
    # Format: KEYRING:type:service:username:checksum
    my $data = "$keyring_type:$service:$username";
    my $checksum = substr(sha256_hex($data), 0, 8);
    
    return "KEYRING:$keyring_type:$service:$username:$checksum";
}

sub _decode_keyring_reference {
    my $reference = shift;
    
    return () unless _is_keyring_reference($reference);
    
    # Parse the reference format
    my (undef, $keyring_type, $service, $username, $checksum) = split(':', $reference, 5);
    
    # Verify checksum
    my $data = "$keyring_type:$service:$username";
    my $expected_checksum = substr(sha256_hex($data), 0, 8);
    
    return () unless $checksum eq $expected_checksum;
    
    return ($service, $username, $keyring_type);
}

sub _is_keyring_reference {
    my $reference = shift;
    
    return 0 unless defined $reference;
    return $reference =~ /^KEYRING:/;
}

1;

__END__

=head1 USAGE EXAMPLES

  use PACCryptoKeyring qw(enable_keyring store_connection_password retrieve_connection_password);
  
  # Enable keyring integration
  if (enable_keyring()) {
      print "Keyring integration enabled\n";
  }
  
  # Store a password (will use keyring if available, file encryption otherwise)
  my $storage_ref = store_connection_password('server1', 'user', 'password', $master_key);
  
  # Retrieve the password
  my $password = retrieve_connection_password($storage_ref, 'server1', 'user', $master_key);
  
  # Migrate existing config to keyring
  my $migrated = migrate_to_keyring($config, $master_key);
  print "Migrated $migrated passwords to keyring\n";

=head1 STORAGE FORMATS

The module uses different storage formats:

- File-based: Standard base64-encoded encrypted data
- Keyring: Special reference format "KEYRING:type:service:username:checksum"

This allows the system to automatically determine how to retrieve each password.

=head1 SECURITY NOTES

- Keyring storage provides better security through OS-level protection
- File-based encryption is used as a secure fallback
- Keyring references include checksums to prevent tampering
- Passwords are never stored in plain text in configuration files

=head1 AI ASSISTANCE DISCLOSURE

This module was created with AI assistance as part of the Ásbrú Connection
Manager modernization project in 2024.

=cut