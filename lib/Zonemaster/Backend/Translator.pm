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
    my ( $self, $entry, $browser_lang ) = @_;
    my %locale = Zonemaster::Backend::Config->load_config()->Language_Locale_hash();
    my $previous_locale = $self->locale;

    if ( $locale{$browser_lang} ) {
        if ( $locale{$browser_lang} eq 'NOT-UNIQUE') {
            die "Language string not unique: '$browser_lang'\n";
        }
        else {
            $self->locale( $locale{$browser_lang} );
        }
    }
    elsif ( $browser_lang eq 'nb' ) {
        $self->locale( "nb_NO.UTF-8" );
    }
    else {
        die "Undefined language string: '$browser_lang'\n";
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
