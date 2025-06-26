package Zonemaster::Backend::Validator;

our $VERSION = '0.1.0';

use strict;
use warnings;
use 5.14.2;

use Exporter qw( import );
use File::Spec::Functions qw( file_name_is_absolute );
use JSON::Validator::Joi;
use Readonly;
use Locale::TextDomain qw[Zonemaster-Backend];
use Net::IP::XS;
use Zonemaster::Engine::Logger::Entry;
use Zonemaster::Engine::Normalization qw( normalize_name trim_space );
use Zonemaster::LDNS;

our @EXPORT_OK = qw(
  untaint_abs_path
  untaint_bool
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
  check_domain
  check_ip
  check_profile
  check_language_tag
);

our %EXPORT_TAGS = (
    untaint => [
        qw(
          untaint_abs_path
          untaint_bool
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
    format => [
        qw(
            check_domain
            check_ip
            check_profile
            check_language_tag
        )
    ]
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
Readonly my $LANGUAGE_RE                => qr/^[a-z]{2}$/;
Readonly my $LDH_DOMAIN_RE1             => qr{^[a-z0-9_./-]{1,253}[.]?$}i;
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

# Boolean
Readonly my $BOOL_TRUE_RE           => qr/^(true|yes)$/i;
Readonly my $BOOL_FALSE_RE          => qr/^(false|no)$/i;
Readonly my $BOOL_RE                => qr/^$BOOL_TRUE_RE|$BOOL_FALSE_RE$/i;

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
    return {
        type => 'string',
        format => 'domain',
    };
}
sub ds_info {
    return {
        type => 'object',
        additionalProperties => 0,
        required => [ 'digest', 'algorithm', 'digtype', 'keytag' ],
        properties => {
            digest => {
                type => 'string',
                pattern => $DIGEST_RE,
                'x-error-message' => N__ 'Invalid digest format'
            },
            algorithm => {
                type => 'number',
                minimum => 0,
                'x-error-message' => N__ 'Algorithm must be a positive integer'
            },
            digtype => {
                type => 'number',
                minimum => 0,
                'x-error-message' => N__ 'Digest type must be a positive integer'
            },
            keytag => {
                type => 'number',
                minimum => 0,
                'x-error-message' => N__ 'Keytag must be a positive integer'
            }
        }
    };
}
sub ip_address {
    return {
        type => 'string',
        format => 'ip',
    };
}
sub nameserver {
    return {
        type => 'object',
        required => [ 'ns' ],
        additionalProperties => 0,
        properties => {
            ns => domain_name,
            ip => ip_address
        }
    };
}
sub priority {
    return joi->integer;
}
sub profile_name {
    return {
        type => 'string',
        format => 'profile',
    };
}
sub queue {
    return joi->integer;
}
sub test_id {
    return joi->string->regex( $TEST_ID_RE );
}
sub language_tag {
    return {
        type => 'string',
        format => 'language_tag',
    };
}
sub username {
    return joi->string->regex( $USERNAME_RE );
}
sub jsonrpc_method {
    return joi->string->regex( $JSONRPC_METHOD_RE );
}

=head1 FORMAT INTERFACE

This module contains a set of procedures for validating data types.
The C<check_*> procedures take the value to validate and potential extra
arguments and return either undef if the validation succeeded or the reason of
the failure.

    use Zonemaster::Backend::Validator qw( :format );

    # prints "invalid value: The domain name character(s) are not supported"
    if ( defined ( my $error = check_domain( 'not a domain' ) ) ) {
        print "invalid value: $error\n";
    } else {
        print "value is valid\n";
    }

    # prints "value is valid"
    if ( defined ( my $error = check_domain( 'zonemaster.net' ) ) ) {
        print "invalid value: $error\n";
    } else {
        print "value is valid\n";
    }

=cut

=head2 formats($config)

Returns a hashref to be used with the L<"format" method in JSON::Validator|JSON::Validator::Schema/formats>.
The keys are the names of the custom formats, supports: C<domain>,
C<language_tag>, C<ip> and C<profile>.

The method takes a L<Config|Zonemaster::Backend::Config> object as argument.

=cut

sub formats {
    my ( $config ) = @_;
    return {
        domain => \&check_domain,
        language_tag => sub { check_language_tag( @_, $config->LANGUAGE_locale ) },
        ip => \&check_ip,
        profile => sub { check_profile( @_, ( $config->PUBLIC_PROFILES, $config->PRIVATE_PROFILES ) ) },
    };
}

=head2 check_domain(%value)

Validates a L<domain name|https://github.com/zonemaster/zonemaster/blob/master/docs/public/using/backend/rpcapi-reference.md#domain-name>.

=cut

sub check_domain {
    my ( $domain ) = @_;

    if ( !defined( $domain ) ) {
        return N__ 'Domain name required';
    }

    my ( $errors, $_domain ) = normalize_name( trim_space( $domain ) );

    if ( @{$errors} ) {
        return $errors->[0]->message;
    }

    return undef
}

=head2 check_language_tag($value, %locales)

Validates a L<https://github.com/zonemaster/zonemaster/blob/master/docs/public/using/backend/rpcapi-reference.md#language-tag>.

=over

=item %locales

A hash of configured locales, as returned by L<Zonemaster::Backend::Config::LANGUAGE_locale>.

=back

=cut

sub check_language_tag {
    my ( $language, %locales ) = @_;

    my @error;

    if ( $language !~ $LANGUAGE_RE ) {
        return N__ 'Invalid language tag format';
    }
    elsif ( !exists $locales{$language} ) {
        return N__ "Unkown language string";
    }

    return undef;
}

=head2 check_ip($value)

Validates an L<IP address|https://github.com/zonemaster/zonemaster/blob/master/docs/public/using/backend/rpcapi-reference.md#ip-address>.

=cut

sub check_ip {
    my ( $ip ) = @_;

    return N__ 'Invalid IP address' unless untaint_ip_address($ip) ;

    return undef

}

=head2 check_profile($value, %profiles)

Validates a L<profile name|https://github.com/zonemaster/zonemaster/blob/master/docs/public/using/backend/rpcapi-reference.md#profile-name>.

=over

=item %profiles

A hash of configured profiles, as returned by L<Zonemaster::Backend::Config::PUBLIC_PROFILES>.

=back

=cut

sub check_profile  {
    my ( $profile, %profiles ) = @_;

    if ( $profile !~ $PROFILE_NAME_RE ) {
        return N__ "Invalid profile format";
    }

    if ( !exists $profiles{ lc($profile) } ) {
        return N__ "Unknown profile";
    }
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
        && Net::IP::XS::ip_is_ipv4( $value ) )
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
        && Net::IP::XS::ip_is_ipv6( $value ) )
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

sub untaint_bool {
    my ( $value ) = @_;

    my $ret;
    $ret = 1 if defined _untaint_pat( $value, $BOOL_TRUE_RE );
    $ret = 0 if defined _untaint_pat( $value, $BOOL_FALSE_RE );
    return $ret;
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
