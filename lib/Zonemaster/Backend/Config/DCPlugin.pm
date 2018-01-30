package Zonemaster::Backend::Config::DCPlugin;

use strict;
use warnings;

=head1 NAME

Zonemaster::Backend::Config::DCPlugin - Daemon::Control plugin that
loads the backend configuration.

=head1 SYNOPSIS

Provides validated and sanity-checked backend configuration through the L<config> property.

    my $daemon = Daemon::Control
        ->with_plugins('+Zonemaster::Backend::Config::DCPlugin')
        ->new({
            program => sub {
                my $self = shift;
                my $db   = $self->config->{db};
                ...
            },
        });

The configuration is loaded on start and restart. The start/restart
is aborted if the configuration fails the validity- and sanity check.
In case of the database configuration, sanity is checked by actually
connecting to the database.

=head1 AUTHOR

Mattias P, C<< <mattias.paivarinta@iis.se> >>

=cut

use parent 'Daemon::Control';

use Role::Tiny;
use Class::Method::Modifiers;
use Zonemaster::Backend::Config;

before do_start   => \&_load_config;
before do_restart => \&_load_config;

=head1 CLASS VARIABLES

=head2 %config

The loaded configuration.

=cut

our %config;

=head1 PROPERTIES

=head2 config

The loaded configuration.

A hashref with the following keys.

=over 4

=item db

A L<Zonemaster::Backned::DB> object. It's been able to connect to
the database at least once.

=back

=cut

sub config {
    return { %config };
};

=head1 PRIVATE METHODS

=head2 _load_config

Checks if the configuration has been loaded before, and delegates
to _load_config otherwise.

=cut

sub _load_config {
    _do_load_config() if !%config;
}

=head2 _do_load_config

Loads, validates and sanity-checks the backend configuration.

=cut

sub _do_load_config {
    %config = ( db => Zonemaster::Backend::Config->new_DB() );
}

1;
