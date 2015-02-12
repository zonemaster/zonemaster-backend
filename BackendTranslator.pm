package BackendTranslator;

use 5.14.0;

use Moose;
use Locale::TextDomain 'Zonemaster';
use Encode;
use Data::Dumper;
use POSIX qw[setlocale LC_ALL];

use FindBin qw($RealScript $Script $RealBin $Bin);
##################################################################
my $PROJECT_NAME = "zonemaster-backend";

my $SCRITP_DIR = __FILE__;
$SCRITP_DIR = $Bin unless ($SCRITP_DIR =~ /^\//);

#warn "SCRITP_DIR:$SCRITP_DIR\n";
#warn "RealScript:$RealScript\n";
#warn "Script:$Script\n";
#warn "RealBin:$RealBin\n";
#warn "Bin:$Bin\n";
#warn "__PACKAGE__:".__PACKAGE__;
#warn "__FILE__:".__FILE__;

my ($PROD_DIR) = ($SCRITP_DIR =~ /(.*?\/)$PROJECT_NAME/);
#warn "PROD_DIR:$PROD_DIR\n";

my $PROJECT_BASE_DIR = $PROD_DIR.$PROJECT_NAME."/";
#warn "PROJECT_BASE_DIR:$PROJECT_BASE_DIR\n";
unshift(@INC, $PROJECT_BASE_DIR);
##################################################################

unshift(@INC, $PROD_DIR."Zonemaster/lib") unless $INC{$PROD_DIR."Zonemaster/lib"};
# Zonemaster Modules
require Zonemaster::Translator;

extends 'Zonemaster::Translator';

sub translate_tag {
    my ( $self, $entry, $browser_lang ) = @_;

    if ($browser_lang eq 'fr') {
       setlocale( LC_ALL, "fr_FR.UTF-8" );
    }
    elsif ($browser_lang eq 'sv') {
       setlocale( LC_ALL, "sv_SE.UTF-8" );
    }
    else {
       setlocale( LC_ALL, "en_US.UTF-8" );
    }

    my $string = $self->data->{ $entry->{module} }{ $entry->{tag} };

    if ( not $string ) {
        return $entry->{string};
    }

	my $str = decode_utf8(__x( $string, %{ $entry->{args} } ));
#	my $str = __x( $string, %{ $entry->{args} } );
#	my $translated_string = __x( $string, %{ $entry->{args} } );
#	say STDERR Dumper($translated_string);
#	my $str = decode('iso-8859-1', $translated_string);

	return $str;
}

1;
