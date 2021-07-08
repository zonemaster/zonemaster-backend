package Zonemaster::Backend::Validator;

our $VERSION = '0.1.0';

use strict;
use warnings;
use 5.14.2;

use Exporter qw( import );
use File::Spec::Functions qw( file_name_is_absolute );
use JSON::Validator::Joi;
use Readonly;
use Zonemaster::Engine::Net::IP;

our @EXPORT_OK = qw(
  untaint_abs_path
  untaint_engine_type
  untaint_ip_address
  untaint_ipv4_address
  untaint_ipv6_address
  untaint_host
  untaint_ldh_domain
  untaint_locale_tag
  untaint_mariadb_database
  untaint_mariadb_user
  untaint_non_negative_int
  untaint_password
  untaint_postgresql_ident
  untaint_profile_name
  untaint_strictly_positive_int
  untaint_strictly_positive_millis
);

our %EXPORT_TAGS = (
    untaint => [
        qw(
          untaint_abs_path
          untaint_engine_type
          untaint_ip_address
          untaint_ipv4_address
          untaint_ipv6_address
          untaint_host
          untaint_ldh_domain
          untaint_locale_tag
          untaint_mariadb_database
          untaint_mariadb_user
          untaint_non_negative_int
          untaint_password
          untaint_postgresql_ident
          untaint_profile_name
          untaint_strictly_positive_int
          untaint_strictly_positive_millis
          )
    ],
);

# Does not check value ranges within the groups
Readonly my $IPV4_RE => qr/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/;

