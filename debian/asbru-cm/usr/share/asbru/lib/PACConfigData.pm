package PACConfigData;

# Modern configuration and data handling for Ásbrú Connection Manager
# Enhanced YAML processing and secure data serialization
# AI-assisted modernization - 2024

use strict;
use warnings;

use YAML::XS;  # Faster and more secure than YAML
use Storable qw(dclone nstore retrieve);
use JSON::PP;  # Alternative serialization format
use File::Spec;
use File::Basename;
use Carp;

# Export functions
use Exporter 'import';
our @EXPORT_OK = qw(
    load_yaml_config save_yaml_config
    load_config save_config
    clone_data serialize_data deserialize_data
    validate_config_structure
    migrate_config_format
);

=head1 NAME

PACConfigData - Modern configuration and data handling for Ásbrú Connection Manager

=head1 DESCRIPTION

This module provides enhanced configuration file handling with improved YAML
processing, data validation, and secure serialization capabilities.

=head1 FUNCTIONS

=head2 load_yaml_config($file_path)

Loads a YAML configuration file with enhanced error handling and validation.

=cut

sub load_yaml_config {
    my $file_path = shift;
    
    return undef unless defined $file_path && -f $file_path;
    
    my $config;
    eval {
        # Use YAML::XS for better performance and security
        $config = YAML::XS::LoadFile($file_path);
    };
    
    if ($@) {
        warn "Failed to load YAML config from '$file_path': $@";
        return undef;
    }
    
    # Validate basic structure
    return validate_config_structure($config) ? $config : undef;
}

=head2 save_yaml_config($config, $file_path)

Saves configuration data to a YAML file with backup and atomic write.

=cut

sub save_yaml_config {
    my ($config, $file_path) = @_;
    
    return 0 unless defined $config && defined $file_path;
    
    # Create backup if file exists
    if (-f $file_path) {
        my $backup_path = "$file_path.backup." . time();
        unless (rename $file_path, $backup_path) {
            warn "Failed to create backup: $!";
            return 0;
        }
    }
    
    # Atomic write using temporary file
    my $temp_path = "$file_path.tmp.$$";
    
    eval {
        # Add modernization metadata
        my $config_with_meta = _add_modernization_metadata($config);
        
        YAML::XS::DumpFile($temp_path, $config_with_meta);
        
        # Atomic move
        unless (rename $temp_path, $file_path) {
            die "Failed to move temporary file: $!";
        }
        
        return 1;
    };
    
    if ($@) {
        warn "Failed to save YAML config to '$file_path': $@";
        unlink $temp_path if -f $temp_path;
        return 0;
    }
}

=head2 load_config($file_path, $format)

Loads configuration in multiple formats (yaml, json, storable).

=cut

sub load_config {
    my ($file_path, $format) = @_;
    
    $format //= _detect_format($file_path);
    
    if ($format eq 'yaml' || $format eq 'yml') {
        return load_yaml_config($file_path);
    } elsif ($format eq 'json') {
        return _load_json_config($file_path);
    } elsif ($format eq 'storable') {
        return _load_storable_config($file_path);
    }
    
    warn "Unsupported config format: $format";
    return undef;
}

=head2 save_config($config, $file_path, $format)

Saves configuration in multiple formats.

=cut

sub save_config {
    my ($config, $file_path, $format) = @_;
    
    $format //= _detect_format($file_path);
    
    if ($format eq 'yaml' || $format eq 'yml') {
        return save_yaml_config($config, $file_path);
    } elsif ($format eq 'json') {
        return _save_json_config($config, $file_path);
    } elsif ($format eq 'storable') {
        return _save_storable_config($config, $file_path);
    }
    
    warn "Unsupported config format: $format";
    return 0;
}

=head2 clone_data($data)

Creates a deep clone of data structures with enhanced safety.

=cut

sub clone_data {
    my $data = shift;
    
    return undef unless defined $data;
    
    # Use Storable's dclone for deep copying
    my $result = eval {
        dclone($data);
    };
    
    if ($@) {
        warn "Failed to clone data: $@";
        return undef;
    }
    
    return $result;
}

=head2 validate_config_structure($config)

Validates the basic structure of an Ásbrú configuration.

=cut

sub validate_config_structure {
    my $config = shift;
    
    return 0 unless ref $config eq 'HASH';
    
    # Check for required top-level keys
    my @required_keys = qw(defaults environments);
    
    for my $key (@required_keys) {
        return 0 unless exists $config->{$key};
    }
    
    # Validate defaults structure
    return 0 unless ref $config->{defaults} eq 'HASH';
    
    # Validate environments structure
    return 0 unless ref $config->{environments} eq 'HASH';
    
    return 1;
}

=head2 migrate_config_format($old_config)

Migrates configuration from older formats to modern structure.

=cut

sub migrate_config_format {
    my $old_config = shift;
    
    return undef unless defined $old_config;
    
    # Clone to avoid modifying original
    my $new_config = clone_data($old_config);
    
    # Add modernization metadata if not present
    $new_config = _add_modernization_metadata($new_config);
    
    # Perform any necessary structure migrations
    $new_config = _migrate_security_settings($new_config);
    $new_config = _migrate_display_settings($new_config);
    
    return $new_config;
}

