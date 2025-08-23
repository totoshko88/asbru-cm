package PACSecurityConfig;

# Security configuration management for Ásbrú Connection Manager
# Handles SSL/TLS settings, certificate policies, and security profiles
# AI-assisted modernization - 2024

use strict;
use warnings;

use File::Spec;
use File::Path qw(make_path);
use YAML::XS qw(LoadFile DumpFile);
use Carp;

# Export functions
use Exporter 'import';
our @EXPORT_OK = qw(
    load_security_config
    save_security_config
    get_security_profile
    set_security_profile
    get_ssl_settings
    update_ssl_settings
    is_certificate_validation_enabled
    get_cipher_preferences
);

# Configuration file location
my $CONFIG_DIR = "$ENV{HOME}/.config/asbru";
my $SECURITY_CONFIG_FILE = "$CONFIG_DIR/security.yml";

# Default security configuration
my %DEFAULT_CONFIG = (
    version => '1.0',
    security_profile => 'standard',
    
    profiles => {
        legacy => {
            description => 'Legacy compatibility mode with relaxed security',
            ssl_verify_certificates => 0,
            ssl_verify_hostname => 0,
            ssl_min_version => 'TLSv1',
            ssl_cipher_list => 'ALL:!aNULL:!eNULL',
            allow_weak_ciphers => 1,
            certificate_pinning => 0,
        },
        
        standard => {
            description => 'Standard security with modern TLS',
            ssl_verify_certificates => 1,
            ssl_verify_hostname => 1,
            ssl_min_version => 'TLSv1_2',
            ssl_cipher_list => 'ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS',
            allow_weak_ciphers => 0,
            certificate_pinning => 0,
        },
        
        strict => {
            description => 'Strict security with certificate pinning',
            ssl_verify_certificates => 1,
            ssl_verify_hostname => 1,
            ssl_min_version => 'TLSv1_3',
            ssl_cipher_list => 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256',
            allow_weak_ciphers => 0,
            certificate_pinning => 1,
        },
    },
    
    ssl_settings => {
        ca_bundle_path => '',  # Auto-detect system CA bundle
        custom_ca_path => "$CONFIG_DIR/certificates/custom_ca.pem",
        trusted_certs_path => "$CONFIG_DIR/certificates/trusted.pem",
        rejected_certs_path => "$CONFIG_DIR/certificates/rejected.pem",
        client_cert_path => '',
        client_key_path => '',
        verify_depth => 9,
        session_cache => 1,
        session_timeout => 300,
    },
    
    certificate_policies => {
        prompt_on_unknown => 1,
        auto_accept_lan => 0,
        auto_reject_expired => 1,
        auto_reject_weak_keys => 1,
        min_key_size => 2048,
        allowed_signature_algorithms => ['sha256', 'sha384', 'sha512'],
        blocked_signature_algorithms => ['md5', 'sha1'],
    },
    
    authentication => {
        enable_2fa => 0,
        totp_issuer => 'Ásbrú Connection Manager',
        backup_codes_count => 10,
        session_timeout => 3600,
    },
);

=head1 NAME

PACSecurityConfig - Security configuration management for Ásbrú Connection Manager

=head1 DESCRIPTION

This module manages security-related configuration including SSL/TLS settings,
certificate policies, and security profiles. It provides different security
levels from legacy compatibility to strict modern security.

=head1 FUNCTIONS

=head2 load_security_config()

Loads the security configuration from file, creating defaults if needed.

=cut

sub load_security_config {
    # Ensure config directory exists
    make_path($CONFIG_DIR) unless -d $CONFIG_DIR;
    
    # Load existing config or create default
    my $config;
    if (-f $SECURITY_CONFIG_FILE) {
        eval {
            $config = LoadFile($SECURITY_CONFIG_FILE);
        };
        if ($@) {
            warn "Failed to load security config: $@";
            $config = \%DEFAULT_CONFIG;
        }
    } else {
        $config = \%DEFAULT_CONFIG;
        save_security_config($config);
    }
    
    # Merge with defaults to ensure all keys exist
    $config = _merge_config($config, \%DEFAULT_CONFIG);
    
    return $config;
}

=head2 save_security_config($config)

Saves the security configuration to file.

=cut

sub save_security_config {
    my $config = shift;
    
    return 0 unless $config;
    
    # Ensure config directory exists
    make_path($CONFIG_DIR) unless -d $CONFIG_DIR;
    
    eval {
        DumpFile($SECURITY_CONFIG_FILE, $config);
    };
    
    if ($@) {
        warn "Failed to save security config: $@";
        return 0;
    }
    
    return 1;
}

=head2 get_security_profile($profile_name)

Gets the configuration for a specific security profile.

=cut

sub get_security_profile {
    my $profile_name = shift;
    
    my $config = load_security_config();
    $profile_name ||= $config->{security_profile};
    
    return $config->{profiles}{$profile_name} || $config->{profiles}{standard};
}

