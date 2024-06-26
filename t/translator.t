#!/usr/bin/env perl

use v5.16;
use warnings;
use utf8;

use POSIX qw (setlocale);
use Locale::Messages qw[LC_ALL];
use Test::More;

# Set correct locale for translation in case not set in calling environment
delete $ENV{"LANG"};
delete $ENV{"LANGUAGE"};
delete $ENV{"LC_CTYPE"};
delete $ENV{"LC_MESSAGE"};
setlocale( LC_ALL, "C.UTF-8");

###
### Basic tests
###

BEGIN { use_ok 'Zonemaster::Backend::Translator'; }

isa_ok 'Zonemaster::Backend::Translator', 'Zonemaster::Engine::Translator';

my $translator;

$translator = Zonemaster::Backend::Translator->instance();
isa_ok $translator, 'Zonemaster::Backend::Translator',
    "Zonemaster::Backend::Translator->instance()";

###
### Change locale
###

my $locale = 'fr_FR.UTF-8';
ok( $translator->locale($locale), "Setting locale to '$locale' works" );


# Skip remaining subtests when running on Travis because it was not possible to
# make them pass while passing on tested OSs.
if ( $ENV{"ZONEMASTER_TRAVIS_TESTING"} ) {
    ok( 1, "Remaining subests are skipped on Travis due to issue in Travis" );
    done_testing;
    exit 0;
}

###
### Testing some translations
###

my $message;
my $translation;

$message = {
    module => 'System',
    testcase => 'Unspecified',
    timestamp => '0.000778913497924805',
    level => 'INFO',
    tag => 'GLOBAL_VERSION',
    args => { version => 'v5.0.0' }
};
$translation = $translator->translate_tag($message);
like $translation, qr/\AUtilisation de la version .* du moteur Zonemaster\.\Z/,
    'Translating a GLOBAL_VERSION message tag works';

###
### Test a message translation from Engine with non-ASCII strings
###

$message = {
    module => 'Basic',
    testcase => 'Basic02',
    timestamp => '4.085114956678410350',
    level => 'ERROR',
    tag => 'B02_NS_BROKEN',
    args => { ns => 'ns1.example' }
};
$translation = $translator->translate_tag($message);

like $translation, qr/\ARéponse cassée du serveur de noms /,
    'Translating a B02_NS_BROKEN message works';
like $translation, qr/cass\x{e9}e/,
    'Translation is a string of Unicode codepoints, not bytes';

###
### Test a Backend-specific translation
###

$message = {
    module => 'Backend',
    testcase => '',
    timestamp => '59',
    level => 'CRITICAL',
    tag => 'TEST_DIED',
    args => {}
};
$translation = $translator->translate_tag($message);

like $translation, qr/\AUne erreur est survenue /,
    'Translating a backend-specific TEST_DIED message tag works';

###
### Test a test case translation with non-ASCII strings
###

$translation = $translator->test_case_description( 'Consistency01' );

like $translation, qr/\ACoh\x{e9}rence du num\x{e9}ro de s\x{e9}rie/,
    'Translating Consistency01 gives a string of Unicode codepoints';

done_testing;
