package Zonemaster::Backend::Translator;

our $VERSION = '1.1.0';

use 5.14.2;

use Moose;
use Encode;
use POSIX qw[setlocale LC_MESSAGES LC_CTYPE];
use Zonemaster::Backend::Config;

# Zonemaster Modules
require Zonemaster::Engine::Translator;
require Zonemaster::Engine::Logger::Entry;

extends 'Zonemaster::Engine::Translator';

sub translate_tag {
    my ( $self, $hashref ) = @_;

    my $entry = Zonemaster::Engine::Logger::Entry->new( { %{ $hashref } } );
    my $octets = Zonemaster::Engine::Translator::translate_tag( $self, $entry );

    return decode_utf8( $octets );
}

sub test_case_description {
    return decode_utf8(Zonemaster::Engine::Translator::test_case_description(@_));
}
1;
