use strict;
use warnings;

package Zonemaster::Backend::Log;

use English qw( $PID );
use POSIX;
use JSON::PP;
use Log::Any::Adapter::Util ();
use Carp;
use Data::Dumper;

use base qw(Log::Any::Adapter::Base);


my $trace_level = Log::Any::Adapter::Util::numeric_level('trace');

sub init {
    my ($self) = @_;

    if ( defined $self->{log_level} && $self->{log_level} =~ /\D/ ) {
        $self->{log_level} = lc $self->{log_level};
        my $numeric_level = Log::Any::Adapter::Util::numeric_level( $self->{log_level} );
        if ( !defined($numeric_level) ) {
            croak "Error: Unrecognized log level " . $self->{log_level} . "\n";
        }
        $self->{log_level} = $numeric_level;
    }

    $self->{log_level} //= $trace_level;

    my $fd;
    if ( !exists $self->{file} || $self->{file} eq '-') {
        if ( $self->{stderr} ) {
            open( $fd, '>&', \*STDERR ) or croak "Can't dup STDERR: $!";
        } else {
            open( $fd, '>&', \*STDOUT ) or croak "Can't dup STDOUT: $!";
        }
    } else {
        open( $fd, '>>', $self->{file} ) or croak "Can't open log file: $!";
    }

    $self->{handle} = IO::Handle->new_from_fd( $fd, "w" ) or croak "Can't fdopen file: $!";
    $self->{handle}->autoflush(1);

    if ( !exists $self->{formatter} ) {
        if ( $self->{json} ) {
            $self->{formatter} = \&format_json;
        } else {
            $self->{formatter} = \&format_text;
        }
    }
}

sub format_text {
    my ($self, $log_params) = @_;
    my $msg;
    $msg .= sprintf "%s ", $log_params->{timestamp};
    delete $log_params->{timestamp};
    $msg .= sprintf(
        "[%d] [%s] [%s] %s",
        delete $log_params->{pid},
        uc delete $log_params->{level},
        delete $log_params->{category},
        delete $log_params->{message}
    );

    if ( %$log_params ) {
        local $Data::Dumper::Indent = 0;
        local $Data::Dumper::Terse = 1;
        my $data = Dumper($log_params);

        $msg .= " Extra parameters: $data";
    }

    return $msg
}

sub format_json {
    my ($self, $log_params) = @_;

    my $js = JSON::PP->new;
    $js->canonical( 1 );

    return $js->encode( $log_params );
}


sub structured {
    my ($self, $level, $category, $string, @items) = @_;

    my $log_level = Log::Any::Adapter::Util::numeric_level($level);

    return if $log_level > $self->{log_level};

    my %log_params = (
        timestamp => strftime( "%FT%TZ", gmtime ),
        level => $level,
        category => $category,
        message => $string,
        pid => $PID,
    );

    for my $item ( @items ) {
        if (ref($item) eq 'HASH') {
            for my $key (keys %$item) {
                $log_params{$key} = $item->{$key};
            }
        }
    }

    my $msg = $self->{formatter}->($self, \%log_params);
    $self->{handle}->print($msg . "\n");
}

# From Log::Any::Adapter::File
foreach my $method ( Log::Any::Adapter::Util::detection_methods() ) {
    no strict 'refs';
    my $base = substr($method,3);
    my $method_level = Log::Any::Adapter::Util::numeric_level( $base );
    *{$method} = sub {
        return !!(  $method_level <= $_[0]->{log_level} );
    };
}

1;
