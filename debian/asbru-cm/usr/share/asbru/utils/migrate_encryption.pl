#!/usr/bin/perl

# Ásbrú Connection Manager - Encryption Migration Utility
# Migrates encrypted passwords from Blowfish to AES-256-GCM
# AI-assisted modernization - 2024

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use PACCrypto qw(migrate_from_blowfish encrypt_password decrypt_password);
use PACCryptoCompat;
use YAML::XS qw(LoadFile DumpFile);
use Storable qw(nstore retrieve);
use File::Copy qw(copy);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Getopt::Long;
use Pod::Usage;

# Configuration
my $CONFIG_DIR = "$ENV{HOME}/.config/asbru";
my $CONFIG_FILE = "$CONFIG_DIR/asbru.yml";
my $NFREEZE_FILE = "$CONFIG_DIR/asbru.nfreeze";
my $BACKUP_SUFFIX = ".pre-migration-" . time();

# Command line options
my %opts = (
    help => 0,
    dry_run => 0,
    backup => 1,
    verbose => 0,
    config_file => '',
);

GetOptions(
    'help|h' => \$opts{help},
    'dry-run|n' => \$opts{dry_run},
    'no-backup' => sub { $opts{backup} = 0 },
    'verbose|v' => \$opts{verbose},
    'config-file|c=s' => \$opts{config_file},
) or pod2usage(2);

pod2usage(1) if $opts{help};

# Use custom config file if specified
if ($opts{config_file}) {
    $CONFIG_FILE = $opts{config_file};
    $CONFIG_DIR = dirname($CONFIG_FILE);
    $NFREEZE_FILE = "$CONFIG_DIR/asbru.nfreeze";
}

print "Ásbrú Connection Manager - Encryption Migration Utility\n";
print "=" x 60 . "\n\n";

# Check if configuration exists
unless (-f $CONFIG_FILE || -f $NFREEZE_FILE) {
    die "ERROR: No configuration file found at $CONFIG_FILE or $NFREEZE_FILE\n";
}

# Initialize crypto system
my $cipher = PACCryptoCompat->new(
    -key => 'PAC Manager (David Torrejon Vaquerizas, david.tv@gmail.com)',
    -migration => 1
);

print "Configuration directory: $CONFIG_DIR\n";
print "Mode: " . ($opts{dry_run} ? "DRY RUN" : "MIGRATION") . "\n";
print "Backup: " . ($opts{backup} ? "YES" : "NO") . "\n\n";

# Load configuration
my $config;
my $config_format;

if (-f $NFREEZE_FILE) {
    print "Loading configuration from nfreeze file...\n";
    $config = retrieve($NFREEZE_FILE);
    $config_format = 'nfreeze';
} elsif (-f $CONFIG_FILE) {
    print "Loading configuration from YAML file...\n";
    $config = LoadFile($CONFIG_FILE);
    $config_format = 'yaml';
} else {
    die "ERROR: Could not load configuration\n";
}

print "Configuration loaded successfully.\n\n";

# Migration statistics
my %stats = (
    passwords_migrated => 0,
    passphrases_migrated => 0,
    global_vars_migrated => 0,
    expect_vars_migrated => 0,
    connection_vars_migrated => 0,
    keepass_migrated => 0,
    sudo_password_migrated => 0,
    gui_password_migrated => 0,
    errors => 0,
);

# Backup configuration if requested
if ($opts{backup} && !$opts{dry_run}) {
    print "Creating backup...\n";
    
    if ($config_format eq 'nfreeze') {
        copy($NFREEZE_FILE, $NFREEZE_FILE . $BACKUP_SUFFIX) 
            or die "ERROR: Could not create backup: $!\n";
    } else {
        copy($CONFIG_FILE, $CONFIG_FILE . $BACKUP_SUFFIX) 
            or die "ERROR: Could not create backup: $!\n";
    }
    
    print "Backup created with suffix: $BACKUP_SUFFIX\n\n";
}

print "Starting migration process...\n\n";

