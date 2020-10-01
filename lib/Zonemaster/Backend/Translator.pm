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
    my ( $self, $hashref, $browser_lang ) = @_;
    my $previous_locale = $self->locale;
    $self->locale( $locale{$browser_lang} );

    # Make locale really be set. Fix that makes translation work on FreeBSD 12.1. Solution copied from
    # CLI.pm in the Zonemaster-CLI repository.
    undef $ENV{LANGUAGE};
    $ENV{LC_ALL} = $self->locale;
    if ( not defined setlocale( LC_MESSAGES, "" ) ) {
        warn sprintf "Warning: setting locale category LC_MESSAGES to %s failed (is it installed on this system?).",
        $ENV{LANGUAGE} || $ENV{LC_ALL} || $ENV{LC_MESSAGES};
    }
    if ( not defined setlocale( LC_CTYPE, "" ) ) {
        warn sprintf "Warning: setting locale category LC_CTYPE to %s failed (is it installed on this system?)." ,
        $ENV{LC_ALL} || $ENV{LC_CTYPE};
    }

    my $entry = Zonemaster::Engine::Logger::Entry->new( %{ $hashref } );
    my $octets = Zonemaster::Engine::Translator::translate_tag( $self, $entry );
    $self->locale( $previous_locale );

    return decode_utf8( $octets );
}

1;
