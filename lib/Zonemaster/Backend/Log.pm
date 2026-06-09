use strict;
use warnings;

package Zonemaster::Backend::Log;

use English qw( $PID );
use POSIX;
use JSON::PP;
use IO::Handle;
use Log::Any::Adapter::Util ();
use Carp;
use Data::Dumper;

use base qw(Log::Any::Adapter::Base);

my $default_level = Log::Any::Adapter::Util::numeric_level( 'info' );

sub init {
    my ( $self ) = @_;

    if ( defined $self->{log_level} && $self->{log_level} =~ /\D/ ) {
        $self->{log_level} = lc $self->{log_level};
        my $numeric_level = Log::Any::Adapter::Util::numeric_level( $self->{log_level} );
        if ( !defined( $numeric_level ) ) {
            croak "Error: Unrecognized log level " . $self->{log_level} . "\n";
        }
        $self->{log_level} = $numeric_level;
    }

    $self->{log_level} //= $default_level;

    my $fd;
    if ( !exists $self->{file} || $self->{file} eq '-' ) {
        if ( $self->{stderr} ) {
            $fd = fileno( STDERR );
        }
        else {
            $fd = fileno( STDOUT );
        }
    }
    else {
        open( $fd, '>>', $self->{file} ) or croak "Can't open log file: $!";
    }

    $self->{handle} = IO::Handle->new_from_fd( $fd, "w" ) or croak "Can't fdopen file: $!";
    $self->{handle}->autoflush( 1 );

    $self->{with_timestamp} //= 1;
    $self->{with_pid}       //= 1;

    if ( !exists $self->{formatter} ) {
        if ( $self->{json} ) {
            $self->{formatter} = \&format_json;
        }
        else {
            $self->{formatter} = \&format_text;
        }
    }
}

sub format_text {
    my ( $self, $log_params ) = @_;
    my $msg = '';

    my $timestamp = delete $log_params->{timestamp};
    if ( defined $timestamp ) {
        $msg .= sprintf "%s ", $timestamp;
    }

    my $pid = delete $log_params->{pid};
    if ( defined $pid ) {
        $msg .= sprintf "[%d] ", $pid;
    }

    $msg .= sprintf( "[%s] [%s] %s", uc delete $log_params->{level}, delete $log_params->{category}, delete $log_params->{message} );

    if ( %$log_params ) {
        local $Data::Dumper::Indent = 0;
        local $Data::Dumper::Terse  = 1;
        my $data = Dumper( $log_params );

        $msg .= " Extra parameters: $data";
    }

    return $msg;
}

sub format_json {
    my ( $self, $log_params ) = @_;

    my $js = JSON::PP->new;
    $js->canonical( 1 );

    return $js->encode( $log_params );
}

sub structured {
    my ( $self, $level, $category, $string, @items ) = @_;

    my $log_level = Log::Any::Adapter::Util::numeric_level( $level );

    return if $log_level > $self->{log_level};

    my %log_params = (
        level    => $level,
        category => $category,
        message  => $string,
    );

    if ( $self->{with_timestamp} ) {
        $log_params{timestamp} = strftime( "%FT%TZ", gmtime );
    }

    if ( $self->{with_pid} ) {
        $log_params{pid} = $PID;
    }

    for my $item ( @items ) {
        if ( ref( $item ) eq 'HASH' ) {
            for my $key ( keys %$item ) {
                $log_params{$key} = $item->{$key};
            }
        }
    }

    my $msg = $self->{formatter}->( $self, \%log_params );
    $self->{handle}->print( $msg . "\n" );
}

# From Log::Any::Adapter::File
foreach my $method ( Log::Any::Adapter::Util::detection_methods() ) {
    no strict 'refs';
    my $base         = substr( $method, 3 );
    my $method_level = Log::Any::Adapter::Util::numeric_level( $base );
    *{$method} = sub {
        return !!( $method_level <= $_[0]->{log_level} );
    };
}

1;

=head1 NAME

Zonemaster::Backend::Log

=head1 SYNOPSIS

    Log::Any::Adapter->set(
        '+Zonemaster::Backend::Log',
        log_level      => 'info',
        json           => 0,
        file           => '/path/to/logfile.log',
        with_pid       => 1,
        with_timestamp => 1,
    );

=head1 DESCRIPTION

This is an adapter for Log::Any, tailored towards the needs of Zonemaster
Backend.

The following attributes are supported.

=over 4

=item file

A string. The location of the log file to use. Default: C<->.

The special value C<-> sends output to stdout or stderr depending on the
C<stderr> attribute.

=item stderr

A boolean. True means log to stderr. False means log to stdout. Default: false.

Ignored if C<file> is anything other than C<->.

=item log_level

The threshold for emitting log entries. Default: info.

The allowed values are specified at L<Log::Any/LOG-LEVELS>.

=item json

A boolean. When true, logs are written in JSON format. Default: false.

=item with_timestamp

A boolean. Controls the inclusion of timestamp log entries. Default: true.

=item with_pid

A boolean. Controls the inclusion of PID in log entries. Default: true.

=back

=cut
