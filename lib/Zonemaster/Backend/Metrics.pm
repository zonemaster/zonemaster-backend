package Zonemaster::Backend::Metrics;

eval("use Net::Statsd");

my $enable_metrics = 0;

if (!$@ && defined $ENV{ZM_STATS_HOST}) {
    $enable_metrics = 1;
    $Net::Statsd::HOST = $ENV{ZM_STATS_HOST};
    $Net::Statsd::PORT = $ENV{ZM_STATS_PORT} // 8125;
}

my %CODE_STATUS_HASH = (
    -32700 => 'RPC_PARSE_ERROR',
    -32600 => 'RPC_INVALID_REQUEST',
    -32601 => 'RPC_METHOD_NOT_FOUND',
    -32602 => 'RPC_INVALID_PARAMS',
    -32603 => 'RPC_INTERNAL_ERROR'
);

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
