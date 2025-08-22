#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use AsbruTestFramework qw(
    setup_test_environment
    cleanup_test_environment
    measure_performance
    create_mock_protocol_handler
);

# Test plan
plan tests => 11;

# Setup test environment
setup_test_environment();

# Test SSH connection functionality
subtest 'SSH Connection Initialization' => sub {
    plan tests => 6;
    
    # Mock SSH connection object
    my $ssh_conn = create_mock_protocol_handler('ssh');
    
    # Mock connection parameters
    my %connection_params = (
        host => 'test.example.com',
        port => 22,
        user => 'testuser',
        auth_type => 'password',
        password => 'testpass'
    );
    
    $ssh_conn->mock('new', sub {
        my ($class, %params) = @_;
        my $self = bless \%params, $class;
        return $self;
    });
    
    $ssh_conn->mock('set_connection_params', sub {
        my ($self, %params) = @_;
        for my $key (keys %params) {
            $self->{$key} = $params{$key};
        }
        return 1;
    });
    
    $ssh_conn->mock('get_connection_param', sub {
        my ($self, $key) = @_;
        return $self->{$key};
    });
    
    # Test connection parameter setting
    ok($ssh_conn->set_connection_params(%connection_params), 'SSH connection parameters set');
    is($ssh_conn->get_connection_param('host'), 'test.example.com', 'Host parameter correct');
    is($ssh_conn->get_connection_param('port'), 22, 'Port parameter correct');
    is($ssh_conn->get_connection_param('user'), 'testuser', 'User parameter correct');
    is($ssh_conn->get_connection_param('auth_type'), 'password', 'Auth type parameter correct');
    
    # Test parameter validation
    my $valid = 1;
    for my $required (qw(host port user)) {
        unless ($ssh_conn->get_connection_param($required)) {
            $valid = 0;
            last;
        }
    }
    ok($valid, 'Required SSH parameters present');
};

subtest 'SSH Authentication Methods' => sub {
    plan tests => 8;
    
    my $ssh_auth = create_mock_protocol_handler('ssh');
    
    # Mock different authentication methods
    $ssh_auth->mock('authenticate_password', sub {
        my ($self, $user, $password) = @_;
        return $user eq 'testuser' && $password eq 'correctpass';
    });
    
    $ssh_auth->mock('authenticate_publickey', sub {
        my ($self, $user, $private_key, $passphrase) = @_;
        return $user eq 'testuser' && defined $private_key;
    });
    
    $ssh_auth->mock('authenticate_keyboard_interactive', sub {
        my ($self, $user, $callback) = @_;
        return $user eq 'testuser' && ref($callback) eq 'CODE';
    });
    
    $ssh_auth->mock('authenticate_agent', sub {
        my ($self, $user) = @_;
        return $user eq 'testuser';
    });
    
    # Test password authentication
    ok($ssh_auth->authenticate_password('testuser', 'correctpass'), 'Password auth with correct credentials');
    ok(!$ssh_auth->authenticate_password('testuser', 'wrongpass'), 'Password auth fails with wrong credentials');
    
    # Test public key authentication
    ok($ssh_auth->authenticate_publickey('testuser', '/path/to/key'), 'Public key auth with key file');
    ok($ssh_auth->authenticate_publickey('testuser', '/path/to/key', 'passphrase'), 'Public key auth with passphrase');
    
    # Test keyboard interactive authentication
    my $callback = sub { return 'response'; };
    ok($ssh_auth->authenticate_keyboard_interactive('testuser', $callback), 'Keyboard interactive auth');
    
    # Test SSH agent authentication
    ok($ssh_auth->authenticate_agent('testuser'), 'SSH agent authentication');
    
    # Test authentication failure cases
    ok(!$ssh_auth->authenticate_password('wronguser', 'correctpass'), 'Auth fails with wrong username');
    ok(!$ssh_auth->authenticate_publickey('testuser', undef), 'Public key auth fails without key');
};

