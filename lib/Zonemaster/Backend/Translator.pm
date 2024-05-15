package Zonemaster::Backend::Translator;

our $VERSION = '1.1.0';

use 5.14.2;

use Moose;
use Encode;
use Readonly;
use POSIX qw[setlocale LC_MESSAGES LC_CTYPE];
use Locale::TextDomain qw[Zonemaster-Backend];
use Zonemaster::Backend::Config;

# Zonemaster Modules
require Zonemaster::Engine::Translator;
require Zonemaster::Engine::Logger::Entry;

extends 'Zonemaster::Engine::Translator';

Readonly my %TAG_DESCRIPTIONS => (
    TEST_DIED => sub {
        __x    # BACKEND_TEST_AGENT:TEST_DIED
          'An error occured and Zonemaster could not start or finish the test.', @_;
    },
    UNABLE_TO_FINISH_TEST => sub {
        __x    # BACKEND_TEST_AGENT:UNABLE_TO_FINISH_TEST
          'The test took too long to run (the current limit is {max_execution_time} seconds). '
          . 'Maybe there are too many name servers or the name servers are either unreachable or not responsive enough.', @_;
    },
);

sub _build_all_tag_descriptions {
    my ( $class ) = @_;

    my $all_tag_descriptions = Zonemaster::Engine::Translator::_build_all_tag_descriptions();
    $all_tag_descriptions->{Backend_Test_Agent} = \%TAG_DESCRIPTIONS;
    return $all_tag_descriptions;
}

sub translate_tag {
    my ( $self, $hashref ) = @_;

    my $entry = Zonemaster::Engine::Logger::Entry->new( { %{ $hashref } } );

    return decode_utf8( $self->SUPER::translate_tag( $entry ) );
}

sub test_case_description {
    my ( $self, $test_name ) = @_;

    return decode_utf8( $self->SUPER::test_case_description( $test_name ) );
}

1;