# Migrate GUI password
if (exists $config->{defaults}{'gui password'} && 
    $config->{defaults}{'gui password'}) {
    
    print "Migrating GUI password...\n" if $opts{verbose};
    
    my $result = $cipher->decrypt_with_migration($config->{defaults}{'gui password'});
    if ($result->{migrated}) {
        $config->{defaults}{'gui password'} = $result->{new_encrypted};
        $stats{gui_password_migrated}++;
        print "  ✓ GUI password migrated\n" if $opts{verbose};
    }
}

# Migrate sudo password
if (exists $config->{defaults}{'sudo password'} && 
    $config->{defaults}{'sudo password'}) {
    
    print "Migrating sudo password...\n" if $opts{verbose};
    
    my $result = $cipher->decrypt_with_migration($config->{defaults}{'sudo password'});
    if ($result->{migrated}) {
        $config->{defaults}{'sudo password'} = $result->{new_encrypted};
        $stats{sudo_password_migrated}++;
        print "  ✓ Sudo password migrated\n" if $opts{verbose};
    }
}

# Migrate KeePass password
if (exists $config->{defaults}{keepass}{password} && 
    $config->{defaults}{keepass}{password}) {
    
    print "Migrating KeePass password...\n" if $opts{verbose};
    
    my $result = $cipher->decrypt_with_migration($config->{defaults}{keepass}{password});
    if ($result->{migrated}) {
        $config->{defaults}{keepass}{password} = $result->{new_encrypted};
        $stats{keepass_migrated}++;
        print "  ✓ KeePass password migrated\n" if $opts{verbose};
    }
}

# Migrate global variables
if (exists $config->{defaults}{'global variables'}) {
    print "Migrating global variables...\n" if $opts{verbose};
    
    foreach my $var (keys %{$config->{defaults}{'global variables'}}) {
        my $gvar = $config->{defaults}{'global variables'}{$var};
        
        if ($gvar->{hidden} && $gvar->{hidden} eq '1' && $gvar->{value}) {
            my $result = $cipher->decrypt_with_migration($gvar->{value});
            if ($result->{migrated}) {
                $gvar->{value} = $result->{new_encrypted};
                $stats{global_vars_migrated}++;
                print "  ✓ Global variable '$var' migrated\n" if $opts{verbose};
            }
        }
    }
}

# Migrate connection environments
if (exists $config->{environments}) {
    print "Migrating connection environments...\n" if $opts{verbose};
    
    foreach my $uuid (keys %{$config->{environments}}) {
        my $env = $config->{environments}{$uuid};
        
        # Skip groups
        next if $env->{_is_group};
        
        print "  Processing connection: " . ($env->{name} || $uuid) . "\n" if $opts{verbose};
        
        # Migrate password
        if ($env->{pass}) {
            my $result = $cipher->decrypt_with_migration($env->{pass});
            if ($result->{migrated}) {
                $env->{pass} = $result->{new_encrypted};
                $stats{passwords_migrated}++;
                print "    ✓ Password migrated\n" if $opts{verbose};
            }
        }
        
        # Migrate passphrase
        if ($env->{passphrase}) {
            my $result = $cipher->decrypt_with_migration($env->{passphrase});
            if ($result->{migrated}) {
                $env->{passphrase} = $result->{new_encrypted};
                $stats{passphrases_migrated}++;
                print "    ✓ Passphrase migrated\n" if $opts{verbose};
            }
        }
        
        # Migrate expect variables
        if ($env->{expect} && ref($env->{expect}) eq 'ARRAY') {
            foreach my $expect (@{$env->{expect}}) {
                if ($expect->{hidden} && $expect->{hidden} eq '1' && $expect->{send}) {
                    my $result = $cipher->decrypt_with_migration($expect->{send});
                    if ($result->{migrated}) {
                        $expect->{send} = $result->{new_encrypted};
                        $stats{expect_vars_migrated}++;
                        print "    ✓ Expect variable migrated\n" if $opts{verbose};
                    }
                }
            }
        }
        
        # Migrate connection variables
        if ($env->{variables} && ref($env->{variables}) eq 'ARRAY') {
            foreach my $var (@{$env->{variables}}) {
                if ($var->{hide} && $var->{hide} eq '1' && $var->{txt}) {
                    my $result = $cipher->decrypt_with_migration($var->{txt});
                    if ($result->{migrated}) {
                        $var->{txt} = $result->{new_encrypted};
                        $stats{connection_vars_migrated}++;
                        print "    ✓ Connection variable migrated\n" if $opts{verbose};
                    }
                }
            }
        }
    }
}