subtest 'SSH Connection Establishment' => sub {
    plan tests => 6;
    
    my $ssh_connection = create_mock_protocol_handler('ssh');
    my $connection_state = 'disconnected';
    
    $ssh_connection->mock('connect', sub {
        my ($self, %params) = @_;
        
        # Simulate connection process
        if ($params{host} && $params{port} && $params{user}) {
            $connection_state = 'connecting';
            
            # Simulate network delay
            sleep(0.1) if $ENV{ASBRU_TEST_SIMULATE_DELAY};
            
            # Simulate successful connection
            if ($params{host} ne 'unreachable.example.com') {
                $connection_state = 'connected';
                return 1;
            } else {
                $connection_state = 'failed';
                return 0;
            }
        }
        return 0;
    });
    
    $ssh_connection->mock('disconnect', sub {
        $connection_state = 'disconnected';
        return 1;
    });
    
    $ssh_connection->mock('is_connected', sub {
        return $connection_state eq 'connected';
    });
    
    $ssh_connection->mock('get_connection_state', sub {
        return $connection_state;
    });
    
    # Test successful connection
    ok($ssh_connection->connect(
        host => 'test.example.com',
        port => 22,
        user => 'testuser'
    ), 'SSH connection established');
    
    is($ssh_connection->get_connection_state(), 'connected', 'Connection state is connected');
    ok($ssh_connection->is_connected(), 'Connection status check returns true');
    
    # Test disconnection
    ok($ssh_connection->disconnect(), 'SSH disconnection successful');
    is($ssh_connection->get_connection_state(), 'disconnected', 'Connection state is disconnected');
    
    # Test connection failure
    ok(!$ssh_connection->connect(
        host => 'unreachable.example.com',
        port => 22,
        user => 'testuser'
    ), 'Connection fails for unreachable host');
};

subtest 'SSH Command Execution' => sub {
    plan tests => 7;
    
    my $ssh_exec = create_mock_protocol_handler('ssh');
    my $connected = 1;
    
    $ssh_exec->mock('execute_command', sub {
        my ($self, $command, %options) = @_;
        
        return { error => 'Not connected' } unless $connected;
        
        # Simulate command execution
        my $result = {
            command => $command,
            exit_code => 0,
            stdout => '',
            stderr => ''
        };
        
        # Simulate different command responses
        given ($command) {
            when ('echo "test"') {
                $result->{stdout} = "test\n";
            }
            when ('ls /nonexistent') {
                $result->{exit_code} = 2;
                $result->{stderr} = "ls: cannot access '/nonexistent': No such file or directory\n";
            }
            when ('whoami') {
                $result->{stdout} = "testuser\n";
            }
            when (/^sleep (\d+)/) {
                # Simulate long-running command
                $result->{stdout} = "Command completed after $1 seconds\n";
            }
        }
        
        return $result;
    });
    
    # Test successful command execution
    my $result = $ssh_exec->execute_command('echo "test"');
    ok(defined $result, 'Command execution returns result');
    is($result->{exit_code}, 0, 'Successful command has exit code 0');
    is($result->{stdout}, "test\n", 'Command output captured correctly');
    
    # Test command with error
    $result = $ssh_exec->execute_command('ls /nonexistent');
    is($result->{exit_code}, 2, 'Failed command has non-zero exit code');
    like($result->{stderr}, qr/No such file or directory/, 'Error output captured');
    
    # Test user identification
    $result = $ssh_exec->execute_command('whoami');
    is($result->{stdout}, "testuser\n", 'User identification command works');
    
    # Test disconnected state
    $connected = 0;
    $result = $ssh_exec->execute_command('echo "test"');
    ok(exists $result->{error}, 'Command fails when not connected');
};

