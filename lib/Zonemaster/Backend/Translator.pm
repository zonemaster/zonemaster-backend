package Zonemaster::Backend::Translator;

our $VERSION = '1.1.0';

use 5.14.2;

use Moose;
use Encode;
use POSIX qw[setlocale LC_MESSAGES LC_CTYPE];

# Zonemaster Modules
require Zonemaster::Engine::Translator;
require Zonemaster::Engine::Logger::Entry;

extends 'Zonemaster::Engine::Translator';

sub translate_tag {
    my ( $self, $entry, $browser_lang ) = @_;

    my $previous_locale = $self->locale;
    if ( $browser_lang eq 'fr' ) {
        $self->locale( "fr_FR.UTF-8" );
    }
    elsif ( $browser_lang eq 'sv' ) {
        $self->locale( "sv_SE.UTF-8" );
    }
    elsif ( $browser_lang eq 'da' ) {
        $self->locale( "da_DK.UTF-8" );
    }
    else {
        $self->locale( "en_US.UTF-8" );
    }

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

    my $string = $self->data->{ $entry->{module} }{ $entry->{tag} };

    if ( not $string ) {
        return $entry->{string};
    }

    my $blessed_entry = bless($entry, 'Zonemaster::Engine::Logger::Entry');
    my $octets = Zonemaster::Engine::Translator::translate_tag( $self, $blessed_entry );
    $self->locale( $previous_locale );
    my $str = decode_utf8( $octets );
    return $str;
}

1;
