package TestDbServer::Command::DeleteDatabase;

use TestDbServer::PostgresInstance;
use TestDbServer::Exceptions;

use Moose;
use namespace::autoclean;

has database_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => (isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );
has host => ( isa => 'Str', is => 'ro', required => 1 );
has port => ( isa => 'Str', is => 'ro', required => 1 );

sub execute {
    my $self = shift;

    my $database = $self->schema->find_database($self->database_id);
    unless ($database) {
        Exception::DatabaseNotFound->throw(name => $self->database_id);
    }

    my $pg = TestDbServer::PostgresInstance->new(
                        name => $database->name,
                        host => $self->host,
                        port => $self->port,
                        owner => $database->owner,
                        superuser => $self->superuser,
                    );

    $pg->dropdb();

    $database->delete();

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