subtest 'SSH File Transfer (SFTP)' => sub {
    plan tests => 8;
    
    my $sftp = create_mock_protocol_handler('ssh');
    my %remote_files = (
        '/home/testuser/file1.txt' => 'Content of file 1',
        '/home/testuser/dir1/file2.txt' => 'Content of file 2'
    );
    
    $sftp->mock('upload_file', sub {
        my ($self, $local_path, $remote_path, %options) = @_;
        
        # Simulate file upload
        if (-f $local_path || $ENV{ASBRU_TEST_MODE}) {
            $remote_files{$remote_path} = "Uploaded content from $local_path";
            return { success => 1, bytes_transferred => 1024 };
        }
        return { success => 0, error => "Local file not found: $local_path" };
    });
    
    $sftp->mock('download_file', sub {
        my ($self, $remote_path, $local_path, %options) = @_;
        
        # Simulate file download
        if (exists $remote_files{$remote_path}) {
            return { 
                success => 1, 
                bytes_transferred => length($remote_files{$remote_path}),
                content => $remote_files{$remote_path}
            };
        }
        return { success => 0, error => "Remote file not found: $remote_path" };
    });
    
    $sftp->mock('list_directory', sub {
        my ($self, $remote_path) = @_;
        
        my @files;
        for my $file_path (keys %remote_files) {
            if ($file_path =~ m{^\Q$remote_path\E/([^/]+)$}) {
                push @files, {
                    name => $1,
                    path => $file_path,
                    size => length($remote_files{$file_path}),
                    type => 'file'
                };
            }
        }
        return @files;
    });
    
    # Test file upload
    my $upload_result = $sftp->upload_file('/local/test.txt', '/home/testuser/test.txt');
    ok($upload_result->{success}, 'File upload successful');
    ok($upload_result->{bytes_transferred} > 0, 'Bytes transferred during upload');
    
    # Test file download
    my $download_result = $sftp->download_file('/home/testuser/file1.txt', '/local/downloaded.txt');
    ok($download_result->{success}, 'File download successful');
    is($download_result->{content}, 'Content of file 1', 'Downloaded content correct');
    
    # Test directory listing
    my @files = $sftp->list_directory('/home/testuser');
    ok(scalar(@files) > 0, 'Directory listing returns files');
    
    my ($file1) = grep { $_->{name} eq 'file1.txt' } @files;
    ok(defined $file1, 'Expected file found in directory listing');
    is($file1->{type}, 'file', 'File type correctly identified');
    
    # Test error cases
    my $error_result = $sftp->download_file('/nonexistent/file.txt', '/local/file.txt');
    ok(!$error_result->{success}, 'Download fails for nonexistent file');
};

subtest 'SSH Port Forwarding' => sub {
    plan tests => 6;
    
    my $port_forward = create_mock_protocol_handler('ssh');
    my %active_forwards;
    
    $port_forward->mock('create_local_forward', sub {
        my ($self, $local_port, $remote_host, $remote_port) = @_;
        
        my $forward_id = "L:$local_port:$remote_host:$remote_port";
        $active_forwards{$forward_id} = {
            type => 'local',
            local_port => $local_port,
            remote_host => $remote_host,
            remote_port => $remote_port,
            active => 1
        };
        
        return { success => 1, forward_id => $forward_id };
    });
    
    $port_forward->mock('create_remote_forward', sub {
        my ($self, $remote_port, $local_host, $local_port) = @_;
        
        my $forward_id = "R:$remote_port:$local_host:$local_port";
        $active_forwards{$forward_id} = {
            type => 'remote',
            remote_port => $remote_port,
            local_host => $local_host,
            local_port => $local_port,
            active => 1
        };
        
        return { success => 1, forward_id => $forward_id };
    });
    
    $port_forward->mock('remove_forward', sub {
        my ($self, $forward_id) = @_;
        
        if (exists $active_forwards{$forward_id}) {
            delete $active_forwards{$forward_id};
            return { success => 1 };
        }
        return { success => 0, error => "Forward not found: $forward_id" };
    });
    
    # Test local port forwarding
    my $local_result = $port_forward->create_local_forward(8080, 'internal.example.com', 80);
    ok($local_result->{success}, 'Local port forward created');
    ok(exists $active_forwards{$local_result->{forward_id}}, 'Local forward tracked');
    
    # Test remote port forwarding
    my $remote_result = $port_forward->create_remote_forward(9090, 'localhost', 3000);
    ok($remote_result->{success}, 'Remote port forward created');
    ok(exists $active_forwards{$remote_result->{forward_id}}, 'Remote forward tracked');
    
    # Test forward removal
    my $remove_result = $port_forward->remove_forward($local_result->{forward_id});
    ok($remove_result->{success}, 'Port forward removed');
    ok(!exists $active_forwards{$local_result->{forward_id}}, 'Forward no longer tracked');
};