# Does not check the length and number of the hex groups, nor the value ranges in the IPv4 groups
Readonly my $IPV6_RE => qr/^[0-9a-f:]*:[0-9a-f:]+(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?$/i;

Readonly my $API_KEY_RE                 => qr/^[a-z0-9-_]{1,512}$/i;
Readonly my $CLIENT_ID_RE               => qr/^[a-z0-9-+~_.: ]{1,50}$/i;
Readonly my $CLIENT_VERSION_RE          => qr/^[a-z0-9-+~_.: ]{1,50}$/i;
Readonly my $DIGEST_RE                  => qr/^[a-f0-9]{40}$|^[a-f0-9]{64}$|^[a-f0-9]{96}$/i;
Readonly my $ENGINE_TYPE_RE             => qr/^(?:mysql|postgresql|sqlite)$/i;
Readonly my $IPADDR_RE                  => qr/^$|$IPV4_RE|$IPV6_RE/;
Readonly my $JSONRPC_METHOD_RE          => qr/^[a-z0-9_-]*$/i;
Readonly my $LANGUAGE_RE                => qr/^[a-z]{2}(_[A-Z]{2})?$/;
Readonly my $LDH_DOMAIN_RE1             => qr{^[a-z0-9-.]{1,253}[.]?$}i;
Readonly my $LDH_DOMAIN_RE2             => qr{^(?:[.]|[^.]{1,63}(?:[.][^.]{1,63})*[.]?)$};
Readonly my $LOCALE_TAG_RE              => qr/^[a-z]{2}_[A-Z]{2}$/;
Readonly my $MARIADB_DATABASE_LENGTH_RE => qr/^.{1,64}$/;

# See: https://mariadb.com/kb/en/identifier-names/#unquoted
Readonly my $MARIADB_IDENT_RE       => qr/^[0-9a-z\$_]+$/i;
Readonly my $MARIADB_USER_LENGTH_RE => qr/^.{1,80}$/u;

# Up to 5 and 3 digits in the integer and fraction components respectively
Readonly my $MILLIS_RE => qr/^(?:0|[1-9][0-9]{0,4})(?:[.][0-9]{1,3})?$/;

# Up to 5 digits
Readonly my $NON_NEGATIVE_INT_RE => qr/^(?:0|[1-9][0-9]{0,4})$/;

# At least one non-zero digit
Readonly my $NON_ZERO_NUM_RE => qr/[1-9]/;

# Printable ASCII but first character must not be space or '<'
Readonly my $PASSWORD_RE => qr/^(?:[\x21-\x3b\x3d-\x7e][\x20-\x7e]{0,99})?$/;

# See: https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
Readonly my $POSTGRESQL_IDENT_RE    => qr/^[a-z_][a-z0-9_\$]{0,62}$/i;
Readonly my $PROFILE_NAME_RE        => qr/^[a-z0-9]$|^[a-z0-9][a-z0-9_-]{0,30}[a-z0-9]$/i;
Readonly my $RELAXED_DOMAIN_NAME_RE => qr/^[.]$|^.{2,254}$/;
Readonly my $TEST_ID_RE             => qr/^[0-9a-f]{16}$/;
Readonly my $USERNAME_RE            => qr/^[a-z0-9-.@]{1,50}$/i;

sub joi {
    return JSON::Validator::Joi->new;
}

sub new {
    my ( $type ) = @_;

    my $self = {};
    bless( $self, $type );

    return ( $self );
}

sub api_key {
    return joi->string->regex( $API_KEY_RE );
}
sub batch_id {
    return joi->integer->positive;
}
sub client_id {
    return joi->string->regex( $CLIENT_ID_RE );
}
sub client_version {
    return joi->string->regex( $CLIENT_VERSION_RE );
}
sub domain_name {
    return joi->string->regex( $RELAXED_DOMAIN_NAME_RE );
}
sub ds_info {
    return joi->object->strict->props(
        digest => joi->string->regex($DIGEST_RE)->required,
        algorithm => joi->integer->min(0)->required,
        digtype => joi->integer->min(0)->required,
        keytag => joi->integer->min(0)->required,
    );
}
sub ip_address {
    return joi->string->regex( $IPADDR_RE );
}
sub nameserver {
    return joi->object->strict->props(
            ns => joi->string->required,
            ip => ip_address()
    );
}
sub priority {
    return joi->integer;
}
sub profile_name {
    return joi->string->regex( $PROFILE_NAME_RE );
}
sub queue {
    return joi->integer;
}
sub test_id {
    return joi->string->regex( $TEST_ID_RE );
}
sub language_tag {
    return joi->string->regex( $LANGUAGE_RE );
}
sub username {
    return joi->string->regex( $USERNAME_RE );
}
sub jsonrpc_method {
    return joi->string->regex( $JSONRPC_METHOD_RE );
}

=head1 UNTAINT INTERFACE

This module contains a set of procedures for validating and untainting strings.

    use Zonemaster::Backend::Validator qw( :untaint );

    # prints "untainted: sqlite"
    if ( defined ( my $value = untaint_engine_type( 'sqlite' ) ) ) {
        print "untainted: $value\n";
    }

    # does not print anything
    if ( defined ( my $value = untaint_engine_type( 'Excel' ) ) ) {
        print "untainted: $value\n";
    }

These procedures all take a possibly tainted single string argument.
If the string is accepted an untainted copy of the string is returned.

=cut

sub untaint_abs_path {
    my ( $value ) = @_;
    return _untaint_pred( $value, \&file_name_is_absolute );
}

=head2 untaint_engine_type

Accepts the strings C<"MySQL">, C<"PostgreSQL"> and C<"SQLite">,
case-insensitively.

=cut

sub untaint_engine_type {
    my ( $value ) = @_;
    return _untaint_pat( $value , $ENGINE_TYPE_RE );
}

=head2 untaint_ip_address

Accepts an IPv4 or IPv6 address.

=cut

sub untaint_ip_address {
    my ( $value ) = @_;
    return untaint_ipv4_address( $value ) // untaint_ipv6_address( $value );
}

=head2 untaint_ipv4_address

Accepts an IPv4 address.

=cut

sub untaint_ipv4_address {
    my ( $value ) = @_;
    if ( $value =~ /($IPV4_RE)/
        && Zonemaster::Engine::Net::IP::ip_is_ipv4( $value ) )
    {
        return $1;
    }
    return;
}

=head2 untaint_ipv6_address

Accepts an IPv6 address.

=cut

sub untaint_ipv6_address {
    my ( $value ) = @_;
    if ( $value =~ /($IPV6_RE)/
        && Zonemaster::Engine::Net::IP::ip_is_ipv6( $value ) )
    {
        return $1;
    }
    return;
}

=head2 untaint_host

Accepts an LDH domain name or an IPv4 or IPv6 address.

=cut

sub untaint_host {
    my ( $value ) = @_;
    return untaint_ldh_domain( $value ) // untaint_ip_address( $value );
}

=head2 untaint_ldh_domain

Accepts an LDH domain name.

=cut

sub untaint_ldh_domain {
    my ( $value ) = @_;
    return _untaint_pat( $value, $LDH_DOMAIN_RE1, $LDH_DOMAIN_RE2 );
}

=head2 untaint_locale_tag

Accepts a locale tag.

=cut

sub untaint_locale_tag {
    my ( $value ) = @_;
    return _untaint_pat( $value, $LOCALE_TAG_RE );
}

sub untaint_mariadb_database {
    my ( $value ) = @_;
    return _untaint_pat( $value, $MARIADB_IDENT_RE, $MARIADB_DATABASE_LENGTH_RE );
}

sub untaint_mariadb_user {
    my ( $value ) = @_;
    return _untaint_pat( $value, $MARIADB_IDENT_RE, $MARIADB_USER_LENGTH_RE );
}

sub untaint_password {
    my ( $value ) = @_;
    return _untaint_pat( $value, $PASSWORD_RE );
}

sub untaint_strictly_positive_int {
    my ( $value ) = @_;
    return _untaint_pat( $value, $NON_NEGATIVE_INT_RE, $NON_ZERO_NUM_RE );
}

sub untaint_strictly_positive_millis {
    my ( $value ) = @_;
    return _untaint_pat( $value, $MILLIS_RE, $NON_ZERO_NUM_RE );
}

sub untaint_postgresql_ident {
    my ( $value ) = @_;
    return _untaint_pat( $value, $POSTGRESQL_IDENT_RE );
}

sub untaint_non_negative_int {
    my ( $value ) = @_;
    return _untaint_pat( $value, $NON_NEGATIVE_INT_RE );
}

sub untaint_profile_name {
    my ( $value ) = @_;
    return _untaint_pat( $value, $PROFILE_NAME_RE );
}

sub _untaint_pat {
    my ( $value, @patterns ) = @_;

    for my $pattern ( @patterns ) {
        if ( $value !~ /($pattern)/ ) {
            return;
        }
    }

    $value =~ qr/(.*)/;
    return $1;
}

sub _untaint_pred {
    my ( $value, $predicate ) = @_;

    if ( $predicate->( $value ) ) {
        $value =~ qr/(.*)/;
        return $1;
    }
    else {
        return;
    }
}

1;