# Private helper functions

sub _detect_format {
    my $file_path = shift;
    
    my ($name, $path, $suffix) = fileparse($file_path, qr/\.[^.]*/);
    
    return 'yaml' if $suffix =~ /\.ya?ml$/i;
    return 'json' if $suffix =~ /\.json$/i;
    return 'storable' if $suffix =~ /\.(?:stor|dat)$/i;
    
    # Default to YAML
    return 'yaml';
}

sub _load_json_config {
    my $file_path = shift;
    
    eval {
        open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot open file: $!";
        local $/;
        my $json_text = <$fh>;
        close $fh;
        
        my $json = JSON::PP->new->utf8->relaxed;
        return $json->decode($json_text);
    };
    
    if ($@) {
        warn "Failed to load JSON config: $@";
        return undef;
    }
}

sub _save_json_config {
    my ($config, $file_path) = @_;
    
    eval {
        my $json = JSON::PP->new->utf8->pretty->canonical;
        my $json_text = $json->encode($config);
        
        open my $fh, '>:encoding(UTF-8)', $file_path or die "Cannot open file: $!";
        print $fh $json_text;
        close $fh;
        
        return 1;
    };
    
    if ($@) {
        warn "Failed to save JSON config: $@";
        return 0;
    }
}

sub _load_storable_config {
    my $file_path = shift;
    
    eval {
        return retrieve($file_path);
    };
    
    if ($@) {
        warn "Failed to load Storable config: $@";
        return undef;
    }
}

sub _save_storable_config {
    my ($config, $file_path) = @_;
    
    eval {
        nstore($config, $file_path);
        return 1;
    };
    
    if ($@) {
        warn "Failed to save Storable config: $@";
        return 0;
    }
}

sub _add_modernization_metadata {
    my $config = shift;
    
    # Add modernization information
    $config->{defaults}{modernization_info} = {
        ai_assisted => 1,
        migration_date => _get_current_date(),
        crypto_version => '2.0',  # AES-256-GCM
        config_version => '7.0.0',
    } unless exists $config->{defaults}{modernization_info};
    
    return $config;
}

sub _migrate_security_settings {
    my $config = shift;
    
    # Add modern security profile if not present
    $config->{defaults}{security_profile} = 'modern'
        unless exists $config->{defaults}{security_profile};
    
    # Migrate any old encryption settings
    if (exists $config->{defaults}{encryption_method} && 
        $config->{defaults}{encryption_method} eq 'blowfish') {
        $config->{defaults}{encryption_method} = 'aes-256-gcm';
        $config->{defaults}{migration_required} = 1;
    }
    
    return $config;
}

sub _migrate_display_settings {
    my $config = shift;
    
    # Add modern display server detection
    $config->{defaults}{display_server} = 'auto'
        unless exists $config->{defaults}{display_server};
    
    $config->{defaults}{desktop_environment} = 'auto'
        unless exists $config->{defaults}{desktop_environment};
    
    return $config;
}

sub _get_current_date {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
    return sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
}

=head2 serialize_data($data, $format)

Serializes data to string format (json, yaml, storable).

=cut

sub serialize_data {
    my ($data, $format) = @_;
    
    $format //= 'yaml';
    
    if ($format eq 'yaml') {
        return YAML::XS::Dump($data);
    } elsif ($format eq 'json') {
        my $json = JSON::PP->new->utf8->pretty->canonical;
        return $json->encode($data);
    } elsif ($format eq 'storable') {
        return Storable::freeze($data);
    }
    
    warn "Unsupported serialization format: $format";
    return undef;
}

=head2 deserialize_data($serialized_data, $format)

Deserializes data from string format.

=cut

sub deserialize_data {
    my ($serialized_data, $format) = @_;
    
    $format //= 'yaml';
    
    eval {
        if ($format eq 'yaml') {
            return YAML::XS::Load($serialized_data);
        } elsif ($format eq 'json') {
            my $json = JSON::PP->new->utf8->relaxed;
            return $json->decode($serialized_data);
        } elsif ($format eq 'storable') {
            return Storable::thaw($serialized_data);
        }
    };
    
    if ($@) {
        warn "Failed to deserialize data: $@";
        return undef;
    }
    
    warn "Unsupported deserialization format: $format";
    return undef;
}

1;

__END__

=head1 MIGRATION NOTES

This module enhances the existing YAML and Storable functionality:

- YAML → YAML::XS (faster, more secure)
- Enhanced error handling and validation
- Atomic file operations with backup
- Multi-format support (YAML, JSON, Storable)
- Configuration structure validation
- Automatic modernization metadata

=head1 CONFIGURATION STRUCTURE

The module expects Ásbrú configuration files to have this basic structure:

```yaml
defaults:
  version: "7.0.0"
  # ... other default settings
environments:
  uuid1:
    name: "Connection Name"
    # ... connection settings
```

=head1 AI ASSISTANCE DISCLOSURE

This module was created with AI assistance as part of the Ásbrú Connection
Manager modernization project in 2024. All configuration handling follows
current best practices for data integrity and security.

=cut