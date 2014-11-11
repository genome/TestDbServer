package TestDbServer::Schema::Result::Database;
use parent 'DBIx::Class::Core';

__PACKAGE__->table('live_database');
__PACKAGE__->add_columns(qw(database_id host port name owner create_time expire_time template_id));
__PACKAGE__->set_primary_key('database_id');
__PACKAGE__->belongs_to(template => 'TestDbServer::Schema::Result::Template', 'template_id');

sub real_owner {
    my $self = shift;
    my $dbh = $self->result_source->storage->dbh();
    my $statement = "SELECT rolname FROM pg_database JOIN pg_authid ON pg_database.datdba = pg_authid.oid WHERE pg_database.datname = ?;";
    my $row = $dbh->selectrow_arrayref($statement, undef, $self->name);
    return $row->[0];
}

1;
