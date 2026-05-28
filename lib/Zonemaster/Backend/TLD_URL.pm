package Zonemaster::Backend::TLD_URL;

=head1 Zonemaster::Backend::TLD_URL

This Perl module is the backend for the RPCAPI method "get_tld_url"

=cut

use strict;
use warnings;
use 5.14.2;

use HTTP::Tiny;
use JSON::PP qw(decode_json);
use Readonly;

# Zonemaster Modules
use Zonemaster::Engine;
use Zonemaster::Engine::Recursor;
use Zonemaster::Backend;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::Validator qw[ untaint_tld_block untaint_tld_url_no_path untaint_tld_url_with_path untaint_tld_url_string ];
use Zonemaster::Backend::Errors;

Readonly my $IANA_RDAP_URL_BASE         => "https://rdap.iana.org/domain";
Readonly my $DNS_NAME_BASE_TXT_RECORD   => "_url._zonemaster";
Readonly my $SOURCE_BACKEND_CONF_STR    => "BACKEND CONF";
Readonly my $SOURCE_TXT_RECORD_STR      => "TXT RECORD";
Readonly my $SOURCE_IANA_RDAP_STR       => "IANA RDAP";

=head2 process ($self, $domain)

Processes the domain name ($domain) for Zonemaster::Backend::RPCAPI::get_tld_url
and returns a complete hash reference to be returned by the RPCAPI.
See L<domain name|https://github.com/zonemaster/zonemaster/blob/master/docs/public/configuration/tld-url-specification.md>
for a specification of the features implemented in this module.

=cut

sub process {    
    my ( $self, $domain ) = @_;
    
    my %result;
    my $timeout = $self->{config}->TLD_URL_SETTINGS_lookup_timeout;
    my $include_source = $self->{config}->TLD_URL_SETTINGS_include_source;
    my $enable_tld_url = $self->{config}->TLD_URL_SETTINGS_enable_tld_url;
    my %overrides = $self->{config}->TLD_URL_OVERRIDE;
    my @labels = split( /\./, $domain );
    my $tld = $labels[$#labels]; # Empty if $domain is root '.'

    # Empty response if the function is not enabled
    unless ( $enable_tld_url ) {
        $result{tld} = $tld if defined $tld and $tld ne '';
        return \%result;
    }

    # Empty response if the domain is the root zone
    if ( $domain eq '.' ) {
        return \%result;
    }

    # Empty response if the domain is just a TLD
    if ( scalar @labels == 1 ) {
        $result{tld} = $tld;
        return \%result;
    }

    # Check any override from the configuration
    my $href_override_result = url_from_override( $domain, $tld, $include_source, \%overrides );
    return $href_override_result if %$href_override_result;

    # Do a lookup of "_url._zonemaster.$tld"
    my $href_txt_record_result = url_from_txt_record( $domain, $tld, $timeout, $include_source );
    return $href_txt_record_result if %$href_txt_record_result;
    
    # Do an IANA RDAP lookup
    my $href_rdap_lookup_result = url_from_rdap ( $tld, $timeout, $include_source );
    return $href_rdap_lookup_result if %$href_rdap_lookup_result;

    $result{tld} = $tld;
    return \%result;
}

=head2 url_from_override ($dom, $tld, $include_source, $href_or)

Used by subroutine "process" to do the "dirty work" to process
any overrides in the configuration.

The following variables are mandatory in the call:

=over 8

=item * The domain name to be processed ($dom)

=item * The TLD extracted from the domain name ($tld)

=item * Boolean value whether source of URL should be indicated in the result ($include_source)

=item * Reference of a HASH of the override data (if any) from the configuration file ($href_or)

=back

A HASH reference ready to be sent by the RPCAPI is returned. Or empty then not to be sent.

=cut

sub url_from_override {
    my ($dom, $tld, $include_source, $href_or) = @_;
    my $url;
    my %result;
    
    if ( exists $$href_or{$tld} ) {

        if ( untaint_tld_block( $$href_or{$tld} ) ) {
            $result{tld} = $tld;
        } else {
            $url = $$href_or{$tld};
            $url = $url . '/' if untaint_tld_url_no_path( $url );
            $url =~ s/\Q[DOMAIN]\E/$dom/; # If any "[DOMAIN]"
            $result{tld} = $tld;
            $result{url} = $url;
            $result{source} = $SOURCE_BACKEND_CONF_STR if $include_source;
        }
    }
    return \%result;
}

=head2 url_from_txt_record ($dom, $tld, $timeout, $include_source)

Used by subroutine "process" to do the "dirty work" to process
the TXT lookup and the postprocessing of it.

The following variables are mandatory in the call:

=over 8

=item * The domain name to be processed ($dom)

=item * The TLD extracted from the domain name ($tld)

=item * The time limit for the lookup ($timeout)

=item * Boolean value whether source of URL should be indicated in the result ($include_source)

=back

A HASH reference ready to be sent by the RPCAPI is returned. Or empty then not to be sent.

=cut

sub url_from_txt_record {
    my ( $dom, $tld, $timeout, $include_source ) = @_;
    my $url;
    my %result;
    my $name =  $DNS_NAME_BASE_TXT_RECORD . '.' . $tld;
    my $packet;
    
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        $packet = Zonemaster::Engine::Recursor->recurse( $name, 'TXT' );
        alarm 0;
    };
    # Use $packet if defined
    if ( $packet and $packet->rcode eq q{NOERROR} ) {
        my @rrs = $packet->get_records_for_name( q{TXT}, $name );
        my @txt_rdata = map { $_->txtdata() } @rrs;
        if ( scalar ( @txt_rdata ) == 1 ) { # Ignore all if more than one
	        my $data = $txt_rdata[0];
            if ( untaint_tld_block( $data ) ) { # "[BLOCK]"
                $result{tld} = $tld;
            } elsif ( untaint_tld_url_no_path( $data ) ) { # URL without path
                $result{tld} = $tld;
                $result{url} = $data . '/';
                $result{source} = $SOURCE_TXT_RECORD_STR if $include_source;
            } elsif ( untaint_tld_url_string( $data ) ) { # URL with path and possible "[DOMAIN]"
                $data =~ s/\Q[DOMAIN]\E/$dom/;  # If any "[DOMAIN]"
                $result{tld} = $tld;
                $result{url} = $data;
                $result{source} = $SOURCE_TXT_RECORD_STR if $include_source;
            }
        }
    }
    return \%result;
}

