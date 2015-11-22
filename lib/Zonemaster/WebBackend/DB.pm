package Zonemaster::WebBackend::DB;

our $VERSION = '1.0.4';

use Moose::Role;

use 5.14.2;

use Data::Dumper;

requires 'add_api_user_to_db', 'user_exists_in_db', 'user_authorized', 'test_progress', 'test_results',
  'create_new_batch_job', 'create_new_test', 'get_test_params', 'get_test_history';

sub user_exists {
    my ( $self, $user ) = @_;

    die "username not provided to the method user_exists\n" unless ( $user );

    return $self->user_exists_in_db( $user );
}

sub add_api_user {
    my ( $self, $params ) = @_;

    die "username or api_key not provided to the method add_api_user\n"
      unless ( $params->{username} && $params->{api_key} );

    die "User already exists\n" if ( $self->user_exists( $params->{username} ) );

    my $result = $self->add_api_user_to_db( $params );

    die "add_api_user_to_db not successfull" unless ( $result );

    return $result;
}

sub _get_allowed_id_field_name {
	my ( $self, $test_id ) = @_;
	
    my $id_field;
    if (length($test_id) == 16) {
		$id_field = 'hash_id';
    }
    else {
		if ($test_id <= Zonemaster::WebBackend::Config->force_hash_id_use_in_API_starting_from_id()) {
			$id_field = 'id';
		}
		else {
			die "Querying test results with the [id] field is dissallowed by the current configuration values";
		}
    }
}

# Standatd SQL, can be here
sub get_test_request {
    my ( $self ) = @_;

    my $result_id;
    my $dbh = $self->dbh;
    my ( $id, $hash_id ) = $dbh->selectrow_array(
        q[ SELECT id, hash_id FROM test_results WHERE progress=0 ORDER BY priority ASC, id ASC LIMIT 1 ] );
        
    if ($id) {
		$dbh->do( q[UPDATE test_results SET progress=1 WHERE id=?], undef, $id );

		if ( $id > Zonemaster::WebBackend::Config->force_hash_id_use_in_API_starting_from_id() ) {
			$result_id = $hash_id;
		}
		else {
			$result_id = $id;
		}
	}
   
	return $result_id;
}


no Moose::Role;

1;
