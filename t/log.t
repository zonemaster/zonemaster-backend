#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use Capture::Tiny qw( capture );
use File::Slurp   qw( slurp );
use File::Temp    qw( tempdir );
use JSON::PP      qw( decode_json );
use Log::Any::Adapter;
use Test::Fatal qw( exception );
use Zonemaster::Backend::Log;

subtest 'render entry in text format' => sub {
    my $stdout = capture {
        my $logger = Zonemaster::Backend::Log->new;
        $logger->structured( 'error', 'unit.test', 'text message', { request_id => 'abc123' }, );
    };

    like $stdout, qr{
        \A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z  # timestamp
        \s+\[\d+\]                              # pid
        \s+\[ERROR\]                            # log level
        \s+\[unit[.]test\]                      # category
        \s+text[ ]message                       # message
    }x, 'text log entry contains timestamp, pid, level, category and message',;

    like $stdout, qr/Extra parameters:/, 'extra parameters are appended';
    like $stdout, qr/request_id/,        'extra parameter key is present';
    like $stdout, qr/abc123/,            'extra parameter value is present';
};

subtest 'render entry in text format without pid' => sub {
    my $stdout = capture {
        my $logger = Zonemaster::Backend::Log->new( with_pid => 0 );
        $logger->structured( 'error', 'unit.test', 'text message', { request_id => 'abc123' }, );
    };

    like $stdout, qr{
        \A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z  # timestamp
                                                # no pid
        \s+\[ERROR\]                            # log level
        \s+\[unit[.]test\]                      # category
        \s+text[ ]message                       # message
    }x, 'text log entry contains timestamp, level, category and message, but no pid',;
};

subtest 'render entry in text format without timestamp' => sub {
    my $stdout = capture {
        my $logger = Zonemaster::Backend::Log->new( with_timestamp => 0 );
        $logger->structured( 'error', 'unit.test', 'text message', { request_id => 'abc123' }, );
    };

    like $stdout, qr{
                            # no timestamp
        \A\[\d+\]           # pid
        \s+\[ERROR\]        # log level
        \s+\[unit[.]test\]  # category
        \s+text[ ]message   # message
    }x, 'text log entry contains pid, level, category and message, but no timestamp',;
};

subtest 'render entry in JSON format' => sub {
    my $stdout = capture {
        my $logger = Zonemaster::Backend::Log->new( json => 1 );
        $logger->structured( 'error', 'unit.test', 'json message', { request_id => 'def456' }, );
    };

    my $entry = decode_json( $stdout );

    is $entry->{level},      'error',        'level is serialized';
    is $entry->{category},   'unit.test',    'category is serialized';
    is $entry->{message},    'json message', 'message is serialized';
    is $entry->{request_id}, 'def456',       'structured data is serialized';

    like $entry->{timestamp}, qr/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, 'timestamp is serialized as UTC ISO-like string';

    is( $entry->{pid}, $$, 'pid is serialized' );
};

subtest 'rejects unknown textual log level' => sub {
    my $error = exception {
        Zonemaster::Backend::Log->new( log_level => 'not-a-level' );
    };

    like $error, qr/Unrecognized log level not-a-level/, 'unknown textual log level dies';
};

subtest 'redirect output to stderr' => sub {
    my ( $stdout, $stderr ) = capture {
        my $logger = Zonemaster::Backend::Log->new( stderr => 1 );
        $logger->structured( 'error', 'unit.test', 'message' );
    };

    is $stdout, '', 'nothing was written to stdout';
    like $stderr, qr/\[ERROR\]/, 'entry was written to stderr';
};

subtest 'redirect output to file' => sub {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = "$dir/backend.log";
    my ( $stdout, $stderr ) = capture {
        my $logger = Zonemaster::Backend::Log->new( file => $file );
        $logger->structured( 'error', 'unit.test', 'message' );
    };
    my $content = slurp( $file );

    is $stdout, '', 'nothing was written to stdout';
    is $stderr, '', 'nothing was written to stderr';
    like $content, qr/\[ERROR\]/, 'entry was written to file';
};

subtest 'works as a Log::Any adapter' => sub {
    Log::Any::Adapter->set(
        { lexically => \my $adapter_scope },
        '+Zonemaster::Backend::Log',
        log_level => 'debug',
        json      => 1,
    );

    my $log = Log::Any->get_logger( category => 'zonemaster.backend.log.test' );

    ok !$log->is_trace, 'trace is disabled through Log::Any';
    ok $log->is_debug,  'debug is enabled through Log::Any';
    ok $log->is_info,   'info is enabled through Log::Any';

    my $stdout = capture {
        $log->info( 'message through Log::Any', { request_id => 'abc123' }, );
    };

    my $entry;
    is
      exception { $entry = decode_json( $stdout ) },
      undef,
      'a single valid JSON value was written';

    is $entry->{level},      'info',                        'Log::Any level reached backend logger';
    is $entry->{category},   'zonemaster.backend.log.test', 'Log::Any category reached backend logger';
    is $entry->{message},    'message through Log::Any',    'message reached backend logger';
    is $entry->{request_id}, 'abc123',                      'structured data reached backend logger';
    is $entry->{pid},        $$,                            'pid was added by backend logger';
    ok $entry->{timestamp}, 'timestamp was added by backend logger';
};

subtest 'Log::Any level detection and filtering use backend log_level' => sub {
    Log::Any::Adapter->set( { lexically => \my $adapter_scope }, '+Zonemaster::Backend::Log', log_level => 'warning', );

    my $log = Log::Any->get_logger( category => 'zonemaster.backend.log.test' );

    ok !$log->is_info, 'info is disabled through Log::Any';
    ok $log->is_error, 'error is enabled through Log::Any';

    my $stdout = capture {
        $log->info( 'filtered message' );
        $log->warn( 'visible message 1' );
        $log->error( 'visible message 2' );
    };

    like $stdout,   qr/\[ERROR\]/,   'error entry was written';
    like $stdout,   qr/\[WARNING\]/, 'warn entry was written';
    unlike $stdout, qr/\[INFO\]/,    'info entry was skipped';
};

done_testing;
