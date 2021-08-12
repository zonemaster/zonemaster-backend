package Zonemaster::Backend::Error;
use Moose;
use Data::Dumper;


has 'message' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'code' => (
    is => 'rw',
    isa => 'Int',
    required => 1,
);

has 'data' => (
    is => 'rw',
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
    my $str = sprintf "%s (code %d)", $self->message, $self->code;
    if (defined $self->data) {
        $str .= sprintf "; Context: %s", $self->_data_dump;
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
    is => 'rw',
    initializer => 'reason',
);

has 'method' => (
    is => 'rw',
    isa => 'Str',
    builder => '_build_method'
);

has 'id' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
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

around 'reason' => sub {
    my $orig = shift;
    my $self = shift;

    my ( $value, $setter, $attr ) = @_;

    # reader
    return $self->$orig if not $value;

    # trim new lines
    $value =~ s/\n/ /g;
    $value =~ s/^\s+|\s+$//g;

    # initializer
    return $setter->($value) if $setter;

    # writer
    $self->$orig($value);
};

around 'as_hash' => sub {
    my $orig = shift;
    my $self = shift;

    my $href = $self->$orig;

    $href->{exception_id} = $self->id;
    $href->{reason} = $self->reason;
    $href->{method} = $self->method;

    return $href;
};


sub as_string {
    my $self = shift;
    my $str = sprintf "Internal error %0.3d (%s): Unexpected error in the `%s` method: [%s]", $self->id, ref($self), $self->method, $self->reason;
    if (defined $self->data) {
        $str .= sprintf "; Context: %s", $self->_data_dump;
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

package Zonemaster::Backend::Error::JsonError;
use Moose;

extends 'Zonemaster::Backend::Error::Internal';

1;
