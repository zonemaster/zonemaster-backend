package Zonemaster::Backend::Config::DCPlugin;

use strict;
use warnings;

=head1 NAME

Zonemaster::Backend::Config::DCPlugin - Daemon::Control plugin that
loads the backend configuration.

=head1 SYNOPSIS

Provides validated and sanity-checked backend configuration through the
L<config>, L<db> and L<pm> properties.

    my $daemon = Daemon::Control
        ->with_plugins('+Zonemaster::Backend::Config::DCPlugin')
        ->new({
            program => sub {
                my $self = shift;

                $self->init_backend_config();

                my $config = $self->config;
                my $db     = $self->db;
                my $pm     = $self->pm;
                ...
            },
        });

No configuration is loaded automatically.
Instead a successful call to init_backend_config() is required.

On restart the reload_config() method is called automatically.

=head1 AUTHOR

Mattias P, C<< <mattias.paivarinta@iis.se> >>

=cut

use parent 'Daemon::Control';
use Role::Tiny;    # Must be loaded before Class::Method::Modifiers or it will warn

use Carp;
use Class::Method::Modifiers;
use Hash::Util::FieldHash qw( fieldhash );
use Log::Any qw( $log );
use Zonemaster::Backend::Config;

before do_restart => \&init_backend_config;

# Using the inside-out technique to avoid collisions with other instance
# variables.
fieldhash my %config;
fieldhash my %db;
fieldhash my %pm;

=head1 INSTANCE METHODS

=head2 init_backend_config

Initializes or reinitializes the L<config>, L<db> and L<pm> properties.

A candidate for the L<config> property is either accepted as an argument,
or L<Zonemaster::Backend::Config::load_config> is invoked to provide one.
Candidates for the L<db> and L<pm> properties are constructed according to the
L<config> candidate.

Returns 1 if all candidates are successfully constructed.
In this case all properties are assigned their respective candidate values.

Returns 0 if the construction of any one of the candidates fails.
Details about the construction failure are logged.
None of the properties are updated.

=cut

sub init_backend_config {
    my ( $self, $config_candidate ) = @_;

    eval {
        $config_candidate //= Zonemaster::Backend::Config->load_config();
        my $db_candidate = $config_candidate->new_DB();
        my $pm_candidate = $config_candidate->new_PM();

        $config{$self} = $config_candidate;
        $db{$self}     = $db_candidate;
        $pm{$self}     = $pm_candidate;
    };

    if ( $@ ) {
        $log->warn( "Failed to load the configuration: $@" );
        return 0;
    }

    return 1;
}

=head1 PROPERTIES

=head2 config

Getter for the currently loaded configuration.

Throws an exception if no successful call to init_backend_config() has been
made prior to this call.

=cut

sub config {
    my ( $self ) = @_;

    exists $config{$self} or croak "Not initialized";

    return $config{$self};
}

=head2 db

Getter for a database adapter constructed according to the current
configuration.

Throws an exception if no successful call to init_backend_config() has been
made prior to this call.

=cut

sub db {
    my ( $self ) = @_;

    exists $db{$self} or croak "Not initialized";

    return $db{$self};
}

=head2 pm

Getter for a processing manager constructed according to the current
configuration.

Throws an exception if no successful call to init_backend_config() has been
made prior to this call.

=cut

sub pm {
    my ( $self ) = @_;

    exists $pm{$self} or croak "Not initialized";

    return $pm{$self};
}

1;
