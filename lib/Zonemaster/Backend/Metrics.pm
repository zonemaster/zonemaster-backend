package Zonemaster::Backend::Metrics;

use Log::Any qw($log);

eval("use Net::Statsd");

my $enable_metrics = 0;

if (!$@) {
    $enable_metrics = 1;
}

my %CODE_STATUS_HASH = (
    -32700 => 'RPC_PARSE_ERROR',
    -32600 => 'RPC_INVALID_REQUEST',
    -32601 => 'RPC_METHOD_NOT_FOUND',
    -32602 => 'RPC_INVALID_PARAMS',
    -32603 => 'RPC_INTERNAL_ERROR'
);

sub setup {
    my ( $cls, $host, $port ) = @_;
    if (!defined $host) {
        $enable_metrics = 0;
    } else {
        $log->info('Enabling metrics module', { host => $host, port => $port });
        $Net::Statsd::HOST = $host;
        $Net::Statsd::PORT = $port;
    }
}

sub code_to_status {
    my ($cls, $code) = @_;
    if (defined $code) {
        return %CODE_STATUS_HASH{$code};
    } else {
        return 'RPC_SUCCESS'
    }
}

sub increment {
    if ( $enable_metrics ) {
        Net::Statsd::increment(@_)
    }
}

sub gauge {
    if ( $enable_metrics ) {
        Net::Statsd::gauge(@_)
    }
}

sub timing {
    if ( $enable_metrics ) {
        Net::Statsd::timing(@_)
    }
}
