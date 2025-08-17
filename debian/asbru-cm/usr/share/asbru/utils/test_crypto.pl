#!/usr/bin/perl

# Test script for the new cryptographic modules
# Verifies AES-256-GCM encryption and keyring integration
# AI-assisted modernization - 2024

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use PACCrypto qw(encrypt_password decrypt_password);
use PACCryptoCompat;
use PACKeyring qw(is_keyring_available get_default_keyring list_available_keyrings);
use PACCryptoKeyring qw(is_keyring_enabled enable_keyring get_keyring_status);

print "Ásbrú Connection Manager - Cryptographic Module Test\n";
print "=" x 60 . "\n\n";

# Test basic AES encryption
print "Testing AES-256-GCM encryption...\n";
my $test_password = "test_password_123!@#";
my $master_key = "test_master_key";

my $encrypted = PACCrypto::encrypt_password($test_password, $master_key);
print "Encrypted: " . substr($encrypted, 0, 50) . "...\n";

my $decrypted = PACCrypto::decrypt_password($encrypted, $master_key);
if ($decrypted eq $test_password) {
    print "✓ AES encryption/decryption successful\n\n";
} else {
    print "✗ AES encryption/decryption failed\n\n";
}

# Test compatibility layer
print "Testing compatibility layer...\n";
my $cipher = PACCryptoCompat->new(-key => $master_key, -migration => 1);

my $encrypted_hex = $cipher->encrypt_hex($test_password);
print "Encrypted (hex): " . substr($encrypted_hex, 0, 50) . "...\n";

my $decrypted_hex = $cipher->decrypt_hex($encrypted_hex);
if ($decrypted_hex eq $test_password) {
    print "✓ Compatibility layer successful\n\n";
} else {
    print "✗ Compatibility layer failed\n\n";
}

# Test keyring availability
print "Testing keyring integration...\n";
my $default_keyring = get_default_keyring();
print "Default keyring: $default_keyring\n";

my @available_keyrings = list_available_keyrings();
if (@available_keyrings) {
    print "Available keyrings: " . join(", ", @available_keyrings) . "\n";
} else {
    print "No keyrings available\n";
}

if (is_keyring_available($default_keyring)) {
    print "✓ Keyring '$default_keyring' is available\n";
    
    # Test keyring integration
    if (enable_keyring($default_keyring)) {
        print "✓ Keyring integration enabled\n";
        
        my $status = get_keyring_status();
        print "Keyring status: enabled=" . ($status->{enabled} ? 'yes' : 'no') . 
              ", type=" . ($status->{type} || 'none') . "\n";
    } else {
        print "✗ Failed to enable keyring integration\n";
    }
} else {
    print "✗ No keyring available for testing\n";
}

print "\nCryptographic module test completed.\n";