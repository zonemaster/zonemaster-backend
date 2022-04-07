use strict;
use warnings;

package Zonemaster::Backend::Log;

use POSIX;
use JSON::PP;
use Log::Any::Adapter::Util ();
use base qw(Log::Any::Adapter::Base);
use Carp;

my $trace_level = Log::Any::Adapter::Util::numeric_level('trace');

sub init {
    my ($self) = @_;

    if ( exists $self->{log_level} && $self->{log_level} =~ /\D/ ) {
        my $numeric_level = Log::Any::Adapter::Util::numeric_level( $self->{log_level} );
        if ( !defined($numeric_level) ) {
            croak "Error: Unrecognized log level " . $self->{log_level} . "\n";
        }
        $self->{log_level} = $numeric_level;
    }

    if ( !defined $self->{log_level} ) {
        $self->{log_level} = $trace_level;
    }

    my $fd;
    if ( !exists $self->{file} || $self->{file} eq '-') {
        if ( $self->{stderr} ) {
            open( $fd, '>&', \*STDERR ) or die "Can't dup STDERR: $!";
        } else {
            open( $fd, '>&', \*STDOUT ) or die "Can't dup STDOUT: $!";
        }
        my $handle = IO::Handle->new_from_fd( $fd, "w" ) or die "Can't fdopen duplicated STDOUT: $!";
    } else {
        open( $fd, '>>', $self->{file} ) or die "Can't open log file: $!";
    }
    $self->{handle} = IO::Handle->new_from_fd( $fd, "w" ) or die "Can't fdopen file: $!";
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
    if (exists $log_params->{pid}) {
        $msg .= sprintf "[%d] ", $log_params->{pid};
        delete $log_params->{pid};
    }
    $msg .= sprintf "[%s] [%s] %s", uc $log_params->{level}, $log_params->{category}, $log_params->{message};
    delete $log_params->{level};
    delete $log_params->{message};
    delete $log_params->{category};

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
        message => $string
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
