package TestDbServer::Schema::Result::Database;
use parent 'DBIx::Class::Core';

__PACKAGE__->table('live_database');
__PACKAGE__->add_columns(qw(database_id name owner create_time expire_time template_id));
__PACKAGE__->set_primary_key('database_id');
__PACKAGE__->belongs_to(template => 'TestDbServer::Schema::Result::Template', 'template_id');

sub real_owner {
    my $self = shift;
    my $dbh = $self->result_source->storage->dbh();
    my $statement = "SELECT pg_roles.rolname FROM pg_database JOIN pg_roles ON pg_database.datdba = pg_roles.oid WHERE pg_database.datname = ?;";
    my $row = $dbh->selectrow_arrayref($statement, undef, $self->name);
    return $row->[0];
}

1;
