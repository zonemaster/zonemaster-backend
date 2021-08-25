package Zonemaster::Backend::Error;
use Moose;
use Data::Dumper;


has 'message' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'code' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has 'data' => (
    is => 'ro',
    isa => 'Any',
    default => undef,
);

sub as_hash {
    my $self = shift;
    my $error = {
        code => $self->code,
        message => $self->message,
        error => ref($self),
    };
    $error->{data} = $self->data if defined $self->data;
    return $error;
}

sub as_string {
    my $self = shift;
    my $str = sprintf "%s (code %d).", $self->message, $self->code;
    if (defined $self->data) {
        $str .= sprintf " Context: %s", $self->_data_dump;
    }
    return $str;
}

sub _data_dump {
    my $self = shift;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 1;
    my $data = Dumper($self->data);
    $data =~ s/[\n\r]/ /g;
    return $data ;
}

package Zonemaster::Backend::Error::Internal;
use Moose;

extends 'Zonemaster::Backend::Error';

has '+message' => (
    default => 'Internal server error'
);

has '+code' => (
    default => -32603
);

has 'reason' => (
    isa => 'Str',
    is => 'ro'
);

has 'method' => (
    is => 'ro',
    isa => 'Str',
    builder => '_build_method'
);

sub _build_method {
    my $s = 0;
    while (my @c = caller($s)) {
        $s ++;
        last if $c[3] eq 'Moose::Object::new';
    }
    my @c = caller($s);
    if ($c[3] =~ /^(.*)::handle_exception$/ ) {
        @c = caller(++$s);
    }

    return $c[3];
}

around 'BUILDARGS', sub {
    my ($orig, $class, %args) = @_;

    if(exists $args{reason}) {
        # trim new lines
        $args{reason} =~ s/\n/ /g;
        $args{reason} =~ s/^\s+|\s+$//g;
    }

    $class->$orig(%args);
};

sub as_string {
    my $self = shift;
    my $str = sprintf "Caught %s in the `%s` method: %s", ref($self), $self->method, $self->reason;
    if (defined $self->data) {
        $str .= sprintf " Context: %s", $self->_data_dump;
    }
    return $str;
}


package Zonemaster::Backend::Error::ResourceNotFound;
use Moose;

extends 'Zonemaster::Backend::Error';

has '+message' => (
    default => 'Resource not found'
);

has '+code' => (
    default => -32000
);

package Zonemaster::Backend::Error::PermissionDenied;
use Moose;

extends 'Zonemaster::Backend::Error';

has '+message' => (
    default => 'Permission denied'
);

has '+code' => (
    default => -32001
);

package Zonemaster::Backend::Error::Conflict;
use Moose;

extends 'Zonemaster::Backend::Error';

has '+message' => (
    default => 'Conflicting resource'
);

has '+code' => (
    default => -32002
);

package Zonemaster::Backend::Error::JsonError;
use Moose;

extends 'Zonemaster::Backend::Error::Internal';

1;