=head2 url_from_rdap ($tld, $timeout, $include_source )

Used by subroutine "process" to do the "dirty work" to process
the IANA RDAP lookup and the postprocessing of it.

The following variables are mandatory in the call:

=over 8


=item * The TLD extracted from the domain name ($tld)

=item * The time limit for the lookup ($timeout)

=item * Boolean value whether source of URL should be indicated in the result ($include_source)

=back

A HASH reference ready to be sent by the RPCAPI is returned. Or empty then not to be sent.

=cut

sub url_from_rdap {
    my ( $tld, $timeout, $include_source ) = @_;
    my $url = $IANA_RDAP_URL_BASE . '/' . $tld;
    my $response;
    my @links = ();
    my $link = '';
    my %result;
    
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        $response = HTTP::Tiny->new->get($url);
        alarm 0;
    };
    if ($@) {
        if ( $@ eq "alarm\n" ) {
            handle_exception( "Timeout looking $url up" );
        } else {
            handle_exception( "Unexpected error looking $url up: $@" );
        }
    }
    if ($response->{success}) {
        my $data = decode_json($response->{content});
        @links = map { $_->{href} } grep { ($_->{rel} // '') eq 'related' } @{ $data->{links} // [] };
    };
    if (scalar @links > 0) {
        $links[0] = $links[0] . '/' if untaint_tld_url_no_path( $links[0] );
        $link = $links[0] if untaint_tld_url_with_path( $links[0] );
        if ( $link ) {
            $result{tld} = $tld;
            $result{url} = $link;
            $result{source} = $SOURCE_IANA_RDAP_STR if $include_source;
        }
    }
    return \%result;
}

1;