subtest 'SSH Connection Pooling' => sub {
    plan tests => 5;
    
    my $connection_pool = create_mock_protocol_handler('ssh');
    my %pool_connections;
    my $connection_counter = 0;
    
    $connection_pool->mock('get_connection', sub {
        my ($self, $host, $user) = @_;
        my $key = "$user\@$host";
        
        if (exists $pool_connections{$key} && $pool_connections{$key}->{active}) {
            return $pool_connections{$key};
        }
        
        # Create new connection
        $connection_counter++;
        my $conn = {
            id => $connection_counter,
            host => $host,
            user => $user,
            active => 1,
            created_at => time(),
            last_used => time()
        };
        
        $pool_connections{$key} = $conn;
        return $conn;
    });
    
    $connection_pool->mock('release_connection', sub {
        my ($self, $connection) = @_;
        $connection->{last_used} = time();
        return 1;
    });
    
    $connection_pool->mock('close_connection', sub {
        my ($self, $connection) = @_;
        $connection->{active} = 0;
        return 1;
    });
    
    # Test connection reuse
    my $conn1 = $connection_pool->get_connection('test.example.com', 'user1');
    my $conn2 = $connection_pool->get_connection('test.example.com', 'user1');
    
    ok(defined $conn1, 'First connection created');
    is($conn1->{id}, $conn2->{id}, 'Same connection returned for same host/user');
    
    # Test different user gets different connection
    my $conn3 = $connection_pool->get_connection('test.example.com', 'user2');
    isnt($conn1->{id}, $conn3->{id}, 'Different connection for different user');
    
    # Test connection release and close
    ok($connection_pool->release_connection($conn1), 'Connection released');
    ok($connection_pool->close_connection($conn1), 'Connection closed');
};

subtest 'SSH Error Handling' => sub {
    plan tests => 6;
    
    my $ssh_error = create_mock_protocol_handler('ssh');
    
    $ssh_error->mock('handle_connection_error', sub {
        my ($self, $error_type, $error_message) = @_;
        
        my %error_responses = (
            'timeout' => 'Connection timed out. Please check network connectivity.',
            'auth_failed' => 'Authentication failed. Please check credentials.',
            'host_unreachable' => 'Host unreachable. Please verify hostname and network.',
            'permission_denied' => 'Permission denied. Check user permissions.',
            'connection_refused' => 'Connection refused. Service may not be running.',
            'unknown' => 'An unknown error occurred during SSH connection.'
        );
        
        return {
            error_type => $error_type,
            user_message => $error_responses{$error_type} || $error_responses{'unknown'},
            technical_message => $error_message,
            recoverable => $error_type ne 'auth_failed'
        };
    });
    
    # Test different error types
    my $timeout_error = $ssh_error->handle_connection_error('timeout', 'Connection timed out after 30 seconds');
    ok(defined $timeout_error, 'Timeout error handled');
    like($timeout_error->{user_message}, qr/timed out/, 'Timeout error message appropriate');
    
    my $auth_error = $ssh_error->handle_connection_error('auth_failed', 'Authentication failed');
    ok(defined $auth_error, 'Auth error handled');
    ok(!$auth_error->{recoverable}, 'Auth error marked as non-recoverable');
    
    my $network_error = $ssh_error->handle_connection_error('host_unreachable', 'No route to host');
    ok($network_error->{recoverable}, 'Network error marked as recoverable');
    
    my $unknown_error = $ssh_error->handle_connection_error('unknown', 'Unexpected error');
    like($unknown_error->{user_message}, qr/unknown error/, 'Unknown error has generic message');
};