=head2 set_security_profile($profile_name)

Sets the active security profile.

=cut

sub set_security_profile {
    my $profile_name = shift;
    
    my $config = load_security_config();
    
    # Validate profile exists
    unless (exists $config->{profiles}{$profile_name}) {
        croak "Unknown security profile: $profile_name";
    }
    
    $config->{security_profile} = $profile_name;
    return save_security_config($config);
}

=head2 get_ssl_settings()

Gets the current SSL/TLS settings.

=cut

sub get_ssl_settings {
    my $config = load_security_config();
    my $profile = get_security_profile();
    
    # Merge profile settings with SSL settings
    my %ssl_settings = (
        %{$config->{ssl_settings}},
        %$profile,
    );
    
    return \%ssl_settings;
}

=head2 update_ssl_settings($settings)

Updates SSL/TLS settings.

=cut

sub update_ssl_settings {
    my $settings = shift;
    
    my $config = load_security_config();
    
    # Update SSL settings
    for my $key (keys %$settings) {
        $config->{ssl_settings}{$key} = $settings->{$key};
    }
    
    return save_security_config($config);
}

=head2 is_certificate_validation_enabled()

Checks if certificate validation is enabled in the current profile.

=cut

sub is_certificate_validation_enabled {
    my $profile = get_security_profile();
    return $profile->{ssl_verify_certificates} || 0;
}

=head2 get_cipher_preferences()

Gets the cipher preferences for the current security profile.

=cut

sub get_cipher_preferences {
    my $profile = get_security_profile();
    
    return {
        cipher_list => $profile->{ssl_cipher_list},
        min_version => $profile->{ssl_min_version},
        allow_weak => $profile->{allow_weak_ciphers},
    };
}

=head2 get_certificate_policy()

Gets the certificate validation policy.

=cut

sub get_certificate_policy {
    my $config = load_security_config();
    return $config->{certificate_policies};
}

=head2 update_certificate_policy($policy)

Updates the certificate validation policy.

=cut

sub update_certificate_policy {
    my $policy = shift;
    
    my $config = load_security_config();
    
    # Update certificate policies
    for my $key (keys %$policy) {
        $config->{certificate_policies}{$key} = $policy->{$key};
    }
    
    return save_security_config($config);
}

=head2 get_authentication_settings()

Gets the authentication settings.

=cut

sub get_authentication_settings {
    my $config = load_security_config();
    return $config->{authentication};
}

=head2 is_security_feature_enabled($feature)

Checks if a specific security feature is enabled.

=cut

sub is_security_feature_enabled {
    my $feature = shift;
    
    my $config = load_security_config();
    my $profile = get_security_profile();
    
    # Check in profile first, then in general config
    return $profile->{$feature} if exists $profile->{$feature};
    return $config->{$feature} if exists $config->{$feature};
    
    return 0;  # Default to disabled
}

=head2 get_available_profiles()

Returns a list of available security profiles.

=cut

sub get_available_profiles {
    my $config = load_security_config();
    return keys %{$config->{profiles}};
}

=head2 create_custom_profile($name, $settings)

Creates a new custom security profile.

=cut

sub create_custom_profile {
    my ($name, $settings) = @_;
    
    my $config = load_security_config();
    
    # Validate profile name
    croak "Profile name required" unless $name;
    croak "Profile already exists" if exists $config->{profiles}{$name};
    
    # Merge with standard profile as base
    my $base_profile = $config->{profiles}{standard};
    $config->{profiles}{$name} = { %$base_profile, %$settings };
    
    return save_security_config($config);
}

# Private helper functions

sub _merge_config {
    my ($config, $defaults) = @_;
    
    my %merged = %$defaults;
    
    for my $key (keys %$config) {
        if (ref($config->{$key}) eq 'HASH' && ref($defaults->{$key}) eq 'HASH') {
            $merged{$key} = _merge_config($config->{$key}, $defaults->{$key});
        } else {
            $merged{$key} = $config->{$key};
        }
    }
    
    return \%merged;
}

1;

__END__

=head1 SECURITY PROFILES

The module provides three built-in security profiles:

=head2 Legacy Profile

- Minimal security for compatibility with old systems
- Allows weak ciphers and protocols
- Disables certificate verification
- Use only when necessary for legacy systems

=head2 Standard Profile (Default)

- Modern TLS 1.2+ with strong ciphers
- Certificate verification enabled
- Good balance of security and compatibility
- Recommended for most users

=head2 Strict Profile

- TLS 1.3 only with strongest ciphers
- Certificate pinning enabled
- Maximum security settings
- For high-security environments

=head1 CONFIGURATION FILE

The security configuration is stored in ~/.config/asbru/security.yml
and includes settings for:

- Security profiles
- SSL/TLS configuration
- Certificate policies
- Authentication settings

=head1 AI ASSISTANCE DISCLOSURE

This module was created with AI assistance as part of the Ásbrú Connection
Manager modernization project in 2024.

=cut