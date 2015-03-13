package Zonemaster::WebBackend::Translator;

our $VERSION = '1.0.1';

use 5.14.0;

use Moose;
use Locale::TextDomain 'Zonemaster';
use Encode;
use POSIX qw[setlocale LC_ALL];

# Zonemaster Modules
require Zonemaster::Translator;

extends 'Zonemaster::Translator';

sub translate_tag {
    my ( $self, $entry, $browser_lang ) = @_;

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

    my $str = decode_utf8( __x( $string, %{ $entry->{args} } ) );

    #	my $str = __x( $string, %{ $entry->{args} } );
    #	my $translated_string = __x( $string, %{ $entry->{args} } );
    #	say STDERR Dumper($translated_string);
    #	my $str = decode('iso-8859-1', $translated_string);

    return $str;
}

1;