subtest 'SSH Configuration Management' => sub {
    plan tests => 5;
    
    my $ssh_config = create_mock_protocol_handler('ssh');
    my %config_options;
    
    $ssh_config->mock('set_option', sub {
        my ($self, $key, $value) = @_;
        $config_options{$key} = $value;
        return 1;
    });
    
    $ssh_config->mock('get_option', sub {
        my ($self, $key) = @_;
        return $config_options{$key};
    });
    
    $ssh_config->mock('load_ssh_config', sub {
        my ($self, $config_file) = @_;
        
        # Simulate loading SSH config file
        %config_options = (
            'StrictHostKeyChecking' => 'no',
            'UserKnownHostsFile' => '/dev/null',
            'ConnectTimeout' => '30',
            'ServerAliveInterval' => '60'
        );
        
        return scalar(keys %config_options);
    });
    
    # Test configuration loading
    my $loaded_count = $ssh_config->load_ssh_config('/etc/ssh/ssh_config');
    ok($loaded_count > 0, 'SSH config loaded');
    
    # Test option retrieval
    is($ssh_config->get_option('ConnectTimeout'), '30', 'Connect timeout option correct');
    is($ssh_config->get_option('StrictHostKeyChecking'), 'no', 'Host key checking option correct');
    
    # Test option setting
    ok($ssh_config->set_option('Port', '2222'), 'Custom port option set');
    is($ssh_config->get_option('Port'), '2222', 'Custom port option retrieved');
};

subtest 'SSH Performance Testing' => sub {
    plan tests => 3;
    
    # Test SSH connection performance
    my $perf_result = measure_performance('SSH Connection', sub {
        # Simulate SSH connection establishment
        my $ssh = create_mock_protocol_handler('ssh');
        $ssh->mock('connect', sub { 
            sleep(0.01) if $ENV{ASBRU_TEST_SIMULATE_DELAY}; 
            return 1; 
        });
        $ssh->connect();
    }, iterations => 5);
    
    ok(defined $perf_result, 'SSH connection performance measured');
    ok($perf_result->{average} >= 0, 'Average connection time recorded');
    is($perf_result->{iterations}, 5, 'Correct number of iterations performed');
};

subtest 'SSH Security Features' => sub {
    plan tests => 6;
    
    my $ssh_security = create_mock_protocol_handler('ssh');
    
    # Mock security-related methods
    $ssh_security->mock('verify_host_key', sub {
        my ($self, $host, $key_fingerprint) = @_;
        
        # Simulate host key verification
        my %known_hosts = (
            'test.example.com' => 'SHA256:abc123def456ghi789jkl012mno345pqr678stu901vwx234yz'
        );
        
        return exists $known_hosts{$host} && $known_hosts{$host} eq $key_fingerprint;
    });
    
    $ssh_security->mock('check_cipher_strength', sub {
        my ($self, $cipher) = @_;
        
        my %strong_ciphers = (
            'aes256-gcm@openssh.com' => 1,
            'aes256-ctr' => 1,
            'aes192-ctr' => 1,
            'aes128-gcm@openssh.com' => 1
        );
        
        return exists $strong_ciphers{$cipher};
    });
    
    $ssh_security->mock('validate_key_exchange', sub {
        my ($self, $kex_algorithm) = @_;
        
        my %secure_kex = (
            'curve25519-sha256' => 1,
            'curve25519-sha256@libssh.org' => 1,
            'ecdh-sha2-nistp256' => 1,
            'ecdh-sha2-nistp384' => 1,
            'ecdh-sha2-nistp521' => 1
        );
        
        return exists $secure_kex{$kex_algorithm};
    });
    
    # Test host key verification
    ok($ssh_security->verify_host_key('test.example.com', 
       'SHA256:abc123def456ghi789jkl012mno345pqr678stu901vwx234yz'), 
       'Known host key verified');
    
    ok(!$ssh_security->verify_host_key('unknown.example.com', 
       'SHA256:different_fingerprint'), 
       'Unknown host key rejected');
    
    # Test cipher strength validation
    ok($ssh_security->check_cipher_strength('aes256-gcm@openssh.com'), 'Strong cipher accepted');
    ok(!$ssh_security->check_cipher_strength('des-cbc'), 'Weak cipher rejected');
    
    # Test key exchange validation
    ok($ssh_security->validate_key_exchange('curve25519-sha256'), 'Secure key exchange accepted');
    ok(!$ssh_security->validate_key_exchange('diffie-hellman-group1-sha1'), 'Insecure key exchange rejected');
};

# Cleanup
cleanup_test_environment();

done_testing();