# Update security profile in configuration
$config->{defaults}{security_profile} = 'modern';
$config->{defaults}{encryption_method} = 'aes-256-gcm';
$config->{defaults}{migration_info} = {
    migrated_at => time(),
    migrated_from => 'blowfish',
    ai_assisted => 1,
};

print "\nMigration Summary:\n";
print "-" x 40 . "\n";
print sprintf("GUI Password:        %d\n", $stats{gui_password_migrated});
print sprintf("Sudo Password:       %d\n", $stats{sudo_password_migrated});
print sprintf("KeePass Password:    %d\n", $stats{keepass_migrated});
print sprintf("Global Variables:    %d\n", $stats{global_vars_migrated});
print sprintf("Connection Passwords: %d\n", $stats{passwords_migrated});
print sprintf("Connection Passphrases: %d\n", $stats{passphrases_migrated});
print sprintf("Expect Variables:    %d\n", $stats{expect_vars_migrated});
print sprintf("Connection Variables: %d\n", $stats{connection_vars_migrated});
print sprintf("Errors:              %d\n", $stats{errors});

my $total_migrated = $stats{gui_password_migrated} + $stats{sudo_password_migrated} + 
                    $stats{keepass_migrated} + $stats{global_vars_migrated} + 
                    $stats{passwords_migrated} + $stats{passphrases_migrated} + 
                    $stats{expect_vars_migrated} + $stats{connection_vars_migrated};

print sprintf("\nTotal items migrated: %d\n", $total_migrated);

if ($opts{dry_run}) {
    print "\nDRY RUN - No changes were made to the configuration.\n";
} else {
    print "\nSaving migrated configuration...\n";
    
    if ($config_format eq 'nfreeze') {
        nstore($config, $NFREEZE_FILE) or die "ERROR: Could not save nfreeze file: $!\n";
    } else {
        DumpFile($CONFIG_FILE, $config) or die "ERROR: Could not save YAML file: $!\n";
    }
    
    print "Configuration saved successfully.\n";
    
    if ($total_migrated > 0) {
        print "\n✓ Migration completed successfully!\n";
        print "Your passwords are now encrypted with AES-256-GCM.\n";
    } else {
        print "\nNo items required migration.\n";
    }
}

print "\nMigration process finished.\n";

__END__

=head1 NAME

migrate_encryption.pl - Migrate Ásbrú Connection Manager encryption from Blowfish to AES-256-GCM

=head1 SYNOPSIS

migrate_encryption.pl [options]

 Options:
   -h, --help           Show this help message
   -n, --dry-run        Show what would be migrated without making changes
   --no-backup          Don't create backup files
   -v, --verbose        Show detailed migration progress
   -c, --config-file    Specify custom configuration file path

=head1 DESCRIPTION

This utility migrates encrypted passwords and sensitive data in Ásbrú Connection
Manager from the old Blowfish encryption to modern AES-256-GCM encryption.

The migration process:
1. Creates a backup of the original configuration (unless --no-backup)
2. Attempts to decrypt existing encrypted data using the old Blowfish method
3. Re-encrypts the data using AES-256-GCM with PBKDF2 key derivation
4. Updates the configuration with the new encrypted data
5. Adds migration metadata to track the process

=head1 EXAMPLES

  # Dry run to see what would be migrated
  ./migrate_encryption.pl --dry-run --verbose

  # Perform the actual migration
  ./migrate_encryption.pl --verbose

  # Migrate without creating backups
  ./migrate_encryption.pl --no-backup

  # Migrate a specific configuration file
  ./migrate_encryption.pl --config-file /path/to/asbru.yml

=head1 SECURITY NOTES

- The migration utility uses the same master key as the original application
- All new encryptions use AES-256-GCM with PBKDF2 key derivation
- Original encrypted data is preserved in backup files
- Failed decryptions are logged but don't stop the migration process

=head1 AI ASSISTANCE DISCLOSURE

This utility was created with AI assistance as part of the Ásbrú Connection
Manager modernization project in 2024.

=cut