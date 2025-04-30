#!/usr/bin/env perl
use v5.16;
use warnings;
use utf8;
use Test::More;

use Locale::Messages qw( LC_ALL );
use POSIX            qw( setlocale );

BEGIN {
    # Set correct locale for translation in case not set in calling environment
    delete $ENV{"LANG"};
    delete $ENV{"LANGUAGE"};
    delete $ENV{"LC_CTYPE"};
    delete $ENV{"LC_MESSAGES"};
    setlocale( LC_ALL, "C.UTF-8" );

    use_ok( 'Zonemaster::Backend::Translator' )
      or BAIL_OUT "Cannot continue without translator module";
}

my $translator = Zonemaster::Backend::Translator->instance();
isa_ok $translator, 'Zonemaster::Backend::Translator', "Zonemaster::Backend::Translator->instance()"
  or BAIL_OUT "Cannot continue without a translator instance";

subtest 'Basic tests' => sub {
    isa_ok 'Zonemaster::Backend::Translator', 'Zonemaster::Engine::Translator';

    my $locale = 'fr_FR.UTF-8';
    ok( $translator->locale( $locale ), "Setting locale to '$locale' works" );
};

subtest 'Testing some translations' => sub {
    my $message = {
        module    => 'System',
        testcase  => 'Unspecified',
        timestamp => '0.000778913497924805',
        level     => 'INFO',
        tag       => 'GLOBAL_VERSION',
        args      => { version => 'v5.0.0' }
    };
    my $translation = $translator->translate_tag( $message );
    like $translation, qr/\AUtilisation de la version .* du moteur Zonemaster\.\Z/, 'Translating a GLOBAL_VERSION message tag works';
};

subtest 'Test a message translation from Engine with non-ASCII strings' => sub {
    my $message = {
        module    => 'Basic',
        testcase  => 'Basic02',
        timestamp => '4.085114956678410350',
        level     => 'ERROR',
        tag       => 'B02_NS_BROKEN',
        args      => { ns => 'ns1.example' }
    };
    my $translation = $translator->translate_tag( $message );

    like $translation, qr/\ARéponse cassée du serveur de noms /, 'Translating a B02_NS_BROKEN message works';
    like $translation, qr/cass\x{e9}e/,                          'Translation is a string of Unicode codepoints, not bytes';
};

subtest 'Test a Backend-specific translation' => sub {
    my $message = {
        module    => 'Backend',
        testcase  => '',
        timestamp => '59',
        level     => 'CRITICAL',
        tag       => 'TEST_DIED',
        args      => {}
    };
    my $translation = $translator->translate_tag( $message );

    like $translation, qr/\AUne erreur est survenue /, 'Translating a backend-specific TEST_DIED message tag works';
};

subtest 'Test a test case translation with non-ASCII strings' => sub {
    my $translation = $translator->test_case_description( 'Consistency01' );

    like $translation, qr/\ACoh\x{e9}rence du num\x{e9}ro de s\x{e9}rie/, 'Translating Consistency01 gives a string of Unicode codepoints';
};

done_testing;
