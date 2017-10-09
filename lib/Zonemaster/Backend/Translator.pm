package Zonemaster::Backend::Translator;

our $VERSION = '1.1.0';

use 5.14.2;

use Moose;
use Locale::TextDomain 'Zonemaster-Engine';
use Encode;
use POSIX qw[setlocale LC_ALL];

# Zonemaster Modules
require Zonemaster::Engine::Translator;
require Zonemaster::Engine::Logger::Entry;

extends 'Zonemaster::Engine::Translator';

sub translate_tag {
    my ( $self, $entry, $browser_lang ) = @_;

    my $previous_locale = setlocale( LC_ALL );
    if ( $browser_lang eq 'fr' ) {
        setlocale( LC_ALL, "fr_FR.UTF-8" );
    }
    elsif ( $browser_lang eq 'sv' ) {
        setlocale( LC_ALL, "sv_SE.UTF-8" );
    }
    else {
        setlocale( LC_ALL, "en_US.UTF-8" );
    }
    my $string = $self->data->{ $entry->{module} }{ $entry->{tag} };

    if ( not $string ) {
        return $entry->{string};
    }

    my $blessed_entry = bless($entry, 'Zonemaster::Engine::Logger::Entry');
    my $str = decode_utf8( __x( $string, %{ ($blessed_entry->can('printable_args'))?($blessed_entry->printable_args()):($entry->{args}) } ) );
    setlocale( LC_ALL, $previous_locale );

    return $str;
}

1;
